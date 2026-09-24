-- 用真实配表验证室内入口、墙边隔断和四人穿门；不启动 Editor。
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local data=file:read('*a');file:close();return data
end}})
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(2,require('Game.MapArea.TownGenerator'),'MapAreaTownTable','MapAreaTownThemeTable')
local squad=require('Game.MapArea.SquadMovement')
for _,areaId in ipairs({2,6}) do
    local area=generator:Generate(areaId,20260924,11,{regionId=1,regionType=1,regionConfigId=1,q=0,r=0,height=1,biomeWeights={{regionType=1,weight=1}}})
    local expected=0
    for _,facility in ipairs(area.facilities) do
        local definition=config:GetTable('MapAreaTownFacilityTable'):Get(facility.configId)
        if config:GetTable('MapAreaTownInteriorTable'):Find(definition.lotIds[1]) then expected=expected+1 end
    end
    assert(#area.interiors==expected,'Required building interiors missing')
    local surfaces=config:GetTable('MapAreaSurfaceTable')
    local kinds={}
    for _,cell in ipairs(area.cells) do surfaces:Get(cell.surfaceId);surfaces:Get(cell.sideSurfaceId);kinds[cell.surfaceId]=true end
    assert(kinds[areaId==6 and 6 or 5] and kinds[7] and kinds[8],'Plaza, yard or garden material missing')
    local positions=squad.Deploy(area,area.entryIndex,4)
    local function travel(index)
        local path=assert(area:FindPath(positions[1],index));local frames,reason=squad.Plan(area,positions,path,function()return true end)
        assert(frames,'area='..areaId..' target='..index..' room='..tostring(area.cells[index].interiorId)..' from='..table.concat(positions,',')..': '..tostring(reason))
        for offset=1,#frames,4 do
            local occupied={}
            for i=1,4 do
                local nextIndex=frames[offset+i-1];assert(not occupied[nextIndex]);occupied[nextIndex]=true
                assert(nextIndex==positions[i] or area:CanStep(area.cells[positions[i]],area.cells[nextIndex]))
                positions[i]=nextIndex
            end
        end
        assert(positions[1]==index)
    end
    for _,room in ipairs(area.interiors) do
        local covers,structures=0,0
        for _,prop in ipairs(area.props) do if prop.interiorId==room.id then
            assert(prop.scaleX==1 and prop.scaleY==1 and prop.scaleZ==1,'Buildings must remain meter scale')
            if prop.cutaway then covers=covers+1 else structures=structures+1 end
        end end
        assert(covers==1 and structures==1,'A building needs one persistent structure and one removable cover')
        local portalEdges=0
        for _,index in ipairs(room.cells) do
            local cell=area.cells[index];assert(cell.interiorId==room.id and not cell.blocked)
            assert(area:FindPath(room.doorIndex,index),'Disconnected interior floor')
            for _,nextIndex in ipairs(cell.neighbors) do
                local other=area.cells[nextIndex]
                if other and other.interiorId~=room.id and area:CanStep(cell,other) then
                    assert(nextIndex==room.doorIndex,'Walking through a side wall or window')
                    assert(area:CanStep(other,cell),'Door must work in both directions');portalEdges=portalEdges+1
                end
            end
        end
        assert(portalEdges>=1)
        travel(room.serviceIndex);assert(area.cells[positions[1]].interiorId==room.id)
        travel(area.entryIndex)
        for _,index in ipairs(positions) do assert(not area.cells[index].interiorId,'Follower remained indoors after leaving') end
    end
    print('PASS town '..areaId..': '..#area.interiors..' meter-scale interiors, door-only navigation and four-member return routes')
end
local display=require('Game.Rendering.MapPresentation').Snapshot(config)
assert(#display.keys>=2 and #display.weather==2 and display.profile.cycleSeconds>0)
print('PASS visual configuration snapshot and ground material references')
