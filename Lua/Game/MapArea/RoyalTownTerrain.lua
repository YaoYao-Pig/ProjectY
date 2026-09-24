-- 王城先生成地形与独立片区锚点。台阶逐层错位，桥下与桥面共享坐标但不共享层。
local Geometry=require('Game.MapArea.DungeonGeometry')
local Terrain={}
function Terrain.Build(area,row,recipe,random,config)
    local turn=random:Integer(0,5);local cq,cr=area.width//2,area.height//2
    local step=recipe.terraceHeight*area.theme.reliefScale
    local context={turn=turn,step=step,bridgeCells={},districts={},connectors={}}
    function context:World(q,r)local x,y=Geometry.Rotate(q,r,turn);return cq+x,cr+y end
    function context:Cell(q,r,layer)local x,y=self:World(q,r);return area:Find(x,y,layer) end
    function context:Boundary(band,u)
        local boundary=recipe.boundaryR[band]+u*recipe.boundarySlope[band]+(random:Noise(u,band*23,recipe.contourScale,711)-.5)*2*recipe.boundaryAmplitude[band]
        if math.abs(u-self.valleyU)<=row.valleyHalfWidth+2 then
            if band==1 then boundary=math.max(boundary,recipe.bridgeR+(row.bridgeWidth-1)/2+1)
            elseif band==2 then boundary=math.min(boundary,recipe.bridgeR-(row.bridgeWidth-1)/2-1) end
        end
        if band>1 then boundary=math.min(boundary,self:Boundary(band-1,u)-recipe.rampLength-2) end
        return boundary
    end
    local function outline(r)
        local band=1
        while band<#recipe.outlineR-1 and r>recipe.outlineR[band+1] do band=band+1 end
        local t=math.max(0,math.min(1,(r-recipe.outlineR[band])/(recipe.outlineR[band+1]-recipe.outlineR[band])))
        t=t*t*(3-2*t)
        local left=recipe.outlineLeft[band]*(1-t)+recipe.outlineLeft[band+1]*t
        local right=recipe.outlineRight[band]*(1-t)+recipe.outlineRight[band+1]*t
        return left+random:Noise(r,0,recipe.contourScale,713)*recipe.outlineInset,
            right-random:Noise(r,0,recipe.contourScale,719)*recipe.outlineInset
    end
    local districts=config:GetTable('MapAreaRoyalDistrictTable')
    for _,id in ipairs(recipe.districtIds) do
        local definition=districts:Get(id)
        context.districts[id]={id=id,role=definition.role,name=definition.name,searchRadius=definition.searchRadius,roadRadius=definition.roadRadius,
            q=definition.centerQ+random:Integer(-definition.shiftQ,definition.shiftQ),
            r=definition.centerR+random:Integer(-definition.shiftR,definition.shiftR)}
    end
    assert(#recipe.boundaryR==3 and #recipe.boundaryAmplitude==3 and #recipe.stairBand==#recipe.stairU,'Invalid royal contour configuration')
    assert(step-row.bridgeThickness>=row.bridgeClearance,'Invalid royal bridge clearance')
    for i,u in ipairs(recipe.stairU) do
        local band=recipe.stairBand[i];assert(recipe.boundaryR[band],'Invalid royal stair band')
        local cross=u+random:Integer(-recipe.stairJitter,recipe.stairJitter)
        local minimum,maximum=-math.huge,math.huge
        local reach=math.ceil(recipe.rampLength/2+recipe.boundaryAmplitude[band]+math.abs(recipe.boundarySlope[band])*recipe.halfWidth+1)
        for r=recipe.boundaryR[band]-reach,recipe.boundaryR[band]+reach do
            local left,right=outline(r)
            minimum=math.max(minimum,left+row.rampWidth/2+recipe.stairBoundaryMargin)
            maximum=math.min(maximum,right-row.rampWidth/2-recipe.stairBoundaryMargin)
        end
        assert(minimum<maximum,'Royal stairs have no clearance inside the city boundary')
        cross=math.max(math.ceil(minimum),math.min(math.floor(maximum),cross))
        context.connectors[#context.connectors+1]={band=band,u=cross,kind=i%2==1 and 'stairs' or 'ramp'}
    end
    context.valleyU=random:Integer(recipe.valleyURange[1],recipe.valleyURange[2])
    local angle=math.rad(-turn*60);local cosine,sine=math.cos(angle),math.sin(angle)
    for _,cell in ipairs(area.cells) do
        local q,r=Geometry.Rotate(cell.q-cq,cell.r-cr,-turn);local u=q+r/2
        cell.localQ=q;cell.localR=r;cell.kind='garden';cell.surface='ground';cell.blocksSight=false
        -- 两侧城界分别受地形影响，不做左右镜像；整体方向仍可随种子旋转。
        local left,right=outline(r)
        cell.blocked=u<left or u>right or r<recipe.minR or r>recipe.maxR
        local valley=math.abs(u-context.valleyU)<row.valleyHalfWidth and r>=recipe.valleyMinR
        local level=0;for band in ipairs(recipe.boundaryR) do if r<context:Boundary(band,u) then level=level+1 end end
        cell.height=valley and 0 or level*step
        local connector
        if not valley then for _,candidate in ipairs(context.connectors) do
            if math.abs(u-candidate.u)<=row.rampWidth/2 and math.abs(r-context:Boundary(candidate.band,u))<=recipe.rampLength/2+.7 then
                connector=candidate;break
            end
        end end
        local function sample(dx,dz)
            if not connector then return cell.height end
            local du=(dx*cosine-dz*sine)/math.sqrt(3);local dr=(dx*sine+dz*cosine)/1.5
            local t=math.max(0,math.min(1,(context:Boundary(connector.band,u+du)+recipe.rampLength/2-r-dr)/recipe.rampLength))
            return (connector.band-1+t)*step
        end
        cell.corners={};for i=1,6 do local a=math.rad(30+(i-1)*60);cell.corners[i]=sample(math.cos(a),math.sin(a)) end
        if connector then
            cell.height=sample(0,0);cell.kind=connector.kind;cell.stairRise=connector.kind=='stairs' and row.stairRise or 0;cell.reserved=true
            cell.floorAccent=recipe.pavingColor;cell.floorAccentWeight=.96
        end
        if cell.blocked then cell.height=-.4;cell.kind='garden';cell.corners={-.4,-.4,-.4,-.4,-.4,-.4};cell.stairRise=0 end
        cell.townInside=not cell.blocked
        if not cell.blocked then area.walkableCount=area.walkableCount+1 end
    end
    local half=(row.bridgeWidth-1)//2
    for r=recipe.bridgeR-half,recipe.bridgeR+half do for q=-recipe.halfWidth,recipe.halfWidth do
        if math.abs(q+r/2-context.valleyU)<row.valleyHalfWidth then
            local base=assert(context:Cell(q,r));assert(not base.blocked,'Royal bridge outside terrain')
            local cell=area:AddLayerCell(base.q,base.r,1,step)
            cell.localQ=q;cell.localR=r;cell.corners={step,step,step,step,step,step};cell.deckThickness=row.bridgeThickness
            cell.floorAccent=recipe.pavingColor;cell.floorAccentWeight=.96;cell.reserved=true
            context.bridgeCells[#context.bridgeCells+1]=cell.index
        end
    end end
    require('Game.MapArea.TownTerrain').Connect(area,row)
    area.districts=context.districts
    return context
end
return Terrain
