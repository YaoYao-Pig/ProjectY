-- 真实配表的建筑二楼检查：楼梯连续边、板底净空、服务 NPC 和四人上下楼。
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local data=file:read('*a');file:close();return data
end}})
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(2,require('Game.MapArea.TownGenerator'),'MapAreaTownTable','MapAreaTownThemeTable')
local Hex=require('Game.Map.HexGrid')
local Geometry=require('Game.MapArea.DungeonGeometry')
local Squad=require('Game.MapArea.SquadMovement')
local AreaSystem=require('Game.MapArea.MapAreaSystem')
local animals=require('Game.Animals.AnimalRules').New(config)
local actors={{TemplateId=1},{TemplateId=1},{TemplateId=1},{TemplateId=1}}
local owner={combatStats={animals=animals},PartyActor=function(_,id)return actors[id] end}
local edges={{1,6,3,4},{5,6,3,2},{4,5,2,1},{3,4,1,6},{2,3,6,5},{1,2,5,4}}
for _,spec in ipairs({{2,20260924,1},{6,20260925,2}}) do
    local areaId,seed,region=table.unpack(spec)
    local area=generator:Generate(areaId,seed,11,{regionId=1,regionType=region,regionConfigId=region,q=0,r=0,height=1,biomeWeights={{regionType=region,weight=1}}})
    local serviceNpcs={}
    for _,npc in ipairs(area.npcs) do
        assert(not area.cells[npc.spawnIndex].blocked,'NPC spawned inside a closed stair base')
        if #npc.route==0 then serviceNpcs[npc.spawnIndex]=true end
        if #npc.route>0 then assert(not area.cells[npc.spawnIndex].interiorId,'A patrolling resident spawned in a private stairwell') end
        local previous=npc.spawnIndex
        for _,index in ipairs(npc.route) do
            assert(not area.cells[index].interiorId,'Public patrol entered a private building')
            assert(area:CanStep(area.cells[previous],area.cells[index]),'Resident route crosses a disconnected stair base');previous=index
        end
    end
    local footprint=AreaSystem.SquadFootprint(owner,area,{1,2,3,4})
    local allowed=function(cell,member)
        local cells=footprint(cell.index,member or 1);if not cells then return false end
        for _,index in ipairs(cells) do if area.cells[index].blocked or serviceNpcs[index] then return false end end
        return true
    end
    local positions=Squad.Deploy(area,area.entryIndex,4,allowed,footprint)
    local framesCount=0
    local function travel(target)
        local path=assert(area:FindPath(positions[1],target,allowed),'Service NPC blocks town '..areaId..' route '..positions[1]..' to '..target)
        local frames,reason=Squad.Plan(area,positions,path,allowed,nil,footprint)
        assert(frames,'Town '..areaId..', target '..target..': '..tostring(reason))
        for offset=1,#frames,4 do
            local occupied={};local previous={table.unpack(positions)}
            for i=1,4 do
                local nextIndex=frames[offset+i-1]
                assert(not occupied[nextIndex] and allowed(area.cells[nextIndex]),'Squad overlaps a member or service NPC')
                assert(nextIndex==previous[i] or area:CanStep(area.cells[previous[i]],area.cells[nextIndex]),'Squad teleported between floors')
                for j=1,i-1 do assert(nextIndex~=previous[j] or frames[offset+j-1]~=previous[i],'Squad swaps through a member') end
                occupied[nextIndex]=true;positions[i]=nextIndex
            end
        end
        framesCount=framesCount+#frames//4;assert(positions[1]==target)
    end
    local count=0
    for _,room in ipairs(area.interiors) do
        local definition=config:GetTable('MapAreaTownFloorTable'):Find(room.lotId)
        if definition then
            count=count+1
            assert(serviceNpcs[room.serviceNpcIndex],'Building service NPC did not use its configured station')
            local prop
            for _,candidate in ipairs(area.props) do if candidate.interiorId==room.id and not candidate.cutaway then prop=candidate;break end end
            assert(prop)
            for i,q in ipairs(definition.closedGroundQ) do
                local x,y=Geometry.Rotate(q,definition.closedGroundR[i],prop.rotation);local cell=area:Find(prop.q+x,prop.r+y)
                assert(cell.blocked and cell.walkMask==0 and not area:FindPath(room.doorIndex,cell.index),'Closed stair base remained traversable')
            end
            local floorCount,stairCount,farthest,farthestDistance=0,0,nil,-1
            for _,index in ipairs(room.cells) do
                local cell=area.cells[index]
                assert(cell.interiorId==room.id and not cell.blocked)
                assert(area:FindPath(room.doorIndex,index),'Unreachable building floor')
                if cell.layer==1 then
                    local shape=footprint(index,1);assert(#shape==1 and shape[1]==index,'Runtime squad footprint fell through to the ground floor')
                    if cell.kind=='stairs' then stairCount=stairCount+1 else
                        assert(cell.kind=='interior');floorCount=floorCount+1
                        local path=assert(area:FindPath(room.upperEntryIndex,index))
                        if #path>farthestDistance then farthest,farthestDistance=index,#path end
                    end
                    local lower=assert(area:Find(cell.q,cell.r));assert(lower.index~=index,'Floors share a navigation identity')
                    if not lower.blocked then
                        assert(math.min(table.unpack(cell.corners))-cell.deckThickness-math.max(table.unpack(lower.corners))>=definition.minimumClearance-.000001,'Insufficient headroom')
                        assert(not area:CanStep(cell,lower) and not area:CanStep(lower,cell),'Direct vertical floor hop')
                    end
                end
                for d,nextIndex in ipairs(cell.neighbors) do
                    local other=area.cells[nextIndex]
                    if area:CanStep(cell,other) then
                        assert(area:CanStep(other,cell),'Building floor edge is one-way')
                        assert(Hex.Distance(cell.q,cell.r,other.q,other.r)==1,'Building stair skips a hex')
                        assert(math.abs(cell.height-other.height)<=.800001,'Stair center rise is too steep')
                        local edge=edges[d]
                        assert(math.abs(cell.corners[edge[1]]-other.corners[edge[3]])<.000001 and math.abs(cell.corners[edge[2]]-other.corners[edge[4]])<.000001,'Stair corner seam is discontinuous')
                        assert(other.interiorId==room.id or other.index==room.doorIndex,'Building floor opens through an exterior wall')
                    end
                end
            end
            assert(floorCount==#definition.floorQ and stairCount==#definition.stairQ)
            travel(room.serviceIndex);travel(room.upperEntryIndex);travel(farthest)
            for _,index in ipairs(positions) do assert(area.cells[index].layer==1 and area.cells[index].interiorId==room.id,'Not all squad members reached the upper storey') end
            travel(room.serviceIndex);travel(area.entryIndex)
            for _,index in ipairs(positions) do assert(not area.cells[index].interiorId,'Squad remained inside after exit') end
            print('PASS town '..areaId..' lot '..room.lotId..': '..floorCount..' upper floors / '..stairCount..' stair cells, bidirectional seams and four-member return with service NPC present')
        end
    end
    assert(count==2,'Town should include the tavern and guild upper floors')
    assert(#Geometry.Reachable(area,area.entryIndex)==area.walkableCount,'A floor disconnected the town graph')
    print('PASS town '..areaId..': '..framesCount..' squad frames, NPC routes and total walkable count')
end
-- A mounted footprint must not fill a missing upper cell with the ground at the same q/r.
local Layout=require('Game.MapArea.MapAreaLayout')
local fixture=Layout.New({id=1,name='layered footprint',areaType=2,width=4,height=4,hexRadius=1.5,visionRadius=9,moveStepSeconds=.5},1,{}, {})
for _,cell in ipairs(fixture.cells) do cell.blocked=false end
local upper=fixture:AddLayerCell(1,1,1,3.2)
local multi=require('Game.Animals.AnimalRules').New(config)
local species={};for key,value in pairs(multi.byUnit[201]) do species[key]=value end
species.footprintQ={0,1};species.footprintR={0,0};multi.byUnit[201]=species
local rider={TemplateId=1,MountedAnimal={TemplateId=201}}
local mountedOwner={combatStats={animals=multi},PartyActor=function()return rider end}
local footprint=AreaSystem.SquadFootprint(mountedOwner,fixture,{1})
assert(not footprint(upper.index,1),'Mounted footprint borrowed a lower floor')
local neighbor=fixture:AddLayerCell(2,1,1,3.2)
footprint=AreaSystem.SquadFootprint(mountedOwner,fixture,{1}) -- 新地形在下一次规划中查询，旧规划缓存不跨命令。
local shape=assert(footprint(upper.index,1));assert(#shape==2 and shape[1]==upper.index and shape[2]==neighbor.index)
assert(footprint(upper.index,1)==shape,'Repeated footprint queries should reuse the command-local result')
local legacy=assert(multi:Cells(rider,fixture,1,1));assert(legacy[1].layer==0 and legacy[2].layer==0,'Omitted layer changed MapArea default behavior')
local board=require('Game.Battle.BattleBoard').FromArea(fixture,1,1,2,1)
local inherited=assert(multi:Cells(rider,board,1,1));assert(inherited[1]==upper and inherited[2]==neighbor,'Omitted layer ignored the battle origin layer')
print('PASS runtime SquadFootprint preserves upper cells, mounted shapes stay on one layer and legacy default layers remain unchanged')
