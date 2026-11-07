-- Prepared-object migration only. No Unity, disk state, live Adventure mutation or random rolls.
package.path='Lua/?.lua;'..package.path
local Migration=require('Game.Adventure.UnitTraitMigration')
local completed=0
CS={ProjectY={Data={
    UnitInspections={NeedsTraitMigration=function(p)return p.legacy end,
        CompleteTraitMigration=function(p)assert(p.legacy);p.legacy=false;completed=completed+1 end},
    AnimalCompanionState={Bound=function(a)return a.bound end},
    ExpeditionPersistence={HasWorld=function(p)return p.world end,
        AreaCount=function(p)return #p.areas end,Area=function(p,i)return p.areas[i+1]end},
    WorldPartiesData={Prepared=function(p)return p.parties end},
}}}
local function actor(id,template,hp,traits)
    local a={Id=id,TemplateId=template,HP=hp,MaxHP=30,traits=traits or {},resizes=0,wound={kind=2,damage=10},dead=hp==0}
    function a:HasTrait(value)for _,id in ipairs(self.traits)do if id==value then return true end end;return false end
    function a:AddTrait(id)assert(not self:HasTrait(id));self.traits[#self.traits+1]=id end
    function a:SetMaxHP(maximum)
        self.resizes=self.resizes+1
        if self.HP>0 then self.HP=self.HP+maximum-self.MaxHP end
        self.MaxHP=maximum
    end
    function a:Restore()error('Migration must not heal or resurrect actors')end
    return a
end
local templates={[1]={traitIds={3,6,7,9}},[2]={traitIds={8,10}},[3]={traitIds={11}},[4]={traitIds={101}}}
local stats={traits={Get=function(_,id)assert(id>=7 and id<=11);return {id=id}end},
    Template=function(_,unit)return assert(templates[unit.TemplateId])end,
    MaximumHP=function(_,unit)return 30+(unit:HasTrait(9)and 10 or 0)end}
local adventure={factions={rules={FullPower=function(_,unit,s)assert(s==stats);return unit.MaxHP+#unit.traits end}}}
local function party(members)
    local p={MemberCount=#members,members=members,strengths={},updates=0}
    function p:GetMemberAt(i)return self.members[i+1]end
    function p:SetMemberStrength(i,value)self.strengths[i]=value;self.updates=self.updates+1 end
    return p
end
local function area(actors)
    local group={EnemyCount=#actors,GetEnemyAt=function(_,i)return actors[i+1]end}
    return {EncounterCount=1,GetEncounterAt=function(_,i)assert(i==0);return group end}
end
local function fixture(world)
    local active,reserve,bound=actor(1,1,22,{1}),actor(2,2,14,{5}),actor(100,1,13)
    local enemy,areaOnly,legend=actor(101,1,0),actor(102,3,20),actor(103,4,25,{101})
    active.bound=bound
    local members=party({bound,enemy,legend})
    local p={legacy=true,ActorCount=2,actors={active,reserve},world=world,areas={area({bound,enemy,legend,areaOnly})},
        parties={Count=1,GetAt=function(_,i)assert(i==0);return members end}}
    function p:GetActorAt(i)return self.actors[i+1]end
    return p,active,reserve,bound,enemy,areaOnly,legend,members
end
local p,active,reserve,bound,enemy,areaOnly,legend,members=fixture(true)
local wound=active.wound
Migration.Prepare(adventure,p,stats)
assert(completed==1 and not p.legacy)
assert(active:HasTrait(7) and active:HasTrait(9) and active:HasTrait(1) and not active:HasTrait(3) and not active:HasTrait(6))
assert(reserve:HasTrait(8) and reserve:HasTrait(10) and reserve:HasTrait(5))
assert(bound:HasTrait(9) and enemy:HasTrait(9) and areaOnly:HasTrait(11))
assert(active.resizes==1 and reserve.resizes==1 and bound.resizes==1 and enemy.resizes==1 and areaOnly.resizes==1 and legend.resizes==0)
assert(active.HP==32 and active.MaxHP-active.HP==8 and active.wound==wound and wound.damage==10)
assert(enemy.HP==0 and enemy.dead and enemy.MaxHP==40)
assert(members.updates==2 and members.strengths[0]==42 and members.strengths[1]==42 and members.strengths[2]==nil)
print('PASS prepared roster, bound/shared world/area actors, damage/death preservation and LOD recalibration')
Migration.Prepare(adventure,p,stats)
assert(completed==1 and bound.resizes==1 and active.resizes==1 and members.updates==2)
local current,unit=fixture(false);current.legacy=false;Migration.Prepare(adventure,current,{})
assert(unit.resizes==0 and not unit:HasTrait(7))
print('PASS new saves and repeated candidate validation never reapply migration')
local old,hero,back,animal,foreign=fixture(false);Migration.Prepare(adventure,old,stats)
assert(hero:HasTrait(9) and back:HasTrait(8) and animal:HasTrait(9) and foreign.resizes==0 and not foreign:HasTrait(9))
print('PASS character-only legacy saves migrate owned roster without nonexistent world state')
local bad,first,second=fixture(true);second.MaxHP=999;local before=completed
assert(not pcall(Migration.Prepare,adventure,bad,stats))
assert(bad.legacy and completed==before and first.resizes==0 and not first:HasTrait(7) and second.MaxHP==999)
local duplicate,original=fixture(true);duplicate.areas={area({actor(original.Id,1,20)})}
assert(not pcall(Migration.Prepare,adventure,duplicate,stats))
assert(duplicate.legacy and original.resizes==0 and not original:HasTrait(7))
print('PASS invalid original maximum and conflicting identity reject before candidate mutation')
