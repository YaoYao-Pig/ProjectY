-- MapArea 静态布局归此系统，唯一可变探索状态归 AdventureData.Areas。
local Class=require('Core.Class')
local System=require('Core.LuaSystem')
local Generator=require('Game.MapArea.MapAreaGenerator')
local Squad=require('Game.MapArea.SquadMovement')
local AreaSystem=Class('MapAreaSystem',System)
function AreaSystem:OnInit(context)
    System.OnInit(self,context)
    self.config=context.systems:Get('Config')
    self.generator=Generator(self.config)
    self.generator:Register(self.config:GetEnum('MapArea','E_MapAreaType').Dungeon,
        require('Game.MapArea.DungeonGenerator'),'MapAreaDungeonTable')
    self.townType=self.config:GetEnum('MapArea','E_MapAreaType').Town
    self.generator:Register(self.townType,require('Game.MapArea.TownGenerator'),'MapAreaTownTable','MapAreaTownThemeTable')
    self.appearance=require('Game.Adventure.PawnAppearance').New(self.config)
    self.adventure=assert(context.services.Adventure,'Adventure data is required for MapArea')
    self.data=assert(self.adventure.Areas,'AdventureData.Areas is missing; compile C# and generate xLua bindings')
    self.entrances={};self.layouts={}
    for _,row in ipairs(self.config:GetTable('MapAreaEntranceTable'):All()) do
        assert(not self.entrances[row.townId],'Duplicate MapArea entrance for a town style')
        self.entrances[row.townId]=self.generator.definitions:Get(row.areaId)
    end
end
-- 一个聚落实例只有一个入口；多栋建筑不重复创建城镇内部地图。
function AreaSystem:Entrances(map)
    local result={}
    for _,town in ipairs(map.towns) do
        local definition=self.entrances[town.configId]
        if definition then
            local cell=town.center;local region=map:GetRegion(cell.regionId)
            local x,y,z=map:GetCellWorldPosition(cell.q,cell.r)
            result[#result+1]={areaConfigId=definition.id,pointId=town.id,name=town.name..' · '..definition.name,
                q=cell.q,r=cell.r,x=x,y=y,z=z,source={regionId=region.instanceId,regionConfigId=region.configId,
                regionType=region.regionType,q=cell.q,r=cell.r,height=cell.height,biomeWeights=cell.biomeWeights}}
        end
    end
    return result
end
function AreaSystem:CanEnter(site)
    if self.adventure.Phase~='map' then return false,'请先离开当前地点' end
    if not self.generator:CanGenerate(site.areaConfigId) then return false,'此类型的 MapArea 生成策略待实现' end
    local living=false
    for i=0,self.adventure.PartyCount-1 do if self.adventure:GetPartyAt(i).HP>0 then living=true end end
    if not living then return false,'请先回营地治疗至少一名队员' end
    return true
end
function AreaSystem:Enter(site,worldSeed)
    local ok,reason=self:CanEnter(site);if not ok then return false,reason end
    local layout=self.layouts[site.id]
    if not layout then
        layout=self.generator:Generate(site.areaConfigId,worldSeed,site.pointId,site.source)
        self.layouts[site.id]=layout
    end
    local state=self.data:Enter(site.id,#layout.cells,layout.entryIndex)
    if state.NpcCount==0 then for _,npc in ipairs(layout.npcs) do state:AddNpc(npc.id,npc.spawnIndex) end end
    local ids={};for i=0,self.adventure.PartyCount-1 do
        local actor=self.adventure:GetPartyAt(i);if actor.HP>0 then ids[#ids+1]=actor.Id end
    end
    local same=state.MemberCount==#ids
    for i,id in ipairs(ids) do if not same or state:GetMemberIdAt(i-1)~=id then same=false;break end end
    if not same then state:DeployMembers(ids,Squad.Deploy(layout,state.CellIndex,#ids,function(cell) return not state:IsNpcOccupied(cell.index) end)) end
    self:RevealSquad(layout,state)
    self.adventure:BeginArea(site.id)
    return true
end
function AreaSystem:RevealSquad(layout,state)
    if layout.discovery=='open' then
        if state.KnownCount==0 then
            local all={};for i=1,#layout.cells do all[i]=i end;state:Reveal(all)
        end
        return
    end
    local cells,seen={},{}
    for i=0,state.MemberCount-1 do for _,index in ipairs(layout:VisibleFrom(state:GetMemberCellAt(i))) do
        if not seen[index] then seen[index]=true;cells[#cells+1]=index end
    end end
    state:Reveal(cells)
end
function AreaSystem:ActiveLayout() return assert(self.layouts[self.data.ActiveSiteId],'No active MapArea layout') end
function AreaSystem:MoveTo(q,r,settle)
    if self.adventure.Phase~='area' then return false,'当前不在探索区域' end
    local layout,state=self:ActiveLayout(),self.data.Active
    if state.InteractionKind~=0 then return false,'请先关闭交互介绍' end
    local goal=layout:Find(q,r)
    if not goal or goal.blocked then return false,'墙壁、陈设占地或地图边界不可通行' end
    if not state:IsKnown(goal.index) then return false,'请先探索附近可见的地面' end
    if state:IsNpcOccupied(goal.index) then return false,'居民正在经过，请稍候或从旁边绕行' end
    -- 单次命令读取一份已探索集合，规划完成即释放，避免距离场遍历频繁跨 Lua/C#。
    local known={};for i=0,state.KnownCount-1 do known[state:GetKnownAt(i)]=true end
    local occupied={};for i=0,state.NpcCount-1 do occupied[state:GetNpcAt(i).CellIndex]=true end
    local allowed=function(cell) return known[cell.index]==true and not occupied[cell.index] end
    local path=layout:FindPath(state.CellIndex,goal.index,allowed)
    if not path then return false,'已探索范围内没有可达路径' end
    local positions={};for i=0,state.MemberCount-1 do positions[#positions+1]=state:GetMemberCellAt(i) end
    local frames,reason=Squad.Plan(layout,positions,path,allowed,settle)
    if not frames then return false,reason end
    state:SetSquadRoute(frames);return true
end
-- 第三人称键盘输入只发六邻接方向，不直接写位置；仍经过同一整队规划与占格检查。
function AreaSystem:Walk(direction)
    if self.adventure.Phase~='area' then return false,'当前不在探索区域' end
    local area,state=self:ActiveLayout(),self.data.Active
    if area.areaType~=self.townType then return false,'此区域使用俯视探索操控' end
    if type(direction)~='number' or direction%1~=0 or direction<1 or direction>6 then return false,'无效的移动方向' end
    if state.RemainingSteps>0 then return true end
    local cell=area.cells[area.cells[state.CellIndex].neighbors[direction]]
    if not cell then return false,'已到城镇边界' end
    return self:MoveTo(cell.q,cell.r,false)
end
function AreaSystem:Interact(kind,id)
    if self.adventure.Phase~='area' then return false,'当前不在探索区域' end
    local area,state=self:ActiveLayout(),self.data.Active
    local index,radius
    if kind==1 then
        local facility=area.facilities[id]
        if not facility then return false,'设施不存在' end
        index=facility.entryIndex;radius=facility.interactionRadius
    elseif kind==2 then
        if not area.npcs[id] then return false,'居民不存在' end
        index=state:GetNpcAt(id-1).CellIndex;radius=1
    else return false,'未知交互类型' end
    local from,to=area.cells[state.CellIndex],area.cells[index]
    if require('Game.Map.HexGrid').Distance(from.q,from.r,to.q,to.r)>radius then return false,'靠近门口或居民后再交互' end
    state:SetInteraction(kind,id);return true
end
function AreaSystem:CloseInteraction()
    if self.adventure.Phase~='area' then return false,'当前不在探索区域' end
    self.data.Active:SetInteraction(0,0);return true
end
function AreaSystem:Stop()
    if self.adventure.Phase~='area' then return false,'当前不在探索区域' end
    self.data.Active:Stop();return true
end
function AreaSystem:Leave()
    if self.adventure.Phase~='area' then return false,'当前不在探索区域' end
    self.adventure:LeaveArea();return true
end
function AreaSystem:Tick(dt)
    if self.adventure.Phase~='area' then return end
    local layout,state=self:ActiveLayout(),self.data.Active
    if state:Advance(dt,layout.moveStepSeconds) then self:RevealSquad(layout,state) end
    require('Game.MapArea.TownResidents').Tick(layout,state,dt)
end
function AreaSystem:Clear() self.layouts={};self.data:Clear() end
-- 后续遭遇从当前区域裁取同坐标战场，不另随机一张竞技场，不移动或替换原地形。
function AreaSystem:BattleWindow(centerIndex,radius)
    local area=self:ActiveLayout();local center=assert(area.cells[centerIndex])
    return require('Game.Battle.BattleBoard').FromArea(area,center.q,center.r,radius)
end
function AreaSystem:Snapshot()
    local area,state=self:ActiveLayout(),self.data.Active
    local known,visible,route,members,npcs={},{},{},{},{}
    for i=0,state.NpcCount-1 do local npc=state:GetNpcAt(i);npcs[#npcs+1]={id=npc.Id,cellIndex=npc.CellIndex} end
    for i=0,state.MemberCount-1 do members[#members+1]={actorId=state:GetMemberIdAt(i),cellIndex=state:GetMemberCellAt(i)} end
    for i=0,state.KnownCount-1 do known[#known+1]=state:GetKnownAt(i) end
    for i=0,state.VisibleCount-1 do visible[#visible+1]=state:GetVisibleAt(i) end
    for i=0,state.RemainingSteps-1 do route[#route+1]=state:GetRouteAt(i) end
    return {name=area.name,theme=area.theme.name,seed=area.seed,cellIndex=state.CellIndex,known=known,visible=visible,npcs=npcs,
        interactionKind=state.InteractionKind,interactionId=state.InteractionId,
        route=route,members=members,revision=state.Revision,entryIndex=area.entryIndex,goalIndex=area.goalIndex,
        roomCount=#area.rooms,walkableCount=area.walkableCount,knownCount=state.KnownCount,
        sourceRegionId=area.source.regionId,sourceRegionType=area.source.regionType,propCount=#area.props}
end
function AreaSystem:LayoutSnapshot()
    local area=self:ActiveLayout();local Hex=require('Game.Map.HexGrid')
    local asset=self.config:GetTable('MapAssetTable'):Get(area.theme.assetId)
    local result={name=area.name,areaType=area.areaType,moveStepSeconds=area.moveStepSeconds,hexRadius=area.hexRadius,cells={},assetId=asset.id,assetPath=asset.prefabPath,tintMaterial=asset.tintMaterial,
        rooms={},props={},propAssets={},corridorWidth=area.corridorRadius*2+1}
    result.facilities={};result.npcs={}
    for i,site in ipairs(area.facilities) do result.facilities[i]={id=site.id,name=site.name,description=site.description,
        entryIndex=site.entryIndex,interactionRadius=site.interactionRadius} end
    for i,npc in ipairs(area.npcs) do
        local template=self.config:GetTable('MapAreaTownNpcTable'):Get(npc.templateId)
        result.npcs[i]={id=npc.id,name=template.name,description=template.description,stepSeconds=npc.stepSeconds,
            appearance={templateId=npc.templateId,parts=self.appearance:Resolve(template.partIds)}}
    end
    for i,cell in ipairs(area.cells) do
        local x,_,z=Hex.ToWorld(cell.q,cell.r,cell.height,area.hexRadius)
        result.cells[i]={q=cell.q,r=cell.r,x=x,z=z,height=cell.height,wallHeight=cell.wallHeight,
            color=cell.color,blocked=cell.blocked,kind=cell.kind,roomId=cell.roomId}
    end
    for i,room in ipairs(area.rooms) do
        result.rooms[i]={id=room.id,name=room.name,tier=room.tier,presetId=room.presetId,centerIndex=room.center}
    end
    local used={}
    for i,prop in ipairs(area.props) do
        local top=-math.huge;local cells={}
        for j,index in ipairs(prop.cells) do top=math.max(top,area.cells[index].height);cells[j]=index end
        local x,_,z=Hex.ToWorld(prop.q,prop.r,top,area.hexRadius)
        result.props[i]={assetId=prop.assetId,x=x,y=top+.015,z=z,rotation=-prop.rotation*60,scale=prop.scale*area.hexRadius,cells=cells}
        if not used[prop.assetId] then
            used[prop.assetId]=true
            local row=self.config:GetTable('MapAssetTable'):Get(prop.assetId)
            result.propAssets[#result.propAssets+1]={id=row.id,path=row.prefabPath}
        end
    end
    return result
end
function AreaSystem:OnShutdown()
    self.layouts=nil
    if self.data then self.data:Clear();self.data=nil end
    self.adventure=nil
end
return AreaSystem
