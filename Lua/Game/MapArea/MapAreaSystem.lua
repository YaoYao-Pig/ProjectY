-- MapArea 静态布局归此系统，唯一可变探索状态归 AdventureData.Areas。
local Class=require('Core.Class')
local System=require('Core.LuaSystem')
local Generator=require('Game.MapArea.MapAreaGenerator')
local Squad=require('Game.MapArea.SquadMovement')
local AreaSystem=Class('MapAreaSystem',System)
function AreaSystem:PartyActor(id)
    for i=0,self.adventure.PartyCount-1 do local actor=self.adventure:GetPartyAt(i);if actor.Id==id then return actor end end
    error('Unknown squad actor: '..tostring(id))
end
function AreaSystem:SquadFootprint(layout,ids)
    local animals=self.combatStats.animals;local species,caches,bySpecies={},{},{}
    for i,id in ipairs(ids) do
        local row=animals:Species(self:PartyActor(id));species[i]=row
        local key=row and #row.footprintQ>1 and row or false
        if not bySpecies[key] then bySpecies[key]={} end
        caches[i]=bySpecies[key]
    end
    return function(index,member)
        member=member or 1;local cache=caches[member];local result=cache[index]
        if result~=nil then return result~=false and result or nil end
        local anchor=assert(layout.cells[index],'Unknown squad footprint anchor');local row=species[member]
        if not row or #row.footprintQ==1 then result={index}
        else
            local cells=animals:CellsForSpecies(row,layout,anchor.q,anchor.r,anchor.layer)
            if not cells then cache[index]=false;return nil end
            result={};for _,cell in ipairs(cells) do result[#result+1]=cell.index end
        end
        cache[index]=result;return result
    end
end
function AreaSystem:OnInit(context)
    System.OnInit(self,context)
    self.config=context.systems:Get('Config')
    self.explorationRoundSeconds=self.config:GetConstant('Global','ExplorationRoundSeconds')
    assert(self.explorationRoundSeconds>0 and self.explorationRoundSeconds<math.huge,'Invalid exploration round interval')
    self.characterAppearances=require('Game.Adventure.CharacterAppearance').New(self.config,context.services.Appearances)
    self.generator=Generator(self.config)
    self.generator:Register(self.config:GetEnum('MapArea','E_MapAreaType').Dungeon,
        require('Game.MapArea.DungeonGenerator'),'MapAreaDungeonTable')
    self.townType=self.config:GetEnum('MapArea','E_MapAreaType').Town
    self.generator:Register(self.townType,require('Game.MapArea.TownGenerator'),'MapAreaTownTable','MapAreaTownThemeTable')
    self.forestType=self.config:GetEnum('MapArea','E_MapAreaType').Forest
    self.generator:Register(self.forestType,require('Game.MapArea.ForestGenerator'),'MapAreaForestTable','MapAreaForestThemeTable')
    self.battlefieldType=self.config:GetEnum('MapArea','E_MapAreaType').Battlefield
    self.battlefieldAreaId=self.config:GetConstant('Loot','EventBattlefieldAreaId')
    self.generator:Register(self.battlefieldType,require('Game.MapArea.BattlefieldGenerator'),'MapAreaBattlefieldTable','MapAreaBattlefieldThemeTable')
    self.shipwreckType=self.config:GetEnum('MapArea','E_MapAreaType').Shipwreck
    self.generator:Register(self.shipwreckType,require('Game.MapArea.ShipwreckGenerator'),'MapAreaShipwreckTable','MapAreaShipwreckThemeTable')
    self.generator:Register(self.config:GetEnum('MapArea','E_MapAreaType').Mine,
        require('Game.MapArea.MineGenerator'),'MapAreaMineTable','MapAreaMineThemeTable')
    assert(self.generator.definitions:Get(self.battlefieldAreaId).areaType==self.battlefieldType,'Invalid event battlefield definition')
    self.appearance=require('Game.Adventure.PawnAppearance').New(self.config)
    self.combatStats=require('Game.Battle.CombatStats')(self.config,context.services.Adventure.Equipment)
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
    for _,entrance in ipairs(self.config:GetTable('MapAreaForestEntranceTable'):All()) do
        local selected={}
        for _,cell in ipairs(map:GetCells()) do
            local region=map:GetRegion(cell.regionId)
            if region.regionType==entrance.regionType and not cell.waterLevel and not cell.buildingId then
                local old=selected[region.instanceId]
                if not old or cell.q*cell.q+cell.r*cell.r<old.q*old.q+old.r*old.r then selected[region.instanceId]=cell end
            end
        end
        for _,region in ipairs(map.regions) do
            local cell=selected[region.instanceId]
            if cell then
                local definition=self.generator.definitions:Get(entrance.areaId)
                local x,y,z=map:GetCellWorldPosition(cell.q,cell.r)
                result[#result+1]={areaConfigId=definition.id,pointId=100000+region.instanceId,name=definition.name,
                    q=cell.q,r=cell.r,x=x,y=y,z=z,source={regionId=region.instanceId,regionConfigId=region.configId,
                    regionType=region.regionType,q=cell.q,r=cell.r,height=cell.height,biomeWeights=cell.biomeWeights}}
            end
        end
    end
    for _,site in ipairs(map:GetWaterSites()) do
        local cell=site.cell;local region=map:GetRegion(cell.regionId)
        local x,_,z=map:GetCellWorldPosition(cell.q,cell.r)
        result[#result+1]={areaConfigId=site.areaId,pointId=site.pointId,name=site.name,
            q=cell.q,r=cell.r,x=x,y=cell.waterLevel,z=z,source={regionId=region.instanceId,regionConfigId=region.configId,
            regionType=region.regionType,q=cell.q,r=cell.r,height=cell.waterLevel,biomeWeights=cell.biomeWeights}}
    end
    return result
end
function AreaSystem:CanEnter(site)
    if self.adventure.Phase~='map' then return false,'请先离开当前地点' end
    local areaId=self:AreaId(site)
    if not areaId or not self.generator:CanGenerate(areaId) then return false,'此类型的 MapArea 生成策略待实现' end
    local living=false
    for i=0,self.adventure.PartyCount-1 do if self.adventure:GetPartyAt(i).HP>0 then living=true end end
    if not living then return false,'请先回营地治疗至少一名队员' end
    return true
end
function AreaSystem:AreaId(site)
    return site.areaConfigId or (self.layouts[site.id] and self.layouts[site.id].configId)
end
function AreaSystem:Enter(site,worldSeed)
    local ok,reason=self:CanEnter(site);if not ok then return false,reason end
    return self:Activate(site,worldSeed,false)
end
function AreaSystem:EnterEventBattlefield(site,worldSeed,source)
    assert(self.adventure.Phase=='resolving' and self.data.ActiveSiteId==0,'Event battlefield must start from a resolved world event')
    assert(not self.layouts[site.id],'Event battlefield already exists')
    self.layouts[site.id]=self.generator:Generate(self.battlefieldAreaId,worldSeed,site.id,source)
    return self:Activate(site,worldSeed,true)
end
function AreaSystem:Activate(site,worldSeed,fromEvent)
    local layout=self.layouts[site.id]
    if not layout then
        local decorate=self.narrative and function(area) self.narrative.npcs:Populate(area,site) end or nil
        layout=self.generator:Generate(site.areaConfigId,worldSeed,site.pointId,site.source,decorate)
        self.layouts[site.id]=layout
    end
    if self.construction and not layout.constructionSite then
        layout=self.construction:Layout(layout,site.id);self.layouts[site.id]=layout
    end
    local state=self.data:Enter(site.id,#layout.cells,layout.entryIndex)
    self:InitializeEncounters(layout,state)
    if state.NpcCount==0 then for _,npc in ipairs(layout.npcs) do state:AddNpc(npc.id,npc.spawnIndex) end end
    if self.narrative then self.narrative.npcs:SyncPresence() end
    local ids={};for i=0,self.adventure.PartyCount-1 do
        local actor=self.adventure:GetPartyAt(i);if actor.HP>0 then ids[#ids+1]=actor.Id end
    end
    local same=state.MemberCount==#ids
    for i,id in ipairs(ids) do if not same or state:GetMemberIdAt(i-1)~=id then same=false;break end end
    if not same then
        local enemies=self:EnemyOccupancy(layout,state)
        local obstacles=self.obstacles and self.obstacles:BlockedCells() or {}
        local shape=self:SquadFootprint(layout,ids)
        local function allowed(cell,member)
            local cells=shape(cell.index,member);if not cells then return false end
            for _,index in ipairs(cells) do if layout.cells[index].blocked or obstacles[index] or state:IsNpcOccupied(index) or enemies[index] then return false end end
            return true
        end
        state:DeployMembers(ids,Squad.Deploy(layout,state.CellIndex,#ids,allowed,shape))
    end
    self:RevealSquad(layout,state)
    if fromEvent then self.adventure:BeginEventArea(site.id) else self.adventure:BeginArea(site.id) end
    return true
end
function AreaSystem:InitializeEncounters(layout,state)
    if state.EncountersInitialized then return end
    local rule=self.encounterRules:Find(layout.configId)
    if rule then
        local encounter=self.config:GetTable('CombatEncounterTable'):Get(rule.encounterId)
        local plans=layout.encounterPlans or (layout.areaType==self.forestType and require('Game.MapArea.ForestEncounters').Plan(layout,rule,self.config)
            or require('Game.MapArea.DungeonEncounters').Plan(layout,rule,encounter))
        for _,plan in ipairs(plans) do
            local encounter=self.config:GetTable('CombatEncounterTable'):Get(plan.encounterId)
            local group=state:AddEncounter(plan.id,plan.encounterId)
            local appearanceGroup=self.characterAppearances:Group(encounter.appearancePoolId,(layout.seed ~ (plan.id*65537)) & 0xffffffff)
            for i,cell in ipairs(plan.cells) do
                local actor=group:AddEnemy(100000+state.SiteId*1000+plan.id*10+i,encounter.enemyIds[i],cell.q,cell.r)
                local species=self.combatStats.animals.byUnit[actor.TemplateId]
                if species then
                    actor:InitializeAnimal(species.id,(layout.seed ~ actor.Id) & 0xffffffff)
                    actor:Deploy(plan.team or 2,cell.q,cell.r)
                else
                    assert(not plan.team or plan.team==2,'Only animals can be neutral encounter actors')
                    self.characterAppearances:Assign(actor,appearanceGroup)
                end
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
            if actor.HP>0 and actor.AnimalOwnerId==0 then
                for _,cell in ipairs(assert(self.combatStats.animals:Cells(actor,layout))) do occupied[cell.index]=true end
            end
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
            if enemy.HP>0 and enemy.Team==2 and enemy.AnimalOwnerId==0 then
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
    for i=0,group.EnemyCount-1 do local actor=group:GetEnemyAt(i);if actor.HP>0 and actor.AnimalOwnerId==0 then enemies[#enemies+1]=actor end end
    local center=assert(area:Find(enemies[1].Q,enemies[1].R));local radius=0
    local Hex=require('Game.Map.HexGrid')
    for _,row in ipairs(party) do radius=math.max(radius,Hex.Distance(center.q,center.r,row.q,row.r)) end
    for _,actor in ipairs(enemies) do radius=math.max(radius,Hex.Distance(center.q,center.r,actor.Q,actor.R)) end
    local board=self:BattleWindow(center.index,radius+rule.battleMargin)
    board.onRoundCompleted=function() state:CompleteWorldRound() end
    local obstacles=self.obstacles and self.obstacles:BlockedCells() or {}
    board.allowed=function(cell) return state:IsKnown(cell.index) and not obstacles[cell.index] end
    for index in pairs(self:EnemyOccupancy(area,state,group.Id)) do
        local cell=area.cells[index];board.externalOccupied[Hex.Key(cell.q,cell.r)]=true
    end
    self.adventure:BeginAreaBattle(group.Id)
    battle:StartArea(group.EncounterId,board,party,enemies)
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
        if state.VisibleCount~=#layout.cells then
            local all={};for i=1,#layout.cells do all[i]=i end;state:Reveal(all)
        end
        return
    end
    local cells,seen={},{}
    -- 所有地图的单次队伍揭示都复用查询投影，避免每条射线重复跨 C# 查询相同工事版本。
    local sight=layout.NavigationView and layout:NavigationView() or layout
    local query=sight.layeredVisibility and require('Game.MapArea.LayeredVisibility').NewQuery(sight)
    for i=0,state.MemberCount-1 do for _,index in ipairs(sight:VisibleFrom(state:GetMemberCellAt(i),query)) do
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
function AreaSystem:FindAnimal(id)
    local state=self.data.Active
    for i=0,state.EncounterCount-1 do
        local group=state:GetEncounterAt(i)
        for j=0,group.EnemyCount-1 do local actor=group:GetEnemyAt(j);if actor.Id==id then return actor end end
    end
end
function AreaSystem:CanTame(actorId,animalId)
    if self.adventure.Phase~='area' then return false,'非战斗驯服需要处于探索中' end
    local state,area=self.data.Active,self:ActiveLayout()
    local source=self:PartyActor(actorId);local target=self:FindAnimal(animalId)
    local animals=self.combatStats.animals
    local ok,reason=animals:CanTame(source,target);if not ok then return false,reason end
    if target.Team~=0 then return false,'探索中只能驯服中立动物' end
    local knows=false
    for _,id in ipairs(self.combatStats.equipment:SkillIds(source,self.combatStats:Template(source))) do
        if id==animals.rule.tameSkillId then knows=true end
    end
    if not knows then return false,'需要先研习驯服技能' end
    local origin
    for i=0,state.MemberCount-1 do if state:GetMemberIdAt(i)==actorId then origin=area.cells[state:GetMemberCellAt(i)];break end end
    if not origin then return false,'此角色没有参与探索' end
    local distance=math.huge;local Hex=require('Game.Map.HexGrid')
    for _,cell in ipairs(assert(animals:Cells(target,area))) do
        distance=math.min(distance,Hex.Distance(origin.q,origin.r,cell.q,cell.r))
    end
    local skill=self.config:GetTable('CombatSkillTable'):Get(animals.rule.tameSkillId)
    if distance>skill.range then return false,'请先靠近动物' end
    local targetCell=area:Find(target.Q,target.R)
    if not area:CanSee(origin,targetCell) then return false,'树木或地形遮挡了动物' end
    local occupied={}
    for i=0,state.MemberCount-1 do if state:GetMemberIdAt(i)~=actorId then
        local member=self:PartyActor(state:GetMemberIdAt(i));local cell=area.cells[state:GetMemberCellAt(i)]
        for _,part in ipairs(assert(animals:Cells(member,area,cell.q,cell.r,cell.layer))) do occupied[Hex.Key(part.q,part.r)]=true end
    end end
    if not animals:CanPlace(target,area,target.Q,target.R,occupied) then return false,'动物占地与队友重叠，暂时无法骑乘' end
    return true
end
function AreaSystem:Tame(actorId,animalId)
    local ok,reason=self:CanTame(actorId,animalId);if not ok then return false,reason end
    local source,target=self:PartyActor(actorId),self:FindAnimal(animalId)
    local success,chance=self.combatStats.animals:Tame(source,target,self.combatStats)
    self.data.Active:Stop()
    if success then
        local area,state=self:ActiveLayout(),self.data.Active;local ids,cells={},{}
        for i=0,state.MemberCount-1 do
            local id=state:GetMemberIdAt(i);ids[#ids+1]=id
            cells[#cells+1]=id==actorId and area:Find(target.Q,target.R).index or state:GetMemberCellAt(i)
        end
        state:DeployMembers(ids,cells);self:RevealSquad(area,state)
        return true
    end
    return false,string.format('驯服未成功（成功率 %.0f%%），还需等待 %d 回合',chance,target.TameRetryTurns)
end
-- 点击使用完整 cellIndex，桥上与桥下相同 q/r 不会被折叠成同一个目标。
function AreaSystem:MoveToIndex(index,settle)
    if self.adventure.Phase~='area' then return false,'当前不在探索区域' end
    local liveLayout,state=self:ActiveLayout(),self.data.Active
    local layout=liveLayout.NavigationView and liveLayout:NavigationView() or liveLayout
    if state.InteractionKind~=0 then return false,'请先关闭交互介绍' end
    local goal=layout.cells[index]
    if not goal or goal.blocked then return false,'墙壁、陈设占地或地图边界不可通行' end
    local obstacles=self.obstacles and self.obstacles:BlockedCells() or {}
    if obstacles[index] then return false,'请先处理阻挡道路的障碍' end
    if not state:IsKnown(goal.index) then return false,'请先探索附近可见的地面' end
    if state:IsNpcOccupied(goal.index) then return false,'居民正在经过，请稍候或从旁边绕行' end
    local enemies=self:EnemyOccupancy(layout,state)
    if enemies[goal.index] then return false,'敌人占据了这个位置' end
    -- 探索图单次读取已知集合；公开城镇无需每走一格跨 Lua/C# 复制全图。
    local known
    if layout.discovery~='open' then
        known={};for i=0,state.KnownCount-1 do known[state:GetKnownAt(i)]=true end
    end
    local occupied=enemies;for cell in pairs(obstacles) do occupied[cell]=true end
    for i=0,state.NpcCount-1 do local npc=state:GetNpcAt(i);if npc.Present then occupied[npc.CellIndex]=true end end
    local ids={};for i=0,state.MemberCount-1 do ids[#ids+1]=state:GetMemberIdAt(i) end
    local shape=self:SquadFootprint(layout,ids)
    local allowed=function(cell,member)
        local cells=shape(cell.index,member);if not cells then return false end
        for _,index in ipairs(cells) do if layout.cells[index].blocked or (known and not known[index]) or occupied[index] then return false end end
        return true
    end
    local path=layout:FindPath(state.CellIndex,goal.index,allowed)
    if not path then return false,'已探索范围内没有可达路径' end
    local positions={};for i=0,state.MemberCount-1 do positions[#positions+1]=state:GetMemberCellAt(i) end
    local frames,reason=Squad.Plan(layout,positions,path,allowed,settle,shape)
    if not frames then return false,reason end
    state:SetSquadRoute(frames)
    -- 城镇先提交一个合法的整队步进，让显示立即开始走；剩余帧仍按原步长推进。
    if layout.areaType==self.townType then
        self:AdvanceMovement(liveLayout,state,liveLayout.moveStepSeconds)
    end
    return true
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
        if not state:GetNpcAt(id-1).Present then return false,'这位居民已经离开' end
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
    if self.obstacles then self.obstacles.data:Cancel() end
    self.adventure:LeaveArea();return true
end
-- 即时首步与后续 Tick 共用探索回合/效果结算，不能只推进占格而漏掉回合效果。
function AreaSystem:ResolveWorldRounds(rounds)
    local state=self.data.Active
    if rounds>0 then
        local effects=self.context.systems:Get('Battle').gameEffects
        local targets={}
        for i=0,self.adventure.PartyCount-1 do targets[#targets+1]=self.adventure:GetPartyAt(i) end
        for i=0,state.EncounterCount-1 do local group=state:GetEncounterAt(i)
            for j=0,group.EnemyCount-1 do local actor=group:GetEnemyAt(j);if actor.AnimalOwnerId==0 then targets[#targets+1]=actor end end
        end
        for _=1,rounds do for _,actor in ipairs(targets) do
            CS.ProjectY.Data.ContainerState.AdvanceCooldowns(actor)
            effects:TickActor(actor,'turn_start');effects:TickActor(actor,'turn_end')
        end end
        self.context.systems:Get('Equipment'):GenerateActorDrops(self,targets,self.combatStats)
    end
end
function AreaSystem:RefreshLivingSquad()
    local state,layout=self.data.Active,self:ActiveLayout();local ids,cells={},{}
    for i=0,state.MemberCount-1 do local id=state:GetMemberIdAt(i)
        if self:PartyActor(id).HP>0 then ids[#ids+1]=id;cells[#cells+1]=state:GetMemberCellAt(i) end
    end
    if #ids==0 then state:Stop();self.adventure:LeaveArea();return false end
    if #ids~=state.MemberCount then state:Stop();state:DeployMembers(ids,cells);self:RevealSquad(layout,state) end
    return true
end
function AreaSystem:SpendWorkRounds(rounds)
    for _=1,rounds do self.data.Active:CompleteWorldRound() end
    self:ResolveWorldRounds(rounds)
end
function AreaSystem:AdvanceMovement(layout,state,dt)
    local rounds=state:AdvanceExplorationRounds(dt,self.explorationRoundSeconds,layout.moveStepSeconds)
    self:ResolveWorldRounds(rounds)
    if rounds>0 and not self:RefreshLivingSquad() then return end
    if state:Advance(dt,layout.moveStepSeconds) then self:RevealSquad(layout,state) end
end
function AreaSystem:Tick(dt)
    if self.adventure.Phase~='area' then return end
    local ui=self.context.services.UI -- 独立 Edit Mode 数据检查允许无 UIHost。
    if (ui and ui.IsWorldPaused) or (self.narrative and self.narrative.data.DialogueOpen) then return end
    local layout,state=self:ActiveLayout(),self.data.Active
    self:AdvanceMovement(layout,state,dt)
    if self.adventure.Phase~='area' then return end
    require('Game.MapArea.TownResidents').Tick(layout,state,dt)
    if self.narrative then self.narrative.npcs:Tick(layout,state,dt) end
end
function AreaSystem:Clear() self.layouts={};self.data:Clear();if self.obstacles then self.obstacles.data:Clear() end end
-- 后续遭遇从当前区域裁取同坐标战场，不另随机一张竞技场，不移动或替换原地形。
function AreaSystem:BattleWindow(centerIndex,radius)
    local area=self:ActiveLayout();local center=assert(area.cells[centerIndex])
    local board=require('Game.Battle.BattleBoard').FromArea(area,center.q,center.r,radius,center.layer)
    board.externalOccupied={}
    if self.obstacles then for index in pairs(self.obstacles:BlockedCells()) do
        local cell=area.cells[index];board.externalOccupied[require('Game.Map.HexGrid').Key(cell.q,cell.r)]=true
    end end
    return board
end
function AreaSystem:Snapshot(battle)
    local area,state=self:ActiveLayout(),self.data.Active
    local known,visible,route,members,npcs={},{},{},{},{}
    local knownCount,visibleCount=state.KnownCount,state.VisibleCount
    local fullVisibilityCount=knownCount==#area.cells and visibleCount==#area.cells and #area.cells or 0
    for i=0,state.NpcCount-1 do local npc=state:GetNpcAt(i);npcs[#npcs+1]={id=npc.Id,cellIndex=npc.CellIndex,present=npc.Present} end
    for i=0,state.MemberCount-1 do members[#members+1]={actorId=state:GetMemberIdAt(i),cellIndex=state:GetMemberCellAt(i)} end
    -- 全公开区域发送范围，不让每次人物/NPC移动把整张地图逐项搬过 xLua 两次。
    if fullVisibilityCount==0 then
        for i=0,knownCount-1 do known[#known+1]=state:GetKnownAt(i) end
        for i=0,visibleCount-1 do visible[#visible+1]=state:GetVisibleAt(i) end
    end
    if battle then members=self:BattleMembers(battle) end
    local enemies,defeated,visibleSet={},{},{}
    for _,index in ipairs(visible) do visibleSet[index]=true end
    local cleared=0
    for i=0,state.EncounterCount-1 do
        local group=state:GetEncounterAt(i);if group.Defeated then cleared=cleared+1 end
        for j=0,group.EnemyCount-1 do
            local actor=group:GetEnemyAt(j);local cell=assert(area:Find(actor.Q,actor.R))
            if actor.AnimalOwnerId==0 and actor.HP>0 and (fullVisibilityCount>0 or visibleSet[cell.index]) then
                enemies[#enemies+1]=require('Game.Battle.CombatSnapshot')(actor,self.combatStats,self.appearance,area)
            elseif actor.AnimalOwnerId==0 and actor.HP==0 and (fullVisibilityCount>0 or visibleSet[cell.index]) then
                defeated[#defeated+1]=require('Game.Battle.CombatSnapshot')(actor,self.combatStats,self.appearance,area)
            end
        end
    end
    for i=0,state.RemainingSteps-1 do route[#route+1]=state:GetRouteAt(i) end
    return {name=area.name,theme=area.theme.name,seed=area.seed,cellIndex=members[1] and members[1].cellIndex or state.CellIndex,known=known,visible=visible,fullVisibilityCount=fullVisibilityCount,npcs=npcs,
        enemies=enemies,defeated=defeated,encounterCount=state.EncounterCount,clearedEncounters=cleared,
        interactionKind=state.InteractionKind,interactionId=state.InteractionId,
        route=route,members=members,revision=state.Revision,entryIndex=area.entryIndex,goalIndex=area.goalIndex,
        roomCount=#area.rooms,walkableCount=area.walkableCount,knownCount=knownCount,
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
    result.facilities={};result.npcs={};result.surfaces={};result.floorBoundaryPatches={}
    for i,patch in ipairs(area.floorBoundaryPatches or {}) do
        result.floorBoundaryPatches[i]={ownerIndex=patch.ownerIndex,points=snapshotArray(patch.points),height=patch.height,thickness=patch.thickness}
    end
    for _,row in ipairs(self.config:GetTable('MapAreaSurfaceTable'):All()) do
        result.surfaces[#result.surfaces+1]={id=row.id,pattern=row.pattern,color=row.baseColor,tileMeters=row.tileMeters,
            contrast=row.contrast,jointWidth=row.jointWidth,smoothness=row.smoothness,detailColor=row.detailColor}
    end
    for i,site in ipairs(area.facilities) do result.facilities[i]={id=site.id,name=site.name,description=site.description,
        entryIndex=site.entryIndex,interactionRadius=site.interactionRadius} end
    for i,npc in ipairs(area.npcs) do
        local template=self.config:GetTable('MapAreaTownNpcTable'):Get(npc.templateId)
        local identity=npc.narrativeId and self.narrative.rules.npcs:Get(npc.narrativeId) or template
        result.npcs[i]={id=npc.id,narrativeId=npc.narrativeId or 0,name=identity.name,description=identity.description,stepSeconds=npc.stepSeconds,
            appearance={templateId=npc.templateId,parts=self.appearance:Resolve(template.partIds)}}
        if npc.narrativeId then
            local look=self.narrative.adventure.characterAppearances.fixed[identity.actorTemplateId]
            if look then result.npcs[i].appearance.customizationJson=look end
        end
    end
    for i,cell in ipairs((area.baseLayout or area).cells) do
        local x,_,z=Hex.ToWorld(cell.q,cell.r,cell.height,area.hexRadius)
        result.cells[i]={q=cell.q,r=cell.r,x=x,z=z,height=cell.height,wallHeight=cell.wallHeight,layer=cell.layer,
            color=snapshotArray(cell.color),blocked=cell.blocked,kind=cell.kind,renderGround=cell.renderGround~=false,roomId=cell.roomId,interiorId=cell.interiorId or 0,
            coverInteriorId=cell.coverInteriorId or 0,cutawayGroup=cell.cutawayGroup or 0,cutawayLayer=cell.cutawayLayer or 0,walkMask=cell.walkMask,neighbors=snapshotArray(cell.neighbors),
            corners=cell.corners and snapshotArray(cell.corners) or {cell.height,cell.height,cell.height,cell.height,cell.height,cell.height},
            deckThickness=cell.deckThickness or 0,stairRise=cell.stairRise or 0,surfaceId=cell.surfaceId or 0,sideSurfaceId=cell.sideSurfaceId or 0}
    end
    for i,room in ipairs(area.rooms) do
        result.rooms[i]={id=room.id,name=room.name,tier=room.tier,presetId=room.presetId,centerIndex=room.center}
    end
    local used={}
    for _,prop in ipairs(area.props) do if not prop.container then
        local top=-math.huge;local cells={}
        for j,index in ipairs(prop.cells) do top=math.max(top,area.cells[index].height);cells[j]=index end
        top=prop.height or top
        local x,_,z=Hex.ToWorld(prop.q,prop.r,top,area.hexRadius);local scale=prop.scale*area.hexRadius
        result.props[#result.props+1]={assetId=prop.assetId,x=x+(prop.offsetX or 0),y=top+.015,z=z+(prop.offsetZ or 0),rotation=prop.yaw or -prop.rotation*60,scale=scale,
            interiorId=prop.interiorId or 0,cutaway=prop.cutaway==true,cameraObstacle=prop.cameraObstacle~=false,layer=prop.layer or -1,cutawayGroup=prop.cutawayGroup or 0,cutawayLayer=prop.cutawayLayer or 0,
            scaleX=prop.scaleX or scale,scaleY=prop.scaleY or scale,scaleZ=prop.scaleZ or scale,cells=cells}
        if not used[prop.assetId] then
            used[prop.assetId]=true
            local row=self.config:GetTable('MapAssetTable'):Get(prop.assetId)
            result.propAssets[#result.propAssets+1]={id=row.id,path=row.prefabPath}
        end
    end end
    return result
end
function AreaSystem:OnShutdown()
    self.layouts=nil
    if self.data then self.data:Clear();self.data=nil end
    self.adventure=nil
end
return AreaSystem
