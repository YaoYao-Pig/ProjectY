local Random=require('Game.Map.SeededRandom')
local Hex=require('Game.Map.HexGrid')
local Actions=require('Game.Narrative.NarrativeActions')
local Rewards=require('Game.Narrative.MissionRewards')
local Missions={};Missions.__index=Missions
function Missions.New(story)
    local config=story.rules.config
    local self=setmetatable({story=story,data=CS.ProjectY.Data.TownMissionData.For(story.data),
        definitions=config:GetTable('TownMissionTable'),settings=config:GetTable('TownMissionSettingsTable'):Get(1)},Missions)
    assert(self.settings.minOffers>=1 and self.settings.maxOffers>=self.settings.minOffers and self.settings.maxOffers<=5,'Invalid town mission count range')
    for _,row in ipairs(self.definitions:All()) do
        assert(row.minCount>0 and row.maxCount>=row.minCount,'Invalid town mission objective range')
        if row.kind=='delivery' then assert(config:GetTable('EquipmentItemTable'):Get(row.itemId).kind=='material','Town delivery requires a stackable material')
        else assert((row.kind=='clear' or row.kind=='escort') and row.itemId==0,'Unknown town mission kind') end
        for _,id in ipairs(row.actionIds) do local action=story.rules.actions:Get(id)
            assert((action.kind=='add_coins' or action.kind=='grant_experience') and action.value>0,'Town mission rewards require positive coins or experience')
        end
    end
    self.escort=require('Game.Adventure.EscortMissions').New(story)
    return self
end
function Missions:NpcId(npc) return assert(npc.stableId,'Town NPC requires a stable identity') end
function Missions:EnsureTown()
    local adventure=self.story.adventure
    if adventure.data.Phase~='area' then return end
    local area=adventure.areas:ActiveLayout();local siteId=adventure.data.Areas.ActiveSiteId
    if area.areaType~=adventure.areas.townType or not adventure.factions:ServiceAllowed(siteId) then return end
    local day=math.floor(self.story.data.Minutes/1440)
    if self.data:GetDay(siteId)==day then return end
    local residents={}
    for _,npc in ipairs(area.npcs) do
        if not npc.narrativeId and not npc.facilityId then residents[#residents+1]=self:NpcId(npc) end
    end
    assert(#residents>0,'Town missions require at least one resident')
    local candidates={};local escort=self.escort:Prepare(siteId)
    for _,row in ipairs(self.definitions:All()) do if row.kind~='escort' or escort then candidates[#candidates+1]=row end end
    assert(#candidates>=self.settings.maxOffers,'Town missions require enough non-escort templates for the maximum offer count')
    local random=Random((adventure.data.Seed ~ (siteId*104729) ~ (day*7919)) & 0xffffffff)
    local count=random:Integer(self.settings.minOffers,self.settings.maxOffers)
    self.data:BeginDay(siteId,day)
    for i=1,count do
        local index=random:Integer(1,#candidates);local row=table.remove(candidates,index)
        local npcId=residents[random:Integer(1,#residents)]
        self.data:Add(row.id,siteId,npcId,day,row.itemId,random:Integer(row.minCount,row.maxCount))
    end
end
function Missions:Refresh()
    local adventure=self.story.adventure
    if not adventure.map or (adventure.data.Phase~='map' and adventure.data.Phase~='area') then return end
    self:EnsureTown();self.escort:Refresh()
    for i=0,self.data.Count-1 do local mission=self.data:GetAt(i)
        if mission.State=='active' and self.definitions:Get(mission.DefinitionId).kind=='delivery'
            and self.story:ItemCount(mission.TargetId)>=mission.RequiredCount then
            if mission.Progress<mission.RequiredCount then self.data:AddProgress(mission.Id,mission.RequiredCount-mission.Progress) end
            self.data:Ready(mission.Id)
        end
    end
end
function Missions:NearPublisher(mission)
    local adventure=self.story.adventure;local areas=adventure.data.Areas
    if adventure.data.Phase~='area' or areas.ActiveSiteId~=mission.SiteId then return false,'请回发布委托的城镇，与委托人交谈' end
    local ok,reason=adventure.factions:ServiceAllowed(mission.SiteId);if not ok then return false,reason end
    local state=areas.Active
    if state.InteractionKind~=2 then return false,'请先与发布委托的居民交谈' end
    local npc=adventure.areas:ActiveLayout().npcs[state.InteractionId]
    if self:NpcId(npc)~=mission.NpcId then return false,'请与原来的委托人交谈' end
    local resident=state:GetNpcAt(npc.id-1)
    local path=resident.Present and adventure.areas:ActiveLayout():FindPath(state.CellIndex,resident.CellIndex)
    if not path or #path>1 then return false,'请沿街道靠近委托人后再交谈' end
    return true
end
function Missions:Accept(id)
    self:Refresh()
    local mission=self.data:Find(id)
    if not mission or mission.State~='offered' then return false,'这份委托已刷新或已被接取' end
    local ok,reason=self:NearPublisher(mission);if not ok then return false,reason end
    local row=self.definitions:Get(mission.DefinitionId);local plan
    if row.kind=='escort' then plan,reason=self.escort:Prepare(mission.SiteId);if not plan then return false,reason end end
    self.data:Accept(id)
    if plan then self.escort:Start(mission,plan) end
    self:Refresh();return true
end
function Missions:CanClaim(mission)
    if mission.State~='ready' then return false,'委托目标尚未完成' end
    local row=self.definitions:Get(mission.DefinitionId)
    if row.kind=='delivery' and self.story:ItemCount(mission.TargetId)<mission.RequiredCount then
        return false,'材料不足，请补齐后交付'
    end
    local plan,reason=Actions.Prepare(self.story,row.actionIds)
    return plan~=nil,reason or '',plan
end
function Missions:Claim(id)
    self:Refresh()
    local mission=self.data:Find(id)
    if not mission then return false,'委托不存在' end
    local ok,reason=self:NearPublisher(mission);if not ok then return false,reason end
    local plan;ok,reason,plan=self:CanClaim(mission);if not ok then return false,reason end
    if self.definitions:Get(mission.DefinitionId).kind=='delivery' then
        self.story.adventure.data.Equipment:ConsumeStack(mission.TargetId,mission.RequiredCount)
    end
    local rewards=Actions.Apply(self.story,plan)
    self.data:Complete(id)
    self.story.RewardSettled:Emit({title=self.definitions:Get(mission.DefinitionId).name,kind='town',id=id,rows=rewards})
    return true
end
-- Called only after Narrative has attributed a hostile defeat to the player's side.
function Missions:RecordKill()
    local adventure=self.story.adventure;local site=adventure.sites[adventure.data.Areas.ActiveSiteId]
    local q,r=site and site.q or adventure.travel.data.Q,site and site.r or adventure.travel.data.R
    for i=0,self.data.Count-1 do local mission=self.data:GetAt(i);local row=self.definitions:Get(mission.DefinitionId)
        if mission.State=='active' and row.kind=='clear' then
            local town=assert(adventure.sites[mission.SiteId])
            if Hex.Distance(q,r,town.q,town.r)<=row.radius then
                self.data:AddProgress(mission.Id,1)
                if mission.Progress==mission.RequiredCount then self.data:Ready(mission.Id) end
            end
        end
    end
end
function Missions:HasPublisher(siteId,npcId)
    for i=0,self.data.Count-1 do local mission=self.data:GetAt(i)
        if mission.SiteId==siteId and mission.NpcId==npcId and mission.State~='completed' and mission.State~='failed' then return true end
    end
    return false
end
function Missions:Marker(siteId,npc)
    local result=0;local npcId=self:NpcId(npc)
    for i=0,self.data.Count-1 do local mission=self.data:GetAt(i)
        if mission.SiteId==siteId and mission.NpcId==npcId then
            if mission.State=='ready' and self:CanClaim(mission) then return 2 end
            if mission.State=='offered' then result=1 end
        end
    end
    return result
end
function Missions:PublisherName(mission)
    local layout=self.story.adventure.areas.layouts[mission.SiteId]
    if layout then for _,npc in ipairs(layout.npcs) do if self:NpcId(npc)==mission.NpcId then
        return self.story.rules.config:GetTable('MapAreaTownNpcTable'):Get(npc.templateId).name
    end end end
    return '委托居民'
end
function Missions:Rows(siteId,npcId)
    local result={};local adventure=self.story.adventure
    for i=0,self.data.Count-1 do local mission=self.data:GetAt(i)
        if (not siteId or mission.SiteId==siteId and mission.NpcId==npcId) and (mission.State~='offered' or siteId) then
            local row=self.definitions:Get(mission.DefinitionId);local town=assert(adventure.sites[mission.SiteId]);local objective
            if row.kind=='delivery' then
                local item=self.story.rules.config:GetTable('EquipmentItemTable'):Get(mission.TargetId)
                objective=string.format('交付 %s %d 份（背包 %d 份；交付时扣除）',item.name,mission.RequiredCount,self.story:ItemCount(mission.TargetId))
            elseif row.kind=='clear' then objective=string.format('在 %s 周围 %d 格内击败敌人：%d / %d',town.name,row.radius,mission.Progress,mission.RequiredCount)
            else
                local destination=mission.DestinationSiteId>0 and adventure.sites[mission.DestinationSiteId]
                objective='护送至'..(destination and destination.name or '附近可达城镇')..'。可随商队同行，也可独立行动并在商队遇袭时主动参战。'
            end
            local claimable,reason=false,''
            if mission.State=='ready' then claimable,reason=self:CanClaim(mission) end
            local nearby,nearReason=self:NearPublisher(mission)
            if not nearby then claimable=false;reason=nearReason end
            result[#result+1]={id=-mission.Id,contractId=mission.Id,name=town.name..' · '..row.name,category='town',
                status=mission.State=='offered' and 'inactive' or mission.State,kind=row.kind,claimable=claimable,reason=reason,
                description=row.description,objective=objective,publisher=self:PublisherName(mission),location=town.name,
                rewards=Rewards.Preview(self.story,row.actionIds),turnInHint='完成后回原委托人处交付并领取报酬。',quests={}}
        end
    end
    return result
end
function Missions:ValidateSaved(data,world,parties)
    for i=0,data.Count-1 do local mission=data:GetAt(i);local row=self.definitions:Get(mission.DefinitionId)
        local site=assert(world.sites[mission.SiteId],'存档委托城镇不存在')
        assert(site.areaConfigId and self.story.adventure.areas.generator.definitions:Get(site.areaConfigId).areaType==self.story.adventure.areas.townType,'存档委托地点不是城镇')
        local layout=assert(world.layouts[mission.SiteId],'存档委托城镇布局缺失');local found=false
        for _,npc in ipairs(layout.npcs) do if self:NpcId(npc)==mission.NpcId then found=true;break end end
        assert(found,'存档委托人不存在')
        assert(mission.TargetId==row.itemId and mission.RequiredCount>=row.minCount and mission.RequiredCount<=row.maxCount,'存档委托目标与配置不一致')
        if row.kind=='escort' and mission.State~='offered' then
            local party=parties:Find(mission.PartyId)
            local destination=world.sites[mission.DestinationSiteId]
            assert(party and party.Role=='caravan' and party.DefinitionId==self.settings.escortPartyDefinitionId and party.HomeSiteId==mission.SiteId
                and destination and destination.areaConfigId and self.story.adventure.areas.generator.definitions:Get(destination.areaConfigId).areaType==self.story.adventure.areas.townType,'存档护送商队或目的地失效')
            if mission.State=='active' then assert(party.Mission=='escort' or party.Mission=='escort_wait','进行中护送商队缺少护送状态') end
        else assert(mission.PartyId==0 and mission.DestinationSiteId==0,'非护送委托包含商队引用') end
    end
end
return Missions
