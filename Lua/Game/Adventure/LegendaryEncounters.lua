-- Configured identities; mutable progress remains in NarrativeData and WorldPartyData.
local Legends={};Legends.__index=Legends
function Legends.New(parties)
    local self=setmetatable({parties=parties,byUnit={}},Legends)
    self.definitions=parties.adventure.config:GetTable('LegendaryEncounterTable')
    for _,row in ipairs(self.definitions:All()) do
        local party=parties.definitions:Get(row.id)
        local encounter=parties.adventure.config:GetTable('CombatEncounterTable'):Get(party.encounterId)
        local npc=parties.adventure.config:GetTable('NpcTable'):Get(row.npcId)
        assert(party.count==1 and npc.locationKind=='world_party' and #encounter.enemyIds==1 and encounter.enemyIds[1]==npc.actorTemplateId,'Legend needs one unique world-party actor')
        assert(not self.byUnit[npc.actorTemplateId],'Legendary actor template reused')
        self.byUnit[npc.actorTemplateId]=row
    end
    return self
end
function Legends:Find(id) return self.definitions:Find(id) end
function Legends:CanTalk(party)
    local adventure=self.parties.adventure
    if adventure.data.Phase~='map' or party.Defeated or party.BattleSiteId>0 or not self.parties:Near(party) then return false,'传奇已不在附近或正在交战' end
    if #adventure.events:LivingParty()==0 then return false,'没有能够交谈的队员' end
    return true
end
function Legends:Finish(partyId,action)
    local party=assert(self.parties.data:Find(partyId),'Dialogue party is missing')
    local row=assert(self:Find(party.DefinitionId));local adventure=self.parties.adventure
    local ok,reason=self:CanTalk(party);if not ok then return false,reason end
    if action=='attack' then
        self.parties.data:Open(party.Id)
        return self.parties:Attack()
    end
    -- Reuse persisted disengagement protection so closing the dialogue does not reopen it next tick.
    self.parties.data:ReleaseParty(party.Id,false,adventure.narrative.data.Minutes+row.contactGraceMinutes)
    self.parties.data:Target(0)
    adventure.travel.data:SetPaused(true)
    return true
end
function Legends:RecordDefeat(actor)
    local row=self.byUnit[actor.TemplateId]
    if row and row.defeatedFlag~='' then self.parties.adventure.narrative.data:SetValue('flag:'..row.defeatedFlag,1) end
end
return Legends
