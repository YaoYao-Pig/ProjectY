-- A single-layer roadside interception; the sheltered traveler remains south of the tactical window.
local Hex=require('Game.Map.HexGrid')
local Rescue={}
function Rescue.Validate(profile)
    assert(profile.encounterId>0 and profile.roadSurfaceId>0 and profile.groundSurfaceId>0,'Roadside rescue requires encounter and surfaces')
    assert(#profile.treeAssetIds>0 and profile.rockAssetId>0 and profile.cartAssetId>0,'Roadside rescue requires existing cover assets')
    assert(math.tointeger(profile.battleRadius) and profile.battleRadius>=10 and profile.battleRadius<=12,'Roadside battle radius must leave the rear shelter outside combat')
end
function Rescue.Generate(area,profile,random,config)
    assert(area.hexRadius==1 and area.width>=32 and area.height>=32,'Roadside rescue requires meter-scale 32 x 32 sampling')
    local encounter=config:GetTable('CombatEncounterTable'):Get(profile.encounterId)
    assert(#encounter.enemyIds==4,'Roadside rescue needs three pursuers and one sheltered traveler')
    local surfaces=config:GetTable('MapAreaSurfaceTable')
    local centerQ,centerR=math.floor(area.width/2),math.floor(area.height/2)
    local function at(q,r)return assert(area:Find(centerQ+q,centerR+r))end
    area.props={};area.corridorRadius=1;area.generationVersion=1
    for _,cell in ipairs(area.cells) do
        local q,r=cell.q-centerQ,cell.r-centerR
        local across=2*q+r
        local land=r>=-15 and r<=9 and math.abs(across)<=13
        local road=math.abs(across)<=3
        cell.kind=land and 'floor' or 'void';cell.renderGround=land
        cell.blocked=not land;cell.blocksSight=not land
        cell.height=0;cell.roomId=1;cell.roomOwner=1;cell.roomTier=1;cell.reserved=true
        cell.surfaceId=road and profile.roadSurfaceId or profile.groundSurfaceId;cell.sideSurfaceId=cell.surfaceId
        cell.floorAccent=surfaces:Get(cell.surfaceId).baseColor;cell.floorAccentWeight=1
        if land then area.walkableCount=area.walkableCount+1 end
    end
    local function cover(assetId,q,r,yaw,scale)
        config:GetTable('MapAssetTable'):Get(assetId)
        local cell=at(q,r);assert(not cell.blocked,'Roadside cover overlaps another obstacle')
        cell.blocked=true;cell.blocksSight=true;area.walkableCount=area.walkableCount-1
        area.props[#area.props+1]={id=#area.props+1,assetId=assetId,q=cell.q,r=cell.r,layer=0,
            rotation=0,yaw=yaw,height=0,scale=scale,scaleX=scale,scaleY=scale,scaleZ=scale,cells={cell.index}}
    end
    -- The center of the road remains clear; side cover supports both melee and ranged approaches.
    for i,position in ipairs({{-6,3},{4,1},{-2,-5},{5,-3},{-6,8},{3,7}}) do
        cover(profile.treeAssetIds[(i-1)%#profile.treeAssetIds+1],position[1],position[2],random:Integer(0,359),.9)
    end
    for _,position in ipairs({{-4,3},{2,1},{-1,-3}}) do cover(profile.rockAssetId,position[1],position[2],25,1) end
    cover(profile.cartAssetId,-2,-1,65,1)
    -- A cart, stones and trees screen the rear clearing without disconnecting its approach.
    cover(profile.cartAssetId,9,-12,110,1)
    cover(profile.rockAssetId,8,-11,10,1)
    cover(profile.rockAssetId,10,-13,40,1)
    cover(profile.treeAssetIds[1],7,-12,180,1)
    cover(profile.treeAssetIds[#profile.treeAssetIds],12,-15,15,1)
    local entry,goal=at(2,-4),at(-4,8)
    local cells={at(-2,4),at(-4,5),at(0,4),at(10,-14)}
    area.entryIndex=entry.index;area.goalIndex=goal.index
    area.rooms={{id=1,name='路边拦截地',tier=1,presetId=0,center=at(0,0).index}}
    area.encounterPlans={{id=1,encounterId=encounter.id,cells=cells}}
    -- The event owns exclusion from the battle roster. These immutable bounds make its geometry check explicit.
    area.battleCenterIndex=cells[1].index;area.battleRadius=profile.battleRadius;area.safeIndex=cells[4].index
    assert(Hex.Distance(cells[1].q,cells[1].r,cells[4].q,cells[4].r)>profile.battleRadius+3,'Rear shelter is too close to the tactical window')
    for _,cell in ipairs(cells) do
        assert(not cell.blocked and area:FindPath(entry.index,cell.index),'Roadside deployment must remain reachable')
    end
    assert(area:FindPath(entry.index,goal.index),'Roadside road is disconnected')
end
return Rescue
