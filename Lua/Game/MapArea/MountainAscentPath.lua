-- Curved traverses and level turning platforms precede the terrain height field.
local Hex=require('Game.Map.HexGrid')
local Terrain=require('Game.MapArea.NaturalTerrain')
local Path={};Path.__index=Path
local function smooth(t) return t*t*(3-2*t) end
local function clamp(value,low,high) return math.max(low,math.min(high,value)) end
function Path.Validate(row)
    assert(row.ascentPlatforms>=4 and row.ascentPlatforms<=5 and math.tointeger(row.ascentPlatforms),'Mountain ascent needs four or five intermediate platforms')
    assert(row.ascentPlatformRadius>=2 and row.ascentTrailRadius==1,'Mountain ascent requires a three-cell trail and roomy turns')
    assert(row.ascentHeight>=35 and row.ascentMaxGrade>0 and row.ascentMaxGrade<=.4,'Invalid mountain ascent grade')
    assert(row.ascentShoulderCells>=3 and row.ascentDetailHeight>=0 and row.ascentDetailHeight<=2,'Mountain shoulders must dominate small terrain noise')
end
function Path.Build(area,row,random)
    Path.Validate(row)
    assert(area.width>=64 and area.height>=64,'Mountain ascent requires at least 64 x 64 sampling')
    local self=setmetatable({area=area,row=row,nodes={},stages={},navigation={}},Path)
    self.step=math.sqrt(3)*area.hexRadius
    self.coreWidth=self.step*row.ascentTrailRadius+area.hexRadius
    local sign=random:Integer(0,1)==0 and -1 or 1
    local function jitter(amount) return random:Integer(-1000,1000)/1000*amount end
    local anchors={{u=sign*(-10+jitter(1)),r=7}}
    local firstR,lastR=16,area.height-17
    for i=1,row.ascentPlatforms do
        local t=(i-1)/(row.ascentPlatforms-1)
        local side=i%2==1 and sign or -sign
        anchors[#anchors+1]={u=side*(16-6*t+jitter(1.25)),r=math.floor(firstR+(lastR-firstR)*t+jitter(.8)+.5)}
    end
    anchors[#anchors+1]={u=jitter(1.5),r=area.height-8}
    local seen={}
    local function append(u,r)
        local q=area.width/2+u-(r-area.height/2)/2
        local iq,ir=Hex.FromWorld(math.sqrt(3)*area.hexRadius*(q+r/2),1.5*area.hexRadius*r,area.hexRadius)
        local cell=assert(area:Find(iq,ir),'Mountain traverse left the sampling rectangle')
        local previous=self.nodes[#self.nodes]
        if previous and previous.index==cell.index then return end
        if seen[cell.index] then
            local keep=seen[cell.index]
            assert(#self.nodes-keep<=2,'Mountain ascent self-intersects')
            for i=#self.nodes,keep+1,-1 do seen[self.nodes[i].index]=nil;self.nodes[i]=nil end
            return
        end
        if previous then assert(Hex.Distance(previous.q,previous.r,iq,ir)==1,'Mountain curve skipped a navigation hex') end
        local x,_,z=Hex.ToWorld(iq,ir,0,area.hexRadius)
        local node={index=cell.index,q=iq,r=ir,x=x,z=z,arc=(previous and previous.arc+self.step or 0)}
        self.nodes[#self.nodes+1]=node;seen[cell.index]=#self.nodes
    end
    for i=2,#anchors do
        local a,b=anchors[i-1],anchors[i]
        local bend=jitter(1.3);local skew=jitter(.55)
        local samples=math.ceil((math.abs(b.u-a.u)+b.r-a.r)*10)
        for sample=0,samples do
            local t=sample/samples
            append(a.u+(b.u-a.u)*smooth(t)+bend*math.sin(math.pi*t)^2*math.sin(2*math.pi*t),
                a.r+(b.r-a.r)*t+skew*math.sin(2*math.pi*t))
        end
    end
    for id,anchor in ipairs(anchors) do
        local x=math.sqrt(3)*area.hexRadius*(area.width/2+area.height/4+anchor.u)
        local z=1.5*area.hexRadius*anchor.r
        local station,distance
        for i,node in ipairs(self.nodes) do
            local score=(node.x-x)^2+(node.z-z)^2
            if not distance or score<distance then station,distance=i,score end
        end
        assert(distance<=area.hexRadius^2*1.01,'Mountain turn left its rasterized curve')
        local center=area.cells[self.nodes[station].index]
        local first,last=station,station
        while first>1 and Hex.Distance(center.q,center.r,self.nodes[first-1].q,self.nodes[first-1].r)<=row.ascentPlatformRadius do first=first-1 end
        while last<#self.nodes and Hex.Distance(center.q,center.r,self.nodes[last+1].q,self.nodes[last+1].r)<=row.ascentPlatformRadius do last=last+1 end
        if id>1 then assert(first>self.stages[id-1].routeEnd+2,'Mountain platforms overlap') end
        local x,_,z=Hex.ToWorld(center.q,center.r,0,area.hexRadius)
        local u=Terrain.Local(area,center.q,center.r)
        local stage={id=id,centerIndex=center.index,station=station,routeStart=first,routeEnd=last,x=x,z=z,u=u,r=center.r}
        self.stages[id]=stage
        for k=first,last do self.nodes[k].platform=id end
    end
    local climbingLength=0
    for i=2,#self.nodes do
        local previous,node=self.nodes[i-1],self.nodes[i]
        if not (node.platform and previous.platform==node.platform) then climbingLength=climbingLength+self.step end
        node.climbingLength=climbingLength
    end
    self.grade=row.ascentHeight/climbingLength
    assert(self.grade<=row.ascentMaxGrade,'Mountain ascent does not have enough run for its height and platforms')
    self.baseHeight=1.5;self.peakHeight=self.baseHeight+row.ascentHeight
    for _,node in ipairs(self.nodes) do node.height=self.baseHeight+(node.climbingLength or 0)*self.grade end
    for _,stage in ipairs(self.stages) do stage.height=self.nodes[stage.station].height end
    self.length=self.nodes[#self.nodes].arc
    for i,node in ipairs(self.nodes) do for j=i+10,#self.nodes do
        local other=self.nodes[j]
        assert(Hex.Distance(node.q,node.r,other.q,other.r)>row.ascentTrailRadius*2,'Mountain traverses overlap')
    end end
    local function assign(cell,station,platform)
        assert(cell and cell.q>=2 and cell.r>=2 and cell.q<area.width-2 and cell.r<area.height-2,'Mountain trail clearance touches the boundary')
        local node=self.nodes[station];local x,_,z=Hex.ToWorld(cell.q,cell.r,0,area.hexRadius)
        local distance=(node.x-x)^2+(node.z-z)^2
        local old=self.navigation[cell.index]
        if platform or not old or distance<old.distance then
            local _,height,position,arc=self:Project(x,z)
            self.navigation[cell.index]={station=math.floor(position+.5),arc=arc,height=platform and self.stages[platform].height or height,
                distance=distance,platform=platform}
        end
    end
    for station,node in ipairs(self.nodes) do
        for dr=-row.ascentTrailRadius,row.ascentTrailRadius do for dq=-row.ascentTrailRadius,row.ascentTrailRadius do
            if Hex.Distance(0,0,dq,dr)<=row.ascentTrailRadius then assign(area:Find(node.q+dq,node.r+dr),station) end
        end end
    end
    for _,stage in ipairs(self.stages) do
        local center=area.cells[stage.centerIndex]
        for dr=-row.ascentPlatformRadius,row.ascentPlatformRadius do for dq=-row.ascentPlatformRadius,row.ascentPlatformRadius do
            if Hex.Distance(0,0,dq,dr)<=row.ascentPlatformRadius then assign(area:Find(center.q+dq,center.r+dr),stage.station,stage.id) end
        end end
    end
    return self
end
function Path:Project(x,z)
    local nearest,height,station,arc=math.huge
    for i=2,#self.nodes do
        local a,b=self.nodes[i-1],self.nodes[i];local dx,dz=b.x-a.x,b.z-a.z
        local t=clamp(((x-a.x)*dx+(z-a.z)*dz)/(dx*dx+dz*dz),0,1)
        local distance=(x-a.x-dx*t)^2+(z-a.z-dz*t)^2
        if distance<nearest then
            nearest=distance;height=a.height+(b.height-a.height)*t;station=i-1+t;arc=a.arc+(b.arc-a.arc)*t
        end
    end
    return math.sqrt(nearest),height,station,arc
end
function Path:PlatformAt(x,z,extra)
    local radius=self.row.ascentPlatformRadius*self.step+(extra or 0)
    for _,stage in ipairs(self.stages) do if (x-stage.x)^2+(z-stage.z)^2<=radius*radius then return stage end end
end
function Path:CanConnect(a,b)
    if a.ascentStageGate and a.ascentStageGate==b.ascentStageGate then return true end
    return math.abs(a.ascentDistance-b.ascentDistance)<=self.step*3.1
end
return Path
