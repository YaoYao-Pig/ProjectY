package.path='Lua/?.lua;'..package.path
local Conflicts=require('Game.Adventure.WorldConflicts')
local function actor(hp,owner)
    return {HP=hp,MaxHP=hp,AnimalOwnerId=owner,Damage=function(self,n)self.HP=math.max(0,self.HP-n)end}
end
local pet,wild=actor(73,1),actor(40,0)
local function party(id,actors)
    return {Id=id,FactionId=id,MemberCount=#actors,Role='wildlife',Mission='idle',
        GetMemberAt=function(_,index)return actors[index+1]end,
        Travel={Plan=function()end},SetMission=function()end}
end
local captured=party(11,{pet});local enemy=party(14,{wild})
local conflict={PartyA=11,PartyB=14,Phase='active',TargetSiteId=0,Materialized=false,
    Engage=function(self,value)self.engaged=value end,
    Resolve=function(self,winner)self.winner=winner;self.Phase='resolved'end}
local parties={Find=function(_,id)return id==11 and captured or enemy end,ReleaseParty=function(_,id,defeated)
    assert(defeated==(id==11),'A living tamed animal must not keep its former faction alive')
end,DeferCargo=function()end}
local aid=0
local system=setmetatable({adventure={data={SiteId=5},parties={data=parties},narrative={data={Minutes=10}},
    battle={IsHostile=function(_,_,unit)return unit==wild end}},
    data={FindConflict=function()return conflict end},
    factions={InvalidatePower=function()end,RewardAid=function()aid=aid+1 end,
        rules={settings={retreatMinutes=60,ruinMinutes=100}}}},Conflicts)
system:Damage(party(20,{pet,wild}),10)
assert(pet.HP==73 and wild.HP==30,'Faction attrition must never damage its former member after taming')
local realResolve=system.Resolve
function system:Resolve(value,winner)assert(value==conflict);self.winner=winner end
assert(system:Settle('victory'));assert(system.winner==0 and aid==0,'Captured wildlife must not become an allied faction winner or yield aid rewards')
assert(system:Settle('defeat'));assert(system.winner==14,'Withdrawal after taming must resolve a two-party conflict to the remaining wild party')
system.Resolve=realResolve
system:Resolve(conflict,0,10)
assert(conflict.Phase=='resolved' and not conflict.engaged and pet.HP==73,'Resolution must release the old party without killing its living companion')
print('PASS tamed wildlife excluded from faction attrition, aid rewards and survivors; withdrawal resolves retired conflict participants')
