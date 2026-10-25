-- 复用 GameBootstrap 的常驻 LuaEnv；返回值为调用方须立即读取并释放的显示快照。
-- Only retain a change fingerprint; full snapshots and one-shot visual events are never cached.
local pausedPoll
local function requiredFields(...)
    local values=table.pack(...)
    for i=1,values.n do assert(values[i]~=nil,'Paused snapshot requires public state field '..i) end
    values.n=nil;return values
end
local function pausedState(adventure)
    local data,travel=adventure.data,adventure.travel.data
    if data.Phase~='map' or not travel.Paused then return nil end
    local narrative,factions=adventure.narrative.data,adventure.factions.data
    local state=requiredFields(adventure.map,data,travel.Revision,adventure.parties.data.Revision,adventure.parties.data.Clock,
        data.Equipment.Revision,adventure.water.data.Revision,narrative.Revision,narrative.Minutes,factions.Revision,
        adventure.player.Coins,adventure.player.Level,data.JournalCount,data.ResultText,data.PartyCount,
        adventure.characterSaves.Status or '',adventure.characterSaves.HasSave,adventure.battle.vfxSequence or 0)
    local function actorState(actor)
        local values=requiredFields(actor.Id,actor.TemplateId,actor.Team,actor.HP,actor.MaxHP,actor.AP,actor.Q,actor.R,
            actor.Guard,actor.Moved,actor.MainUsed,actor.ActionSequence,actor.MovementSequence,
            actor.Growth.Revision,actor.Effects.Revision,actor.CustomizationJson,actor.TraitCount,
            actor.AnimalSpeciesId,actor.AnimalOwnerId,actor.AnimalBond,actor.TameRetryTurns)
        for _,value in ipairs(values) do state[#state+1]=value end
        for i=0,actor.TraitCount-1 do state[#state+1]=actor:GetTraitAt(i) end
    end
    for i=0,data.PartyCount-1 do
        local actor=data:GetPartyAt(i);actorState(actor)
        local mount=actor.MountedAnimal;state[#state+1]=mount~=nil
        if mount then actorState(mount) end
    end
    state[#state+1]=factions.SiteCount
    for i=0,factions.SiteCount-1 do state[#state+1]=factions:GetSiteAt(i).Revision end
    return state
end
local function unchanged(state)
    if not pausedPoll or not state or #pausedPoll~=#state then return false end
    for i,value in ipairs(state) do if value~=pausedPoll[i] then return false end end
    return true
end
return function(command, a, b, c)
    local adventure = require('Main'):Get('Adventure')
    if command~='snapshot' then pausedPoll=nil
    elseif unchanged(pausedState(adventure)) then return {unchanged=true}
    else pausedPoll=nil end
    if command=='visual_effect_catalog' then return require('Game.Presentation.VisualEffectCatalog').Snapshot(adventure.config) end
    if command=='campaign_saves' then return CS.ProjectY.Data.CampaignSaves.List(adventure.characterSaves) end
    if command=='menu_load' then
        if type(b)~='string' or b=='' then return nil,{error='请选择存档'} end
        local ok,reason=require('Game.Adventure.CharacterSave').Read(adventure,b)
        if not ok then return nil,{error=reason} end
        require('Game.Presentation.VisualEffects').Clear(adventure.battle)
        return adventure:MapSnapshot(),adventure:Snapshot()
    end
    if command=='menu_start' then
        local seed=tonumber(b)
        if not seed or not math.tointeger(seed) or seed<0 or seed>4294967295 then return nil,{error='种子须为 0 至 4294967295 的整数'} end
        if a~=2500 and a~=10000 and a~=30000 and a~=100000 then return nil,{error='请选择有效的世界大小'} end
        b=seed
    end
    if command=='menu_start' or command=='campaign_start' or command=='start' or command=='start_story' then
        local reason=require('Game.Adventure.CampaignCreation').Check(adventure)
        if reason then return nil,{error=reason} end
    end
    if command=='menu_start' then
        -- Synchronous callers share the same preparation/commit contract as the loading driver.
        local creation=require('Game.Adventure.CampaignCreation')
        local accepted,job=pcall(creation.New,adventure,tostring(b),a,c)
        if not accepted then return nil,{error=tostring(job)} end
        while true do
            local done,map=creation.Step(job)
            if done then return map,creation.Commit(job) end
        end
    end
    if command == 'campaign_start' then
        local size=a and a>0 and a or 10000
        assert(size==2500 or size==10000 or size==30000 or size==100000,'无效远征规模')
        adventure:Start(CS.ProjectY.Data.ExpeditionPersistence.RandomSeed(),3,size)
        require('Game.Presentation.VisualEffects').Clear(adventure.battle)
        CS.ProjectY.Data.ExpeditionPersistence.ResetProfile(adventure.player,60)
        return adventure:MapSnapshot(),adventure:Snapshot()
    end
    if command == 'start' then adventure:Start(a);require('Game.Presentation.VisualEffects').Clear(adventure.battle); return adventure:MapSnapshot(), adventure:Snapshot() end
    if command == 'start_story' then adventure:Start(nil,adventure.narrative.rules.settings.demoRecipeId);require('Game.Presentation.VisualEffects').Clear(adventure.battle); return adventure:MapSnapshot(),adventure:Snapshot() end
    if command == 'load_characters' or command == 'campaign_continue' then
        local ok,reason=require('Game.Adventure.CharacterSave').Read(adventure)
        if ok then require('Game.Presentation.VisualEffects').Clear(adventure.battle) end
        local snapshot=adventure:Snapshot();snapshot.error=ok and '' or reason
        return adventure:MapSnapshot(),snapshot
    end
    if command == 'area_layout' then return require('Main'):Get('MapArea'):LayoutSnapshot(adventure.water) end
    if command == 'area_state' then return adventure.data.Areas.Active end
    if command == 'presentation' then return require('Game.Rendering.MapPresentation').Snapshot(require('Main'):Get('Config')) end
    local previousArea=adventure.data.Areas.ActiveSiteId
    local ok, reason
    if command == 'torch_toggle' then ok,reason=require('Game.Adventure.Torch').Toggle(adventure)
    elseif command == 'camp_open' then ok,reason=adventure.camp:Open()
    elseif command == 'camp_close' then ok,reason=adventure.camp:Close()
    elseif command == 'camp_upgrade' then ok,reason=adventure.camp:Upgrade(a,b)
    elseif command == 'camp_produce' then ok,reason=adventure.camp:Produce(a,b)
    elseif command == 'camp_claim' then ok,reason=adventure.camp:Claim(a,b)
    elseif command == 'camp_deposit' then ok,reason=adventure.camp:Deposit(a,b,c)
    elseif command == 'camp_withdraw' then ok,reason=adventure.camp:Withdraw(a,b,c)
    elseif command == 'camp_wait' then ok,reason=adventure.camp:Wait(a,b)
    elseif command:sub(1,6)=='water_' then ok,reason=adventure.water:Command(command,a,b)
    elseif command:sub(1,6)=='world_' then ok,reason=adventure.parties:Command(command,a,b,c)
    elseif command == 'shop_open' then ok,reason=adventure.shop:Open(a,b)
    elseif command == 'shop_buy' then ok,reason=adventure.shop:Buy(a,b,c)
    elseif command == 'shop_close' then ok,reason=adventure.shop:Close()
    elseif command == 'dialogue_choose' then ok,reason=adventure.narrative.dialogue:Choose(a,b)
    elseif command == 'dialogue_interject' then ok,reason=adventure.narrative.dialogue:Interject(a,b,c)
    elseif command == 'dialogue_close' then ok,reason=adventure.narrative.dialogue:Close()
    elseif command == 'mission_accept' then ok,reason=adventure.narrative:Accept(a)
    elseif command == 'mission_claim' then ok,reason=adventure.narrative:Claim('mission',a)
    elseif command == 'quest_claim' then ok,reason=adventure.narrative:Claim('quest',a)
    elseif command == 'town_mission_accept' then ok,reason=adventure.narrative.townMissions:Accept(a)
    elseif command == 'town_mission_claim' then ok,reason=adventure.narrative.townMissions:Claim(a)
    elseif command == 'town_mission_attach' then ok,reason=adventure.narrative.townMissions.escort:Attach(a)
    elseif command == 'town_mission_detach' then ok,reason=adventure.narrative.townMissions.escort:Detach()
    elseif command == 'town_mission_join' then ok,reason=adventure.narrative.townMissions.escort:Join(a)
    elseif command == 'save_characters' then ok,reason=require('Game.Adventure.CharacterSave').Write(adventure)
    elseif command == 'visit' then ok, reason = adventure:Visit(a)
    elseif command:sub(1,7)=='travel_' then ok,reason=adventure.travel:Command(command,a)
    elseif command == 'choose' then ok, reason = adventure:Choose(a)
    elseif command == 'return' then ok, reason = adventure:ReturnToMap()
    elseif command == 'snapshot' then ok = true
    elseif command == 'growth_attribute' then ok,reason = adventure.growth:InvestAttribute(a,b)
    elseif command == 'growth_talent' then ok,reason = adventure.growth:InvestTalent(a,b)
    elseif command == 'growth_skill' then ok,reason = adventure.growth:Learn(a,b)
    elseif command == 'growth_profession' then ok,reason = adventure.growth:ChangeProfession(a,b)
    elseif command == 'character_skill' then ok,reason=adventure.characterSkills:Use(a,b,c)
    elseif command:sub(1,3)=='gm_' then ok,reason=require('Main'):Get('GM'):Execute(command:sub(4),a,b)
    elseif command:sub(1,5)=='area_' then ok,reason=adventure:AreaCommand(command,a,b)
    else ok, reason = adventure:BattleCommand(command, a, b) end
    if adventure.narrative then adventure.narrative:Refresh() end
    local snapshot = adventure:Snapshot()
    snapshot.unchanged=false
    snapshot.visualEffects=require('Game.Presentation.VisualEffects').Drain(adventure.battle)
    snapshot.audioEvents=require('Game.Presentation.AudioEvents').Drain(adventure.battle)
    snapshot.gmTeleport=command=='gm_goto_npc' and (ok or previousArea~=adventure.data.Areas.ActiveSiteId)
    snapshot.error = ok and '' or reason
    pausedPoll=pausedState(adventure)
    return snapshot
end
