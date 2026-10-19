-- 复用 GameBootstrap 的常驻 LuaEnv；返回值为调用方须立即读取并释放的显示快照。
return function(command, a, b, c)
    local adventure = require('Main'):Get('Adventure')
    if command=='campaign_start' or command=='start' or command=='start_story' then
        local reason
        if adventure.data.Phase~='map' and adventure.data.Phase~='area' then reason='请先结束当前事件或战斗'
        elseif adventure.parties.data.IsOpen then reason='请先结束队伍交互'
        elseif adventure.camp.data.IsOpen then reason='请先关闭营地面板'
        elseif adventure.shop.data.IsOpen then reason='请先关闭商店'
        elseif adventure.narrative.data.DialogueOpen then reason='请先结束对话'
        elseif adventure.equipment.worldLoot.session.Active then reason='请先关闭战利品窗口' end
        if reason then local snapshot=adventure:Snapshot();snapshot.error=reason;return adventure:MapSnapshot(),snapshot end
    end
    if command == 'campaign_start' then
        local size=a and a>0 and a or 10000
        assert(size==2500 or size==10000 or size==30000 or size==100000,'无效远征规模')
        adventure:Start(CS.ProjectY.Data.ExpeditionPersistence.RandomSeed(),3,size)
        CS.ProjectY.Data.ExpeditionPersistence.ResetProfile(adventure.player,60)
        return adventure:MapSnapshot(),adventure:Snapshot()
    end
    if command == 'start' then adventure:Start(a); return adventure:MapSnapshot(), adventure:Snapshot() end
    if command == 'start_story' then adventure:Start(nil,adventure.narrative.rules.settings.demoRecipeId); return adventure:MapSnapshot(),adventure:Snapshot() end
    if command == 'load_characters' or command == 'campaign_continue' then
        local ok,reason=require('Game.Adventure.CharacterSave').Read(adventure)
        local snapshot=adventure:Snapshot();snapshot.error=ok and '' or reason
        return adventure:MapSnapshot(),snapshot
    end
    if command == 'area_layout' then return require('Main'):Get('MapArea'):LayoutSnapshot() end
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
    elseif command:sub(1,6)=='world_' then ok,reason=adventure.parties:Command(command,a,b,c)
    elseif command == 'shop_open' then ok,reason=adventure.shop:Open(a,b)
    elseif command == 'shop_buy' then ok,reason=adventure.shop:Buy(a,b,c)
    elseif command == 'shop_close' then ok,reason=adventure.shop:Close()
    elseif command == 'dialogue_choose' then ok,reason=adventure.narrative.dialogue:Choose(a,b)
    elseif command == 'dialogue_close' then ok,reason=adventure.narrative.dialogue:Close()
    elseif command == 'mission_accept' then ok,reason=adventure.narrative:Accept(a)
    elseif command == 'mission_claim' then ok,reason=adventure.narrative:Claim('mission',a)
    elseif command == 'quest_claim' then ok,reason=adventure.narrative:Claim('quest',a)
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
    snapshot.gmTeleport=command=='gm_goto_npc' and (ok or previousArea~=adventure.data.Areas.ActiveSiteId)
    snapshot.error = ok and '' or reason
    return snapshot
end
