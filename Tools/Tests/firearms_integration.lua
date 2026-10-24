-- Actual inventory/magazine transactions in an isolated native Edit Mode host.
local registry=require('Core.SystemRegistry')(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('Battle',require('Game.Battle.BattleSystem'),{'Config'})
registry:Register('Equipment',require('Game.Equipment.EquipmentSystem'),{'Config'})
local checks=0
local ok,err=xpcall(function()
    registry:Start()
    local equipment,battle=registry:Get('Equipment'),registry:Get('Battle')
    local adventure=Services.Adventure;adventure:Reset(20261025)
    local actor=adventure:AddPartyActor(1,1);actor.Growth:Initialize(1,0,0,0)
    actor:SetMaxHP(battle.stats:MaximumHP(actor));actor:Restore();equipment:Start()
    local data,rules=equipment.data,equipment.rules
    for id=800,805 do
        data:Clear();local weapon=data:AddWeapon(id);local def=rules.weapons:Get(id)
        assert(equipment:Command('equip',actor.Id,weapon.Id,0,0))
        local mag=rules.magazines:Get(def.magazineItemId)
        local loaded=data:AddMagazine(mag.id,mag.ammoItemId,mag.capacity,mag.capacity)
        local spare=data:AddMagazine(mag.id,mag.ammoItemId,mag.capacity,mag.capacity)
        assert(equipment:Command('attach',actor.Id,weapon.Id,def.socketIds[1],loaded.Id))
        local wrong=rules.magazines:Get(mag.id==811 and 812 or 811)
        local other=data:AddMagazine(wrong.id,wrong.ammoItemId,wrong.capacity,wrong.capacity)
        local revision=data.Revision
        assert(not equipment:Command('attach',actor.Id,weapon.Id,def.socketIds[1],other.Id))
        assert(data.Revision==revision and weapon.MagazineId==loaded.Id)
        local shot=rules:Skill(actor,def.skillIds[1],battle.stats)
        assert(rules:CheckAmmo(actor,shot));rules:Consume(actor,shot)
        local remaining=mag.capacity-shot.shots*shot.ammoPerShot
        assert(loaded.Rounds==remaining)
        local reload=rules:Skill(actor,9,battle.stats)
        assert(rules:CheckAmmo(actor,reload));rules:Consume(actor,reload)
        assert(weapon.MagazineId==spare.Id and loaded.Rounds==remaining and data:MagazineWeapon(loaded.Id)==0)
        data:AddStack(mag.ammoItemId,10)
        assert(equipment:Command('fill',actor.Id,weapon.Id,0,loaded.Id))
        assert(loaded.Rounds==mag.capacity and data:CountItem(mag.ammoItemId)==10-(mag.capacity-remaining))
        for _,sid in ipairs(def.socketIds)do
            local kind=rules.sockets:Get(sid).kind
            for module=813,819 do if rules.runes:Get(module).slotKind==kind then
                data:AddStack(module,1)
                assert(equipment:Command('attach',actor.Id,weapon.Id,sid,module))
                local view=rules:WeaponVisual(weapon);assert(#view.sockets==4)
                local skill=rules:Skill(actor,def.skillIds[1],battle.stats)
                assert(skill.criticalChance>=0 and skill.criticalChance<=100)
                assert(equipment:Command('attach',actor.Id,weapon.Id,sid,0))
                assert(data:CountItem(module)==1);checks=checks+1
            end end
        end
        data:SpendAmmo(weapon.Id,spare.Rounds)
        assert(not rules:CheckAmmo(actor,shot),'Empty loaded magazine must reject firing')
    end
    -- Actual AP + two-shell transaction and multi-target selection for the combat shotgun.
    data:Clear();local weapon=data:AddWeapon(805);assert(equipment:Command('equip',actor.Id,weapon.Id,0,0))
    local mag=data:AddMagazine(812,821,6,6)
    assert(equipment:Command('attach',actor.Id,weapon.Id,rules.weapons:Get(805).socketIds[1],mag.Id))
    battle.board=require('Game.Battle.BattleBoard').Create(4,17,0)
    battle.data:Reset(1,18);battle.data:SetRandomSeed(17);battle.data:AddUnit(actor,1,0,0)
    for i,pos in ipairs({{2,0},{2,1},{1,1}})do
        local enemy=battle.data:AddEnemy(100+i,4,pos[1],pos[2]);enemy:SetMaxHP(500);enemy:Restore()
    end
    assert(loadfile('Tools/Tests/combat_phase_fixture.lua'))()(battle)
    actor:BeginTurn(10)
    local used,reason=battle:TrySkill(1704,101);assert(used,reason)
    assert(mag.Rounds==4 and actor.AP==7 and actor.MainUsed and actor:GetCooldown(1704)==1)
    local damaged=0;for _,enemy in ipairs(battle:Units())do if enemy.Team==2 and enemy.HP<500 then damaged=damaged+1 end end
    assert(damaged>=2,'Shotgun scatter did not reach additional legal targets')
end,debug.traceback)
registry:Shutdown();if not ok then error(err,0)end
return 'PASS 6 native firearms: equip, wrong-magazine atomic rejection, ammo debit, reload/retained rounds, refill, empty-magazine rejection; '..checks..' module installs; shotgun AP/two shells/multi-target combat'
