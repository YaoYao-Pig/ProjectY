-- 只检查新增封边几何和导航不变，不跑整套移动、Unity或编译。
package.path='Lua/?.lua;'..package.path
local Hex=require('Game.Map.HexGrid')
local Boundary=require('Game.MapArea.FloorBoundary')
local Layout=require('Game.MapArea.MapAreaLayout')
local function signedArea(points)
    local total=0;for i=1,#points,2 do local j=i+2;if j>#points then j=1 end;total=total+points[i]*points[j+1]-points[j]*points[i+1] end
    return total/2
end
local function topology(area)
    local rows={tostring(#area.cells),tostring(area.walkableCount),tostring(area.entryIndex),tostring(area.goalIndex)}
    for _,c in ipairs(area.cells) do
        rows[#rows+1]=table.concat({c.index,c.q,c.r,c.layer,c.height,tostring(c.blocked),c.walkMask,table.concat(c.neighbors,',')},':')
    end
    return table.concat(rows,'|')
end
local function geometry(area)
    local total=0
    for _,patch in ipairs(area.floorBoundaryPatches) do
        local owner=assert(area.cells[patch.ownerIndex]);assert(owner.kind~='stairs' and patch.thickness>0)
        local a=signedArea(patch.points);assert(a>1e-8 and a<=3*math.sqrt(3)/2*area.hexRadius^2+1e-6,'Invalid clipped hex area');total=total+a
        local x,z=0,0;for i=1,#patch.points,2 do x=x+patch.points[i];z=z+patch.points[i+1] end;x=x/(#patch.points/2);z=z/(#patch.points/2)
        local q,r=Hex.FromWorld(x,z,area.hexRadius);local existing=area:Find(q,r,owner.layer)
        assert(not existing or existing.kind=='void' or existing.kind=='water' or existing.renderGround==false,'Cap overlaps an existing full floor/furniture/stair cell')
        for i=1,#patch.points,2 do local j=i+2;if j>#patch.points then j=1 end;local k=j+2;if k>#patch.points then k=1 end
            assert((patch.points[j]-patch.points[i])*(patch.points[k+1]-patch.points[j+1])-(patch.points[j+1]-patch.points[i+1])*(patch.points[k]-patch.points[j])>=-1e-7,'Cap must remain convex CCW')
        end
    end
    return total
end
local fixture=Layout.New({id=1,name='边界夹具',areaType=2,width=12,height=12,hexRadius=1,visionRadius=4,moveStepSeconds=.1},1,{}, {})
for _,c in ipairs(fixture.cells) do c.kind='void';c.renderGround=false;c.height=0;c.walkMask=0 end
local owner=fixture:Find(5,5);owner.kind='floor';owner.renderGround=true;owner.height=2;owner.blocked=false
local blocked=fixture:Find(6,5);blocked.kind='floor';blocked.renderGround=true;blocked.height=2
local stair=fixture:Find(5,6);stair.kind='stairs';stair.renderGround=true;stair.height=1
local x,_,z=Hex.ToWorld(owner.q,owner.r,0,1)
local outer={x-3,z-2.2,x+3,z-2.2,x+3,z+2.2,x-3,z+2.2}
local hole={x-2.6,z-.4,x-1.8,z-.4,x-1.8,z+.4,x-2.6,z+.4}
local before=topology(fixture)
Boundary.Append(fixture,{cells={owner.index},outer=outer,holes={hole},height=2,thickness=.2,rings=2})
assert(#fixture.floorBoundaryPatches>0 and before==topology(fixture))
geometry(fixture)
for _,patch in ipairs(fixture.floorBoundaryPatches) do assert(not Boundary.Intersection(patch.points,hole),'A cap filled a protected hole') end
print('PASS clipped convex hex pieces, hole subtraction, existing blocked floor/stair exclusion and unchanged navigation')
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=file:read('*a');file:close();return bytes
end}})
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(2,require('Game.MapArea.TownGenerator'),'MapAreaTownTable','MapAreaTownThemeTable')
generator:Register(5,require('Game.MapArea.ShipwreckGenerator'),'MapAreaShipwreckTable','MapAreaShipwreckThemeTable')
generator:Register(6,require('Game.MapArea.MineGenerator'),'MapAreaMineTable','MapAreaMineThemeTable')
local source={regionId=3,regionConfigId=3,regionType=3,q=0,r=0,height=1,biomeWeights={{regionType=3,weight=1}}}
local stats={}
for _,spec in ipairs({{2,20260924,11},{40,20260921,300010},{50,20261005,7}}) do
    local area=generator:Generate(spec[1],spec[2],spec[3],source)
    local original=Boundary.Build
    Boundary.Build=function(a) a.floorBoundaryPatches={};a.floorBoundaryDefinitions=nil end
    local baseline=generator:Generate(spec[1],spec[2],spec[3],source);Boundary.Build=original
    assert(topology(area)==topology(baseline),'Boundary changed real cell identities or navigation')
    local surface=geometry(area);local count=#area.floorBoundaryPatches
    if spec[1]==50 then assert(count==0,'Natural mine openings must not be filled without authored straight-wall contours') else assert(count>0) end
    if spec[1]==40 then
        local profile=config:GetTable('MapAreaShipwreckTable'):Get(1);local ox,oz=area.shipOrigin.x,area.shipOrigin.z
        local breach={ox-100,oz+profile.gapMinZ,ox+profile.gapMaxX,oz+profile.gapMinZ,ox+profile.gapMaxX,oz+profile.gapMaxZ,ox-100,oz+profile.gapMaxZ}
        for _,patch in ipairs(area.floorBoundaryPatches) do if area.cells[patch.ownerIndex].layer==1 then assert(not Boundary.Intersection(patch.points,breach),'Ship breach was filled') end end
    elseif spec[1]==2 then
        for _,patch in ipairs(area.floorBoundaryPatches) do
            local owner=area.cells[patch.ownerIndex];assert(owner.layer==1 and owner.interiorId>0,'Town ground floor gained duplicate caps')
            local room=area.interiors[owner.interiorId];local floor=config:GetTable('MapAreaTownFloorTable'):Get(room.lotId)
            local prop;for _,p in ipairs(area.props) do if p.interiorId==room.id and not p.cutaway then prop=p;break end end
            local px,_,pz=Hex.ToWorld(prop.q,prop.r,0,area.hexRadius)
            local cx,cz=0,0;for i=1,#patch.points,2 do cx=cx+patch.points[i];cz=cz+patch.points[i+1] end
            local q,r=Hex.FromWorld(cx/(#patch.points/2),cz/(#patch.points/2),area.hexRadius)
            local wx,_,wz=Hex.ToWorld(q,r,0,area.hexRadius);local angle=math.rad(prop.rotation*60)
            local lx=(wx-px)*math.cos(angle)+(wz-pz)*math.sin(angle);local lz=(wz-pz)*math.cos(angle)-(wx-px)*math.sin(angle)
            local hx,hz=math.max(table.unpack(floor.boundaryX)),math.max(table.unpack(floor.boundaryZ))
            assert(math.abs(lx)>=hx-1e-7 or math.abs(lz)>=hz-1e-7,'Town interior atrium was filled')
        end
        -- 右侧完整回廊的外包线必须连续，不能只减小齿尖之间的缺口。
        for _,room in ipairs(area.interiors) do if room.upperEntryIndex then
            local definition=config:GetTable('MapAreaTownFloorTable'):Get(room.lotId)
            local prop;for _,p in ipairs(area.props) do if p.interiorId==room.id and not p.cutaway then prop=p;break end end
            local px,_,pz=Hex.ToWorld(prop.q,prop.r,0,area.hexRadius);local a=math.rad(prop.rotation*60)
            local hx,hz=math.max(table.unpack(definition.boundaryX)),math.max(table.unpack(definition.boundaryZ))
            for step=0,24 do
                local lx,lz=hx-1e-6,-hz+1e-6+(2*hz-2e-6)*step/24
                local x,z=px+lx*math.cos(a)-lz*math.sin(a),pz+lx*math.sin(a)+lz*math.cos(a)
                local covered=false
                for _,index in ipairs(room.cells) do local cell=area.cells[index]
                    if cell.layer==1 and cell.kind~='stairs' and Boundary.Contains(Boundary.Hex(cell.q,cell.r,area.hexRadius),x,z) then covered=true;break end
                end
                if not covered then for _,patch in ipairs(area.floorBoundaryPatches) do
                    if area.cells[patch.ownerIndex].interiorId==room.id and Boundary.Contains(patch.points,x,z) then covered=true;break end
                end end
                assert(covered,'Straight loft outline still has a notch')
            end
        end end
    end
    stats[#stats+1]={areaId=spec[1],patches=count,squareMeters=surface,cells=#area.cells,walkable=area.walkableCount,navigationUnchanged=true}
    print(string.format('PASS area %d: %d patches, %.3f m2, %d cells / %d walkable unchanged',spec[1],count,surface,#area.cells,area.walkableCount))
end
return stats
