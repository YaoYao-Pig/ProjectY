-- 定向离线检查：真实三层船、梯道环路、完整六角、支撑小物、四人逐层往返。
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=file:read('*a');file:close();return bytes
end}})
local Hex=require('Game.Map.HexGrid')
local Floors=require('Game.MapArea.ShipwreckFloors')
local Ship=require('Game.MapArea.ShipwreckGenerator')
local Props=require('Game.MapArea.ShipwreckProps')
local Squad=require('Game.MapArea.SquadMovement')
local Chest=require('Game.Loot.ChestGenerator')
local AreaSystem=require('Game.MapArea.MapAreaSystem')
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(5,Ship,'MapAreaShipwreckTable','MapAreaShipwreckThemeTable')
local profile=config:GetTable('MapAreaShipwreckTable'):Get(1)
local source={regionId=3,regionConfigId=3,regionType=3,q=0,r=0,height=1,biomeWeights={{regionType=3,weight=1}}}
local edges={{1,6,3,4},{5,6,3,2},{4,5,2,1},{3,4,1,6},{2,3,6,5},{1,2,5,4}}
local function signature(a)
    local values={};for _,p in ipairs(a.props) do values[#values+1]=table.concat({p.assetId,p.q,p.r,p.layer,p.offsetX or 0,p.offsetZ or 0},':') end
    return table.concat(values,'|')
end
local function check(area,walk)
    local queue,dist=Chest.Distances(area);assert(#queue==area.walkableCount and #queue>=1200)
    assert(#area.rooms==9 and #area.stairs==4 and area.generationVersion==2)
    local counts={};local actual=0
    for _,cell in ipairs(area.cells) do if not cell.blocked then
        actual=actual+1;counts[cell.layer]=(counts[cell.layer] or 0)+1
        if cell.kind~='stairs' then
            local x,_,z=Hex.ToWorld(cell.q,cell.r,0,area.hexRadius);local safe=false
            for _,floor in ipairs(area.shipFloors) do if floor.layer==cell.layer and Floors.SafeCell(profile,floor,x-area.shipOrigin.x,z-area.shipOrigin.z,area.hexRadius) then safe=true end end
            assert(safe,'Ship walkable hex extends beyond its actual deck')
        end
        for d,index in ipairs(cell.neighbors) do local other=area.cells[index]
            if area:CanStep(cell,other) then
                assert(area:CanStep(other,cell) and Hex.Distance(cell.q,cell.r,other.q,other.r)==1,'Floor edge is one-way or teleports')
                local e=edges[d]
                assert(math.abs(cell.corners[e[1]]-other.corners[e[3]])<.00001 and math.abs(cell.corners[e[2]]-other.corners[e[4]])<.00001,'Stair seam is discontinuous')
                assert(math.abs(cell.height-other.height)<=.801,'Sudden ship step')
            end
        end
        for layer=0,cell.layer-1 do local lower=area:Find(cell.q,cell.r,layer)
            if lower and not lower.blocked then
                assert(not area:CanStep(cell,lower) and not area:CanStep(lower,cell),'Direct vertical floor jump')
                assert(math.min(table.unpack(cell.corners))-cell.deckThickness-math.max(table.unpack(lower.corners))>=2-.00001,'Low passage headroom')
            end
        end
    elseif cell.kind=='water' then assert(not cell.blocksSight and cell.height==-1.15) end end
    assert(actual==area.walkableCount and counts[0]>=400 and counts[1]>=750 and counts[2]>=200)
    for i,bounds in ipairs(area.propBounds) do for j=1,i-1 do local other=area.propBounds[j]
        if bounds.placementId~=other.placementId then assert(not Props.Overlaps(bounds,other,-.02),'Furniture bounds intersect: '..bounds.placementId..'/'..other.placementId) end
    end end
    local types={};local supported=0
    for _,prop in ipairs(area.props) do if prop.dressingId then
        types[prop.assetId]=true
        local row=config:GetTable('MapAreaShipwreckDressingTable'):Get(prop.dressingId)
        assert(prop.scaleX==1 and prop.scaleY==1 and prop.scaleZ==1,'Tabletop item was enlarged with hull')
        if prop.supportId then
            supported=supported+1;local parent=area.props[prop.supportId]
            local support=config:GetTable('MapAreaShipwreckPlacementTable'):Get(parent.placementId)
            assert(math.abs(prop.height+row.baseY-parent.height-support.surfaceHeight)<.00001,'Floating table item')
            assert(prop.localX+row.centerX-row.halfX>=support.surfaceMinX and prop.localX+row.centerX+row.halfX<=support.surfaceMaxX)
            assert(prop.localZ+row.centerZ-row.halfZ>=support.surfaceMinZ and prop.localZ+row.centerZ+row.halfZ<=support.surfaceMaxZ)
            for j=1,prop.id-1 do local previous=area.props[j]
                if previous.supportId==prop.supportId then
                    local before=config:GetTable('MapAreaShipwreckDressingTable'):Get(previous.dressingId)
                    assert(math.abs(prop.localX+row.centerX-previous.localX-before.centerX)>=row.halfX+before.halfX or
                        math.abs(prop.localZ+row.centerZ-previous.localZ-before.centerZ)>=row.halfZ+before.halfZ,'Tabletop items overlap')
                end
            end
        end
    end end
    local kindCount=0;for _ in pairs(types) do kindCount=kindCount+1 end
    assert(kindCount==20 and supported>=18 and #area.props>=80)
    local allowed=function(cell)return not cell.blocked end
    local positions=Squad.Deploy(area,area.entryIndex,4,allowed)
    local occupied={};for _,index in ipairs(positions) do occupied[index]=true end
    local plans=Chest.Plan(area,config:GetTable('MapAreaChestRuleTable'):All(),occupied)
    assert(#plans>=6 and #plans<=9);local lootLayers={}
    for _,plan in ipairs(plans) do lootLayers[area.cells[plan.cellIndex].layer]=true end
    assert(lootLayers[0] and lootLayers[1] and lootLayers[2])
    if walk then
        local function travel(target)
            local path=assert(area:FindPath(positions[1],target));local frames,reason=Squad.Plan(area,positions,path,allowed,true);assert(frames,reason)
            for start=1,#frames,4 do local used={};local previous={table.unpack(positions)}
                for member=1,4 do local index=frames[start+member-1]
                    assert(not used[index] and allowed(area.cells[index]))
                    assert(index==previous[member] or area:CanStep(area.cells[previous[member]],area.cells[index]))
                    for j=1,member-1 do assert(index~=previous[j] or frames[start+j-1]~=previous[member]) end
                    used[index]=true;positions[member]=index
                end
            end
            assert(positions[1]==target)
        end
        for _,stair in ipairs(area.stairs) do travel(stair.bottom);travel(stair.top);travel(stair.bottom) end
        for _,room in ipairs(area.rooms) do travel(room.center) end
        travel(area.entryIndex)
    end
    print('PASS Shipwreck V2 seed '..area.seed..': '..actual..' walkable, layers '..counts[0]..'/'..counts[1]..'/'..counts[2]..', '..#area.props..' props, 20 dressing types')
end
local first=generator:Generate(40,20260921,300010,source)
check(first,true)
assert(signature(first)==signature(generator:Generate(40,20260921,300010,source)))
for _,seed in ipairs({17,400}) do check(generator:Generate(40,seed,300010,source),false) end
local mapSystem=require('Game.Map.MapSystem')()
mapSystem:OnInit({systems={Get=function()return config end},services={}})
local recipe=config:GetTable('AdventureDemoTable'):Get(1);local world=mapSystem:Generate(recipe.seed,recipe.regionIds)
assert(#world.waterSites==1 and world.waterSites[1].pointId==300010,'Existing world selection changed')
local entrances={};for _,row in ipairs(config:GetTable('MapAreaEntranceTable'):All()) do entrances[row.townId]=generator.definitions:Get(row.areaId) end
local reader={config=config,generator=generator,entrances=entrances};local selected
for _,point in ipairs(AreaSystem.Entrances(reader,world)) do if point.areaConfigId==40 then selected=point;break end end
local area=generator:Generate(40,recipe.seed,selected.pointId,selected.source)
reader.ActiveLayout=function()return area end
local json=assert(loadfile('Tools/MapPreview/json.lua'))()
local function serial(value)
    if type(value)~='table' then return value end
    local result={};for k,v in pairs(value) do result[k]=serial(v) end
    return (#value>0 or next(result)==nil) and json.array(result) or result
end
local function save(name,data)
    local file=assert(io.open('Art/AssetExpansion202610/ShipwreckV2/Integration/'..name,'wb'));file:write(json.encode(serial(data)));file:close()
end
save('layout_snapshot.json',AreaSystem.LayoutSnapshot(reader))
local rooms={};for _,room in ipairs(area.rooms) do rooms[#rooms+1]={id=room.id,name=room.name,layer=room.layer,centerIndex=room.center,cells=#room.cells} end
save('navigation.json',{seed=area.seed,site=selected,entryIndex=area.entryIndex,goalIndex=area.goalIndex,walkableCount=area.walkableCount,goalDistance=area.goalDistance,rooms=rooms,stairs=area.stairs})
save('world_snapshot.json',require('Game.Map.MapRenderSnapshot')(world))
print('PASS real three-layer snapshots exported to ShipwreckV2/Integration')
