local Terrain=require('Game.MapArea.NaturalTerrain')
local Mountain={}
function Mountain.Validate(row)
    Terrain.Validate(row)
    assert(row.summitHeight>=35 and row.ridgeRelief>=10 and row.switchbacks>=4,'High mountain needs substantial rugged relief')
    assert(row.lakeRadius>=2 and row.lakeRadius<=5 and row.snowSurfaceId>0,'Invalid alpine lake/snow profile')
end
function Mountain.Generate(area,row,random,config)
    Mountain.Validate(row)
    local phase=random:Integer(0,628)/100
    local lakeR=math.floor(area.height*.35);local lakeU=-16
    local lakeHeight=row.summitHeight*.24
    Terrain.Begin(area,row,function(u,v,cell)
        local t=cell.r/(area.height-1)
        local ridge=random:Ridged(u,v,13,.6,1297)
        local peaks=math.exp(-((u-16)^2/70+(v-13)^2/130))+.8*math.exp(-((u+17)^2/85+(v+2)^2/110))
        local h=2+t*row.summitHeight+row.ridgeRelief*(ridge*.65+peaks)
        local lake=(u-lakeU)^2+(cell.r-lakeR)^2<=row.lakeRadius^2
        if lake then h=lakeHeight end
        local surface=lake and row.waterSurfaceId or (h>row.summitHeight*.82 and row.snowSurfaceId or row.rockSurfaceId)
        return h,surface,lake
    end)
    local anchors={}
    for i=0,row.switchbacks do
        local r=math.floor(7+(area.height-15)*i/row.switchbacks)
        local side=i%2==0 and -1 or 1
        local u=side*(11+math.sin(phase+i)*1.5)
        anchors[#anchors+1]={cell=Terrain.At(area,u,r),height=3+row.summitHeight*i/row.switchbacks}
    end
    Terrain.Trail(area,row,anchors)
    area.entryIndex=anchors[1].cell.index;area.goalIndex=anchors[#anchors].cell.index
    area.rooms={}
    for i,anchor in ipairs(anchors) do
        area.rooms[i]={id=i,name=row.landmarkName,tier=1,presetId=0,center=anchor.cell.index,height=anchor.height}
    end
    Terrain.Finish(area,row,config)
    for _,cell in ipairs(area.cells) do
        if cell.blocked and not cell.naturalBarrier and random:Noise(cell.q,cell.r,2,5939)>.87 then
            Terrain.ScenicProp(area,config,cell,row.rockAssetId,.75+random:Noise(cell.q,cell.r,4,705)*.8,random:Integer(0,359))
        elseif cell.blocked and cell.height<row.summitHeight*.45 and cell.surfaceId~=row.waterSurfaceId and cell.q%6==0 and cell.r%5==0 then
            Terrain.ScenicProp(area,config,cell,row.pineAssetId,.9,random:Integer(0,359))
        end
    end
end
return Mountain
