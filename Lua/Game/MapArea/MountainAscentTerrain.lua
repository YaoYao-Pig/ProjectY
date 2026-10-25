-- Constrained height field: a broad mountain, wide trail shoulders and a small side cirque.
local Hex=require('Game.Map.HexGrid')
local Terrain=require('Game.MapArea.NaturalTerrain')
local Field={};Field.__index=Field
local function clamp(value,low,high) return math.max(low,math.min(high,value)) end
local function smooth(t) t=clamp(t,0,1);return t*t*(3-2*t) end
function Field.Build(area,row,path,random)
    local self=setmetatable({area=area,row=row,path=path,heights={},constraints={},distances={}},Field)
    local lakeStage=path.stages[3]
    local direction=lakeStage.u<0 and -1 or 1
    local lakeU=lakeStage.u+direction*(row.ascentPlatformRadius+row.ascentLakeRadius+3)
    self.lake={x=math.sqrt(3)*area.hexRadius*(area.width/2+area.height/4+lakeU),z=1.5*area.hexRadius*lakeStage.r,
        radius=row.ascentLakeRadius*path.step,height=lakeStage.height-1.5}
    local function backbone(r)
        if r<path.stages[1].r then return .2+(path.baseHeight-.2)*smooth(r/path.stages[1].r) end
        for i=2,#path.stages do
            local a,b=path.stages[i-1],path.stages[i]
            if r<=b.r then
                local ha=a.height+(i==2 and 0 or (path.peakHeight-a.height)*.12)
                local hb=b.height+(path.peakHeight-b.height)*.12
                return ha+(hb-ha)*smooth((r-a.r)/(b.r-a.r))
            end
        end
        return .2+(path.peakHeight-.2)*(1-smooth((r-path.stages[#path.stages].r)/(area.height-1-path.stages[#path.stages].r)))
    end
    local macro={};local fixed=self.constraints;local height=self.heights
    for _,cell in ipairs(area.cells) do
        local u=Terrain.Local(area,cell.q,cell.r)
        local x,_,z=Hex.ToWorld(cell.q,cell.r,0,area.hexRadius)
        local distance,trailHeight=path:Project(x,z);self.distances[cell.index]=distance
        local ridgeU=path.stages[#path.stages].u+math.sin(cell.r*.06)*1.5
        local lateral=clamp(math.abs(u-ridgeU)/(area.width*.62),0,1)
        local value=.2+(backbone(cell.r)-.2)*(1-lateral*lateral)^1.4
        macro[cell.index]=value;height[cell.index]=value
        local platform=path:PlatformAt(x,z,area.hexRadius)
        if platform then fixed[cell.index]=platform.height
        elseif distance<=path.coreWidth then fixed[cell.index]=trailHeight end
        local navigation=path.navigation[cell.index]
        if navigation then fixed[cell.index]=navigation.height end
        local lakeDistance=math.sqrt((x-self.lake.x)^2+(z-self.lake.z)^2)
        if lakeDistance<=self.lake.radius+area.hexRadius then
            assert(not navigation and distance>path.coreWidth,'Mountain lake intrudes into the ascent')
            fixed[cell.index]=self.lake.height
        elseif lakeDistance<=self.lake.radius+path.step*2 then
            fixed[cell.index]=self.lake.height+(lakeDistance-self.lake.radius)*.28
        end
        if cell.q==0 or cell.r==0 or cell.q==area.width-1 or cell.r==area.height-1 then fixed[cell.index]=.2 end
        if fixed[cell.index] then height[cell.index]=fixed[cell.index] end
    end
    local nextHeight={};local screening=.56/(row.ascentShoulderCells*row.ascentShoulderCells)
    for _=1,72 do
        for _,cell in ipairs(area.cells) do
            local index=cell.index
            if fixed[index] then nextHeight[index]=fixed[index]
            else
                local sum,count=macro[index]*screening,screening
                for _,neighbor in ipairs(cell.neighbors) do if neighbor>0 then sum=sum+height[neighbor];count=count+1 end end
                nextHeight[index]=sum/count
            end
        end
        height,nextHeight=nextHeight,height
    end
    self.heights=height
    local shoulder=path.coreWidth+row.ascentShoulderCells*path.step
    for _,cell in ipairs(area.cells) do if not fixed[cell.index] then
        local u,v=Terrain.Local(area,cell.q,cell.r)
        local attenuation=smooth((self.distances[cell.index]-shoulder)/(path.step*3))
        local detail=(random:Fractal(u,v,10,.4,14971)-.5)*2*row.ascentDetailHeight*attenuation
        height[cell.index]=clamp(height[cell.index]+detail,.2,path.peakHeight-.2)
    end end
    return self
end
function Field:IsWater(q,r)
    local x=math.sqrt(3)*self.area.hexRadius*(q+r/2);local z=1.5*self.area.hexRadius*r
    return (x-self.lake.x)^2+(z-self.lake.z)^2<=self.lake.radius^2
end
function Field:Sample(q,r)
    local area,path=self.area,self.path
    local x=math.sqrt(3)*area.hexRadius*(q+r/2);local z=1.5*area.hexRadius*r
    if (x-self.lake.x)^2+(z-self.lake.z)^2<=(self.lake.radius+area.hexRadius)^2 then return self.lake.height end
    local platform=path:PlatformAt(x,z,area.hexRadius)
    if platform then return platform.height end
    local distance,trailHeight=path:Project(x,z)
    if distance<=path.coreWidth then return trailHeight end
    q=clamp(q,0,area.width-1);r=clamp(r,0,area.height-1)
    local q0,r0=math.floor(q),math.floor(r);local q1,r1=math.min(q0+1,area.width-1),math.min(r0+1,area.height-1)
    local function at(a,b) return self.heights[b*area.width+a+1] end
    local lower=at(q0,r0)+(at(q1,r0)-at(q0,r0))*(q-q0)
    local upper=at(q0,r1)+(at(q1,r1)-at(q0,r1))*(q-q0)
    return lower+(upper-lower)*(r-r0)
end
return Field
