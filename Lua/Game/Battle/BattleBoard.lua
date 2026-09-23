local Hex = require('Game.Map.HexGrid')
local Random = require('Game.Map.SeededRandom')
local Board = {}
Board.__index = Board
function Board:Find(q, r) return self.byKey[Hex.Key(q, r)] end
function Board:Neighbors(cell)
    local result = {}
    for d = 1, 6 do
        local q, r = Hex.Neighbor(cell.q, cell.r, d)
        local other = self:Find(q, r)
        if other and not other.blocked then result[#result + 1] = other end
    end
    return result
end
-- MapArea 遭遇窗口只选取原地格，保留 q/r、阻挡和对象身份；不修改持久地形。
function Board.FromArea(area,q,r,radius)
    assert(math.tointeger(radius) and radius>=1 and radius<=32,'Invalid MapArea battle radius')
    assert(area:Find(q,r),'Battle window center must belong to the MapArea')
    local board=setmetatable({radius=radius,originQ=q,originR=r,cells={},byKey={}},Board)
    for dr=-radius,radius do for dq=math.max(-radius,-dr-radius),math.min(radius,-dr+radius) do
        local cell=area:Find(q+dq,r+dr)
        if cell then board.cells[#board.cells+1]=cell;board.byKey[Hex.Key(cell.q,cell.r)]=cell end
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
            local cell = {q = q, r = r, blocked = false}
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
-- BFS 同时返回距离和前驱；占格不跨越，尸体允许通行。
function Board:Search(q, r, occupied, limit)
    local root = assert(self:Find(q, r), 'Path origin outside battle board')
    local queue, distance, previous, head = {root}, {[root] = 0}, {}, 1
    while head <= #queue do
        local current = queue[head]; head = head + 1
        if distance[current] < limit then
            for _, nextCell in ipairs(self:Neighbors(current)) do
                if distance[nextCell] == nil and not occupied[Hex.Key(nextCell.q, nextCell.r)] then
                    distance[nextCell] = distance[current] + 1
                    previous[nextCell] = current
                    queue[#queue + 1] = nextCell
                end
            end
        end
    end
    return queue, distance, previous
end
return Board
