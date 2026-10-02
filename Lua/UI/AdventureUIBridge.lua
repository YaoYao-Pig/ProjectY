return function(command,demo)
    local main=require('Main');local ui=main:Get('UI');local data=main:Get('Adventure').data
    if command=='gm' then
        if ui:IsOpen('GM') then ui:Close('GM');return end
        ui:Open('GM',{demo=assert(demo),font=demo.MainHudFont})
    elseif command=='skill_atlas' then
        if ui:IsOpen('SkillAtlas') then ui:Close('SkillAtlas');return end
        if data.Phase~='map' and data.Phase~='area' and data.Phase~='battle' then return end
        if data.Phase=='area' then main:Get('MapArea'):Stop() end
        ui:Open('SkillAtlas',{demo=assert(demo)})
    elseif command=='missions' then
        if ui:IsOpen('MissionJournal') then ui:Close('MissionJournal');return end
        if data.Phase~='map' and data.Phase~='area' then return end
        if data.Phase=='area' then main:Get('MapArea'):Stop() end
        ui:Open('MissionJournal',{demo=assert(demo)})
    elseif command=='growth' then
        if ui:IsOpen('CharacterGrowth') then ui:Close('CharacterGrowth');return end
        if data.Phase~='map' and data.Phase~='area' then return end
        if data.Phase=='area' then main:Get('MapArea'):Stop() end
        ui:Open('CharacterGrowth',{demo=assert(demo)})
    elseif command=='sync' then
        if not ui:IsOpen('MainHud') then ui:Open('MainHud',{demo=demo}) end
        local dialogue=main:Get('Narrative').data.DialogueOpen
        if dialogue and not ui:IsOpen('Dialogue') then ui:Open('Dialogue',{demo=demo})
        elseif not dialogue and ui:IsOpen('Dialogue') then ui:Close('Dialogue') end
        local event=data.Phase=='event' or data.Phase=='result'
        if event and not ui:IsOpen('StoryEvent') then ui:Open('StoryEvent',{demo=demo})
        elseif not event and ui:IsOpen('StoryEvent') then ui:Close('StoryEvent') end
        local loot=main:Get('Equipment').worldLoot.session
        if loot.Active and (data.Areas.ActiveSiteId==0 or loot.Area~=data.Areas.Active) then loot:Close() end
        if loot.Pending and data.Phase=='area' and not dialogue then
            ui:Open('Loot',{demo=demo});loot:Present()
        elseif not loot.Active and ui:IsOpen('Loot') then ui:Close('Loot') end
        if ui:IsOpen('AdventureJournal') then ui:Close('AdventureJournal') end
        if ui:IsOpen('BattleHUD') then ui:Close('BattleHUD') end
    else error('Unknown story UI command: '..tostring(command)) end
end
