local registry=require('Core.SystemRegistry')(assert(Services))
for _,spec in ipairs({{'Config','Config.ConfigSystem'},{'Battle','Game.Battle.BattleSystem',{'Config'}},
    {'Equipment','Game.Equipment.EquipmentSystem',{'Config'}},{'Growth','Game.Progression.GrowthSystem',{'Battle'}}})do registry:Register(spec[1],require(spec[2]),spec[3])end
local results={};local function test(name,run)run();results[#results+1]='PASS '..name end
local ok,err=xpcall(function()
    registry:Start()
    local config,battle,growth,equipment=registry:Get('Config'),registry:Get('Battle'),registry:Get('Growth'),registry:Get('Equipment')
    local data=Services.Adventure;data:Reset(8642);equipment:Start()
    local actor=data:AddPartyActor(1,1);growth:PrepareActor(actor,1)
    for _,p in ipairs({2,3,5,14})do assert(growth:ChangeProfession(actor.Id,p))end
    local craft=battle.stats.skillCraft;local state=CS.ProjectY.Data.SkillCraftState
    for _,id in ipairs({101,102,103,2301,2401,2411})do actor.Growth:GrantSkill(id)end
    test('native practice preserves every remainder and crosses mastery only at eleven',function()
        for _=1,3 do state.Practice(actor,{1,5,14},1000,craft.maximum)end
        assert(state.Points(actor,1)==1000 and state.Points(actor,5)==1000 and state.Points(actor,14)==1000)
        state.Practice(actor,{1},98999,craft.maximum);assert(craft:Progress(actor,1)==10)
        state.Practice(actor,{1},1,craft.maximum);assert(craft:Progress(actor,1)==11)
        state.Practice(actor,{2,3},200000,craft.maximum)
    end)
    local recipe={name='三途试作',bodyId=103,bodyProfessionId=3,modifierIds={1,6},modifierProfessionIds={1,2}}
    local id
    test('native crafting persists stable identity, rejects duplicate and leaves learning resources intact',function()
        local pending=actor.Growth.PendingCount;local success,why;success,why,id=craft:Save(actor,'map',recipe);assert(success,why)
        assert(id>1000000000 and state.Count(actor)==1 and actor.Growth.PendingCount==pending)
        assert(not craft:Save(actor,'map',recipe))
        recipe.id=id;recipe.name='三途改';assert(craft:Save(actor,'area',recipe));assert(state.Count(actor)==1)
        assert(craft:Recipe(actor,id).name==recipe.name)
        assert(not craft:Save(actor,'battle',recipe))
    end)
    local staff=equipment.data:AddWeapon(103);assert(equipment.data:Equip(actor.Id,staff.Id))
    actor:SetMaxHP(battle.stats:MaximumHP(actor));actor:Restore()
    local enemy=CS.ProjectY.Data.CombatActorData(101,4);enemy:SetMaxHP(1000);enemy:Restore()
    local area=require('Game.MapArea.MapAreaLayout').New({id=999,name='Craft fixture',areaType=1,width=12,height=12,hexRadius=1,visionRadius=9,moveStepSeconds=.1},1,{}, {wallHeight=3})
    for _,cell in ipairs(area.cells)do cell.height=0;cell.blocked=false;cell.blocksSight=false;cell.kind='floor'end
    battle.board=require('Game.Battle.BattleBoard').FromArea(area,4,4,8)
    battle.data:Reset(1,20);battle.data:AddUnit(actor,1,2,4);battle.data:AddUnit(enemy,2,4,4)
    battle.data:BeginDeployment();battle.data:BeginRound();battle.data:AddTurn(actor.Id);battle.data:SelectTurn(0);actor:BeginTurn(10)
    battle.spellcasting:BindBoard(battle);battle.spellcasting:Sync(actor)
    test('real battle resolves a crafted spell, rejects invalid targets for zero cost, commits once',function()
        local skill=battle:Skill(actor,id);assert(skill.crafted and skill.sourceSkillId==103 and skill.cost==4 and skill.castingCost>0)
        local ap,points=actor.AP,CS.ProjectY.Data.SpellcastingState.Current(actor)
        assert(not battle:TrySkill(id,99999));assert(actor.AP==ap and CS.ProjectY.Data.SpellcastingState.Current(actor)==points)
        local success,why=battle:TrySkill(id,enemy.Id);assert(success,why)
        assert(actor.AP==ap-skill.cost and CS.ProjectY.Data.SpellcastingState.Current(actor)==points-skill.castingCost and actor:GetCooldown(id)==skill.cooldownTurns)
        assert(not battle:TrySkill(id,enemy.Id));assert(actor.AP==ap-skill.cost)
    end)
    test('tooltip, discovery and VFX consume explicit static provenance rather than custom handle',function()
        local skill=battle:Skill(actor,id)
        local tip=require('Game.Presentation.SkillTipModel').New(config):Build({skill=skill,name=skill.name,cooldown=actor:GetCooldown(id),available=true},data)
        assert(tip.body:find('三途改',1,true))
        for _,event in ipairs(require('Game.Presentation.VisualEffects').Drain(battle))do assert(event.skillId<1000000000)end
        require('Game.Battle.OpportunityAttacks').Skill(battle,actor,enemy)
        local observation=craft:CaptureUse(actor,id,'combat');assert(#observation.origins==3)
        assert(craft:CaptureUse(actor,id,'deployment')==nil)
    end)
    test('mixed weapon spell cannot skip its catalyst check',function()
        local mixed={name='焰刃试作',bodyId=101,bodyProfessionId=1,modifierIds={3},modifierProfessionIds={3}}
        local success,why,handle=craft:Save(actor,'map',mixed);assert(success,why)
        local skill=battle:Skill(actor,handle);assert(skill.craftDamageType=='fire' and skill.castingCost==1)
        assert(battle.stats.equipment:CheckSkillEquipment(actor,skill,battle.stats))
        local original=battle.stats.equipment.Catalyst
        battle.stats.equipment.Catalyst=function()return nil,'fixture missing catalyst'end
        local allowed=battle.stats.equipment:CheckSkillEquipment(actor,skill,battle.stats)
        battle.stats.equipment.Catalyst=original;assert(not allowed)
        local prepared=battle.gameEffects:Prepare(skill.effectIds[1],actor,enemy,skill)
        assert(prepared.definition.damageType=='fire' and config:GetTable('CombatEffectTable'):Get(skill.effectIds[1]).damageType~='fire')
    end)
    test('a real missed shared course grows both professions once; rejected use grows neither',function()
        actor:BeginTurn(10);actor:SetCooldown(103,0)
        CS.ProjectY.Data.SpellcastingState.Recover(actor,10)
        local before=state.Points(actor,14)
        assert(not battle:TrySkill(103,99999));assert(state.Points(actor,14)==before)
        local original=battle.Skill
        battle.Skill=function(self,source,skillId)local skill=original(self,source,skillId);skill.hitChance=0;return skill end
        local health=enemy.HP;local success,why=battle:TrySkill(103,enemy.Id)
        battle.Skill=original;assert(success,why)
        assert(enemy.HP==health and state.Points(actor,14)==before+500 and state.Points(actor,3)==craft.maximum)
    end)
    SaveCraftActor=actor
end,debug.traceback)
registry:Shutdown();if not ok then error(err,0)end
return table.concat(results,'\n')
