package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local Generator=require('Game.MapArea.MapAreaGenerator')
local generator=Generator(config)
generator:Register(3,require('Game.MapArea.ForestGenerator'),'MapAreaForestTable','MapAreaForestThemeTable')
local source={regionId=5,regionType=5,regionConfigId=5,q=0,r=0,height=0,biomeWeights={{regionType=5,weight=1}}}
local signatures={}
for _,seed in ipairs({17,31,20260928}) do
    local area=generator:Generate(20,seed,100005,source)
    local queue,seen,head={area.entryIndex},{[area.entryIndex]=true},1
    while head<=#queue do
        local cell=area.cells[queue[head]];head=head+1
        for _,next in ipairs(area:Neighbors(cell)) do if not seen[next.index] then seen[next.index]=true;queue[#queue+1]=next.index end end
    end
    assert(#queue==area.walkableCount and seen[area.goalIndex],'Forest walkable ground must be connected')
    local plans=require('Game.MapArea.ForestEncounters').Plan(area,config:GetTable('MapAreaEncounterTable'):Get(20),config)
    local species,used,signature={},{},{}
    for _,plan in ipairs(plans) do
        species[plan.encounterId]=true
        for _,cell in ipairs(plan.cells) do assert(not cell.blocked and not used[cell.index]);used[cell.index]=true end
        signature[#signature+1]=plan.encounterId..':'..plan.team..':'..plan.cells[1].index
    end
    assert(species[201] and species[202] and species[203],'All three initial animals must have spawn opportunities')
    signatures[seed]=table.concat(signature,'|')
    local again=require('Game.MapArea.ForestEncounters').Plan(area,config:GetTable('MapAreaEncounterTable'):Get(20),config)
    for i,row in ipairs(again) do assert(row.cells[1].index==plans[i].cells[1].index and row.team==plans[i].team) end
end
assert(signatures[17]~=signatures[31])
print('PASS forest connectivity, deterministic spawn, three animal species and seed variation')
local rules=require('Game.Animals.AnimalRules').New(config)
local stats={Get=function(_,actor,name) return actor[name] or 0 end}
local hero={animalAffinity=5,charisma=3}
local horse={TemplateId=201,HP=48,MaxHP=48,Team=2}
local full=rules:TameChance(hero,horse,stats);horse.HP=10
assert(rules:TameChance(hero,horse,stats)>full,'Wounded hostile animals must be easier to tame')
local wounded=rules:TameChance(hero,horse,stats);hero.animalAffinity=10
assert(rules:TameChance(hero,horse,stats)>wounded)
hero.charisma=20;assert(rules:TameChance(hero,horse,stats)<=95)
horse.Team=0;horse.HP=48;local neutral=rules:TameChance(hero,horse,stats);horse.HP=1
assert(rules:TameChance(hero,horse,stats)==neutral,'Neutral taming must not encourage injuring a neutral animal')
print('PASS taming chance uses affinity, charisma and hostile missing HP with configured clamps')
local Board=require('Game.Battle.BattleBoard');local board=Board.Create(5,1,0)
local rider={TemplateId=1,Q=0,R=0,MountedAnimal={TemplateId=201,AnimalSpeciesId=1,AnimalBond=0}}
assert(#rules:AddSkills(rider,{})==0)
rider.MountedAnimal.AnimalBond=10;assert(rules:AddSkills(rider,{})[1]==202)
local landing,distance=rules:Landing(rider,board:Find(4,0),board,202,{})
assert(landing.q==3 and landing.r==0 and distance==3)
assert(not rules:Landing(rider,board:Find(3,1),board,202,{}),'Charge must be straight')
assert(not rules:Landing(rider,board:Find(4,0),board,202,{['2:0']=true}),'Charge must not cross occupied cells')
rider.MountedAnimal={TemplateId=203,AnimalSpeciesId=3,AnimalBond=10}
assert(rules:AddSkills(rider,{})[1]==204)
board:Find(1,0).blocked=true
assert(rules:Landing(rider,board:Find(3,0),board,204,{}),'Rabbit can jump over a blocked middle cell')
assert(not rules:Landing(rider,board:Find(4,0),board,204,{}),'Rabbit cannot exceed three hexes')
assert(not rules:Landing(rider,board:Find(1,0),board,204,{}),'Rabbit cannot land on an obstacle')
local fake={GetTable=function(_,name)
    if name=='AnimalSpeciesTable' then
        local row={id=1,unitId=201,footprintQ={0,1},footprintR={0,0},riderSeat={0,1,0},initialBond=0,maximumBond=100}
        return {All=function() return {row} end,Get=function() return row end}
    end
    if name=='AnimalSkillTable' then return {All=function()return {} end} end
    return config:GetTable(name)
end}
local large=require('Game.Animals.AnimalRules').New(fake);local animal={TemplateId=201,Q=0,R=0}
assert(not large:CanPlace(animal,board,0,0,{}),'Every footprint cell must be clear')
board:Find(1,0).blocked=false
assert(large:CanPlace(animal,board,0,0,{}))
assert(not large:CanPlace(animal,board,5,0,{}),'Footprints cannot extend outside the map')
print('PASS species skill unlocks, charge paths, rabbit jump range and multi-hex footprint')
local Layout=require('Game.MapArea.MapAreaLayout')
local area=Layout.New({id=1,name='footprint fixture',areaType=3,width=12,height=12,hexRadius=1.5,visionRadius=9,moveStepSeconds=.1},1,source,{})
for _,cell in ipairs(area.cells) do cell.blocked=false;cell.blocksSight=false end
local function shape(index,member)
    local cell=area.cells[index]
    if member==1 then
        local other=area:Find(cell.q+1,cell.r);if not other then return nil end
        return {index,other.index}
    end
    return {index}
end
local function allowed(cell,member) return shape(cell.index,member or 1)~=nil end
local positions={area:Find(2,2).index,area:Find(2,4).index}
local frames,why=require('Game.MapArea.SquadMovement').Plan(area,positions,{area:Find(3,2).index,area:Find(4,2).index},allowed,true,shape)
assert(frames,why)
for offset=1,#frames,2 do
    local seen={}
    for member=1,2 do for _,index in ipairs(shape(frames[offset+member-1],member)) do
        assert(not seen[index],'Mounted exploration footprints overlap');seen[index]=true
    end end
end
print('PASS multi-hex mounted exploration keeps full squad footprints disjoint')
