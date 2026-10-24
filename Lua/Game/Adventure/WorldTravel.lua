local Hex=require('Game.Map.HexGrid')
local Travel={};Travel.__index=Travel
local function escort(adventure)
    local story=adventure.narrative
    return story and story.townMissions and story.townMissions.escort
end
function Travel.New(adventure)
    local config=adventure.config
    local self=setmetatable({adventure=adventure,data=CS.ProjectY.Data.WorldTravelData.For(adventure.data),
        rule=config:GetTable('WorldTravelTable'):Get(1),terrains={},events=config:GetTable('WorldTravelEventTable')},Travel)
    self.maxStep=self.rule.maxHeightStep
    for _,row in ipairs(config:GetTable('WorldTravelTerrainTable'):All()) do
        assert(not self.terrains[row.regionType],'Duplicate travel terrain');self.terrains[row.regionType]=row
    end
    for _,row in ipairs(self.events:All()) do
        assert((row.eventId>0)~=(row.encounterId>0),'Travel entry needs exactly one event or encounter')
        if row.eventId>0 then config:GetTable('AdventureEventTable'):Get(row.eventId) end
        if row.encounterId>0 then config:GetTable('CombatEncounterTable'):Get(row.encounterId) end
    end
    return self
end
function Travel:Reset(map,sites)
    self.map=map;self.cells=map:GetCells();self.paths=require('Game.Map.MapPathfinder')(map)
    local camp=assert(sites[1]);assert(not map:GetCell(camp.q,camp.r).waterLevel,'Travel camp must be on dry land')
    self.data:Reset(self.adventure.data.Seed,camp.q,camp.r,#sites+1)
end
function Travel:Terrain(cell) return assert(self.terrains[self.map:GetRegion(cell.regionId).regionType],'Missing travel terrain') end
function Travel:Cost(a,b)
    if a.waterLevel or b.waterLevel then return nil end
    local slope=math.abs(a.height-b.height);if slope>self.maxStep then return nil end
    local road=#a.roadIds>0 and #b.roadIds>0
    return (self.rule.minutesPerCell*self:Terrain(b).costMultiplier+slope*self.rule.slopeMinutes)*(road and self.rule.roadMultiplier or 1)
end
function Travel:Allowed()
    if self.adventure.data.Phase~='map' then return false,'请先返回大地图' end
    if self.adventure.parties.data.IsOpen then return false,'请先结束队伍交互' end
    if self.adventure.camp.data.IsOpen or self.adventure.context.services.UI.IsWorldPaused then return false,'请先关闭当前窗口' end
    return true
end
function Travel:Plan(cell,siteId)
    local ok,reason=self:Allowed();if not ok then return false,reason end
    if not cell then return false,'目的地不在地图内' end
    if cell.waterLevel then return false,'目的地位于水域，暂不能步行到达' end
    local start=self.map:GetCell(self.data.AnchorQ,self.data.AnchorR)
    local path=self.paths:FindPath(start,cell,function(a,b)return self:Cost(a,b)end)
    if not path then return false,'没有可通行的陆路，请选择其他目的地' end
    local convoy=escort(self.adventure);if convoy then convoy:Detach() end
    local qs,rs,minutes={},{},{}
    for i=2,#path do qs[#qs+1]=path[i].q;rs[#rs+1]=path[i].r;minutes[#minutes+1]=self:Cost(path[i-1],path[i]) end
    self.data:Plan(qs,rs,minutes,siteId)
    if not self.data.Active then return self:Arrive() end
    return true
end
function Travel:Visit(siteId)
    self.adventure.parties.data:Target(0)
    local site=self.adventure.sites[siteId];if not site then return false,'未知地点' end
    local available,explanation=self.adventure.specialEvents:CanEnter(site)
    if not available then return false,explanation end
    local ok,reason
    if site.factionSite or self.adventure.factions.data:FindConflict(siteId) then ok=true
    elseif self.adventure.areas:AreaId(site) then ok,reason=self.adventure.areas:CanEnter(site) else ok,reason=self.adventure.events:CanVisit(site) end
    if not ok then return false,reason end
    return self:Plan(self.map:GetCell(site.q,site.r),siteId)
end
function Travel:Command(command,value)
    local ok,reason=self:Allowed();if not ok then return false,reason end
    if command=='travel_move' then self.adventure.parties.data:Target(0);return self:Plan(self.cells[value],0)
    elseif command=='travel_pause' then self.data:SetPaused(not self.data.Paused)
    elseif command=='travel_resume' then self.data:SetPaused(false)
    elseif command=='travel_suspend' then self.data:SetPaused(true)
    elseif command=='travel_speed' then
        if value~=1 and value~=2 and value~=4 then return false,'无效时间流速' end
        self.data:SetSpeed(value)
    else error('Unknown travel command: '..command) end
    return true
end
function Travel:Arrive()
    local siteId=self.data.TargetSiteId;self.data:Arrived()
    if siteId>0 then return self.adventure:EnterSite(siteId) end
    return true
end
function Travel:CreateStop(row)
    local stop=self.data:AddStop(row.eventId,row.encounterId);local cell=self.map:GetCell(stop.Q,stop.R)
    local region=self.map:GetRegion(cell.regionId);local x,y,z=self.map:GetCellWorldPosition(stop.Q,stop.R)
    -- Immutable site projection; identity, position and encounter selection are owned by C#.
    local site={id=stop.Id,eventId=stop.EventId,q=stop.Q,r=stop.R,x=x,y=y,z=z,travelStop=true,
        name=row.encounterId>0 and self.adventure.battle.encounters:Get(row.encounterId).name or self.adventure.events.events:Get(row.eventId).name}
    assert(stop.Id==#self.adventure.sites+1,'Travel site IDs must remain contiguous');self.adventure.sites[stop.Id]=site
    return site
end
function Travel:CreateWorldStop(q,r,encounterId)
    local stop=self.data:AddWorldStop(q,r,0,encounterId)
    local x,y,z=self.map:GetCellWorldPosition(q,r)
    local site={id=stop.Id,eventId=0,q=q,r=r,x=x,y=y,z=z,travelStop=true,name=self.adventure.battle.encounters:Get(encounterId).name}
    assert(stop.Id==#self.adventure.sites+1,'World site IDs must remain contiguous')
    self.adventure.sites[stop.Id]=site
    return site
end
function Travel:Trigger(row)
    local site=self:CreateStop(row)
    self.adventure.specialEvents:Discovered(site)
    if row.encounterId==0 then return self.adventure:EnterSite(site.id) end
    return self:EnterBattle(site,row.encounterId)
end
function Travel:EnterBattle(site,encounterId)
    local cell=self.map:GetCell(site.q,site.r);local region=self.map:GetRegion(cell.regionId)
    CS.ProjectY.Data.WorldTravelData.BeginBattle(self.adventure.data,site.id)
    local source={regionId=region.instanceId,regionConfigId=region.configId,regionType=region.regionType,
        q=cell.q,r=cell.r,height=cell.height,biomeWeights=cell.biomeWeights,encounterId=encounterId,
        obstacleChance=self:Terrain(cell).battleObstacleChance,surfaceId=self:Terrain(cell).battleSurfaceId,propIds=self:Terrain(cell).battlePropIds}
    if self.adventure.areas.layouts[site.id] then assert(self.adventure.areas:Activate(site,self.adventure.data.Seed,true))
    else assert(self.adventure.areas:EnterEventBattlefield(site,self.adventure.data.Seed,source)) end
    self.adventure.equipment:InitializeLoot(self.adventure.areas)
    self.adventure.areas:StartBattle(self.adventure.battle,self.adventure.data.Areas.Active:GetEncounterAt(0))
    return true
end
function Travel:Check()
    if #self.adventure.events:LivingParty()==0 then return false end
    if self.data:Roll(100)>self.rule.eventChance then return false end
    local cell=self.map:GetCell(self.data.Q,self.data.R);local kind=self.map:GetRegion(cell.regionId).regionType
    local entries,total={},0
    for _,row in ipairs(self.events:All()) do
        local allowed=#row.regionTypes==0
        for _,region in ipairs(row.regionTypes) do if region==kind then allowed=true;break end end
        if allowed and row.eventId>0 then allowed=self.adventure.events:CanVisit({id=#self.adventure.sites+1,eventId=row.eventId}) end
        if allowed and row.eventId>0 then allowed=self.adventure.specialEvents:CanTrigger(row.eventId,cell) end
        if allowed and row.weight>0 then entries[#entries+1]=row;total=total+row.weight end
    end
    if total==0 then return false end
    local roll=self.data:Roll(total)
    for _,row in ipairs(entries) do roll=roll-row.weight;if roll<=0 then assert(self:Trigger(row));return true end end
    error('Travel weighted pool did not select an entry')
end
function Travel:Tick(dt)
    if self.adventure.data.Phase~='map' or self.data.Paused or self.adventure.parties.data.IsOpen or
        self.adventure.camp.data.IsOpen or self.adventure.context.services.UI.IsWorldPaused then return end
    local budget=dt*self.rule.minutesPerSecond*self.data.Speed
    while budget>0 and self.adventure.data.Phase=='map' and not self.data.Paused do
        local convoy=escort(self.adventure);local attached=convoy and convoy.data.AttachedId>0
        local moving=self.data.Active and not attached
        local spent=moving and self.data:Step(math.min(budget,1)) or math.min(budget,1)
        assert(spent>0,'World clock failed to advance');budget=math.max(0,budget-spent)
        self.adventure.fog:Update()
        self.adventure.narrative:AdvanceMinutes(spent)
        self.adventure.parties:SyncClock()
        if attached then self.adventure.fog:Update() end
        if self.adventure.data.Phase~='map' then return end
        if not attached and self.adventure.parties:CheckContact() then return end
        if moving and self.data.Progress==0 then self.adventure.parties:ReplanPursuit() end
        if self.data.Paused then return end
        if moving and not self.data.Active then
            local ok,reason=self:Arrive();self.data:Report(ok and '已抵达目的地' or reason)
        elseif moving and self.data.Progress==0 then
            while self.data:CheckDue(self.rule.checkMinutes) do if self:Check() then return end end
        end
    end
end
function Travel:Summary()
    local data=self.data;local target=data.TargetSiteId>0 and self.adventure.sites[data.TargetSiteId] or nil
    local convoy=escort(self.adventure);local attached=convoy and convoy.data.AttachedId>0
    if attached then local record=convoy.data:Find(convoy.data.AttachedId);target=self.adventure.sites[record.DestinationSiteId] end
    return {active=data.Active,paused=data.Paused,speed=data.Speed,remaining=data.RemainingMinutes,
        destination=target and (attached and '护送 · ' or '')..target.name or data.Active and '地图位置' or '原地待命',
        terrain=self:Terrain(self.map:GetCell(data.Q,data.R)).name,message=data.Message}
end
function Travel:Snapshot()
    local data=self.data;local x,y,z=self.map:GetCellWorldPosition(data.Q,data.R)
    if data.Active then
        local step=data:GetStepAt(0);local nx,ny,nz=self.map:GetCellWorldPosition(step.Q,step.R);local t=data.Progress
        x,y,z=x+(nx-x)*t,y+(ny-y)*t,z+(nz-z)*t
    end
    local route={}
    for i=0,data.StepCount-1 do local step=data:GetStepAt(i);local px,py,pz=self.map:GetCellWorldPosition(step.Q,step.R)
        route[#route+1]={x=px,y=py,z=pz}
    end
    local result=self:Summary();result.x=x;result.y=y;result.z=z;result.route=route;return result
end
return Travel
