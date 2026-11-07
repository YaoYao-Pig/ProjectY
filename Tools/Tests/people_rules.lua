-- Real exported recruitment configuration; isolated resident state, no Editor/live save.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local Rules=require('Game.Adventure.PeopleRules')
local rules=Rules.New(config)
local function facts(values)
    local result={coins=0,trust=0,helped=0,townHelped=0,mentorSkills=0,victories=0,level=1,targetLevel=1,bondJoined=false}
    for key,value in pairs(values or {})do result[key]=value end
    return result
end
local function route(profileId,values,index)return rules:Routes(rules.profiles:Get(profileId),facts(values))[index or 1]end
local life=rules.profiles:Get(1)
assert(not route(1,{coins=life.fee-1}).ready and route(1,{coins=life.fee}).ready)
assert(route(1,{coins=life.fee}).cost==life.fee)
assert(not route(1,{trust=life.trustRequired-1},2).ready and route(1,{trust=life.trustRequired},2).ready)
assert(route(1,{helped=1,trust=-100},2).ready and route(1,{helped=1},2).cost==0)
local apprentice=rules.profiles:Get(2)
assert(not route(2,{mentorSkills=apprentice.mentorSkills-1}).ready)
assert(route(2,{mentorSkills=apprentice.mentorSkills}).ready and route(2,{mentorSkills=apprentice.mentorSkills}).cost==0)
assert(not route(2,{coins=apprentice.fee},2).ready)
assert(not route(2,{helped=1,coins=apprentice.fee-1},2).ready)
assert(route(2,{helped=1,coins=apprentice.fee},2).ready and route(2,{helped=1,coins=apprentice.fee},2).cost==apprentice.fee)
local guardian=rules.profiles:Get(3)
assert(not route(3,{coins=100000,helped=10}).ready and route(3,{townHelped=1}).ready)
assert(not route(3,{trust=guardian.trustRequired},2).ready)
assert(not route(3,{bondJoined=true,trust=guardian.trustRequired-1},2).ready)
assert(route(3,{bondJoined=true,trust=guardian.trustRequired},2).ready)
local respect=rules.profiles:Get(4)
assert(not route(4,{coins=respect.fee,victories=respect.victories-1}).ready)
assert(not route(4,{coins=respect.fee-1,victories=respect.victories}).ready)
assert(not route(4,{coins=respect.fee,victories=respect.victories,level=4,targetLevel=5}).ready)
assert(route(4,{coins=respect.fee,victories=respect.victories,level=5,targetLevel=5}).ready)
assert(route(4,{coins=respect.fee,victories=respect.victories}).cost==respect.fee)
for id=1,4 do
    local input=facts({coins=9999,trust=100,helped=1,townHelped=1,mentorSkills=99,victories=99,level=99,bondJoined=true})
    local expected={};for key,value in pairs(input)do expected[key]=value end
    for _=1,5 do for _,row in ipairs(rules:Routes(rules.profiles:Get(id),input))do assert(row.ready)end end
    for key,value in pairs(expected)do assert(input[key]==value,'Recruitment browsing mutated facts')end
end
print('PASS: four recruitment motives, independent blockers, exact thresholds and read-only routes')
-- Casting is deterministic and never consumes the gameplay random stream.
local random=math.random;math.random=function()error('Casting consumed shared randomness')end
local identities={}
for templateId=1,5 do
    for siteId=1,12 do
        local profileId,nameId=rules:Cast(12345,siteId,100001,templateId)
        local againProfile,againName=rules:Cast(12345,siteId,100001,templateId)
        assert(profileId==againProfile and nameId==againName)
        local allowed=false;for _,id in ipairs(rules.byResident[templateId])do allowed=allowed or id==profileId end
        assert(allowed and rules.names:Find(nameId))
        identities[profileId..':'..nameId]=true
    end
end
math.random=random
local variety=0;for _ in pairs(identities)do variety=variety+1 end
assert(variety>=12,'Configured town casting should produce varied profile/name combinations')
assert(Rules.FreeResident({stableId=100001}))
for _,definition in ipairs({{stableId=1},{stableId=100001,narrativeId=201},{stableId=100001,facilityId=1},{stableId=100001,dockId=1}})do
    assert(not Rules.FreeResident(definition))
end
print('PASS: stable casting, varied configured identities, and service/authored exclusions')
-- Same local resident IDs in different towns have different durable instances and same-town bonds.
local records={};local nextId,prepares,appearances,restores=600000000,0,0,0
local peopleData={Find=function(_,key)return records[key]end,FindActor=function(_,id)
    for _,record in pairs(records)do if record.Actor.Id==id then return record end end
end}
function peopleData:CreateResident(siteId,residentId,unitId,profileId,nameId,bondKey)
    local key='resident:'..siteId..':'..residentId;assert(not records[key])
    local actor={Id=nextId,TemplateId=unitId,HP=100,SetMaxHP=function(self,hp)self.MaxHP=hp end,
        Restore=function(self)restores=restores+1;self.HP=self.MaxHP end}
    nextId=nextId+1
    local record={Key=key,Actor=actor,SiteId=siteId,ResidentId=residentId,ProfileId=profileId,NameId=nameId,BondKey=bondKey,Joined=false,
        SetBond=function(self,value)self.BondKey=value end}
    records[key]=record;return record
end
CS={ProjectY={Data={PeopleState={Get=function()return peopleData end}}}}
local definitions={{stableId=100001,templateId=1},{stableId=100002,templateId=2}}
local adventure={config=config,data={Seed=12345},areas={ActiveLayout=function()return {npcs=definitions}end},
    growth={PrepareActor=function(_,actor)prepares=prepares+1;actor.Growth={Initialized=true}end},
    characterAppearances={Party=function(_,actor)appearances=appearances+1;actor.CustomizationJson='look:'..actor.Id end},
    battle={stats={MaximumHP=function()return 100 end}}}
local people=require('Game.Adventure.People').New(adventure)
local first=people:EnsureResident(definitions[1],10)
local friend=records[first.BondKey]
assert(first.Key=='resident:10:100001' and friend.Key=='resident:10:100002' and friend.BondKey==first.Key)
assert(prepares==2 and appearances==2 and restores==2)
first.Actor.HP=17;first.Actor.someExperience='kept';local look=first.Actor.CustomizationJson
local profileId,nameId=first.ProfileId,first.NameId
for _=1,5 do assert(people:EnsureResident(definitions[1],10)==first)end
assert(prepares==2 and appearances==2 and restores==2 and first.Actor.HP==17 and first.Actor.someExperience=='kept')
assert(first.Actor.CustomizationJson==look and first.ProfileId==profileId and first.NameId==nameId)
local otherTown=people:EnsureResident(definitions[1],11)
assert(otherTown~=first and otherTown.Actor.Id~=first.Actor.Id and otherTown.Key=='resident:11:100001')
assert(records[otherTown.BondKey].SiteId==11 and otherTown.BondKey~=first.BondKey)
assert(prepares==4 and appearances==4 and restores==4)
first.Joined=true
assert(people:ResidentJoined(10,100001) and not people:ResidentJoined(11,100001))
assert(people:EnsureResident(definitions[1],10)==first and first.Actor.HP==17)
print('PASS: cross-town identity, reciprocal same-town bonds, retained injury/appearance/profile and no re-roll')
