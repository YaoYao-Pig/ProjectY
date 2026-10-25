-- Shared, immutable navigation rules for ferries, owned boats and safe bank transfers.
local Hex=require('Game.Map.HexGrid')
local Navigation={};Navigation.__index=Navigation
function Navigation.New(map,rule)
    local self=setmetatable({map=map,rule=rule,falls={}},Navigation)
    for _,fall in ipairs(map:GetWaterfalls()) do
        self.falls[Hex.Key(fall.from.q,fall.from.r)..'>'..Hex.Key(fall.to.q,fall.to.r)]=true
        self.falls[Hex.Key(fall.to.q,fall.to.r)..'>'..Hex.Key(fall.from.q,fall.from.r)]=true
    end
    return self
end
function Navigation:Water(cell)
    return cell~=nil and cell.waterLevel~=nil and cell.waterDepth>=self.rule.minWaterDepth and not cell.worldTravelBlocked
end
function Navigation:Cost(a,b)
    if not self:Water(a) or not self:Water(b) or Hex.Distance(a.q,a.r,b.q,b.r)~=1 then return nil end
    if math.abs(a.waterLevel-b.waterLevel)>self.rule.maxWaterStep or self.falls[Hex.Key(a.q,a.r)..'>'..Hex.Key(b.q,b.r)] then return nil end
    return self.rule.minutesPerCell
end
function Navigation:Bank(land,water)
    if not land or land.waterLevel or land.worldTravelBlocked or land.buildingId or not self:Water(water) then return false end
    if Hex.Distance(land.q,land.r,water.q,water.r)~=1 or math.abs(land.height-water.waterLevel)>self.rule.maxBankRise then return false end
    -- A landing needs an inland continuation, not an isolated rock or impassable cliff edge.
    for _,nextCell in ipairs(self.map:GetNeighbors(land.q,land.r)) do
        if not nextCell.waterLevel and not nextCell.worldTravelBlocked and not nextCell.buildingId and
            math.abs(nextCell.height-land.height)<=self.rule.maxBankRise then return true end
    end
    return false
end
return Navigation
