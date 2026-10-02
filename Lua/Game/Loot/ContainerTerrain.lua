-- 查询视图只引用 C# 容器状态；破坏不会修改冻结布局。
local Layout=require('Game.MapArea.MapAreaLayout')
local Hex=require('Game.Map.HexGrid')
local Terrain={}
function Terrain.Wrap(base,loot,state)
    local records={}
    for i=0,state.LootCount-1 do local container=state:GetLootAt(i);local physical=loot:Physical(container)
        if physical.Configured then
            local definition=loot.rules.containers:Get(container.TableId)
            for j=0,physical.CellCount-1 do records[physical:GetCellAt(j)]={physical=physical,definition=definition} end
        end
    end
    local function view(source)
        local area={cells={},containerState=state,baseLayout=source.baseLayout or source}
        setmetatable(area.cells,{__len=function() return #source.cells end,__index=function(cells,index)
            local original=source.cells[index];if not original then return nil end
            local record=records[index];local cell=original
            if record then cell=setmetatable({}, {__index=function(_,key)
                if not record.physical.Destroyed then
                    if key=='blocked' then return original.blocked or record.definition.blocksMovement end
                    if key=='blocksSight' then return original.blocksSight or record.definition.blocksSight end
                end
                return original[key]
            end,__newindex=function()error('Container terrain is read-only',2)end}) end
            rawset(cells,index,cell);return cell
        end})
        function area:Find(q,r,layer) local cell=source:Find(q,r,layer);return cell and self.cells[cell.index] end
        function area:CanSee(origin,target)
            if not source:CanSee(origin,target) then return false end
            local distance=Hex.Distance(origin.q,origin.r,target.q,target.r)
            if distance<=1 then return true end
            local ax,_,az=Hex.ToWorld(origin.q,origin.r,0,1);local bx,_,bz=Hex.ToWorld(target.q,target.r,0,1)
            for _,epsilon in ipairs({-.000001,.000001}) do for step=1,distance-1 do
                local t=step/distance;local q,r=Hex.FromWorld(ax+(bx-ax)*t+epsilon,az+(bz-az)*t+epsilon,1)
                local cell=self:Find(q,r,origin.layer)
                if cell and cell.blocksSight then return false end
            end end
            return true
        end
        return setmetatable(area,{__index=function(_,key)
            if key=='MoveCost' then return source.MoveCost end
            return Layout[key] or source[key]
        end})
    end
    local area=view(base)
    function area:NavigationView() return view(base.NavigationView and base:NavigationView() or base) end
    return area
end
return Terrain
