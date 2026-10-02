local Hex = require('Game.Map.HexGrid')
local Random = require('Game.Map.SeededRandom')
local Board = {}
Board.__index = Board
function Board:Find(q, r, layer)
    if self.area then return self.byKey[Hex.Key(q,r)..':'..(layer or self.originLayer)] end
    return self.byKey[Hex.Key(q, r)]
end
function Board:Neighbors(cell)
    local result = {}
    if self.area then
        for _,other in ipairs(self.area:Neighbors(cell)) do if self.byIndex[other.index] then result[#result+1]=other end end
        return result
    end
    for d = 1, 6 do
        local q, r = Hex.Neighbor(cell.q, cell.r, d)
        local other = self:Find(q, r)
        if other and not other.blocked then result[#result + 1] = other end
    end
    return result
end
-- MapArea 遭遇窗口只选取原地格，保留 q/r、阻挡和对象身份；不修改持久地形。
function Board.FromArea(area,q,r,radius,layer)
    assert(math.tointeger(radius) and radius>=1 and radius<=32,'Invalid MapArea battle radius')
    layer=layer or 0;assert(area:Find(q,r,layer),'Battle window center must belong to the MapArea')
    local board=setmetatable({radius=radius,originQ=q,originR=r,originLayer=layer,area=area,cells={},byKey={},byIndex={}},Board)
    for _,cell in ipairs(area.cells) do if Hex.Distance(q,r,cell.q,cell.r)<=radius then
        board.cells[#board.cells+1]=cell;board.byKey[Hex.Key(cell.q,cell.r)..':'..cell.layer]=cell;board.byIndex[cell.index]=cell
    end end
    return board
end
-- 地形只在生成期写入；运行时占格查询来自 C# 单位状态。
function Board.Create(radius, seed, obstacleChance)
    assert(math.tointeger(radius) and radius >= 3 and radius <= 7, 'Invalid battle radius')
    assert(obstacleChance >= 0 and obstacleChance <= .4, 'Invalid obstacle chance')
    local board = setmetatable({radius = radius, cells = {}, byKey = {}}, Board)
    for q = -radius, radius do
        for r = math.max(-radius, -q - radius), math.min(radius, -q + radius) do
            local cell = {index=#board.cells+1,q = q, r = r, blocked = false}
            board.cells[#board.cells + 1] = cell; board.byKey[Hex.Key(q, r)] = cell
        end
    end
    local random = Random(seed)
    local function connected()
        local root = board:Find(-radius, 0)
        local queue, seen, head = {root}, {[root] = true}, 1
        while head <= #queue do
            local current = queue[head]; head = head + 1
            for _, cell in ipairs(board:Neighbors(current)) do
                if not seen[cell] then seen[cell] = true; queue[#queue + 1] = cell end
            end
        end
        for _, cell in ipairs(board.cells) do if not cell.blocked and not seen[cell] then return false end end
        return true
    end
    for _, cell in ipairs(board.cells) do
        if math.abs(cell.q) < radius and cell.r ~= 0 and random:Integer(1, 10000) <= obstacleChance * 10000 then
            cell.blocked = true
            if not connected() then cell.blocked = false end
        end
    end
    return board
end
-- 按移动距离求最短路；工事上下与坑沟附加距离，普通地格仍为 1。
function Board:Search(q, r, occupied, limit, allowed)
    local root = assert(self:Find(q, r), 'Path origin outside battle board')
    local queue,distance,previous,settled,result={root},{[root]=0},{},{},{}
    while #queue>0 do
        local best=1
        for i=2,#queue do if distance[queue[i]]<distance[queue[best]] then best=i end end
        local current=table.remove(queue,best)
        if not settled[current] then
        settled[current]=true;result[#result+1]=current
        if distance[current] < limit then
            for _, nextCell in ipairs(self:Neighbors(current)) do
                local cost=distance[current]+(self.area and self.area.MoveCost and self.area:MoveCost(current,nextCell) or 1)
                if cost<=limit and (not distance[nextCell] or cost<distance[nextCell]) and not occupied[Hex.Key(nextCell.q, nextCell.r)] and (not allowed or allowed(nextCell)) then
                    distance[nextCell] = cost
                    previous[nextCell] = current
                    queue[#queue + 1] = nextCell
                end
            end
        end
        end
    end
    return result, distance, previous
end
return Board
