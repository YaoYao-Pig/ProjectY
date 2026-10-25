-- Production height, trajectory and projectile rules with isolated battle-state adapters.
package.path='Lua/?.lua;'..package.path
local Height=require('Game.Battle.HeightAdvantage')
local Shots=require('Game.Battle.ProjectileCombat')
local Layout=require('Game.MapArea.MapAreaLayout')
local Board=require('Game.Battle.BattleBoard')
local Hex=require('Game.Map.HexGrid')
local rule={heightPerLevel=1,maxLevels=3,hitPerLevel=5,rangePerLevel=1}
local height=Height.New({GetTable=function(_,name)
    assert(name=='HeightAdvantageTable');return {Get=function(_,id)assert(id==1);return rule end}
end})
local tests=0
local function test(name,run)run();tests=tests+1;print('PASS '..name)end
local function near(a,b)assert(math.abs(a-b)<1e-8,tostring(a)..' ~= '..tostring(b))end
local function skill(proficiency)
    return {id=1,name='Test attack',target='enemy',proficiency=proficiency or 'bow',range=3,minRange=0,
        fixedRange=false,hitChance=60,trajectory='lobbed',guided=false,effectIds={1},criticalChance=35}
end
local function sequence(values)
    local count=0
    return function()count=count+1;return assert(values[count],'Unexpected random draw '..count)end,function()return count end
end
local function fixture()
    local env={checks={},applied={},events={}}
    local area=Layout.New({id=1,name='advantage test',areaType=1,width=12,height=12,hexRadius=1,visionRadius=10,moveStepSeconds=.1},1,{}, {})
    for _,cell in ipairs(area.cells)do cell.height=0;cell.blocked=false;cell.blocksSight=false;cell.kind='floor'end
    env.area=area;env.skill=skill()
    env.source={Id=1,Team=1,Q=2,R=4,HP=100,MaxHP=100}
    env.target={Id=2,Team=2,Q=8,R=4,HP=100,MaxHP=100}
    area:Find(2,4).height=2
    local battle={board=Board.FromArea(area,5,5,12),stats={heightAdvantage=height,projectileCover={actorChance=35,objectChance=50},
        Template=function(_,actor)return {name='Unit '..actor.Id}end}}
    env.battle=battle
    function battle:ShotOccupancy()return env.blocker and {[Hex.Key(env.blocker.Q,env.blocker.R)]=env.blocker} or {}end
    function battle:IsAllied(a,b)return a.Team==b.Team end
    function battle:Emit(kind)env.events[#env.events+1]=kind end
    battle.checks=function(source,target,skill,title,chance,value,passed,details)
        env.checks[#env.checks+1]={target=target,chance=chance,value=value,passed=passed,details=details}
    end
    battle.gameEffects={}
    function battle.gameEffects:Prepare(id,source,target,skill)
        assert(id==1);return {definition={kind='damage',duration='instant'},source=source,target=target,skill=skill}
    end
    function battle.gameEffects:ApplyPrepared(effect,impact)
        effect.target.HP=effect.target.HP-(impact.critical and 8 or 4)
        env.applied[#env.applied+1]={target=effect.target,critical=impact.critical,shot=impact.shot}
    end
    function env:Profile(context)
        return Shots.Profile(battle,self.source,self.skill,area:Find(self.target.Q,self.target.R),context,self.target)
    end
    function env:Apply(values)
        local roll,count=sequence(values);battle.data={RollPercent=roll}
        local program={battle.gameEffects:Prepare(1,self.source,self.target,self.skill)}
        Shots.PrepareProgram(battle,self.source,self.skill,program)
        Shots.ApplyProgram(battle,self.source,self.skill,program,1)
        return count()
    end
    return env
end

test('only enemy bow attacks gain high ground advantage; range and other attack bonuses remain',function()
    local bow=skill();local gun=skill('firearm');local melee=skill('sword');melee.range=1
    for _,difference in ipairs({-1,0,.5,1,2,4})do
        local origin,target={height=difference,layer=0},{height=0,layer=0}
        local levels=math.min(3,math.max(0,math.floor(difference)))
        assert(height:HitChance(origin,target,bow)==60)
        local sources=height:AdvantageSources(origin,target,bow)
        assert((sources~=nil)==(levels>0))
        if sources then assert(#sources==1 and sources[1]=='high_ground')end
        assert(height:RangeBonus(origin,target,bow)==levels)
        assert(height:HitChance(origin,target,gun)==60+levels*5)
        assert(height:HitChance(origin,target,melee)==60+levels*5 and height:RangeBonus(origin,target,melee)==0)
    end
    assert(not height:AdvantageSources({height=2,layer=1},{height=0,layer=0},bow))
    assert(not height:AdvantageSources({layer=0},{height=0,layer=0},bow))
    bow.target='ally';assert(not height:AdvantageSources({height=2},{height=0},bow))
end)

test('preview applies advantage before cover and preserves per-target height',function()
    local env=fixture();env.blocker={Id=3,Team=1,Q=3,R=4,HP=100}
    local p=env:Profile()
    assert(p.reachable and p.baseHitChance==60 and p.blockerCount==1 and p.friendlyRisk)
    near(p.effectiveHitChance,84);near(p.hitChance,84*.65)
    assert(p.advantageSources[1]=='high_ground' and #env.checks==0 and #env.applied==0)
    env.area:Find(env.target.Q,env.target.R).height=2
    p=env:Profile();assert(not p.advantageSources);near(p.hitChance,60*.65)
    env.area:Find(env.target.Q,env.target.R).height=0;env.skill.proficiency='firearm'
    p=env:Profile();assert(not p.advantageSources and p.baseHitChance==70);near(p.hitChance,70*.65)
end)

test('multiple sources produce exactly two high rolls and one final selected result',function()
    local roll,count=sequence({89,39});local result
    assert(Shots.Hit({baseHitChance=60,advantageSources={'high_ground','another_source','high_ground'}},roll,function(value,passed,check)
        assert(value==61 and passed);result=check
    end))
    assert(count()==2 and result.rolls[1]==11 and result.rolls[2]==61 and result.selectedIndex==2)
    assert(result.threshold==40 and result.rollComparison=='greater' and #result.advantageSources==2)
    near(result.effectiveChance,84)
    roll,count=sequence({60,99});assert(not Shots.Hit({baseHitChance=60,advantageSources={'high_ground'}},roll) and count()==2)
    roll,count=sequence({59});assert(Shots.Hit({baseHitChance=60},roll) and count()==1)
    roll,count=sequence({});assert(Shots.Hit({baseHitChance=100},roll) and count()==0)
end)

test('cover rolls once, then the two hit draws and one critical draw resolve one damage application',function()
    local env=fixture();env.blocker={Id=3,Team=1,Q=3,R=4,HP=100}
    assert(env:Apply({35,89,39,34})==4)
    assert(env.target.HP==92 and env.blocker.HP==100 and #env.applied==1 and env.applied[1].critical)
    assert(#env.checks==3 and not env.checks[1].details.check and env.checks[2].details.check)
    assert(env.checks[2].details.check.rolls[1]==11 and env.checks[2].details.check.rolls[2]==61)
    assert(not env.checks[3].details.check and env.checks[3].value==34)
    env=fixture();env.blocker={Id=3,Team=1,Q=3,R=4,HP=100}
    assert(env:Apply({34,99})==2,'An intercepted arrow must never roll target hit advantage')
    assert(env.target.HP==100 and env.blocker.HP==96 and #env.applied==1 and #env.checks==2)
    env=fixture();assert(env:Apply({60,99})==2)
    assert(env.target.HP==100 and #env.applied==0 and #env.checks==1,'A double miss must not draw critical or apply damage')
end)

test('guided and sight fallback paths retain high ground advantage',function()
    for _,mode in ipairs({'sight','lobbed'})do
        local env=fixture();env.skill.trajectory=mode;env.skill.guided=mode=='lobbed'
        env.blocker={Id=3,Team=1,Q=3,R=4,HP=100}
        assert(env:Apply({89,39,99})==3)
        assert(env.target.HP==96 and env.blocker.HP==100 and env.checks[1].details.check)
    end
end)

test('preview and resolution use the owning integer or hundredth-percent random precision',function()
    local env=fixture();env.skill.hitChance=60.25
    local p=env:Profile();near(p.effectiveHitChance,61*(2-.61))
    local roll,count=sequence({60,99});local check
    assert(Shots.Hit(p,roll,function(_,_,result)check=result end));assert(count()==2 and check.chance==61)
    local context={board=env.battle.board,origin=env.area:Find(2,4),occupied=function()return {}end,checkPrecision=100}
    p=env:Profile(context);near(p.effectiveHitChance,60.25*(2-.6025))
    roll,count=sequence({99.99,60.24})
    assert(Shots.Hit(p,roll,function(_,_,result)check=result end));assert(count()==2 and check.precision==100)
    near(check.roll,39.76);near(check.threshold,39.75);near(check.chance,60.25)
    roll,count=sequence({60.25,99.99});assert(not Shots.Hit(p,roll) and count()==2)
    env.skill.hitChance=.07;p=env:Profile(context)
    near(p.effectiveHitChance,.07*(2-.0007))
    roll,count=sequence({.07,99.99})
    assert(not Shots.Hit(p,roll,function(_,_,result)check=result end) and count()==2)
    near(check.chance,.07);near(check.threshold,99.93)
    roll,count=sequence({.06,99.99})
    assert(Shots.Hit(p,roll,function(_,_,result)check=result end) and count()==2)
    near(check.roll,99.94)
end)

print('Combat advantage: '..tests..' checks passed')
