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
    self.combatStats=require('Game.Battle.CombatStats')(self.config)
    self.encounterRules=self.config:GetTable('MapAreaEncounterTable')
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
    self:InitializeEncounters(layout,state)
    if state.NpcCount==0 then for _,npc in ipairs(layout.npcs) do state:AddNpc(npc.id,npc.spawnIndex) end end
    local ids={};for i=0,self.adventure.PartyCount-1 do
        local actor=self.adventure:GetPartyAt(i);if actor.HP>0 then ids[#ids+1]=actor.Id end
    end
    local same=state.MemberCount==#ids
    for i,id in ipairs(ids) do if not same or state:GetMemberIdAt(i-1)~=id then same=false;break end end
    if not same then
        local enemies=self:EnemyOccupancy(layout,state)
        state:DeployMembers(ids,Squad.Deploy(layout,state.CellIndex,#ids,function(cell) return not state:IsNpcOccupied(cell.index) and not enemies[cell.index] end))
    end
    self:RevealSquad(layout,state)
    self.adventure:BeginArea(site.id)
    return true
end
function AreaSystem:InitializeEncounters(layout,state)
    if state.EncountersInitialized then return end
    local rule=self.encounterRules:Find(layout.configId)
    if rule then
        local encounter=self.config:GetTable('CombatEncounterTable'):Get(rule.encounterId)
        local plans=require('Game.MapArea.DungeonEncounters').Plan(layout,rule,encounter)
        for _,plan in ipairs(plans) do
            local group=state:AddEncounter(plan.id,plan.encounterId)
            for i,cell in ipairs(plan.cells) do
                local actor=group:AddEnemy(1000+plan.id*10+i,encounter.enemyIds[i],cell.q,cell.r)
                actor:SetMaxHP(self.combatStats:MaximumHP(actor));actor:Restore()
            end
        end
    end
    state:CompleteEncounterInitialization()
end
function AreaSystem:EnemyOccupancy(layout,state,exceptGroup)
    local occupied={}
    for i=0,state.EncounterCount-1 do
        local group=state:GetEncounterAt(i)
        if group.Id~=exceptGroup then for j=0,group.EnemyCount-1 do
            local actor=group:GetEnemyAt(j)
            if actor.HP>0 then occupied[assert(layout:Find(actor.Q,actor.R)).index]=true end
        end end
    end
    return occupied
end
function AreaSystem:FindEncounter()
    if self.adventure.Phase~='area' then return end
    local area,state=self:ActiveLayout(),self.data.Active
    local rule=self.encounterRules:Find(area.configId);if not rule then return end
    local Hex=require('Game.Map.HexGrid')
    for i=0,state.EncounterCount-1 do
        local group=state:GetEncounterAt(i)
        for j=0,group.EnemyCount-1 do
            local enemy=group:GetEnemyAt(j)
            if enemy.HP>0 then
                local cell=assert(area:Find(enemy.Q,enemy.R))
                for k=0,state.MemberCount-1 do
                    local member=area.cells[state:GetMemberCellAt(k)]
                    if Hex.Distance(member.q,member.r,cell.q,cell.r)<=rule.alertRange and area:CanSee(member,cell) then return group end
                end
            end
        end
    end
end
function AreaSystem:StartBattle(battle,group)
    local area,state=self:ActiveLayout(),self.data.Active
    local rule=assert(self.encounterRules:Find(area.configId))
    local party,enemies={},{}
    for i=0,state.MemberCount-1 do
        local actor
        for j=0,self.adventure.PartyCount-1 do
            local member=self.adventure:GetPartyAt(j)
            if member.Id==state:GetMemberIdAt(i) then actor=member;break end
        end
        local cell=area.cells[state:GetMemberCellAt(i)]
        party[#party+1]={actor=assert(actor),q=cell.q,r=cell.r}
    end
    for i=0,group.EnemyCount-1 do local actor=group:GetEnemyAt(i);if actor.HP>0 then enemies[#enemies+1]=actor end end
    local center=assert(area:Find(enemies[1].Q,enemies[1].R));local radius=0
    local Hex=require('Game.Map.HexGrid')
    for _,row in ipairs(party) do radius=math.max(radius,Hex.Distance(center.q,center.r,row.q,row.r)) end
    for _,actor in ipairs(enemies) do radius=math.max(radius,Hex.Distance(center.q,center.r,actor.Q,actor.R)) end
    local board=self:BattleWindow(center.index,radius+rule.battleMargin)
    board.allowed=function(cell) return state:IsKnown(cell.index) end
    board.externalOccupied={}
    for index in pairs(self:EnemyOccupancy(area,state,group.Id)) do
        local cell=area.cells[index];board.externalOccupied[Hex.Key(cell.q,cell.r)]=true
    end
    battle:StartArea(group.EncounterId,board,party,enemies)
    self.adventure:BeginAreaBattle(group.Id)
    self:RevealBattle(battle)
end
function AreaSystem:BattleMembers(battle)
    local members={};local area=self:ActiveLayout()
    for _,actor in ipairs(battle:Units()) do if actor.Team==1 and actor.HP>0 then
        members[#members+1]={actorId=actor.Id,cellIndex=assert(area:Find(actor.Q,actor.R)).index}
    end end
    return members
end
function AreaSystem:RevealBattle(battle)
    local area,state=self:ActiveLayout(),self.data.Active
    local cells,seen={},{}
    for _,member in ipairs(self:BattleMembers(battle)) do for _,index in ipairs(area:VisibleFrom(member.cellIndex)) do
        if not seen[index] then seen[index]=true;cells[#cells+1]=index end
    end end
    state:Reveal(cells)
end
function AreaSystem:RestoreAfterBattle(battle)
    if battle.data.Winner~='victory' then self.data.Active:RetreatToEntry(self:ActiveLayout().entryIndex);return end
    local ids,cells={},{}
    for _,member in ipairs(self:BattleMembers(battle)) do ids[#ids+1]=member.actorId;cells[#cells+1]=member.cellIndex end
    if #ids>0 then self.data.Active:DeployMembers(ids,cells);self:RevealSquad(self:ActiveLayout(),self.data.Active) end
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
    local goal=self:ActiveLayout():Find(q,r)
    return self:MoveToIndex(goal and goal.index or 0,settle)
end
-- 点击使用完整 cellIndex，桥上与桥下相同 q/r 不会被折叠成同一个目标。
function AreaSystem:MoveToIndex(index,settle)
    if self.adventure.Phase~='area' then return false,'当前不在探索区域' end
    local layout,state=self:ActiveLayout(),self.data.Active
    if state.InteractionKind~=0 then return false,'请先关闭交互介绍' end
    local goal=layout.cells[index]
    if not goal or goal.blocked then return false,'墙壁、陈设占地或地图边界不可通行' end
    if not state:IsKnown(goal.index) then return false,'请先探索附近可见的地面' end
    if state:IsNpcOccupied(goal.index) then return false,'居民正在经过，请稍候或从旁边绕行' end
    local enemies=self:EnemyOccupancy(layout,state)
    if enemies[goal.index] then return false,'敌人占据了这个位置' end
    -- 单次命令读取一份已探索集合，规划完成即释放，避免距离场遍历频繁跨 Lua/C#。
    local known={};for i=0,state.KnownCount-1 do known[state:GetKnownAt(i)]=true end
    local occupied=enemies;for i=0,state.NpcCount-1 do occupied[state:GetNpcAt(i).CellIndex]=true end
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
    if not area:CanStep(area.cells[state.CellIndex],cell) then return false,'此方向没有相连的街道或楼梯' end
    return self:MoveToIndex(cell.index,false)
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
    local path=area:FindPath(state.CellIndex,index)
    if not path or #path>radius then return false,'沿街道靠近门口或居民后再交互，不能隔层交谈' end
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
    return require('Game.Battle.BattleBoard').FromArea(area,center.q,center.r,radius,center.layer)
end
function AreaSystem:Snapshot(battle)
    local area,state=self:ActiveLayout(),self.data.Active
    local known,visible,route,members,npcs={},{},{},{},{}
    for i=0,state.NpcCount-1 do local npc=state:GetNpcAt(i);npcs[#npcs+1]={id=npc.Id,cellIndex=npc.CellIndex} end
    for i=0,state.MemberCount-1 do members[#members+1]={actorId=state:GetMemberIdAt(i),cellIndex=state:GetMemberCellAt(i)} end
    for i=0,state.KnownCount-1 do known[#known+1]=state:GetKnownAt(i) end
    for i=0,state.VisibleCount-1 do visible[#visible+1]=state:GetVisibleAt(i) end
    if battle then members=self:BattleMembers(battle) end
    local enemies,visibleSet={},{}
    for _,index in ipairs(visible) do visibleSet[index]=true end
    local cleared=0
    for i=0,state.EncounterCount-1 do
        local group=state:GetEncounterAt(i);if group.Defeated then cleared=cleared+1 end
        for j=0,group.EnemyCount-1 do
            local actor=group:GetEnemyAt(j);local cell=assert(area:Find(actor.Q,actor.R))
            if actor.HP>0 and visibleSet[cell.index] then
                enemies[#enemies+1]=require('Game.Battle.CombatSnapshot')(actor,self.combatStats,self.appearance,area)
            end
        end
    end
    for i=0,state.RemainingSteps-1 do route[#route+1]=state:GetRouteAt(i) end
    return {name=area.name,theme=area.theme.name,seed=area.seed,cellIndex=members[1] and members[1].cellIndex or state.CellIndex,known=known,visible=visible,npcs=npcs,
        enemies=enemies,encounterCount=state.EncounterCount,clearedEncounters=cleared,
        interactionKind=state.InteractionKind,interactionId=state.InteractionId,
        route=route,members=members,revision=state.Revision,entryIndex=area.entryIndex,goalIndex=area.goalIndex,
        roomCount=#area.rooms,walkableCount=area.walkableCount,knownCount=state.KnownCount,
        sourceRegionId=area.source.regionId,sourceRegionType=area.source.regionType,propCount=#area.props}
end
-- xLua 的 LuaTable.Length 使用原始数组长度，不执行只读代理的 __len。
-- 跨语言快照必须复制实体数组，避免 C# 读到空数组，也不暴露静态布局的内部引用。
local function snapshotArray(values)
    local result={};for i,value in ipairs(values) do result[i]=value end;return result
end
function AreaSystem:LayoutSnapshot()
    local area=self:ActiveLayout();local Hex=require('Game.Map.HexGrid')
    local asset=self.config:GetTable('MapAssetTable'):Get(area.theme.assetId)
    local result={name=area.name,areaType=area.areaType,moveStepSeconds=area.moveStepSeconds,hexRadius=area.hexRadius,cells={},assetId=asset.id,assetPath=asset.prefabPath,tintMaterial=asset.tintMaterial,
        rooms={},props={},propAssets={},corridorWidth=area.corridorRadius*2+1}
    result.facilities={};result.npcs={};result.surfaces={}
    for _,row in ipairs(self.config:GetTable('MapAreaSurfaceTable'):All()) do
        result.surfaces[#result.surfaces+1]={id=row.id,pattern=row.pattern,color=row.baseColor,tileMeters=row.tileMeters,
            contrast=row.contrast,jointWidth=row.jointWidth,smoothness=row.smoothness,detailColor=row.detailColor}
    end
    for i,site in ipairs(area.facilities) do result.facilities[i]={id=site.id,name=site.name,description=site.description,
        entryIndex=site.entryIndex,interactionRadius=site.interactionRadius} end
    for i,npc in ipairs(area.npcs) do
        local template=self.config:GetTable('MapAreaTownNpcTable'):Get(npc.templateId)
        result.npcs[i]={id=npc.id,name=template.name,description=template.description,stepSeconds=npc.stepSeconds,
            appearance={templateId=npc.templateId,parts=self.appearance:Resolve(template.partIds)}}
    end
    for i,cell in ipairs(area.cells) do
        local x,_,z=Hex.ToWorld(cell.q,cell.r,cell.height,area.hexRadius)
        result.cells[i]={q=cell.q,r=cell.r,x=x,z=z,height=cell.height,wallHeight=cell.wallHeight,layer=cell.layer,
            color=snapshotArray(cell.color),blocked=cell.blocked,kind=cell.kind,roomId=cell.roomId,interiorId=cell.interiorId or 0,walkMask=cell.walkMask,neighbors=snapshotArray(cell.neighbors),
            corners=cell.corners and snapshotArray(cell.corners) or {cell.height,cell.height,cell.height,cell.height,cell.height,cell.height},
            deckThickness=cell.deckThickness or 0,stairRise=cell.stairRise or 0,surfaceId=cell.surfaceId or 0,sideSurfaceId=cell.sideSurfaceId or 0}
    end
    for i,room in ipairs(area.rooms) do
        result.rooms[i]={id=room.id,name=room.name,tier=room.tier,presetId=room.presetId,centerIndex=room.center}
    end
    local used={}
    for i,prop in ipairs(area.props) do
        local top=-math.huge;local cells={}
        for j,index in ipairs(prop.cells) do top=math.max(top,area.cells[index].height);cells[j]=index end
        top=prop.height or top
        local x,_,z=Hex.ToWorld(prop.q,prop.r,top,area.hexRadius);local scale=prop.scale*area.hexRadius
        result.props[i]={assetId=prop.assetId,x=x,y=top+.015,z=z,rotation=-prop.rotation*60,scale=scale,interiorId=prop.interiorId or 0,cutaway=prop.cutaway==true,
            scaleX=prop.scaleX or scale,scaleY=prop.scaleY or scale,scaleZ=prop.scaleZ or scale,cells=cells}
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
