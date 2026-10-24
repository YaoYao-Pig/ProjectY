-- Existing idle Editor, isolated LuaEnv, real Data, temporary save file supplied by caller.
local registry=require('Core.SystemRegistry')(Services)
for _,spec in ipairs({
    {'Config','Config.ConfigSystem'}, {'Condition','Game.Condition.ConditionSystem',{'Config'}},
    {'PlayerModel','Game.PlayerModelSystem',{'Config'}}, {'Map','Game.Map.MapSystem',{'Config'}},
    {'MapArea','Game.MapArea.MapAreaSystem',{'Config'}}, {'Battle','Game.Battle.BattleSystem',{'Config'}},
    {'Equipment','Game.Equipment.EquipmentSystem',{'Config'}}, {'Growth','Game.Progression.GrowthSystem',{'Battle'}},
    {'AdventureEvents','Game.Adventure.EventSystem',{'Battle','PlayerModel','Growth','Equipment'}},
    {'Adventure','Game.Adventure.AdventureSystem',{'Map','MapArea','AdventureEvents','Equipment'}},
    {'Narrative','Game.Narrative.NarrativeSystem',{'Adventure','Condition'}},
}) do registry:Register(spec[1],require(spec[2]),spec[3]) end
local ok,result=xpcall(function()
    registry:Start()
    local adventure,story=registry:Get('Adventure'),registry:Get('Narrative')
    assert(adventure.characterSaves.FilePath:gsub('\\','/'):lower():find('project%-y%-deserter%-'),'Temporary save is required')
    local data=adventure.data;local special=adventure.specialEvents
    local rule=adventure.config:GetTable('SpecialEventTable'):Get(2)
    local world=adventure:BuildWorld(20261024,3,10000)
    local body=CS.ProjectY.Data.BodyHealth;local save=require('Game.Adventure.CharacterSave')
    local function reset(full)
        local fresh={map=world.map,recipe=world.recipe,seed=world.seed,targetCells=world.targetCells,sites={}}
        for i,site in ipairs(world.sites) do fresh.sites[i]=site end
        adventure:Start(20261024,3,10000,fresh)
        if full then
            local actor=data:PrepareRecruitActor(4,1);adventure.characterAppearances:Party(actor,data.Seed)
            adventure.growth:PrepareActor(actor);actor:SetMaxHP(adventure.battle.stats:MaximumHP(actor));actor:Restore();data:AddPreparedRecruit(actor)
        end
    end
    local function start()
        local distant
        for _,cell in ipairs(world.map:GetCells()) do
            if not cell.waterLevel and not special:CanTrigger(301,cell) then distant=cell;break end
        end
        assert(distant and special:CanTrigger(303,distant),'Deserter must also appear far from towns')
        assert(adventure.travel:Trigger(adventure.config:GetTable('WorldTravelEventTable'):Get(303)))
        local site=data.SiteId;assert(data.EventId==303)
        assert(adventure:Choose(3031));assert(data.EventId==304 and adventure.areas:ActiveLayout().configId==61)
        local actor,group=special:FindAlly(rule,data.Areas.Active)
        assert(actor.Id==10302 and actor.Team==4 and actor.HP==math.max(1,math.floor(actor.MaxHP*.35)))
        for _,index in ipairs({4,5,2,3,1}) do assert(body.Damage(actor,index)==30 and body.RecoveryAt(actor,index)==0) end
        local position=actor.Q..':'..actor.R;local hp=actor.HP
        assert(adventure:Choose(3041));assert(data.Phase=='battle')
        assert(not adventure.battle:FindUnit(actor.Id),'Sheltered deserter cannot be targeted or take a turn')
        assert(not adventure.battle.board:Find(actor.Q,actor.R),'Sheltered deserter must be outside the tactical board')
        assert(data.Battle.UnitCount==data.PartyCount+3 and position==actor.Q..':'..actor.R and actor.HP==hp)
        assert(not adventure:Choose(3041),'Repeated choice cannot restart the encounter')
        return actor,group,site
    end
    local function settle(outcome,group)
        if outcome=='victory' then for i=0,group.EnemyCount-1 do local actor=group:GetEnemyAt(i)
            if actor.Team==2 then actor:Damage(actor.HP) end
        end end
        data.Battle:Finish(outcome);adventure:SettleBattle()
        if adventure.equipment.worldLoot.session.Active then adventure:CloseLoot() end
    end
    reset(false)
    local actor,group,site=start();local hp=actor.HP;settle('victory',group)
    assert(story.data:Status('mission',1002)=='ready' and actor.HP==hp)
    story:AdvanceMinutes(4320)
    for _,index in ipairs({4,5,2,3,1}) do assert(body.Damage(actor,index)==30 and body.RecoveryAt(actor,index)==0,'Waiting before joining must not start recovery') end
    local plan=assert(require('Game.Narrative.NarrativeActions').Prepare(story,{11001}))
    for _,index in ipairs({4,5,2,3,1}) do assert(body.RecoveryAt(actor,index)==0,'Recruitment preflight must not change recovery') end
    assert(not actor.Growth.Initialized)
    local joinedAt=story.data.Minutes;assert(story:Claim('mission',1002));assert(not story:Claim('mission',1002))
    assert(data.PartyCount==4 and data:GetPartyAt(3).Id==actor.Id and actor.HP==hp and group.EnemyCount==3)
    for _,index in ipairs({4,5}) do assert(body.RecoveryAt(actor,index)==joinedAt+1440) end
    for _,index in ipairs({2,3}) do assert(body.RecoveryAt(actor,index)==joinedAt+2880) end
    assert(body.RecoveryAt(actor,1)==joinedAt+4320)
    actor:Heal(actor.MaxHP)
    assert(body.Damage(actor,1)==30 and body.Damage(actor,4)==30,'Ordinary HP healing must not erase body injuries')
    story:AdvanceMinutes(720);assert(save.Write(adventure));assert(save.Read(adventure))
    actor=data:GetPartyAt(3)
    assert(actor.Id==10302 and body.RecoveryAt(actor,1)==joinedAt+4320 and body.Damage(actor,4)==30)
    story:AdvanceMinutes(720)
    assert(body.Damage(actor,4)==0 and body.Damage(actor,5)==0 and body.Damage(actor,2)==30 and body.Damage(actor,1)==30)
    story:AdvanceMinutes(1440)
    assert(body.Damage(actor,2)==0 and body.Damage(actor,3)==0 and body.Damage(actor,1)==30)
    story:AdvanceMinutes(1440)
    for index=0,5 do assert(body.Damage(actor,index)==0 and body.RecoveryAt(actor,index)==0) end
    assert(save.Write(adventure));assert(save.Read(adventure));assert(data.PartyCount==4)
    assert(not special:FindAlly(rule,data.Areas.Active),'Recruited deserter must not respawn after loading')
    reset(true);actor,group=start();settle('victory',group)
    local allowed,reason=story:Claim('mission',1002)
    assert(not allowed and reason:find('队伍已满') and story.data:Status('mission',1002)=='ready')
    assert(not actor.Growth.Initialized and body.RecoveryAt(actor,4)==0 and group.EnemyCount==4)
    for _,outcome in ipairs({'defeat','draw'}) do
        reset(false);actor,group,site=start();local originalHP=actor.HP;settle(outcome,group)
        assert(actor.HP==originalHP and data.Phase=='map' and special:Value(rule,'outcome')==2)
        assert(not special:PrepareRecruit(302) and not adventure:EnterSite(site))
        assert(story.data:Status('mission',1002)=='inactive','Failed interception must not open recruitment')
    end
    return 'PASS deserter: unrestricted travel, real five-part injuries, 35% initial HP, sheltered noncombatant, wounded same-actor recruitment, clocks start on joining, healing separation, 1/2/3-day recovery, temporary-save round trips, full-party deferral and unsuccessful rescue'
end,debug.traceback)
registry:Shutdown()
if not ok then error(result) end
return result
