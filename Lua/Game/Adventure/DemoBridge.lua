-- 复用 GameBootstrap 的常驻 LuaEnv；返回值为调用方须立即读取并释放的显示快照。
return function(command, a, b, c)
    local adventure = require('Main'):Get('Adventure')
    if command == 'start' then adventure:Start(a); return adventure:MapSnapshot(), adventure:Snapshot() end
    if command == 'start_story' then adventure:Start(nil,adventure.narrative.rules.settings.demoRecipeId); return adventure:MapSnapshot(),adventure:Snapshot() end
    if command == 'load_characters' then
        local ok,reason=require('Game.Adventure.CharacterSave').Read(adventure)
        local snapshot=adventure:Snapshot();snapshot.error=ok and '' or reason
        return adventure:MapSnapshot(),snapshot
    end
    if command == 'area_layout' then return require('Main'):Get('MapArea'):LayoutSnapshot() end
    if command == 'area_state' then return adventure.data.Areas.Active end
    if command == 'presentation' then return require('Game.Rendering.MapPresentation').Snapshot(require('Main'):Get('Config')) end
    local previousArea=adventure.data.Areas.ActiveSiteId
    local ok, reason
    if command == 'dialogue_choose' then ok,reason=adventure.narrative.dialogue:Choose(a,b)
    elseif command == 'dialogue_close' then ok,reason=adventure.narrative.dialogue:Close()
    elseif command == 'mission_accept' then ok,reason=adventure.narrative:Accept(a)
    elseif command == 'mission_claim' then ok,reason=adventure.narrative:Claim('mission',a)
    elseif command == 'quest_claim' then ok,reason=adventure.narrative:Claim('quest',a)
    elseif command == 'save_characters' then ok,reason=require('Game.Adventure.CharacterSave').Write(adventure)
    elseif command == 'visit' then ok, reason = adventure:Visit(a)
    elseif command == 'choose' then ok, reason = adventure:Choose(a)
    elseif command == 'return' then ok, reason = adventure:ReturnToMap()
    elseif command == 'snapshot' then ok = true
    elseif command == 'growth_attribute' then ok,reason = adventure.growth:InvestAttribute(a,b)
    elseif command == 'growth_talent' then ok,reason = adventure.growth:InvestTalent(a,b)
    elseif command == 'growth_skill' then ok,reason = adventure.growth:Learn(a,b)
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
