-- Persistent people share real actors; authored NPC projections retain their original recruitment contract.
local Targets={};Targets.__index=Targets

function Targets.New(adventure)
    local self=setmetatable({adventure=adventure,npcByActor={},legendByUnit={},projections={},
        projectionKeys=setmetatable({},{__mode='k'})},Targets)
    local config=adventure.config
    self.npcs=config:GetTable('NpcTable')
    self.residents=config:GetTable('MapAreaTownNpcTable')
    self.mappings=config:GetTable('UnitInspectionNpcTable')
    for _,npc in ipairs(self.npcs:All()) do
        if npc.locationKind=='world_party' then
            assert(not self.legendByUnit[npc.actorTemplateId],'Inspection legendary template is not unique')
            self.legendByUnit[npc.actorTemplateId]=npc
        elseif npc.locationKind~='animal' then self.npcByActor[10000+npc.id]=npc end
    end
    for _,npc in ipairs(self.residents:All()) do
        local mapping=self.mappings:Get(npc.id)
        adventure.battle.stats.units:Get(mapping.unitId)
    end
    return self
end

function Targets:Owned(actor)
    local roster=CS.ProjectY.Data.PartyRoster
    return roster.Find(self.adventure.data,actor.Id)~=nil or
        actor.AnimalOwnerId>0 and roster.Find(self.adventure.data,actor.AnimalOwnerId)~=nil
end

function Targets:Key(actor)
    local person=self.adventure.people and self.adventure.people:ForActor(actor)
    if person then return person.Key end
    local projection=self.projectionKeys[actor]
    if projection then return projection end
    local npc=self.npcByActor[actor.Id] or self.legendByUnit[actor.TemplateId]
    if npc then return 'npc:'..npc.id end
    local adventure=self.adventure;local data=adventure.data
    if data.Phase=='battle' and actor.Id>=101 and actor.Id<=104 and not adventure.battle.board.area then
        return table.concat({'event',data.SiteId,data.EventId,data.ChoiceId,actor.Id},':')
    end
    local duel=CS.ProjectY.Data.ProfessionDuelState
    if duel.Active(data) and actor.Id==9000000+duel.ActorId(data) then
        return table.concat({'duel',data.Areas.ActiveSiteId,math.floor(data.Narrative.Minutes/1440)+1,actor.Id},':')
    end
    return 'actor:'..actor.Id
end

function Targets:Identity(actor) return self:Key(actor),self:Owned(actor) end

function Targets:Name(actor)
    local person=self.adventure.people and self.adventure.people:ForActor(actor)
    if person then return self.adventure.people:Name(person)end
    local npc=self.npcByActor[actor.Id] or self.legendByUnit[actor.TemplateId]
    return npc and npc.name or self.adventure.battle.stats:Template(actor).name
end

function Targets:ProjectNpc(definition,siteId)
    local adventure=self.adventure;local npc=definition.narrativeId and self.npcs:Get(definition.narrativeId)
    if not npc and adventure.people then
        local person=adventure.people:EnsureResident(definition,siteId)
        return {key=person.Key,name=adventure.people:Name(person),actor=person.Actor,owned=person.Joined,kind='resident'}
    end
    local key=npc and 'npc:'..npc.id or table.concat({'resident',siteId,assert(definition.stableId)},':')
    local unitId=npc and npc.actorTemplateId or self.mappings:Get(definition.templateId).unitId
    local actorId=npc and 10000+npc.id or 500000000+definition.stableId
    local actor=npc and CS.ProjectY.Data.PartyRoster.Find(adventure.data,actorId)
    if not actor then
        if self.projectionSeed~=adventure.data.Seed then
            self.projections={};self.projectionSeed=adventure.data.Seed
        end
        actor=self.projections[key]
        if not actor then
            actor=CS.ProjectY.Data.CombatActorData(actorId,unitId)
            local stats=adventure.battle.stats
            -- Birth uses only the world seed and fixed actor ID; future recruitment uses this same identity.
            if stats.growth.profileByUnit[unitId] then adventure.growth:PrepareActor(actor)
            else stats.birth:Initialize(actor,(adventure.data.Seed ~ (siteId*104729)) & 0xffffffff) end
            for _,id in ipairs(stats.units:Get(unitId).traitIds) do actor:AddTrait(id) end
            actor:SetMaxHP(stats:MaximumHP(actor));actor:Restore()
            self.projectionKeys[actor]=key;self.projections[key]=actor
        end
    end
    return {key=key,name=npc and npc.name or self.residents:Get(definition.templateId).name,
        actor=actor,owned=self:Owned(actor),kind=npc and 'npc' or 'resident'}
end

local function visibleCells(layout,state)
    if state.VisibleCount==#layout.cells then return function()return true end end
    local visible={}
    for i=0,state.VisibleCount-1 do visible[state:GetVisibleAt(i)]=true end
    return function(index)return visible[index]==true end
end

function Targets:Rows(includeNpcs)
    local adventure=self.adventure;local data=adventure.data;local rows,seen={},{}
    local function add(actor,kind)
        local key,owned=self:Identity(actor)
        if seen[key] then return end
        seen[key]=true;rows[#rows+1]={key=key,name=self:Name(actor),actor=actor,owned=owned,
            kind=actor.AnimalSpeciesId>0 and 'animal' or owned and 'party' or kind or 'unit'}
    end
    local roster=CS.ProjectY.Data.PartyRoster
    for i=0,roster.Count(data)-1 do
        local actor=roster.At(data,i);add(actor,'party')
        local animal=CS.ProjectY.Data.AnimalCompanionState.Bound(actor)
        if animal then add(animal,'animal') end
    end
    if data.Phase=='battle' then
        local board=adventure.battle.board;local isVisible
        if board.area then isVisible=visibleCells(adventure.areas:ActiveLayout(),data.Areas.Active) end
        for _,actor in ipairs(adventure.battle:Units()) do
            local cell=board.area and board.area:Find(actor.Q,actor.R)
            if not isVisible or cell and isVisible(cell.index) then add(actor) end
        end
    elseif data.Phase=='area' then
        local layout=adventure.areas:ActiveLayout();local state=data.Areas.Active
        local isVisible=visibleCells(layout,state)
        for i=0,state.EncounterCount-1 do
            local group=state:GetEncounterAt(i)
            for j=0,group.EnemyCount-1 do
                local actor=group:GetEnemyAt(j)
                local cell=assert(layout:Find(actor.Q,actor.R),'Inspection target is outside its area')
                if isVisible(cell.index) then add(actor) end
            end
        end
        for i=0,(includeNpcs==false and 0 or state.NpcCount)-1 do
            local live=state:GetNpcAt(i)
            if live.Present and isVisible(live.CellIndex) then
                local row=self:ProjectNpc(assert(layout.npcs[live.Id]),state.SiteId)
                if not seen[row.key] then seen[row.key]=true;rows[#rows+1]=row end
            end
        end
    elseif data.Phase=='map' then
        local parties=adventure.parties
        local contactId=parties.data.ContactId
        -- A legendary dialogue closes the trade panel but retains the validated party identity.
        local story=data.Narrative
        if story.DialogueOpen and story.DialogueNpcId>0 and self.npcs:Get(story.DialogueNpcId).locationKind=='world_party' then
            contactId=story.DialogueLocalNpcId
        elseif adventure.peopleDialogue and adventure.peopleDialogue:Active()then
            contactId=story.DialogueLocalNpcId
        end
        if contactId>0 then
            local party=parties.data:Find(contactId)
            if party and not party.Defeated and parties:Near(party) then
                for i=0,party.MemberCount-1 do add(party:GetMemberAt(i)) end
            end
        end
    end
    return rows
end

function Targets:Find(key)
    if type(key)~='string' then return nil end
    for _,row in ipairs(self:Rows()) do if row.key==key then return row end end
end

return Targets
