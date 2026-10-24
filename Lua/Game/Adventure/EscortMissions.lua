local Hex=require('Game.Map.HexGrid')
local Escort={};Escort.__index=Escort
function Escort.New(story)
    return setmetatable({story=story,adventure=story.adventure,data=CS.ProjectY.Data.TownMissionData.For(story.data),
        rule=story.rules.config:GetTable('TownMissionSettingsTable'):Get(1),active={},byParty={}},Escort)
end
function Escort:Records()
    if self.revision==self.data.Revision then return self.active end
    self.active={};self.byParty={}
    for i=0,self.data.Count-1 do local record=self.data:GetAt(i)
        if record.State=='active' and record.PartyId>0 then
            self.active[#self.active+1]=record;self.byParty[record.PartyId]=record
        end
    end
    self.revision=self.data.Revision;return self.active
end
function Escort:HasActive() return #self:Records()>0 end
function Escort:ForParty(id) self:Records();return self.byParty[id] end
function Escort:Prepare(siteId)
    local parties=self.adventure.parties;local site=self.adventure.sites[siteId]
    if not site then return nil,'委托所在城镇不存在' end
    if parties.data.Count>=4096 then return nil,'世界队伍数量已达上限' end
    local destinations,path=parties:TownRoute(site)
    if #destinations==0 then return nil,'周围没有可通过陆路抵达的营业城镇' end
    local definition=parties.definitions:Get(self.rule.escortPartyDefinitionId)
    assert(definition.kind=='caravan','Escort party definition must be a caravan')
    return {siteId=siteId,destinationSiteId=destinations[1].id,path=path,definition=definition}
end
function Escort:Start(contract,plan)
    assert(contract.State=='active' and contract.PartyId==0 and contract.SiteId==plan.siteId,'Invalid escort start')
    local adventure=self.adventure;local parties=adventure.parties;local site=adventure.sites[contract.SiteId];local definition=plan.definition
    local party=parties.data:Add(definition.id,site.q,site.r,site.id,(adventure.data.Seed ~ contract.Id*104729) & 0xffffffff)
    party:ConfigureFaction(definition.factionId,site.q,site.r,'caravan')
    adventure.factions:PrepareRoster(party,definition.encounterId)
    party:SetDestination(plan.destinationSiteId);parties:Restock(party)
    assert(parties:ApplyRoute(party,plan.path));party.Travel:SetPaused(true)
    party:SetMission('escort_wait',0,plan.destinationSiteId,self.story.data.Minutes)
    parties.lod:Calibrate(party)
    local members=parties.lod.homeParties[site.id]
    if not members then members={};parties.lod.homeParties[site.id]=members end
    members[#members+1]=party
    self.data:SetEscort(contract.Id,party.Id,plan.destinationSiteId)
    return true
end
function Escort:Find(id)
    local record=self.data:Find(id)
    if not record or record.State~='active' or record.PartyId==0 then return nil,nil,'这份护送委托已不在进行中' end
    local party=assert(self.adventure.parties.data:Find(record.PartyId),'Escort contract has no world party')
    if party.Defeated or party.LivingCount==0 then return nil,nil,'护送商队已被消灭' end
    return record,party
end
function Escort:Attach(id)
    if self.adventure.data.Phase~='map' then return false,'请先返回大地图，在商队附近随行' end
    local record,party,reason=self:Find(id);if not record then return false,reason end
    if party.BattleSiteId>0 then return false,'商队正在交战，请先加入战斗' end
    if not self.adventure.parties:Near(party) then return false,'请先走到护送商队附近' end
    self:Detach();self.data:SetAttached(id)
    self.adventure.parties.data:Close();self.adventure.parties.data:Target(0)
    party:SetMission('escort',0,record.DestinationSiteId,self.story.data.Minutes);party.Travel:SetPaused(false)
    self.adventure.travel.data:Follow(party.Travel);self.adventure.travel.data:SetPaused(false)
    self.adventure.travel.data:Report('正在随护送商队同行；遇敌将一同进入战斗')
    return true
end
function Escort:Detach()
    if self.data.AttachedId==0 then return true end
    self.data:SetAttached(0)
    -- Keep the current partial edge; the player can choose an independent route from its endpoint.
    self.adventure.travel.data:Plan({},{},{},0)
    return true
end
function Escort:Join(id)
    if self.adventure.data.Phase~='map' then return false,'请先返回大地图再加入护送战斗' end
    local record,party,reason=self:Find(id);if not record then return false,reason end
    local conflict=party.BattleSiteId>0 and self.adventure.factions.data:FindConflict(party.BattleSiteId)
    if not conflict or conflict.Phase~='active' then return false,'护送商队当前没有战斗' end
    if self.data.AttachedId~=id and not self.adventure.parties:Near(party) then return false,'请先赶到护送商队附近加入战斗' end
    self.adventure.travel.data:SetPaused(true);self.adventure.parties.data:Close()
    return self.adventure.factions.conflicts:Enter(conflict,party.Id)
end
function Escort:Refresh()
    for _,record in ipairs(self:Records()) do
        local party=assert(self.adventure.parties.data:Find(record.PartyId),'Escort contract has no world party')
        if party.Defeated or party.LivingCount==0 then
            if self.data.AttachedId==record.Id then self:Detach() end
            self.data:Fail(record.Id)
        else
            if self.data.AttachedId==record.Id and self.adventure.data.Phase=='map' then
                self.adventure.travel.data:Follow(party.Travel)
                if party.BattleSiteId>0 then
                    local ok,reason=self:Join(record.Id)
                    if not ok then self:Detach();self.adventure.travel.data:Report(reason) end
                end
            end
            local destination=assert(self.adventure.sites[record.DestinationSiteId]);local travel=party.Travel
            if party.BattleSiteId==0 and not travel.Active and travel.Q==destination.q and travel.R==destination.r then
                local player=self.adventure.travel.data
                if (self.adventure.data.Phase=='map' or self.adventure.data.Phase=='area') and player.Progress==0 and
                    Hex.Distance(player.Q,player.R,destination.q,destination.r)<=self.rule.escortArrivalRadius and
                    self.adventure.parties:Near(party) then
                    if self.data.AttachedId==record.Id then self:Detach() end
                    if record.Progress<record.RequiredCount then self.data:AddProgress(record.Id,record.RequiredCount-record.Progress) end
                    self.data:Ready(record.Id)
                    party:SetMission('trade',0,0,self.story.data.Minutes);party.Travel:SetPaused(false)
                    self.adventure.travel.data:Report('商队已安全抵达，返回发布委托的 NPC 领取奖励')
                end
            end
        end
    end
end
function Escort:Snapshot(id)
    local record,party=self:Find(id);if not record then return nil end
    local near=self.adventure.data.Phase=='map' and self.adventure.parties:Near(party)
    return {partyId=party.Id,destinationSiteId=record.DestinationSiteId,attached=self.data.AttachedId==id,
        waiting=party.Mission=='escort_wait',inBattle=party.BattleSiteId>0,
        canAttach=near and party.BattleSiteId==0,canJoin=near and party.BattleSiteId>0}
end
return Escort
