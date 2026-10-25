local Terrain=require('Game.MapArea.NaturalTerrain')
local Canyon={}
function Canyon.Validate(row)
    Terrain.Validate(row)
    assert(row.depth>=24 and row.floorHalfWidth>=3 and row.shelfHeight>=5,'Canyon needs a deep valley and reachable shelves')
    assert(row.streamHalfWidth>0 and row.streamHalfWidth<1.5,'Canyon stream must leave a usable bank')
end
function Canyon.Generate(area,row,random,config)
    Canyon.Validate(row)
    local phase=random:Integer(0,628)/100
    local function center(r) return math.sin(r*.115+phase)*3 end
    local function valley(r) return -row.depth+2+r*.055 end
    Terrain.Begin(area,row,function(u,v,cell)
        local across=math.abs(u-center(cell.r));local along=valley(cell.r)
        local side=math.max(0,across-row.floorHalfWidth)
        local terrace=math.max(0,math.min(1,(side-1)/3))*row.shelfHeight
        local wall=math.max(0,side-7)*2.9
        local h=along+terrace+wall+random:Ridged(u,v,6,.55,2339)*math.min(side,5)
        local stream=across<row.streamHalfWidth and cell.r>12 and cell.r<area.height-12
        if stream then h=along-.4 end
        return h,stream and row.waterSurfaceId or (side<1 and row.valleySurfaceId or row.rockSurfaceId),stream
    end)
    local anchors={}
    for r=7,area.height-7,6 do anchors[#anchors+1]={cell=Terrain.At(area,center(r)+3.2,r),height=valley(r)} end
    Terrain.Trail(area,row,anchors)
    -- A long graded side loop climbs a wall shelf and returns to the same bank downstream.
    local start,last=anchors[2],anchors[#anchors-1]
    local shelf={start,{cell=Terrain.At(area,15,math.floor(area.height*.42)),height=start.height+row.shelfHeight},
        {cell=Terrain.At(area,15,math.floor(area.height*.62)),height=last.height+row.shelfHeight},last}
    Terrain.Trail(area,row,shelf)
    area.entryIndex=anchors[1].cell.index;area.goalIndex=anchors[#anchors].cell.index
    area.ropeLandingIndex=area.entryIndex
    area.rooms={{id=1,name=row.landingName,tier=1,presetId=0,center=area.entryIndex},
        {id=2,name=row.shelfName,tier=1,presetId=0,center=shelf[2].cell.index},
        {id=3,name=row.valleyName,tier=1,presetId=0,center=area.goalIndex}}
    Terrain.Finish(area,row,config)
    for _,cell in ipairs(area.cells) do
        if cell.blocked and cell.surfaceId~=row.waterSurfaceId and cell.q%7==0 and cell.r%6==0 then
            Terrain.ScenicProp(area,config,cell,row.rockAssetId,.8+random:Noise(cell.q,cell.r,6,457)*.6,random:Integer(0,359))
        end
    end
end
return Canyon
