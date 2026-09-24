-- 真实城镇配表的定向检查，不启动 Editor。
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local data=file:read('*a');file:close();return data
end}})
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(2,require('Game.MapArea.TownGenerator'),'MapAreaTownTable','MapAreaTownThemeTable')
local function make(id,kind,seed)
    return generator:Generate(id,seed,11,{regionId=7,regionType=kind,regionConfigId=kind,q=0,r=0,height=1,biomeWeights={{regionType=kind,weight=1}}})
end
local function signature(area)
    local result={};for _,prop in ipairs(area.props) do result[#result+1]=prop.assetId..':'..prop.q..':'..prop.r..':'..prop.rotation end
    return table.concat(result,';')
end
for _,id in ipairs({2,3,4,5}) do
    local area=make(id,id==4 and 6 or 5,20260924)
    local definition=config:GetTable('MapAreaTable'):Get(id);local profile=config:GetTable('MapAreaTownTable'):Get(definition.profileId)
    assert(#area.facilities==#profile.facilityIds and #area.npcs==#area.facilities+profile.residentCount)
    local occupied={}
    for _,prop in ipairs(area.props) do for _,index in ipairs(prop.cells) do
        local prior=occupied[index]
        assert(not prior or prop.cutaway and prop.interiorId==prior.interiorId and not prior.cutaway,'Only a building cover may share its own structure footprint')
        if not prop.cutaway then occupied[index]=prop end
    end end
    for _,facility in ipairs(area.facilities) do assert(area:FindPath(area.entryIndex,facility.entryIndex)) end
    for _,npc in ipairs(area.npcs) do
        assert(not area.cells[npc.spawnIndex].blocked)
        local previous=npc.spawnIndex
        for _,index in ipairs(npc.route) do
            local a,b=area.cells[previous],area.cells[index]
            assert(not b.blocked and require('Game.Map.HexGrid').Distance(a.q,a.r,b.q,b.r)==1)
            previous=index
        end
        if #npc.route>0 then assert(previous==npc.spawnIndex) end
    end
    assert(signature(area)==signature(make(id,id==4 and 6 or 5,20260924)))
    print('PASS town '..id..': '..#area.facilities..' facilities / '..#area.props..' props / '..#area.npcs..' NPCs')
end
assert(signature(make(2,1,20260924))~=signature(make(2,1,20260925)))
print('PASS seeded block variation and Region themes')
local area=make(2,2,20260924)
local deck
for _,cell in ipairs(area.cells) do
    if cell.layer==1 then deck=cell end
    for direction,index in ipairs(cell.neighbors) do
        local nextCell=area.cells[index]
        if area:CanStep(cell,nextCell) and not cell.blocked then
            assert(area:CanStep(nextCell,cell),'Street graph must be bidirectional')
            assert(math.abs(cell.height-nextCell.height)<=.90001,'Walking directly across a cliff')
        end
    end
end
assert(deck);local underneath=area:Find(deck.q,deck.r)
assert(underneath~=deck and not underneath.blocked and deck.height-underneath.height>3.2)
local upperPath=assert(area:FindPath(area.entryIndex,deck.index))
local lowerPath=assert(area:FindPath(deck.index,underneath.index))
assert(#lowerPath>10,'Bridge and underpass must not merge vertically')
local board=require('Game.Battle.BattleBoard').FromArea(area,deck.q,deck.r,5,1)
assert(board:Find(deck.q,deck.r)==deck and board:Find(deck.q,deck.r,0)==underneath)
local squad=require('Game.MapArea.SquadMovement');local positions=squad.Deploy(area,area.entryIndex,4)
for _,path in ipairs({upperPath,lowerPath}) do
    local frames,reason=squad.Plan(area,positions,path,function() return true end);assert(frames,reason)
    for offset=1,#frames,4 do
        local seen={}
        for i=1,4 do
            local index=frames[offset+i-1]
            assert(not seen[index] and (index==positions[i] or area:CanStep(area.cells[positions[i]],area.cells[index])))
            seen[index]=true;positions[i]=index
        end
    end
end
assert(positions[1]==underneath.index)
print('PASS layered bridge / underpass, cliff edges, shared battle cells and four-member traversal')
