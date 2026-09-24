-- Targeted Edit Mode checks: actual C# Data, real config and the production Panel/Widget controllers.
local registry=require('Core.SystemRegistry')(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('MapArea',require('Game.MapArea.MapAreaSystem'),{'Config'})
registry:Register('Battle',require('Game.Battle.BattleSystem'),{'Config'})
registry:Register('Equipment',require('Game.Equipment.EquipmentSystem'),{'Config'})
registry:Register('UI',require('UI.UISystem'),{'Config'})
local results={};local function test(name,run) run();results[#results+1]='PASS '..name end
local ok,err=xpcall(function()
    registry:Start()
    local data=Services.Adventure;data:Reset(123)
    local battle,eq,areas,ui=registry:Get('Battle'),registry:Get('Equipment'),registry:Get('MapArea'),registry:Get('UI')
    local inventory=eq.data;local party={}
    for i,id in ipairs({1,2,3,6}) do local actor=data:AddPartyActor(i,id);actor:SetMaxHP(battle.stats:MaximumHP(actor));actor:Restore();party[i]=actor end
    eq:Start();local staff,gun=inventory:GetWeaponAt(0),inventory:GetWeaponAt(1)
    test('starter inventory contains physical weapons and two separate loaded spare magazines',function()
        assert(inventory.WeaponCount==2 and inventory.MagazineCount==2 and inventory:CountItem(31)==24)
        assert(not inventory:Equipped(1) and gun.MagazineId==0 and inventory:GetMagazineAt(0).Rounds==12)
    end)
    test('reachable dungeon loot grants once and survives leaving and reentering',function()
        local site={id=77,pointId=11,areaConfigId=1,source={regionId=1,regionConfigId=1,regionType=1,q=0,r=0,height=1,biomeWeights={{regionType=1,weight=1}}}}
        assert(areas:Enter(site,123));eq:InitializeLoot(areas)
        local area,state=areas:ActiveLayout(),areas.data.Active
        assert(state.LootCount==3 and state.LootInitialized)
        for i=0,state.LootCount-1 do
            local loot=state:GetLootAt(i);assert(area:FindPath(area.entryIndex,loot.CellIndex))
            state:DeployMembers({party[1].Id},{loot.CellIndex});areas:RevealSquad(area,state)
            assert(eq:Loot(areas,loot.Id));local count=inventory:CountItem(31)
            assert(not eq:Loot(areas,loot.Id));assert(inventory:CountItem(31)==count)
        end
        assert(inventory:CountItem(11)==1 and inventory:CountItem(12)==1 and inventory.MagazineCount==3)
        assert(areas:Leave());assert(areas:Enter(site,123));eq:InitializeLoot(areas)
        assert(areas.data.Active.LootCount==3 and areas.data.Active:GetLootAt(0).Looted)
        assert(areas:Leave())
    end)
    test('runes compose resolved skills, reject mismatched slots, and return to shared inventory',function()
        assert(eq:Command('equip',1,staff.Id,0,0));assert(eq:Command('attach',1,staff.Id,1,11));assert(eq:Command('attach',1,staff.Id,2,12))
        local skill=battle:Skill(party[1],6)
        assert(skill.range==5 and skill.hitChance==95 and skill.cooldownTurns==2 and skill.maxTargets==3 and math.abs(skill.damageScale-.875)<.00001)
        local revision=inventory.Revision;assert(not eq:Command('attach',1,staff.Id,1,12));assert(inventory.Revision==revision)
        assert(eq:Command('attach',1,staff.Id,1,0));assert(inventory:CountItem(11)==1)
        assert(eq:Command('attach',1,staff.Id,1,11));assert(inventory:CountItem(11)==0)
    end)
    local function arena(weapon,seed)
        data:Reset(seed);party={};inventory=eq.data
        local actor=data:AddPartyActor(1,3);actor:SetMaxHP(100);actor:Restore();party[1]=actor
        eq:Start();staff,gun=inventory:GetWeaponAt(0),inventory:GetWeaponAt(1)
        assert(eq:Command('equip',1,weapon=='staff' and staff.Id or gun.Id,0,0))
        if weapon=='staff' then eq:Grant(11,1);eq:Grant(12,1);assert(eq:Command('attach',1,staff.Id,1,11));assert(eq:Command('attach',1,staff.Id,2,12))
        else assert(eq:Command('attach',1,gun.Id,3,inventory:GetMagazineAt(0).Id)) end
        battle.board=require('Game.Battle.BattleBoard').Create(4,seed,0)
        battle.data:Reset(1,18);battle.data:SetRandomSeed(seed);battle.data:AddUnit(actor,1,0,0)
        for i,position in ipairs({{1,0},{1,1},{2,0}}) do local enemy=battle.data:AddEnemy(100+i,4,position[1],position[2]);enemy:SetMaxHP(100);enemy:Restore() end
        battle:NewRound();assert(battle:Active().Id==1)
        data:BeginEvent(1,1);data:ResolveChoice(1);data:BeginBattle()
        return actor
    end
    test('scatter damages three enemies and precision cooldown advances on own turns only',function()
        local actor=arena('staff',1)
        assert(battle:TrySkill(6,101));assert(actor:GetCooldown(6)==2 and actor.AP==2)
        local damaged=0;for _,u in ipairs(battle:Units()) do if u.Team==2 and u.HP<100 then damaged=damaged+1 end end
        assert(damaged==3,'seeded scatter did not reach all three legal targets')
        assert(not battle:TrySkill(6,101));actor:BeginTurn(4);assert(actor:GetCooldown(6)==1 and not battle:SkillBudget(6))
        actor:BeginTurn(4);assert(actor:GetCooldown(6)==0 and battle:SkillBudget(6))
        assert(not eq:Command('attach',1,staff.Id,1,0),'battle modifications must be rejected')
    end)
    test('burst consumes three rounds, reload spends AP and preserves the old magazine',function()
        local actor=arena('gun',2);local old=inventory:GetMagazine(gun.MagazineId)
        assert(battle:TrySkill(8,101));assert(old.Rounds==9 and actor.AP==1 and actor.MainUsed)
        local rev=inventory.Revision;assert(not battle:TrySkill(9,1));assert(inventory.Revision==rev)
        actor:BeginTurn(4);assert(battle:TrySkill(9,1));assert(actor.AP==2 and not actor.MainUsed)
        assert(old.Rounds==9 and inventory:MagazineWeapon(old.Id)==0 and inventory:GetMagazine(gun.MagazineId).Rounds==12)
        assert(battle:TrySkill(7,101));assert(actor.AP==0 and inventory:GetMagazine(gun.MagazineId).Rounds==11)
        actor:BeginTurn(4);inventory:SpendAmmo(gun.Id,11);local ap=actor.AP
        assert(not battle:TrySkill(7,101));assert(actor.AP==ap)
    end)
    test('framework workbench changes actual equipment and releases its modal pause lease',function()
        data:Reset(31);local actor=data:AddPartyActor(1,3);actor:SetMaxHP(34);actor:Restore();eq:Start();eq:Grant(11,1);eq:Grant(12,1)
        local adapter={};function adapter:SetEquipmentOpen(value) self.open=value end;function adapter:SendCommand(command) assert(command=='snapshot') end
        local panel=ui:Open('EquipmentWorkbench',{demo=adapter})
        assert(adapter.open and Services.UI.IsWorldPaused)
        panel.view.Equip.onClick:Invoke();assert(inventory:Equipped(1).Id==panel.weaponId)
        panel.options[1].view.Button.onClick:Invoke();assert(inventory:GetWeapon(panel.weaponId):GetRune(1)==11)
        panel.view.Socket2.onClick:Invoke();panel.options[1].view.Button.onClick:Invoke();assert(inventory:GetWeapon(panel.weaponId):GetRune(2)==12)
        assert(panel.view.Stats.text:find('95%%') and panel.view.Stats.text:find('CD 2'))
        panel.view.Remove.onClick:Invoke();assert(inventory:CountItem(12)==1)
        ui:Close('EquipmentWorkbench');assert(not adapter.open and not Services.UI.IsWorldPaused)
        panel=ui:Open('EquipmentWorkbench',{demo=adapter});panel.view.Unequip.onClick:Invoke();assert(not inventory:Equipped(1))
        ui:Close('EquipmentWorkbench')
    end)
end,debug.traceback)
registry:Shutdown()
if not ok then error(err,0) end
return table.concat(results,'\n')
