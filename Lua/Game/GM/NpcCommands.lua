local Life=require('Game.Battle.ActorLife')
-- GM 查询与传送：读取叙事身份/真实占格，不生成替身，不修改 NPC 日程或任务事实。
local Language=require('Language')
local Npcs={};Npcs.__index=Npcs
function Npcs.New(adventure,story) return setmetatable({adventure=adventure,story=story},Npcs) end
local function integer(id) return type(id)=='number' and id%1==0 and id>0 end
function Npcs:Target(id)
    if not integer(id) then return nil,Language.GmNpcInvalidId end
    local definition=self.story.rules.npcs:Find(id)
    if not definition then return nil,string.format(Language.GmNpcUnknown,id) end
    if definition.locationKind=='world_party' then return nil,string.format(Language.GmNpcWorldParty,definition.name) end
    if definition.locationKind=='animal' then return nil,Language.GmNpcAnimalIdentity end
    local actorId=self.story.data:GetValue('recruited:'..id)
    if actorId~=0 then
        for i=0,self.adventure.data.PartyCount-1 do if self.adventure.data:GetPartyAt(i).Id==actorId then
            return nil,string.format(Language.GmNpcRecruited,definition.name,i+1)
        end end
        error('Recruited NPC is missing from the party: '..id)
    end
    if not self.adventure.sites then return nil,Language.GmNpcRequiresWorld end
    if definition.locationKind=='event' then
        local special=self.adventure.specialEvents
        local row=assert(special.byNpc[id],'Event NPC has no special-event binding')
        local outcome=special:Value(row,'outcome')
        local site=special:SiteForNpc(id)
        if not site then
            assert(outcome~=0,'Pending event NPC has no generated site')
            return nil,Language.GmNpcEventEnded
        end
        local available,reason=special:CanEnter(site)
        if not available then return nil,reason end
        return {kind='event',definition=definition,site=site,outcome=outcome}
    end
    assert(definition.locationKind=='town','Unsupported GM NPC location kind')
    local siteId=self.story.npcs.locations[id]
    if not siteId then return nil,string.format(Language.GmNpcTownUnavailable,definition.name) end
    return {kind='town',definition=definition,site=assert(self.adventure.sites[siteId],'NPC placement references an unknown site')}
end
function Npcs:CanTravel(target)
    local data=self.adventure.data
    if self.story.data.DialogueOpen then return false,Language.GmNpcFinishDialogue end
    if data.Phase~='map' and data.Phase~='area' then return false,Language.GmNpcTravelPhase end
    if target and target.kind=='event' and data.Areas.ActiveSiteId~=target.site.id and self.adventure.travel.data.Progress>0 then
        return false,Language.GmNpcFinishTravelStep
    end
    for i=0,data.PartyCount-1 do if Life.Alive(data:GetPartyAt(i)) then return true end end
    return false,Language.GmNpcNoLivingParty
end
function Npcs:LocalNpc(layout,id)
    for _,npc in ipairs(layout.npcs) do if npc.narrativeId==id then return npc end end
    error('Assigned narrative NPC is missing from the layout: '..id)
end
function Npcs:Search(query)
    query=(query or ''):match('^%s*(.-)%s*$'):lower()
    local result={}
    for _,definition in ipairs(self.story.rules.npcs:All()) do
        if query=='' or tostring(definition.id):find(query,1,true) or definition.name:lower():find(query,1,true) then
            local target,reason=self:Target(definition.id)
            local row={id=definition.id,name=definition.name,available=false,body=reason or ''}
            if target then
                local data=self.adventure.data
                local hint=Language.GmNpcTownGoHint
                if target.kind=='event' then
                    local status=target.outcome==0 and Language.GmNpcEventPending or target.outcome==1 and Language.GmNpcEventRescued or Language.GmNpcEventEnded
                    row.body=string.format(Language.GmNpcEventLocation,target.site.name,target.site.q,target.site.r,status)
                    hint=data.Areas.ActiveSiteId==target.site.id and Language.GmNpcEventPresent or Language.GmNpcEventGoHint
                else
                    local schedule=self.story.npcs:Schedule(definition.id)
                    row.body=string.format(Language.GmNpcTownSchedule,target.site.name,schedule.activity)
                    if data.Areas.ActiveSiteId==target.site.id then
                        local layout=self.adventure.areas:ActiveLayout();local npc=self:LocalNpc(layout,definition.id)
                        local live=data.Areas.Active:GetNpcAt(npc.id-1);local cell=layout.cells[live.CellIndex]
                        row.body=string.format(Language.GmNpcTownPosition,row.body,cell.q,cell.r,cell.layer)
                        if not live.Present then reason=Language.GmNpcNotPresent end
                    else row.body=string.format(Language.GmNpcTownAwaitPosition,row.body) end
                end
                if not reason then row.available,reason=self:CanTravel(target) end
                row.body=string.format(Language.GmNpcSearchAction,row.body,row.available and hint or reason)
            end
            result[#result+1]=row
        end
    end
    return result
end
function Npcs:Deployment(layout,state,targetIndex)
    local ids={}
    for i=0,self.adventure.data.PartyCount-1 do local actor=self.adventure.data:GetPartyAt(i);if Life.Alive(actor) then ids[#ids+1]=actor.Id end end
    local footprint=self.adventure.areas:SquadFootprint(layout,ids)
    local enemies=self.adventure.areas:EnemyOccupancy(layout,state)
    local radius=self.story.rules.settings.recruitSearchRadius
    local distance,queue,head={[targetIndex]=0},{targetIndex},1
    while head<=#queue do local index=queue[head];head=head+1
        if distance[index]<radius then for _,cell in ipairs(layout:Neighbors(layout.cells[index])) do if distance[cell.index]==nil then
            distance[cell.index]=distance[index]+1;queue[#queue+1]=cell.index
        end end end
    end
    -- 领队必须与 NPC 沿真实导航相邻；整队占地均须合法，骑乘同样检查完整 footprint。
    local used,cells={},{}
    local function place(member)
        if member>#ids then return true end
        for _,index in ipairs(queue) do
            if member~=1 or distance[index]==1 then
                local parts=footprint(index,member);local valid=parts~=nil
                if parts then for _,part in ipairs(parts) do
                    if used[part] or enemies[part] or state:IsNpcOccupied(part) or layout.cells[part].blocked then valid=false;break end
                end end
                if valid then
                    for _,part in ipairs(parts) do used[part]=true end;cells[member]=index
                    if place(member+1) then return true end
                    for _,part in ipairs(parts) do used[part]=nil end;cells[member]=nil
                end
            end
        end
        return false
    end
    if not place(1) then return nil,Language.GmNpcNoDeployment end
    return {ids=ids,cells=cells}
end
function Npcs:GoTo(id)
    local target,reason=self:Target(id);if not target then return false,reason end
    local ok;ok,reason=self:CanTravel(target);if not ok then return false,reason end
    local adventure=self.adventure;local areas,data=adventure.areas,adventure.data
    if target.kind=='event' then
        if data.Phase=='area' and data.Areas.ActiveSiteId==target.site.id then
            return true,string.format(Language.GmNpcEventHere,target.site.name)
        end
        if data.Phase=='area' then assert(areas:Stop());assert(areas:Leave()) end
        local travel=adventure.travel.data
        travel:Plan({},{},{},0);travel:Relocate(target.site.q,target.site.r);travel:SetPaused(true)
        adventure.fog:Update()
        ok,reason=adventure:EnterSite(target.site.id)
        if not ok then return false,reason end
        return true,string.format(Language.GmNpcEventEntered,target.site.name)
    end
    local entered=false
    if data.Areas.ActiveSiteId~=target.site.id then
        if data.Phase=='area' then assert(areas:Stop());assert(areas:Leave()) end
        assert(areas:Enter(target.site,data.Seed));adventure.equipment:InitializeLoot(areas);entered=true
    end
    local layout,state=areas:ActiveLayout(),data.Areas.Active
    local npc=self:LocalNpc(layout,id);local live=state:GetNpcAt(npc.id-1)
    if not live.Present then return false,Language.GmNpcNotPresent end
    local deployment;deployment,reason=self:Deployment(layout,state,live.CellIndex)
    if not deployment then return false,entered and string.format(Language.GmNpcEnteredFailure,target.site.name,reason) or reason end
    state:SetInteraction(0,0);state:Stop();state:DeployMembers(deployment.ids,deployment.cells)
    areas:RevealSquad(layout,state)
    return true,string.format(Language.GmNpcTeleported,target.definition.name)
end
return Npcs
