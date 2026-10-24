-- Real actor HP, trauma, disease, skill/config, inventory UI and isolated save service. No Play.
local registry=require('Core.SystemRegistry')(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('MapArea',require('Game.MapArea.MapAreaSystem'),{'Config'})
registry:Register('Battle',require('Game.Battle.BattleSystem'),{'Config'})
registry:Register('Equipment',require('Game.Equipment.EquipmentSystem'),{'Config'})
registry:Register('UI',require('UI.UISystem'),{'Config'})
local results={};local function test(name,fn)
    if BodyHealthValidationSections=='ui_save' and not (name:find('real UI',1,true) or name:find('new saves',1,true))then return end
    fn();results[#results+1]='PASS '..name
end
local state=CS.ProjectY.Data.BodyHealth
local function totals(actor)
    local hp,maximum=0,0
    for i=0,5 do hp=hp+state.HP(actor,i);maximum=maximum+state.MaximumHP(actor,i) end
    assert(hp==actor.HP and maximum==actor.MaxHP,'Actor totals must always equal the six body parts')
end
local ok,err=xpcall(function()
    registry:Start()
    local battle,equipment,ui=registry:Get('Battle'),registry:Get('Equipment'),registry:Get('UI')
    local stats,rules=battle.stats,battle.stats.injuries
    local function actor(id,template,maximum)
        local a=CS.ProjectY.Data.CombatActorData(id,template or 1);a:SetMaxHP(maximum or 100);a:Restore();return a
    end
    test('integer capacities, damage, healing and maximum changes preserve exact body totals',function()
        for _,maximum in ipairs({1,2,6,37,100,999})do
            local a=actor(101,1,maximum);totals(a);assert(a.HP==maximum)
            a:Damage(math.floor(maximum/3));totals(a);a:Heal(2);totals(a)
            a:SetMaxHP(maximum+19);totals(a);a:SetMaxHP(maximum);totals(a)
        end
        local a=actor(102);local expected={10,30,15,15,15,15}
        for i=0,5 do assert(state.MaximumHP(a,i)==expected[i+1])end
        a:Damage(1000);totals(a);assert(a.HP==0 and a:Heal(20)==0)
        a:Restore();assert(a.HP==100);totals(a)
    end)
    test('first zero stays red; a later direct hit disables, with exact overflow and no resurrection',function()
        local a=actor(110)
        assert(state.Hit(a,4,15,1)==15 and state.HP(a,4)==0 and not state.Permanent(a,4));totals(a)
        assert(rules:Rows(a)[5].color=='#D95750','Zero HP alone must be red')
        assert(state.Hit(a,4,3,1)==3 and state.Permanent(a,4) and a.HP==82);totals(a)
        assert(rules:Rows(a)[5].color=='#171A21');a:Heal(1000);assert(a.HP==85 and state.HP(a,4)==0)
        a:Restore();assert(a.HP==85 and state.Permanent(a,4) and a:Heal(1)==0);totals(a)
        local heavy=actor(111);assert(state.Hit(heavy,4,80,1)==80 and heavy.HP==20 and not state.Permanent(heavy,4));totals(heavy)
        for i=0,5 do assert(not state.Permanent(heavy,i),'Overflow must not disable newly emptied parts')end
    end)
    test('every attack deducts part HP even without trauma; low HP and Trauma Strike raise probability',function()
        local source=actor(120,4);local ordinary,strong=battle.effects:Get(1),battle.effects:Get(1901)
        assert(rules:Chance(15,15,1,ordinary)<rules:Chance(2,15,1,ordinary))
        assert(rules:Chance(15,15,1,strong)>rules:Chance(15,15,1,ordinary))
        local a,b=actor(121),actor(122)
        local function roll()local values={80,40};local cursor=0;return function()cursor=cursor+1;return assert(values[cursor])end end
        local amount,injury=rules:DamageHit(source,a,ordinary,1,roll());assert(amount==1 and not injury and state.HP(a,4)==14 and state.Damage(a,4)==0)
        local stronger,strongInjury=rules:DamageHit(source,b,strong,1,roll());assert(stronger==1 and strongInjury.trauma and state.Damage(b,4)>0)
        assert(a.HP==b.HP);totals(a);totals(b)
        local skill=registry:Get('Config'):GetTable('CombatSkillTable'):Get(1630);assert(skill.name=='创伤打击' and skill.effectIds[1]==1901 and skill.cost==2)
        local course=registry:Get('Config'):GetTable('ProfessionSkillTable'):Get(11630);assert(course.professionId==1 and course.skillId==1630)
    end)
    test('periodic and mount damage preserve routing; direct trauma can cause persistent infection',function()
        local source,target=actor(130,4),actor(131);local def={}
        target:SetMaxHP(stats:MaximumHP(target));target:Restore();local partHP=state.HP(target,4)
        for k,v in pairs(battle.effects:Get(1))do def[k]=v end;def.equipmentDamage=0
        local events,rolls={},0;local sequence={80,0,0}
        local effects=require('Game.Battle.GameEffects').New(stats,battle.effects,function(kind)events[#events+1]=kind end,
            {roll=function()rolls=rolls+1;return assert(sequence[rolls])end})
        effects:Execute(def,target,1,source.Id,'source','hit',source,true)
        assert(state.HP(target,4)==partHP-1 and state.Damage(target,4)>0 and target.Effects:Find(11001) and rolls==3);totals(target)
        effects:Clear(target,'battle_end');assert(target.Effects:Find(11001))
        local trauma=state.Damage(target,4);effects:Execute(def,target,2,source.Id,'source','periodic',source,false,nil,true)
        assert(state.Damage(target,4)==trauma and rolls==3);totals(target)
        local mount=actor(132,201);mount:InitializeAnimal(1,17);target:TameAndRide(mount,0)
        local hp=target.HP;effects:Execute(def,target,200,source.Id,'source','mount',source,true)
        assert(target.HP==hp and target.MountedAnimal==nil and rolls==3);totals(target)
    end)
    local data=Services.Adventure;data:Reset(915);equipment:Start()
    local first=data:AddPartyActor(1,1);local second=data:AddPartyActor(2,2)
    for _,a in ipairs({first,second})do
        a.Growth:Initialize(17,0,0,0);a.Growth:JoinProfession(1)
        battle.appearances:Party(a,915);a:SetMaxHP(stats:MaximumHP(a));a:Restore()
    end
    test('warrior course is learnable and Trauma Strike executes through the normal battle transaction',function()
        first.Growth:AddLearningOpportunity(1)
        assert(stats.growth.professions:CanLearn(first,1630,stats,stats.growth.atlas))
        first.Growth:LearnSelected(1630);assert(first.Growth:HasSkill(1630) and first.Growth.PendingCount==0)
        local weapon
        for i=0,equipment.data.WeaponCount-1 do local row=equipment.data:GetWeaponAt(i);if row.ItemId==40 then weapon=row;break end end
        assert(equipment:Command('equip',first.Id,assert(weapon).Id,0,0))
        battle.board=require('Game.Battle.BattleBoard').Create(4,2,0)
        battle.data:Reset(1,18);battle.data:SetRandomSeed(2);battle.data:AddUnit(first,1,0,0)
        local enemy=battle.data:AddEnemy(501,4,1,0);enemy:SetMaxHP(stats:MaximumHP(enemy));enemy:Restore()
        assert(loadfile('Tools/Tests/combat_phase_fixture.lua'))()(battle);assert(battle:Active().Id==first.Id)
        local hp,ap=enemy.HP,first.AP
        assert(battle:TrySkill(1630,enemy.Id));assert(enemy.HP<hp and first.AP==ap-2 and first:GetCooldown(1630)==2)
        totals(enemy);totals(first);battle.data:Clear()
    end)
    test('ordinary healing does not erase trauma; treatment and scheduled recovery only remove trauma',function()
        state.Injure(first,4,1,55);state.ScheduleRecovery(first,4,55,60)
        state.Hit(first,4,2,1);local hp=first.HP;first:Heal(1)
        assert(state.Damage(first,4)==55 and first.HP==hp+1)
        hp=first.HP;local count=equipment.data:CountItem(91)
        assert(equipment:TreatInjury(first.Id,4,1) and first.HP==hp and state.Damage(first,4)==15 and equipment.data:CountItem(91)==count-1)
        state.Injure(first,4,1,10);assert(state.AdvanceRecovery(first,60)==15 and state.Damage(first,4)==10 and first.HP==hp)
        local before=state.Revision(first);assert(not equipment:TreatInjury(999,4,1) and state.Revision(first)==before)
        assert(equipment:TreatInjury(first.Id,4,1));assert(not equipment:TreatInjury(first.Id,4,1));first:Restore();totals(first)
    end)
    test('infection modifiers and medication are real, persistent and transactional',function()
        local speed=stats:Get(first,'speed');assert(battle.gameEffects:Apply(1902,first,first));assert(stats:Get(first,'speed')<speed)
        local medicine=equipment.data:CountItem(190);local hp=first.HP
        assert(equipment:TreatDisease(first.Id,1));assert(not first.Effects:Find(11001) and equipment.data:CountItem(190)==medicine-1 and first.HP==hp)
        assert(stats:Get(first,'speed')==speed and not equipment:TreatDisease(first.Id,1))
        assert(battle.gameEffects:Apply(1902,first,first));assert(not equipment:TreatDisease(first.Id,1) and first.Effects:Find(11001))
        assert(equipment:Grant(190,2))
    end)
    test('real UI scrolls one colored modifier per line and treats diseases without disturbing equipment',function()
        if not first.Effects:Find(11001)then assert(battle.gameEffects:Apply(1902,first,first))end
        state.Injure(first,2,2,80)
        state.Hit(first,3,state.MaximumHP(first,3),1);state.Hit(first,3,1,1)
        local adapter={SetEquipmentOpen=function(self,value)self.open=value end,SendCommand=function(_,command)assert(command=='snapshot')end}
        local panel=ui:Open('Inventory',{demo=adapter});assert(Services.UI.IsWorldPaused)
        local ring;for _,row in ipairs(panel.rows)do if row.itemId==53 then ring=row;break end end
        panel.selected=assert(ring).key;panel:Refresh();panel.view.Equip.onClick:Invoke();assert(equipment.data:Worn(first.Id,'leftRing'))
        panel.view.Unequip.onClick:Invoke();assert(not equipment.data:Worn(first.Id,'leftRing'))
        panel.view.Health.onClick:Invoke();panel.view.HealthPart2.onClick:Invoke();CS.UnityEngine.Canvas.ForceUpdateCanvases()
        assert(panel.view.HealthDetail.text:find('<color=#F19A96>',1,true))
        local scroll=panel.view.HealthDetailsScroll;assert(scroll.content.rect.height>scroll.viewport.rect.height)
        scroll.verticalNormalizedPosition=0;CS.UnityEngine.Canvas.ForceUpdateCanvases();assert(scroll.content.anchoredPosition.y>0)
        panel.view.HealthPart4.onClick:Invoke();CS.UnityEngine.Canvas.ForceUpdateCanvases();assert(panel.view.HealthDetail.rectTransform.anchoredPosition.y<1)
        local format=require('UI.BodyHealthPresenter').ModifierText({{name='A',value=-2,percent=false},{name='B',value=10,percent=true}})
        assert(format:find('#F19A96',1,true) and format:find('#76D6AE',1,true) and format:find('\n',1,true))
        assert(panel.view.HealthDiseases.text:find('伤口感染',1,true) and panel.view.HealthDiseaseTreat.interactable)
        local count=equipment.data:CountItem(190);panel.view.HealthDiseaseTreat.onClick:Invoke();assert(equipment.data:CountItem(190)==count-1 and not first.Effects:Find(11001))
        panel.view.Actor2.onClick:Invoke();assert(panel.actorId==second.Id and panel.view.HealthDiseases.text==require('Language').BodyNoDisease)
        panel.view.HealthBack.onClick:Invoke();assert(panel.view.Character.gameObject.activeSelf)
        panel.view.Close.onClick:Invoke();assert(not Services.UI.IsWorldPaused and not adapter.open)
    end)
    test('new saves retain body HP, permanent injury and disease; legacy migration and bad totals are guarded',function()
        battle.gameEffects:Apply(1902,first,first)
        local service=Services.CharacterSaves;local file=CS.System.IO.File
        local path=service.FilePath:gsub('\\','/'):lower();local temp=CS.System.IO.Path.GetTempPath():gsub('\\','/'):lower()
        assert(path:sub(1,#temp)==temp,'Never write user saves in this test')
        service:Save(data,Services.Player);local original=file.ReadAllText(service.FilePath)
        assert(original:find('"version":23',1,true));local prepared=service:Prepare(equipment.data);local restored=prepared:GetActorAt(0)
        totals(restored);assert(state.Permanent(restored,3) and restored.Effects:Find(11001) and restored.HP==first.HP)
        local bad=original:gsub('"health":(%d+)',function(h)return '"health":'..(tonumber(h)+1)end,1)
        file.WriteAllText(service.FilePath,bad);assert(not pcall(function()service:Prepare(equipment.data)end))
        local legacy=original:gsub('"version":23','"version":21'):gsub('"injuries":(%b[])',function(body)
            return '"injuries":'..body:gsub(',"health":%d+',''):gsub(',"maximum":%d+','')
        end)
        file.WriteAllText(service.FilePath,legacy);prepared=service:Prepare(equipment.data);restored=prepared:GetActorAt(0)
        totals(restored);assert(state.Permanent(restored,3) and state.HP(restored,3)==0 and restored.HP==first.HP)
        local oldest=original:gsub('"version":23','"version":13'):gsub(',"injuries":%b[]','')
        file.WriteAllText(service.FilePath,oldest);prepared=service:Prepare(equipment.data);totals(prepared:GetActorAt(0))
        for i=0,5 do assert(state.Damage(prepared:GetActorAt(0),i)==0 and not state.Permanent(prepared:GetActorAt(0),i))end
        assert(state.Permanent(first,3),'Migration must not mutate live state');file.WriteAllText(service.FilePath,original)
    end)
end,debug.traceback)
registry:Shutdown()
if not ok then error(err,0)end
return table.concat(results,'\n')
