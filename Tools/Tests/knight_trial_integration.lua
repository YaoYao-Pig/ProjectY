-- Isolated Edit Mode LuaEnv with real Data. Caller supplies Services and a temporary save path.
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
    local adventure=registry:Get('Adventure');local story=registry:Get('Narrative')
    local file=adventure.characterSaves.FilePath:gsub('\\','/'):lower()
    assert(file:find('project%-y%-knight%-trial%-'),'Integration requires a temporary save path')
    local world=adventure:BuildWorld(20261024,3,10000)
    local special=adventure.specialEvents;local rule=adventure.config:GetTable('SpecialEventTable'):Get(1)
    local travelRow=adventure.config:GetTable('WorldTravelEventTable'):Get(301)
    local save=require('Game.Adventure.CharacterSave');local data=adventure.data
    local function reset(full)
        local fresh={map=world.map,recipe=world.recipe,seed=world.seed,targetCells=world.targetCells,sites={}}
        for i,site in ipairs(world.sites) do fresh.sites[i]=site end
        adventure:Start(20261024,3,10000,fresh)
        if full then
            local actor=data:PrepareRecruitActor(4,1);adventure.characterAppearances:Party(actor,data.Seed)
            adventure.growth:PrepareActor(actor);actor:SetMaxHP(adventure.battle.stats:MaximumHP(actor));actor:Restore();data:AddPreparedRecruit(actor)
        end
    end
    local function open(defer)
        local camp=world.sites[1];local cell=world.map:GetCell(camp.q,camp.r)
        assert(special:CanTrigger(301,cell),'Camp next to market should qualify')
        local far
        for _,candidate in ipairs(world.map:GetCells()) do if not special:CanTrigger(301,candidate) then far=candidate;break end end
        assert(far,'Town filter must exclude distant wilderness')
        assert(adventure.travel:Trigger(travelRow));local site=data.SiteId
        assert(data.Phase=='event' and data.EventId==301)
        assert(not special:CanTrigger(301,cell),'Discovered unique event must leave random pool')
        if defer then
            assert(adventure:Choose(3012));assert(adventure:ReturnToMap())
            local marker
            for _,candidate in ipairs(adventure:Snapshot().sites) do if candidate.id==site then marker=candidate end end
            assert(marker and marker.available,'Deferred invitation must remain visible and enterable on the map')
            assert(adventure:EnterSite(site));assert(data.EventId==301)
        end
        assert(adventure:Choose(3011));assert(data.Phase=='event' and data.EventId==302 and adventure.areas:ActiveLayout().configId==60)
        return site
    end
    local function fight()
        assert(adventure:Choose(3021));assert(data.Phase=='battle')
        local knight,group=special:FindAlly(rule,data.Areas.Active)
        assert(knight.Team==4 and knight.Id==10301 and not knight.Growth.Initialized)
        assert(adventure.battle:IsAllied(knight,data:GetPartyAt(0)))
        assert(adventure.battle.board.aiProfiles[knight.Id].selfPreservation)
        assert(not adventure:Choose(3021),'Double click cannot restart the battle')
        local view=require('Game.Battle.BattleHUDModel').Build(adventure.battle,data)
        assert(view.encounter:find(tostring(knight.HP)..'/'..knight.MaxHP,1,true),'HUD must expose ally survival')
        return knight,group
    end
    local function settle(outcome,knightAlive)
        local knight,group=fight()
        knight:Damage(knightAlive and 7 or knight.HP)
        if outcome=='victory' then for i=0,group.EnemyCount-1 do local actor=group:GetEnemyAt(i)
            if actor.Team==2 then actor:Damage(actor.HP) end
        end end
        -- A branch fixture finishes battle Data; battle command/AI mechanics have their own focused tests.
        adventure.battle.data:Finish(outcome);adventure:SettleBattle()
        if adventure.equipment.worldLoot.session.Active then adventure:CloseLoot() end
        return knight,group
    end
    reset(false)
    local site=open(true)
    assert(adventure:Choose(3022));assert(data.Phase=='result');assert(adventure:ReturnToMap());assert(data.Phase=='map')
    assert(adventure:EnterSite(site));assert(special:BeforeExplore());assert(data.EventId==302)
    local knight,group=settle('victory',true)
    assert(data.Phase=='area' and special:Value(rule,'outcome')==1 and story.data:Status('mission',1001)=='ready')
    local hp=knight.HP;local weapon=data.Equipment:Equipped(knight.Id);assert(weapon and weapon.ItemId==41)
    local condition=adventure.equipment.rules:Condition(weapon)
    local weaponId=weapon.Id;CS.ProjectY.Data.EquipmentCombatState.DamageWeapon(data.Equipment,weaponId,11);local durability=condition.Current
    assert(save.Write(adventure));assert(save.Read(adventure))
    knight,group=special:FindAlly(rule,data.Areas.Active)
    assert(knight.HP==hp and adventure.equipment.rules:Condition(data.Equipment:Equipped(knight.Id)).Current==durability)
    assert(special:BeforeExplore() and data.Phase=='area','Reloading a won trial must not repeat its decision')
    assert(story:Claim('mission',1001));assert(not story:Claim('mission',1001))
    local recruited=data:GetPartyAt(data.PartyCount-1)
    assert(recruited.Id==10301 and recruited.HP==hp and recruited.Growth.CurrentProfessionId==5)
    assert(recruited.Team==1 and group.EnemyCount==3 and data.Equipment:Equipped(10301).Id==weaponId)
    assert(adventure.equipment.rules:Condition(data.Equipment:Equipped(10301)).Current==durability)
    assert(save.Write(adventure));assert(save.Read(adventure));assert(data.PartyCount==4)
    assert(story.data:GetValue('recruited:301')==10301 and not special:FindAlly(rule,data.Areas.Active))
    assert(adventure.areas:Leave());assert(adventure:EnterSite(site));assert(special:BeforeExplore() and data.Phase=='area')
    assert(not special:FindAlly(rule,data.Areas.Active),'Re-entry cannot respawn a recruited knight')
    reset(true);open();knight,group=settle('victory',true)
    local allowed,reason=story:Claim('mission',1001)
    assert(not allowed and reason:find('队伍已满') and story.data:Status('mission',1001)=='ready' and knight.HP>0 and group.EnemyCount==4)
    assert(save.Write(adventure));assert(save.Read(adventure));assert(story.data:Status('mission',1001)=='ready')
    reset(false);open();knight=settle('victory',false)
    assert(knight.HP==0 and special:Value(rule,'outcome')==2 and story.data:Status('mission',1001)=='inactive')
    assert(not special:PrepareRecruit(301));assert(not story:Claim('mission',1001))
    for _,outcome in ipairs({'defeat','draw'}) do
        reset(false);site=open();knight=settle(outcome,true)
        assert(knight.HP==0 and data.Phase=='map' and special:Value(rule,'outcome')==2)
        assert(not adventure:EnterSite(site) and not special:PrepareRecruit(301))
        for _,marker in ipairs(adventure:Snapshot().sites) do if marker.id==site then assert(not marker.available,'Failed trial marker must show that entry is closed') end end
        assert(save.Write(adventure));assert(save.Read(adventure));assert(not adventure:EnterSite(site))
    end
    reset(false);assert(adventure.travel:Trigger(travelRow))
    for i=0,data.PartyCount-1 do local actor=data:GetPartyAt(i);actor:Damage(actor.HP) end
    assert(not adventure:Choose(3011) and data.Phase=='event','All-down party cannot consume scene entry')
    return 'PASS knight trial: town radius/unique discovery, scene choices, autonomous ally/HUD, victory-survival, same-actor wounded recruitment, full-party deferral, defeat/draw execution, dead-victory exclusion, temporary-save round trips and no respawn'
end,debug.traceback)
registry:Shutdown()
if not ok then error(result) end
return result
