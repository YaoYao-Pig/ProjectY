local L=require('Language')
local Hex=require('Game.Map.HexGrid')
local Navigation=require('Game.Adventure.WaterNavigation')
local Water={};Water.__index=Water
function Water.New(adventure)
    return setmetatable({adventure=adventure,data=CS.ProjectY.Data.WaterTravelData.For(adventure.data),
        rule=adventure.config:GetTable('DockSettingsTable'):Get(1)},Water)
end
function Water:Bind(map,sites,reset)
    self.map=map;self.navigation=Navigation.New(map,self.rule);self.paths=require('Game.Map.MapPathfinder')(map)
    self.docks={};self.sites={};self.routeCache={}
    if reset then self.data:Reset() end
    for _,dock in ipairs(map.docks or {}) do
        self.docks[dock.id]=dock
        self.data:EnsureDock(dock.id,dock.initialDamaged,dock.initialThreat and self.rule.threatKills or 0)
    end
    for _,site in ipairs(sites) do if site.source and site.source.dock then self.sites[site.source.dock.id]=site end end
end
function Water:Position(q,r)
    local cell=self.map:GetCell(q,r);local x,y,z=self.map:GetCellWorldPosition(q,r)
    return x,cell.waterLevel or y,z
end
function Water:Path(first,last)
    return self.paths:FindPath(first,last,function(a,b)return self.navigation:Cost(a,b)end)
end
function Water:Route(fromId,toId)
    local key=fromId..':'..toId
    if self.routeCache[key]~=nil then return self.routeCache[key] or nil end
    local a,b=assert(self.docks[fromId]),assert(self.docks[toId])
    local path=self:Path(self.map:GetCell(a.waterQ,a.waterR),self.map:GetCell(b.waterQ,b.waterR))
    self.routeCache[key]=path or false;return path
end
function Water:Service(id)
    local site=self.sites[id]
    if not site then return false,L.WaterNoDock end
    return self.adventure.factions:ServiceAllowed(site.id)
end
function Water:Near(id)
    local a=self.adventure
    if a.data.Phase~='area' or self.data.Mode~='walk' then return false,L.WaterTalkWorker end
    local front=a.areas:ActiveLayout().waterfront
    if not front or front.dockId~=id then return false,L.WaterTalkWorker end
    local ok,reason=self:Service(id);if not ok then return false,reason end
    return a.areas:Interact(2,front.npcId)
end
function Water:Open(id)
    local ok,reason=self:Near(id);if not ok then return false,reason end
    self.data:Open(id);self.adventure.data.Areas.Active:Stop();return true
end
function Water:Close()
    self.data:Close()
    if self.adventure.data.Phase=='area' then self.adventure.areas:CloseInteraction() end
    return true
end
function Water:StopAtCell()
    local travel=self.adventure.travel.data
    if travel.Progress>0 then return false,L.WaterFinishStep end
    travel:Plan({},{},{},0);travel:Arrived();return true
end
function Water:Detach()
    local a=self.adventure
    a.parties.data:Target(0)
    local convoy=a.narrative.townMissions.escort
    if convoy.data.AttachedId>0 then convoy:Detach() end
end
function Water:Depart(dock)
    self:Detach();self:Close()
    assert(self.adventure.areas:Leave())
    local travel=self.adventure.travel.data
    assert(self:StopAtCell());travel:Relocate(dock.waterQ,dock.waterR)
    travel:SetPaused(false);self.adventure.fog:Update()
end
function Water:PreparePort(id)
    local a=self.adventure;local site=assert(self.sites[id]);local layout=a.areas.layouts[site.id]
    if not layout then
        layout=a.areas.generator:Generate(site.areaConfigId,a.data.Seed,site.pointId,site.source,function(area)a.narrative.npcs:Populate(area,site)end)
        a.areas.layouts[site.id]=layout
    end
    assert(layout.waterfront and not layout.cells[layout.waterfront.landingIndex].blocked,'Dock arrival has no safe landing')
    return layout
end
function Water:ApplyPath(path,siteId)
    local qs,rs,minutes={},{},{}
    for i=2,#path do qs[#qs+1]=path[i].q;rs[#rs+1]=path[i].r;minutes[#minutes+1]=assert(self.navigation:Cost(path[i-1],path[i])) end
    self.adventure.travel.data:Plan(qs,rs,minutes,siteId or 0)
    if not self.adventure.travel.data.Active then return self.adventure.travel:Arrive() end
    return true
end
function Water:Plan(cell,siteId)
    local a=self.adventure;local travel=a.travel.data
    if self.data.Mode=='ferry' then return false,L.WaterFerryFixed end
    if not cell then return false,L.WaterNoRoute end
    if self.data.Mode=='walk' then
        if not self.data.Owned or cell.q~=self.data.BoatQ or cell.r~=self.data.BoatR then return false,L.WaterNeedBoat end
        if travel.Progress>0 then return false,L.WaterFinishStep end
        if not self.navigation:Bank(self.map:GetCell(travel.Q,travel.R),cell) then return false,L.WaterNearBoat end
        assert(self:StopAtCell());self:Detach();self.data:Board(cell.q,cell.r)
        travel:Relocate(cell.q,cell.r);travel:SetPaused(true);a.fog:Update();return true
    end
    if not cell.waterLevel then
        local site=siteId and a.sites[siteId]
        if site and site.source and site.source.dock then
            local dock=site.source.dock;local ok,reason=self:Service(dock.id)
            if not ok then return false,reason end
            if not self.data:GetDock(dock.id).Ready then return false,L.WaterDockClosed end
            cell=self.map:GetCell(dock.waterQ,dock.waterR)
        else
            if travel.Progress>0 then return false,L.WaterFinishStep end
            local water=self.map:GetCell(travel.Q,travel.R)
            if not self.navigation:Bank(cell,water) then return false,L.WaterUnsafeBank end
            assert(self:StopAtCell());self.data:SyncBoat(water.q,water.r);self.data:Land(water.q,water.r,0)
            travel:Relocate(cell.q,cell.r);travel:SetPaused(true);a.fog:Update();return true
        end
    end
    local path=self:Path(self.map:GetCell(travel.AnchorQ,travel.AnchorR),cell)
    if not path then return false,L.WaterNoRoute end
    return self:ApplyPath(path,siteId)
end
function Water:DeployAtDock()
    local a=self.adventure;local area=a.areas:ActiveLayout();local front=area.waterfront
    assert(front,'Dock city lacks its waterfront')
    local state=a.data.Areas.Active;local ids={}
    for i=0,a.data.PartyCount-1 do local actor=a.data:GetPartyAt(i);if actor.HP>0 then ids[#ids+1]=actor.Id end end
    local shape=a.areas:SquadFootprint(area,ids)
    local enemies=a.areas:EnemyOccupancy(area,state)
    local obstacles=a.obstacles:BlockedCells()
    local function allowed(cell,member)
        local footprint=shape(cell.index,member);if not footprint then return false end
        for _,index in ipairs(footprint) do if area.cells[index].blocked or state:IsNpcOccupied(index) or enemies[index] or obstacles[index] then return false end end
        return true
    end
    local cells=require('Game.MapArea.SquadMovement').Deploy(area,front.landingIndex,#ids,allowed,shape)
    state:Stop();state:DeployMembers(ids,cells);a.areas:RevealSquad(area,state)
end
function Water:Arrive()
    local a=self.adventure;local travel=a.travel.data
    local id=self.data.Mode=='ferry' and self.data.FerryTargetDockId or nil
    local site=travel.TargetSiteId>0 and a.sites[travel.TargetSiteId]
    if not id and self.data.Mode=='owned' and site and site.source and site.source.dock then id=site.source.dock.id end
    if not id then return false end
    local dock=assert(self.docks[id]);site=assert(self.sites[id])
    if travel.Q~=dock.waterQ or travel.R~=dock.waterR then travel:SetPaused(true);return true,false,L.WaterNoRoute end
    local ok,reason=self:Service(id)
    if not ok or not self.data:GetDock(id).Ready then travel:SetPaused(true);return true,false,reason or L.WaterDockClosed end
    local allowed,explanation=a.areas:CanEnter(site)
    if not allowed then travel:SetPaused(true);return true,false,explanation end
    self:PreparePort(id);travel:Arrived()
    if self.data.Mode=='ferry' then self.data:FinishFerry()
    else self.data:SyncBoat(dock.waterQ,dock.waterR);self.data:Land(dock.waterQ,dock.waterR,id) end
    travel:Relocate(dock.landQ,dock.landR);travel:SetPaused(true)
    assert(a:EnterSite(site.id));self:DeployAtDock();return true,true
end
function Water:Command(command,value,revision)
    if command=='water_close' then return self:Close() end
    local id=self.data.OpenDockId
    if id==0 or revision~=self.data.Revision then return false,L.WaterMenuChanged end
    local ok,reason=self:Near(id);if not ok then return false,reason end
    local dock,record=self.docks[id],self.data:GetDock(id);local a=self.adventure
    if command=='water_accept' then
        if record.Ready or record.Accepted then return false,L.WaterMenuChanged end
        self.data:AcceptRepair(id);return true
    elseif command=='water_repair' then
        if not record.Accepted or not record.Damaged or record.ThreatRemaining>0 then return false,L.WaterTaskIncomplete end
        if not self.data:CompleteRepair(a.equipment.data,id,self.rule.repairItemId,self.rule.repairCount) then return false,L.WaterMaterialsMissing end
        return true
    end
    if not record.Ready then return false,L.WaterDockClosed end
    if command=='water_buy' then
        if self.data.Owned then return false,L.WaterAlreadyOwned end
        if not self.data:Purchase(a.player,self.rule.boatPrice,id,dock.waterQ,dock.waterR) then return false,L.WaterCoinsMissing end
        return true
    elseif command=='water_board' then
        if not self.data.Owned or self.data.BoatQ~=dock.waterQ or self.data.BoatR~=dock.waterR then return false,L.WaterBoatElsewhere end
        if a.travel.data.Progress>0 then return false,L.WaterFinishStep end
        self:Depart(dock);self.data:Board(dock.waterQ,dock.waterR);return true
    elseif command=='water_ferry' then
        local target=self.docks[value]
        if not target or value==id or not self.data:GetDock(value).Ready then return false,L.WaterDockClosed end
        if not a.fog:Known(self.sites[value].q,self.sites[value].r) then return false,L.WaterUnknownPort end
        ok,reason=self:Service(value);if not ok then return false,reason end
        local path=self:Route(id,value);if not path then return false,L.WaterNoRoute end
        self:PreparePort(value)
        local price=self.rule.fareBase+(#path-1)*self.rule.farePerCell
        if a.player.Coins<price then return false,L.WaterCoinsMissing end
        if a.travel.data.Progress>0 then return false,L.WaterFinishStep end
        assert(self.data:BeginFerry(a.player,price,id,value));self:Depart(dock)
        return self:ApplyPath(path,self.sites[value].id)
    end
    error('Unknown water command: '..tostring(command))
end
function Water:RecordKill()
    local a=self.adventure;local site=a.sites[a.data.Areas.ActiveSiteId]
    if not site then return end
    for id,dock in pairs(self.docks) do
        local record=self.data:GetDock(id)
        if record.Accepted and record.ThreatRemaining>0 and Hex.Distance(site.q,site.r,dock.landQ,dock.landR)<=self.rule.threatRadius then self.data:RecordKill(id,1) end
    end
end
function Water:Menu()
    local id=self.data.OpenDockId;local dock=assert(self.docks[id]);local record=self.data:GetDock(id);local a=self.adventure;local rows={}
    local material=a.equipment.rules.items:Get(self.rule.repairItemId)
    local task=string.format(L.WaterTaskProgress,record.ThreatRemaining,record.Damaged and self.rule.repairCount or 0,material.name,a.equipment.data:CountItem(material.id))
    local function row(command,value,name,body,available) rows[#rows+1]={command=command,id=value,name=name,body=body,available=available} end
    if not record.Ready then
        row('water_accept',id,L.WaterAcceptTask,task,not record.Accepted)
        if record.Damaged then row('water_repair',id,L.WaterRepairDock,task,record.Accepted and record.ThreatRemaining==0 and a.equipment.data:CountItem(material.id)>=self.rule.repairCount) end
    else
        if not self.data.Owned then row('water_buy',id,string.format(L.WaterBuyBoat,self.rule.boatPrice),L.WaterBoatDescription,a.player.Coins>=self.rule.boatPrice)
        else row('water_board',id,L.WaterBoardOwn,string.format(L.WaterParkedAt,self.data.BoatQ,self.data.BoatR),self.data.BoatQ==dock.waterQ and self.data.BoatR==dock.waterR) end
        local count=0
        for _,target in ipairs(self.map.docks) do if target.id~=id then
            local site=self.sites[target.id]
            if site and a.fog:Known(site.q,site.r) then
                local path=self:Route(id,target.id)
                if path then
                    local price=self.rule.fareBase+(#path-1)*self.rule.farePerCell;local service=self:Service(target.id)
                    local ready=self.data:GetDock(target.id).Ready and service
                    row('water_ferry',target.id,string.format(L.WaterFerryTo,site.name),ready and string.format(L.WaterFare,price,(#path-1)*self.rule.minutesPerCell) or L.WaterDockClosed,ready and a.player.Coins>=price);count=count+1
                end
            end
        end end
        if count==0 then row('water_close',0,L.WaterNoDestinations,L.WaterExplorePorts,false) end
    end
    return {name=self.sites[id].name,caption=record.Ready and L.WaterDockReady or L.WaterDockClosed,coins=a.player.Coins,rows=rows,version=self.data.Revision}
end
function Water:WorldSnapshot()
    local a=self.adventure;local rows={};local assets=a.config:GetTable('MapAssetTable')
    for _,dock in ipairs(self.map.docks or {}) do if a.fog:Known(dock.landQ,dock.landR) then
        local record=self.data:GetDock(dock.id)
        rows[#rows+1]={id=dock.id,x=dock.x,y=dock.y,z=dock.z,yaw=dock.yaw,scale=dock.scale,
            modelPath=assets:Get(record.Damaged and self.rule.ruinedAssetId or self.rule.intactAssetId).prefabPath}
    end end
    if self.data.Owned and self.data.Mode~='owned' and a.fog:Known(self.data.BoatQ,self.data.BoatR) then
        local bx,by,bz=self:Position(self.data.BoatQ,self.data.BoatR)
        rows[#rows+1]={id=-1,x=bx,y=by,z=bz,yaw=0,scale=.3*self.map.hexRadius,modelPath=assets:Get(self.rule.boatAssetId).prefabPath}
    end
    local show=self.data.Mode~='walk'
    local x,y,z=0,0,0
    if self.data.Mode=='walk' and self.data.Owned then x,y,z=self:Position(self.data.BoatQ,self.data.BoatR)
    elseif self.data.Mode~='walk' then local view=a.travel:Snapshot();x,y,z=view.x,view.y,view.z end
    return {mode=self.data.Mode,rows=rows,showBoat=show,boatX=x,boatY=y,boatZ=z,boatScale=.3*self.map.hexRadius,boatPath=assets:Get(self.rule.boatAssetId).prefabPath}
end
function Water:JournalRows()
    local rows={};local material=self.adventure.equipment.rules.items:Get(self.rule.repairItemId)
    for _,dock in ipairs(self.map.docks or {}) do
        local record=self.data:GetDock(dock.id)
        if record.Accepted or record.Ready and (dock.initialDamaged or dock.initialThreat) then
            local site=self.sites[dock.id]
            rows[#rows+1]={id='dock:'..dock.id,waterTask=true,name=string.format(L.WaterTaskTitle,site.name),
                status=record.Ready and 'completed' or 'active',description=L.WaterTaskActive,
                objective=string.format(L.WaterTaskProgress,record.ThreatRemaining,record.Damaged and self.rule.repairCount or 0,material.name,self.adventure.equipment.data:CountItem(material.id)),
                publisher=self.adventure.config:GetTable('MapAreaTownNpcTable'):Get(self.rule.npcTemplateId).name,
                location=site.name,turnInHint=L.WaterTalkWorker,rewards={},quests={}}
        end
    end
    return rows
end
function Water:ValidateSaved(prepared,world)
    local data=CS.ProjectY.Data.WaterTravelData.Prepared(prepared);local docks={}
    local navigation=Navigation.New(world.map,self.rule)
    local sites={};for _,site in ipairs(world.sites) do if site.source and site.source.dock then sites[site.source.dock.id]=site end end
    for _,dock in ipairs(world.map.docks or {}) do docks[dock.id]=dock;assert(data:FindDock(dock.id),L.WaterSaveInvalid) end
    for i=0,data.Count-1 do local record=data:GetDockAt(i);assert(docks[record.Id] and record.ThreatRemaining<=self.rule.threatKills,L.WaterSaveInvalid) end
    local travel=CS.ProjectY.Data.ExpeditionPersistence.Travel(prepared)
    if data.Owned then assert(navigation:Water(world.map:FindCell(data.BoatQ,data.BoatR)),L.WaterSaveInvalid) end
    if data.BoatDockId>0 then local dock=docks[data.BoatDockId];assert(dock and dock.waterQ==data.BoatQ and dock.waterR==data.BoatR,L.WaterSaveInvalid) end
    if data.Mode~='walk' then
        local first=world.map:GetCell(travel.Q,travel.R);assert(navigation:Water(first),L.WaterSaveInvalid)
        for i=0,travel.StepCount-1 do local step=travel:GetStepAt(i);local last=world.map:GetCell(step.Q,step.R);assert(navigation:Cost(first,last),L.WaterSaveInvalid);first=last end
        if data.Mode=='ferry' then
            local target=docks[data.FerryTargetDockId];local site=sites[data.FerryTargetDockId]
            assert(target and docks[data.FerryOriginDockId] and site and travel.TargetSiteId==site.id and first.q==target.waterQ and first.r==target.waterR,L.WaterSaveInvalid)
        end
    else assert(not world.map:GetCell(travel.Q,travel.R).waterLevel,L.WaterSaveInvalid) end
end
return Water
