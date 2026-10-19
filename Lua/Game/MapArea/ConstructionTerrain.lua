-- 静态布局的动态只读投影；地格身份稳定，修改值仅从 ConstructionData 查询。
local Hex=require('Game.Map.HexGrid')
local Layout=require('Game.MapArea.MapAreaLayout')
local Terrain={}
local function projection(base,definition,lazy)
    local area={cells={}}
    local function cellView(cell)
        return setmetatable({}, {__index=function(_,key)
            if key=='baseHeight' then return cell.height end
            -- 坐标、身份、邻接等静态字段不能触发 C# 工事版本查询。
            if key~='height' and key~='blocked' and key~='constructionSurface' then return cell[key] end
            local row=definition(cell)
            if key=='constructionSurface' then return row~=nil and (row.kind=='platform' or row.kind=='pit' or row.kind=='trench') end
            if row then
                if key=='height' and (row.kind=='platform' or row.kind=='pit' or row.kind=='trench') then return cell.height+row.height end
                if key=='blocked' then return cell.blocked or row.blocksMovement end
            end
            return cell[key]
        end,__newindex=function() error('Construction terrain is read-only',2) end,__metatable=false})
    end
    if lazy then
        setmetatable(area.cells,{__index=function(cells,index)
            local cell=base.cells[index];if not cell then return nil end
            local value=cellView(cell);rawset(cells,index,value);return value
        end,__len=function() return #base.cells end})
    else for i,cell in ipairs(base.cells) do area.cells[i]=cellView(cell) end end
    function area:Find(q,r,layer) local cell=base:Find(q,r,layer);return cell and self.cells[cell.index] end
    function area:MoveCost(from,to)
        local a,b=definition(from),definition(to);local extra=0
        local climb=math.abs(from.height-to.height)>.05
        if a and a.kind=='platform' and climb then extra=a.moveExtra end
        if b and (b.kind~='platform' or climb) then extra=math.max(extra,b.moveExtra) end
        return 1+extra
    end
    local function ownClear(origin,target,includeCell)
        local distance=Hex.Distance(origin.q,origin.r,target.q,target.r)
        if distance<=1 then return true end
        local ax,_,az=Hex.ToWorld(origin.q,origin.r,0,1);local bx,_,bz=Hex.ToWorld(target.q,target.r,0,1)
        for _,epsilon in ipairs({-.000001,.000001}) do for step=1,distance-1 do
            local t=step/distance;local q,r=Hex.FromWorld(ax+(bx-ax)*t+epsilon,az+(bz-az)*t+epsilon,1)
            if not includeCell or includeCell(q,r) then
                local cell=area:Find(q,r,origin.layer);local row=cell and definition(cell)
                if row and row.blocksSight and cell.baseHeight+row.height>=origin.height+1+(target.height-origin.height)*t then return false end
            end
        end end
        return true
    end
    function area:CanTrace(origin,target,query,includeCell)
        return base:CanTrace(origin,target,query,includeCell) and ownClear(origin,target,includeCell)
    end
    function area:ProjectileBlockers(origin,target,cell)
        local include=function(q,r)return q==cell.q and r==cell.r end
        local result={}
        if base.ProjectileBlockers then result=base:ProjectileBlockers(origin,target,cell)
        elseif not base:CanTrace(origin,target,nil,include) then
            result[1]={kind='terrain',key='terrain:'..(cell.layer or 0)..':'..Hex.Key(cell.q,cell.r),cell=cell,name='地形或陈设'}
        end
        if not ownClear(origin,target,include) then
            local record=assert(self.construction:Record(self.constructionSite,cell.index),'Construction blocker lost its record')
            local name=self.construction.skills and self.construction.skills:Get(record.SkillId).name or '工事'
            result[#result+1]={kind='construction',key='construction:'..self.constructionSite..':'..cell.index,
                cell=self.cells[cell.index],record=record,name=name}
        end
        return result
    end
    return setmetatable(area,{__index=function(_,key) return Layout[key] or base[key] end})
end
function Terrain.Wrap(base,construction,site)
    local function definition(cell)
        local record=construction:Record(site,cell.index)
        return record and construction.definitions:Get(record.SkillId)
    end
    local area=projection(base,definition,false)
    area.constructionSite=site;area.construction=construction;area.baseLayout=base
    -- 只供单次同步规划使用。刷新一次现有权威缓存，不把查询视图保存为地图状态。
    function area:NavigationView()
        local records=construction:Records(site)
        if not records then return base end
        local rows={}
        local function fixedDefinition(cell)
            local row=rows[cell.index]
            if row==nil then
                local record=records[cell.index]
                row=record and construction.definitions:Get(record.SkillId) or false;rows[cell.index]=row
            end
            return row~=false and row or nil
        end
        local view=projection(base,fixedDefinition,true)
        view.constructionSite=site;view.construction=construction;view.baseLayout=base
        return view
    end
    return area
end
return Terrain
