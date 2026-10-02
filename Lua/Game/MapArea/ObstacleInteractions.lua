local Hex=require('Game.Map.HexGrid')
local Random=require('Game.Map.SeededRandom')
local Obstacles={};Obstacles.__index=Obstacles
function Obstacles.New(config,adventure)
    local self=setmetatable({adventure=adventure,areas=adventure.areas,rules=config:GetTable('MapAreaObstacleTable'),
        data=CS.ProjectY.Data.MapObstacleData()},Obstacles)
    for _,row in ipairs(self.rules:All()) do
        adventure.equipment.rules.tags:Get(row.toolTag)
        adventure.equipment.rules.assets:Get(row.assetId)
        adventure.events.events:Get(row.eventId)
        if row.lootTableId~=0 then adventure.equipment.worldLoot.rules.containers:Get(row.lootTableId) end
        assert(row.toolRounds<=row.manualRounds,'Tools must not take longer than manual work')
    end
    return self
end
function Obstacles:Initialize()
    local area,state=self.areas:ActiveLayout(),self.areas.data.Active
    if self.data:IsInitialized(state.SiteId) then return end
    local used=self.areas:EnemyOccupancy(area,state)
    for i=0,state.MemberCount-1 do
        local actor=self.areas:PartyActor(state:GetMemberIdAt(i));local cell=area.cells[state:GetMemberCellAt(i)]
        for _,part in ipairs(assert(self.areas.combatStats.animals:Cells(actor,area,cell.q,cell.r,cell.layer))) do used[part.index]=true end
    end
    for i=0,state.NpcCount-1 do used[state:GetNpcAt(i).CellIndex]=true end
    for i=0,state.LootCount-1 do used[state:GetLootAt(i).CellIndex]=true end
    for _,plan in ipairs(require('Game.MapArea.ObstacleGenerator').Plan(area,self.rules:All(),used)) do
        local rule=self.rules:Get(plan.ruleId);local ids,counts={},{}
        if rule.lootTableId~=0 then ids,counts=self.adventure.equipment.worldLoot.rules:Roll(rule.lootTableId,plan.seed) end
        self.data:Add(state.SiteId,rule.id,rule.blocksMovement,plan.cells,ids,counts)
    end
    self.data:CompleteInitialization(state.SiteId)
end
function Obstacles:BlockedCells()
    local site=self.areas.data.ActiveSiteId;local result={}
    for i=1,self.data:Count(site) do local row=self.data:Get(site,i)
        if row.BlocksMovement and not row.Cleared then for j=0,row.CellCount-1 do result[row:GetCellAt(j)]=true end end
    end
    return result
end
function Obstacles:Near(row)
    local area,state=self.areas:ActiveLayout(),self.areas.data.Active
    for i=0,state.MemberCount-1 do local member=area.cells[state:GetMemberCellAt(i)]
        for j=0,row.CellCount-1 do local cell=area.cells[row:GetCellAt(j)]
            if member.layer==cell.layer and Hex.Distance(member.q,member.r,cell.q,cell.r)<=1 and area:CanSee(member,cell) then return true end
        end
    end
    return false
end
function Obstacles:Begin(id)
    local adventure=self.adventure;local site=self.areas.data.ActiveSiteId
    if adventure.data.Phase~='area' or id<1 or id>self.data:Count(site) then return false,'当前无法处理此障碍' end
    local row=self.data:Get(site,id)
    if row.Cleared then return false,'这里已经处理过了' end
    if not self:Near(row) then return false,'请先靠近障碍（相邻一格）' end
    local rule=self.rules:Get(row.RuleId)
    local ok,reason=adventure.events:BeginArea(rule.eventId,'obstacle:'..site..':'..id,rule.name)
    if not ok then return false,reason end
    self.data:Begin(site,id);self.areas.data.Active:Stop();return true
end
function Obstacles:MoveTo(index)
    local area,state=self.areas:ActiveLayout(),self.areas.data.Active
    if self.adventure.data.Phase~='area' then return false,'当前不在探索区域' end
    self.data:Cancel()
    local target=area.cells[index]
    if not target or target.blocked or not state:IsKnown(index) then return self.areas:MoveToIndex(index) end
    local id=self.data:AtCell(state.SiteId,index)
    if id==0 then
        local ok,reason=self.areas:MoveToIndex(index)
        if ok then return true end
        local path=area:FindPath(state.CellIndex,index,function(cell)return state:IsKnown(cell.index)end)
        if not path then return false,reason end
        for _,cell in ipairs(path) do if self.data:IsBlocked(state.SiteId,cell) then id=self.data:AtCell(state.SiteId,cell);break end end
        if id==0 then return false,reason end
    end
    local row=self.data:Get(state.SiteId,id)
    if self:Near(row) then return self:Begin(id) end
    local blocked=self:BlockedCells();local best,bestLength
    local occupied=self.areas:EnemyOccupancy(area,state)
    for i=0,row.CellCount-1 do for _,cell in ipairs(area:Neighbors(area.cells[row:GetCellAt(i)])) do
        if not blocked[cell.index] and state:IsKnown(cell.index) then
            local path=area:FindPath(state.CellIndex,cell.index,function(c)return state:IsKnown(c.index) and not blocked[c.index] and not occupied[c.index] and not state:IsNpcOccupied(c.index)end)
            if path and (not bestLength or #path<bestLength) then best,bestLength=cell.index,#path end
        end
    end end
    if not best then return false,'尚未发现通往障碍边缘的路线' end
    local ok,reason=self.areas:MoveToIndex(best)
    if ok then self.data:Request(state.SiteId,id) end
    return ok,reason
end
function Obstacles:TryRequested()
    if self.data.RequestedId==0 or self.data.CurrentSiteId~=self.areas.data.ActiveSiteId then return false end
    local row=self.data:Get(self.data.CurrentSiteId,self.data.RequestedId)
    if self:Near(row) then return self:Begin(row.Id) end
    if self.areas.data.Active.RemainingSteps==0 then self.data:Cancel() end
    return false
end
function Obstacles:Worker(tag)
    local equipment=self.adventure.equipment;local best
    for i=0,self.adventure.data.PartyCount-1 do local actor=self.adventure.data:GetPartyAt(i)
        if actor.HP>0 then
            if tag then
                for _,hand in ipairs({'Equipped','Offhand'}) do local weapon=equipment.data[hand](equipment.data,actor.Id)
                    if weapon and equipment.rules:HasWeaponTag(weapon.ItemId,tag) then return actor end
                end
            elseif not best or actor.HP>best.HP then best=actor end
        end
    end
    return best
end
function Obstacles:Current()
    assert(self.data.CurrentId~=0 and self.data.CurrentSiteId==self.areas.data.ActiveSiteId,'No active obstacle event')
    local row=self.data:Get(self.data.CurrentSiteId,self.data.CurrentId)
    return row,self.rules:Get(row.RuleId)
end
function Obstacles:CanChoose(action)
    if self.data.CurrentId==0 or self.data.CurrentSiteId~=self.areas.data.ActiveSiteId then return false,'障碍交互已经结束' end
    local row,rule=self:Current()
    if row.Cleared or self.adventure.data.EventId~=rule.eventId then return false,'障碍事件已失效' end
    if action=='leave' then return true end
    if action=='tool' and not self:Worker(rule.toolTag) then
        return false,'需要存活队员在主手或副手装备「'..self.adventure.equipment.rules.tags:Get(rule.toolTag).name..'」武器'
    end
    if not self:Worker(nil) then return false,'没有存活队员' end
    return true
end
function Obstacles:ChoiceDetails(action)
    local _,rule=self:Current()
    if action=='leave' then return '保留现场，之后可以再来' end
    local tool=action=='tool';local chance=tool and rule.toolChance or rule.manualChance
    return string.format('%d 探索回合 · 成功率 %d%% · %s',tool and rule.toolRounds or rule.manualRounds,chance,
        tool and '免搬运伤害' or ('执行者损失最多 '..rule.manualDamage..' 生命（保留 1 点）'))
end
function Obstacles:Resolve(action)
    local row,rule=self:Current()
    if action=='leave' then self.data:Cancel();return '小队暂时离开，现场保持原样。' end
    local tool=action=='tool';local worker=assert(self:Worker(tool and rule.toolTag or nil));local loss=0
    if not tool then
        -- 搬运由角色本人承担，不通过战斗伤害转移给坐骑。
        loss=self.data:Exert(worker,rule.manualDamage)
    end
    local area,state=self.areas:ActiveLayout(),self.areas.data.Active
    local random=Random((area.seed ~ rule.seedSalt ~ row.Id*104729 ~ (row.Attempts+1)*65537) & 0xffffffff)
    local success=random:Integer(1,100)<= (tool and rule.toolChance or rule.manualChance)
    if success and rule.lootTableId~=0 then
        local ids,counts={},{}
        for i=0,row.ItemCount-1 do ids[#ids+1]=row:GetItemAt(i);counts[#counts+1]=row:GetCountAt(i) end
        state:AddLoot(row:GetCellAt(0),rule.lootTableId,rule.name..'中的发现',ids,counts,true)
    end
    self.data:Resolve(success)
    local rounds=tool and rule.toolRounds or rule.manualRounds
    self.areas:SpendWorkRounds(rounds)
    local name=self.adventure.battle.stats:Template(worker).name
    return string.format('%s花费 %d 探索回合%s。%s',name,rounds,loss>0 and ('，损失 '..loss..' 生命') or '',
        success and (rule.lootTableId~=0 and '已处理完毕，发现可搜刮的容器。' or '障碍已清除，道路恢复通行。') or '未能打开，箱子与内容保留，可以再次尝试。')
end
function Obstacles:Snapshot()
    local state=self.areas.data.Active;local visible,result={},{ }
    for i=0,state.VisibleCount-1 do visible[state:GetVisibleAt(i)]=true end
    for id=1,self.data:Count(state.SiteId) do local row=self.data:Get(state.SiteId,id)
        if not row.Cleared then
            local rule=self.rules:Get(row.RuleId);local cells={}
            for j=0,row.CellCount-1 do local index=row:GetCellAt(j);if visible[index] then cells[#cells+1]=index end end
            if #cells>0 then result[#result+1]={id=id,name=rule.name,cells=cells,blocksMovement=rule.blocksMovement,
                asset=self.adventure.equipment.rules:Asset(rule.assetId)} end
        end
    end
    return result
end
return Obstacles
