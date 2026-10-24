-- 固定比武审判场：中央单层战区、南北入口与仅作布景的三级木看台。
local Hex=require('Game.Map.HexGrid')
local Trial={}
function Trial.Validate(profile)
    assert(profile.encounterId>0 and profile.groundSurfaceId>0 and profile.standSurfaceId>0,'Trial ground needs encounter and surfaces')
    assert(profile.standRise>0 and profile.standRise<=.75,'Invalid trial stand rise')
end
function Trial.Generate(area,profile,random,config)
    assert(area.hexRadius==1 and area.width>=32 and area.height>=32,'Trial ground requires meter-scale 32 x 32 sampling')
    local encounter=config:GetTable('CombatEncounterTable'):Get(profile.encounterId)
    assert(#encounter.enemyIds==4,'Trial ground needs three opponents and one allied knight')
    local surfaces=config:GetTable('MapAreaSurfaceTable')
    local centerQ,centerR=math.floor(area.width/2),math.floor(area.height/2)
    local originX,_,originZ=Hex.ToWorld(centerQ,centerR,0,area.hexRadius)
    area.props={};area.corridorRadius=1;area.generationVersion=1
    local function at(q,r) return assert(area:Find(centerQ+q,centerR+r)) end
    for _,cell in ipairs(area.cells) do
        local x,_,z=Hex.ToWorld(cell.q,cell.r,0,area.hexRadius);x=x-originX;z=z-originZ
        local judge=math.abs(x)<=3.5 and z>=12 and z<=16.5
        local inside=math.abs(x)<=15.6 and z>=-14 and z<=15 or judge
        local court=math.abs(x)<=8.7 and math.abs(z)<=9
        local gate=math.abs(x)<=2.0 and z>=-13.5 and z<=10.5
        local stand=math.abs(x)>=10 and math.abs(x)<=15.6 and math.abs(z)<=9
        cell.kind=inside and 'floor' or 'void';cell.renderGround=inside
        cell.blocked=not (court or gate);cell.blocksSight=not inside
        cell.height=0;cell.roomId=1;cell.roomOwner=1;cell.roomTier=1;cell.reserved=true
        cell.surfaceId=profile.groundSurfaceId;cell.sideSurfaceId=profile.groundSurfaceId
        if stand then
            local tier=math.min(3,1+math.floor((math.abs(x)-10)/1.73))
            cell.height=tier*profile.standRise;cell.surfaceId=profile.standSurfaceId;cell.sideSurfaceId=profile.standSurfaceId
        elseif judge then
            cell.height=profile.standRise*2;cell.surfaceId=profile.judgeSurfaceId;cell.sideSurfaceId=profile.judgeSurfaceId
        end
        cell.floorAccent=surfaces:Get(cell.surfaceId).baseColor;cell.floorAccentWeight=1
        if not cell.blocked then area.walkableCount=area.walkableCount+1 end
    end
    local function prop(assetId,x,z,height,yaw,scaleX,scaleY,scaleZ)
        config:GetTable('MapAssetTable'):Get(assetId)
        local q,r=Hex.FromWorld(originX+x,originZ+z,area.hexRadius);local cell=assert(area:Find(q,r))
        local cx,_,cz=Hex.ToWorld(q,r,0,area.hexRadius)
        area.props[#area.props+1]={id=#area.props+1,assetId=assetId,q=q,r=r,rotation=0,yaw=yaw,
            offsetX=originX+x-cx,offsetZ=originZ+z-cz,height=height,scale=1,
            scaleX=scaleX,scaleY=scaleY,scaleZ=scaleZ,cells={cell.index},layer=0}
    end
    -- 石栏围住比武场，两端各留四米宽的出入口；外侧地格封闭，不能登上看台。
    for _,side in ipairs({-1,1}) do
        for z=-9,9 do prop(profile.fenceAssetId,side*9.5,z,0,90,1,.85,1) end
        for x=-9,9 do if math.abs(x)>=3 then prop(profile.fenceAssetId,x,side*9.75,0,0,1,.85,1) end end
        for tier=1,3 do
            local x=side*(5.5+tier)*math.sqrt(3)
            for z=-7.5,7.5,3 do prop(profile.benchAssetId,x,z,tier*profile.standRise,side*90,1,1,1) end
        end
        prop(profile.gateAssetId,0,side*10.5,0,0,1.35,1,1)
        prop(profile.lampAssetId,-3.2,side*11,0,0,1,1,1)
        prop(profile.lampAssetId,3.2,side*11,0,0,1,1,1)
    end
    -- 审判席在北入口后方，长桌与木凳落在独立的封闭高台上。
    prop(profile.judgeAssetId,0,13.5,profile.standRise*2,180,1,1,1)
    local entry=at(4,-8);local north=at(-3,7);local center=at(0,0)
    area.entryIndex=entry.index;area.goalIndex=north.index
    area.rooms={{id=1,name='骑士审判场',tier=1,presetId=0,center=center.index}}
    local cells={at(-4,4),at(-2,4),at(0,4),at(2,-4)}
    for _,cell in ipairs(cells) do assert(not cell.blocked and cell.height==0,'Trial combatants must stand on the arena floor') end
    area.encounterPlans={{id=1,encounterId=encounter.id,cells=cells}}
    -- 观众和审判席只属于冻结布局的展示布景；不进入可变 NPC 数组及存档。
    area.decorativeNpcs={}
    for _,row in ipairs(config:GetTable('MapAreaTrialGroundNpcTable'):All()) do if row.profileId==profile.id then
        local q,r=Hex.FromWorld(originX+row.localX,originZ+row.localZ,area.hexRadius)
        local cell=assert(area:Find(q,r))
        assert(cell.blocked and cell.renderGround and cell.kind~='void','Trial spectators must remain outside the navigable arena')
        area.decorativeNpcs[#area.decorativeNpcs+1]={id=-row.id,name=row.name,description=row.description,partIds=row.partIds,
            spawnIndex=cell.index,x=originX+row.localX,y=cell.height+.015,z=originZ+row.localZ,
            yaw=row.yaw,scale=row.scale,showName=row.showName}
    end end
end
return Trial
