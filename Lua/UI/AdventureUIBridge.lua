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
        local parties=main:Get('Adventure').parties
        if parties.data.IsOpen and not ui:IsOpen('WorldParty') then ui:Open('WorldParty',{demo=demo})
        elseif not parties.data.IsOpen and ui:IsOpen('WorldParty') then ui:Close('WorldParty') end
        local camp=main:Get('Adventure').camp
        if camp.data.IsOpen and data.Phase~='map' then camp:Close() end
        if camp.data.IsOpen and not ui:IsOpen('Camp') then ui:Open('Camp',{demo=demo})
        elseif not camp.data.IsOpen and ui:IsOpen('Camp') then ui:Close('Camp') end
        local dialogue=main:Get('Narrative').data.DialogueOpen
        if dialogue and not ui:IsOpen('Dialogue') then ui:Open('Dialogue',{demo=demo})
        elseif not dialogue and ui:IsOpen('Dialogue') then ui:Close('Dialogue') end
        if data.Phase~='map' and data.Phase~='area' and ui:IsOpen('MissionJournal') then ui:Close('MissionJournal') end
        if data.Phase=='area' and not dialogue then
            local state=data.Areas.Active;local missions=main:Get('Narrative').townMissions
            if state.InteractionKind==2 then
                local npc=main:Get('MapArea'):ActiveLayout().npcs[state.InteractionId]
                if not npc.narrativeId and not npc.facilityId and missions:HasPublisher(data.Areas.ActiveSiteId,missions:NpcId(npc)) and not ui:IsOpen('MissionJournal') then
                    ui:Open('MissionJournal',{demo=demo,townSiteId=data.Areas.ActiveSiteId,townNpcId=missions:NpcId(npc)})
                end
            end
        end
        local shop=main:Get('Adventure').shop
        if shop.data.IsOpen and (data.Phase~='area' or shop.data.Active.SiteId~=data.Areas.ActiveSiteId) then shop:Close() end
        if shop.data.IsOpen and not ui:IsOpen('Shop') then ui:Open('Shop',{demo=demo})
        elseif not shop.data.IsOpen and ui:IsOpen('Shop') then ui:Close('Shop') end
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
