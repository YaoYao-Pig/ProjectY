-- 只缓存静态坐标索引；已发现/当前可见格由远征 C# Data 唯一持有。
local Hex = require('Game.Map.HexGrid')
local Fog = {}; Fog.__index = Fog
function Fog.New(adventure)
    local radius = adventure.config:GetConstant('Map','WorldVisionRadius')
    assert(math.tointeger(radius) and radius >= 1 and radius <= 32, 'World vision radius must be in 1..32')
    return setmetatable({adventure=adventure,radius=radius,fullVision=false,
        data=CS.ProjectY.Data.WorldMapExplorationData.For(adventure.data)},Fog)
end
local function indexMap(map)
    local indices={};for i,cell in ipairs(map:GetCells()) do indices[Hex.Key(cell.q,cell.r)]=i end;return indices
end
function Fog:Bind(map)
    self.map=map;self.indices=indexMap(map);self.lastQ=nil;self.lastR=nil;self.fullVision=false
    self.knownRegions={};self.indexedKnownCount=0
end
function Fog:Cells(indices,q,r)
    local cells={}
    for dr=-self.radius,self.radius do
        for dq=math.max(-self.radius,-dr-self.radius),math.min(self.radius,-dr+self.radius) do
            local index=indices[Hex.Key(q+dq,r+dr)]
            if index then cells[#cells+1]=index end
        end
    end
    return cells
end
function Fog:Update()
    if self.fullVision then return end
    local travel=self.adventure.travel.data
    if self.lastQ==travel.Q and self.lastR==travel.R then return end
    self.data:Reveal(self:Cells(self.indices,travel.Q,travel.R));self.lastQ=travel.Q;self.lastR=travel.R
end
function Fog:RevealAll()
    assert(self.map,'Bind a world map before revealing it')
    if self.fullVision then return end
    local cells={};for i=1,self.data.CellCount do cells[i]=i end
    self.data:Reveal(cells);self.fullVision=true
end
function Fog:RestoreVision()
    assert(self.map,'Bind a world map before restoring its vision')
    if not self.fullVision then return end
    self.fullVision=false;self.lastQ=nil;self.lastR=nil
    self:Update()
end
function Fog:Reset(map)
    self:Bind(map);self.data:Reset(#map:GetCells());self:Update()
end
function Fog:Known(q,r,regionId)
    local index=self.indices[Hex.Key(q,r)]
    if index~=nil and self.data:IsKnown(index) then return true end
    if not regionId then return false end
    -- Derived query index only. Discovery remains in native Data and is append-only between Bind/Reset.
    local count=self.data.KnownCount
    if count<self.indexedKnownCount then self.knownRegions={};self.indexedKnownCount=0 end
    for i=self.indexedKnownCount,count-1 do
        local cell=self.map.cells[self.data:GetKnownAt(i)]
        self.knownRegions[cell.regionId]=true
    end
    self.indexedKnownCount=count
    return self.knownRegions[regionId]==true
end
function Fog:Visible(q,r)
    local index=self.indices[Hex.Key(q,r)];return index~=nil and self.data:IsVisible(index)
end
function Fog:Prepare(map,prepared)
    local data=CS.ProjectY.Data.WorldMapExplorationData.Prepared(prepared)
    if data.CellCount==0 then data:Reset(#map:GetCells()) end
    assert(data.CellCount==#map:GetCells(),'存档大地图探索范围与地图不符')
    local travel=CS.ProjectY.Data.ExpeditionPersistence.Travel(prepared)
    assert(map:FindCell(travel.Q,travel.R),'存档旅行位置不在地图内')
    data:Reveal(self:Cells(indexMap(map),travel.Q,travel.R))
end
return Fog
