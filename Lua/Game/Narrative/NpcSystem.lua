local Npcs = {}; Npcs.__index = Npcs
function Npcs.New(story) return setmetatable({story=story,locations={}},Npcs) end
function Npcs:BindWorld(sites)
    self.locations = {}
    for _, row in ipairs(self.story.rules.placements:All()) do
        for _, site in ipairs(sites) do if site.areaConfigId == row.areaId then self.locations[row.npcId] = site.id; break end end
    end
end
function Npcs:Populate(area,site)
    local occupied = {}
    for _, npc in ipairs(area.npcs) do occupied[npc.spawnIndex] = true end
    for _, placement in ipairs(self.story.rules.placements:All()) do if self.locations[placement.npcId] == site.id then
        local definition = self.story.rules.npcs:Get(placement.npcId)
        local template = self.story.rules.config:GetTable('MapAreaTownNpcTable'):Get(definition.townTemplateId)
        local targets = {}
        local function target(facilityId)
            if targets[facilityId] then return targets[facilityId] end
            local facility
            for _, candidate in ipairs(area.facilities) do if candidate.configId == facilityId then facility = candidate; break end end
            assert(facility, 'NPC facility is absent from generated town')
            local door = area.cells[facility.entryIndex]
            local candidates,head,seen={},1,{[door.index]=0}
            for _,cell in ipairs(area:Neighbors(door)) do candidates[#candidates+1]=cell;seen[cell.index]=1 end
            while head<=#candidates do
                local cell=candidates[head];head=head+1
                if not occupied[cell.index] and cell.index ~= area.entryIndex and cell.index ~= facility.approachIndex and cell.interiorId == door.interiorId then
                    occupied[cell.index] = true; targets[facilityId] = cell.index; return cell.index
                end
                if seen[cell.index]<self.story.rules.settings.spawnSearchRadius then for _,nextCell in ipairs(area:Neighbors(cell)) do
                    if not seen[nextCell.index] and nextCell.interiorId==door.interiorId then seen[nextCell.index]=seen[cell.index]+1;candidates[#candidates+1]=nextCell end
                end end
            end
            error('No reachable NPC position by facility '..facilityId)
        end
        local spawn = target(placement.facilityId)
        for _, schedule in ipairs(self.story.rules.schedulesByNpc[definition.id]) do target(schedule.facilityId) end
        area.npcs[#area.npcs+1] = {id=#area.npcs+1,stableId=200000+definition.id,narrativeId=definition.id,templateId=definition.townTemplateId,
            spawnIndex=spawn,route={},stepSeconds=template.stepSeconds,idleSeconds=template.idleSeconds,scheduleTargets=targets}
    end end
end
function Npcs:Schedule(id)
    local minute = self.story.data.Minutes % 1440
    for _, row in ipairs(self.story.rules.schedulesByNpc[id]) do if minute >= row.startMinute and minute < row.endMinute then return row end end
    error('No NPC schedule for current time')
end
function Npcs:ActorName(actor)
    for _,npc in ipairs(self.story.rules.npcs:All()) do
        if self.story.data:GetValue('recruited:'..npc.id)==actor.Id then return npc.name end
    end
end
function Npcs:SyncPresence()
    local story = self.story; local area,state = story.adventure.areas:ActiveLayout(), story.adventure.data.Areas.Active
    local siteId=story.adventure.data.Areas.ActiveSiteId
    local service=story.adventure.factions:ServiceAllowed(siteId)
    for _,npc in ipairs(area.npcs) do
        local present=service
        if npc.narrativeId then
            local recruited=story.data:GetValue('recruited:'..npc.narrativeId)~=0
            if recruited then present=service and story.data.DialogueOpen and story.data.DialogueNpcId==npc.narrativeId
            elseif story.rules.npcs:Get(npc.narrativeId).recruitable then
                present=service and story.adventure.factions:NpcAvailable(siteId,npc.narrativeId)
            end
        end
        state:SetNpcPresent(npc.id,present)
    end
end
function Npcs:MissionMarker(siteId,npc)
    local story=self.story
    local stamp=story.data.Revision..':'..story.adventure.data.Equipment.Revision..':'..story.adventure.player.Coins
    if self.markerStamp~=stamp then self.markerStamp=stamp;self.markers={} end
    local key=siteId..':'..npc.stableId
    if self.markers[key]==nil then
        local marker=story.townMissions:Marker(siteId,npc)
        if npc.narrativeId then marker=math.max(marker,require('Game.Narrative.NpcMissionMarkers').Story(story,npc.narrativeId)) end
        self.markers[key]=marker
    end
    return self.markers[key]
end
function Npcs:Tick(area,state,dt)
    self:SyncPresence()
    local story = self.story
    local ui=story.context.services.UI
    if story.data.DialogueOpen or (ui and ui.IsWorldPaused) then return end
    for _, definition in ipairs(area.npcs) do if definition.narrativeId then
        local npc = state:GetNpcAt(definition.id-1)
        if npc.Present and not (state.InteractionKind == 2 and state.InteractionId == npc.Id) and npc:Due(dt,definition.stepSeconds) then
            local target = definition.scheduleTargets[self:Schedule(definition.narrativeId).facilityId]
            if npc.CellIndex ~= target then
                local function allowed(cell) return (cell.index == npc.CellIndex or not state:IsNpcOccupied(cell.index)) and not state:IsSquadReserved(cell.index) end
                if allowed(area.cells[target]) then
                    local path = area:FindPath(npc.CellIndex,target,allowed)
                    if path and #path > 0 then state:MoveNpc(npc.Id,path[1],0,0) end
                end
            end
        end
    end end
end
function Npcs:PrepareRecruit(id)
    local story = self.story; local definition = story.rules.npcs:Get(id)
    assert(definition.recruitable,'NPC cannot join the party')
    if story.data:GetValue('recruited:'..id)~=0 then return nil,'这位同行者已经入队' end
    if definition.locationKind=='event' then
        local prepared,reason=story.adventure.specialEvents:PrepareRecruit(id)
        if not prepared then return nil,reason end
        assert(prepared.existing and prepared.actorId==10000+id and prepared.actor.Id==prepared.actorId and
            prepared.actor.TemplateId==definition.actorTemplateId and not prepared.actor.Growth.Initialized,'Invalid event recruit identity')
        CS.ProjectY.Data.EncounterRecruitment.Validate(story.adventure.data,prepared.group,prepared.actor)
        prepared.recovery=require('Game.Narrative.EventRecruitRecovery').Prepare(story.adventure,id,prepared.actor)
        return prepared
    end
    local siteId=self.locations[id]
    if not siteId then return nil,'这位同行者尚未出现在世界中' end
    local service,reason=story.adventure.factions:ServiceAllowed(siteId)
    if not service then return nil,reason end
    if not story.adventure.factions:NpcAvailable(siteId,id) then return nil,'据点仍在恢复，这位同行者暂未归来' end
    local actorId = 10000 + id
    local actor = story.adventure.data:PrepareRecruitActor(actorId,definition.actorTemplateId)
    story.adventure.characterAppearances:Party(actor,story.adventure.data.Seed)
    story.adventure.growth:PrepareActor(actor)
    actor:SetMaxHP(story.adventure.battle.stats:MaximumHP(actor)); actor:Restore()
    return {npcId=id,actorId=actorId,actor=actor}
end
function Npcs:PrepareDeployment(recruits)
    local adventure = self.story.adventure
    if adventure.data.Phase == 'map' then return {} end
    local area,state = adventure.areas:ActiveLayout(),adventure.data.Areas.Active
    local ids,cells,occupied = {},{},{}
    for index in pairs(adventure.areas:EnemyOccupancy(area,state)) do occupied[index]=true end
    for i=0,state.MemberCount-1 do
        local id,index = state:GetMemberIdAt(i),state:GetMemberCellAt(i)
        ids[#ids+1],cells[#cells+1] = id,index
        local actor=adventure.areas:PartyActor(id);local anchor=area.cells[index]
        for _,part in ipairs(assert(adventure.battle.stats.animals:Cells(actor,area,anchor.q,anchor.r,anchor.layer))) do occupied[part.index]=true end
    end
    for _, recruit in ipairs(recruits) do
        local queue,head,seen = {state.CellIndex},1,{[state.CellIndex]=0}
        local found
        while head <= #queue and not found do
            local index=queue[head];head=head+1
            if not occupied[index] and not state:IsNpcOccupied(index) and not area.cells[index].blocked then found=index;break end
            if seen[index] < self.story.rules.settings.recruitSearchRadius then for _, cell in ipairs(area:Neighbors(area.cells[index])) do if seen[cell.index] == nil then
                seen[cell.index]=seen[index]+1;queue[#queue+1]=cell.index
            end end end
        end
        if not found then return nil,'附近没有可供新队员站立的位置，请到开阔处再领取' end
        occupied[found]=true;ids[#ids+1]=recruit.actorId;cells[#cells+1]=found
    end
    return {ids=ids,cells=cells}
end
function Npcs:Recruit(prepared)
    local adventure=self.story.adventure
    if prepared.existing then
        CS.ProjectY.Data.EncounterRecruitment.Validate(adventure.data,prepared.group,prepared.actor)
        adventure.growth:PrepareActor(prepared.actor)
        CS.ProjectY.Data.EncounterRecruitment.Transfer(adventure.data,prepared.group,prepared.actor)
        CS.ProjectY.Data.EquipmentCombatState.RefreshMaximum(prepared.actor,adventure.battle.stats:MaximumHP(prepared.actor))
        require('Game.Narrative.EventRecruitRecovery').Apply(adventure,prepared.actor,prepared.recovery)
    else
        adventure.data:AddPreparedRecruit(prepared.actor)
        adventure.equipment.initialLoadouts:Apply(adventure.equipment.data,prepared.actor)
        prepared.actor:SetMaxHP(adventure.battle.stats:MaximumHP(prepared.actor));prepared.actor:Restore()
    end
    self.story.data:SetValue('recruited:'..prepared.npcId,prepared.actorId)
    self.story.adventure.growth:RecordJoined(prepared.actor,'旅途中')
end
function Npcs:ApplyDeployment(deployment)
    if not deployment.ids then return end
    local areas=self.story.adventure.areas;local state=self.story.adventure.data.Areas.Active
    state:Stop();state:DeployMembers(deployment.ids,deployment.cells);areas:RevealSquad(areas:ActiveLayout(),state)
end
return Npcs
