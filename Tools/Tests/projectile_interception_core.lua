-- Real projectile/terrain/container/effect modules with isolated native-state adapters.
-- Configuration is read from the normal exported tables; no Editor, Player or saves.
package.path='Lua/?.lua;'..package.path
local Hex=require('Game.Map.HexGrid')
local Layout=require('Game.MapArea.MapAreaLayout')
local Board=require('Game.Battle.BattleBoard')
local Shots=require('Game.Battle.ProjectileCombat')
local ContainerCombat=require('Game.Loot.ContainerCombat')
local EmptyGrowth=assert(loadfile('Tools/Tests/growth_empty.lua'))()
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local f=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=f:read('*a');f:close();return bytes
end}})
local count=0
local function test(name,run)run();count=count+1;print('PASS '..name)end
CS=CS or {};CS.ProjectY=CS.ProjectY or {};CS.ProjectY.Data=CS.ProjectY.Data or {}
CS.ProjectY.Data.ContainerState={Hit=function(state,id,amount)
    local physical=assert(state.byId[id]).physical
    assert(physical.MaxDurability>0 and physical.Unlocked and not physical.Destroyed,'Hit called for absorbing-only scenery')
    state.hits[#state.hits+1]={id=id,amount=amount}
    local actual=math.min(physical.Durability,amount);physical.Durability=physical.Durability-actual
    physical.Destroyed=physical.Durability==0;state.Revision=state.Revision+1;return actual
end}

local function fixture()
    local env={notifications={},units={},containers={},rolls={},rollCount=0}
    local base=Layout.New({id=999,name='interception',areaType=1,width=12,height=12,hexRadius=1,visionRadius=10,moveStepSeconds=.1},1,{}, {wallHeight=3})
    for _,cell in ipairs(base.cells)do cell.height=0;cell.blocked=false;cell.blocksSight=false;cell.kind='floor'end
    env.base=base
    local battle=require('Game.Battle.BattleSystem')();env.battle=battle
    battle.stats=require('Game.Battle.CombatStats')(config)
    assert(battle.stats.projectileCover.actorChance==35 and battle.stats.projectileCover.objectChance==50)
    local definitions=config:GetTable('CombatEffectTable')
    battle.effects=definitions
    local function notify(kind,message,sourceId,targetId,amount,target,attackHit,impact)
        env.notifications[#env.notifications+1]={kind=kind,targetId=targetId,amount=amount,target=target,impact=impact}
    end
    function battle:Emit(kind,message,sourceId,targetId,amount,target,attackHit,impact)
        notify(kind,message,sourceId,targetId,amount,target,attackHit,impact)
    end
    battle.gameEffects=require('Game.Battle.GameEffects').New(battle.stats,definitions,notify,{roll=function()return 0 end,minutes=function()return 0 end})
    function env:Actor(id,team,q,r)
        local a={Id=id,Team=team,TemplateId=1,Q=q,R=r,HP=20,Guard=0,AnimalOwnerId=0,
            TraitCount=0,Growth=EmptyGrowth(),Effects={Count=0,Find=function()end}}
        a.MaxHP=battle.stats:MaximumHP(a)
        function a:Damage(amount)local loss=math.min(amount,self.HP);self.HP=self.HP-loss;return loss end
        function a:Heal(amount)local gain=math.min(amount,self.MaxHP-self.HP);self.HP=self.HP+gain;return gain end
        env.units[#env.units+1]=a;return a
    end
    env.source=env:Actor(1,1,2,4);env.target=env:Actor(9,2,8,4)
    function battle:Active()return env.source end
    function battle:Units()return env.units end
    function battle:ShotOccupancy(source,victim)
        local occupied={}
        for _,a in ipairs(env.units)do
            if a.Id~=source.Id and (not victim or a.Id~=victim.Id) and a.HP>0 then occupied[Hex.Key(a.Q,a.R)]=a end
        end
        return occupied
    end
    battle.data={RollPercent=function()
        env.rollCount=env.rollCount+1;return assert(env.rolls[env.rollCount],'Missing explicit test roll')
    end}
    env.state={Revision=1,LootCount=0,VisibleCount=#base.cells,MemberCount=1,hits={},byId={},
        GetVisibleAt=function(_,i)return i+1 end,GetMemberIdAt=function()return env.source.Id end,
        GetMemberCellAt=function()return base:Find(env.source.Q,env.source.R).index end,
        GetLootAt=function(_,i)return env.containers[i+1]end}
    function env.state:Loot(id)self.byId[id].Looted=true end
    function env:Container(id,q,r,durability,unlocked)
        local cell=assert(base:Find(q,r))
        local physical={Configured=true,Destroyed=false,Unlocked=unlocked,MaxDurability=durability,Durability=durability,
            CellCount=1,GetCellAt=function()return cell.index end}
        local container={Id=id,TableId=1,Name='test crate '..id,physical=physical,ItemCount=1,GetCountAt=function()return 1 end,Looted=false}
        self.containers[#self.containers+1]=container;self.state.byId[id]=container;self.state.LootCount=#self.containers
        return container
    end
    local definition={structuralDefense=0,blocksSight=true,blocksMovement=true}
    local loot={rules={containers={Get=function()return definition end}},session={Active=false}}
    function loot:Find(_,id)return env.state.byId[id]end
    function loot:Physical(container)return container.physical end
    function loot:SyncLock(_,container)return container.physical end
    local areas={data={Active=env.state,ActiveSiteId=1},ActiveLayout=function()return env.area end,
        ShotOccupancy=function(_,_,victim)return battle:ShotOccupancy(env.source,victim and {Id=victim})end}
    local adventure={areas=areas,battle=battle,data={Areas={ActiveSiteId=1},Phase='area'}}
    env.combat=setmetatable({adventure=adventure,loot=loot},{__index=ContainerCombat});battle.containerCombat=env.combat
    function env:Bind()
        self.area=require('Game.Loot.ContainerTerrain').Wrap(base,loot,self.state)
        battle.board=Board.FromArea(self.area,5,5,12)
    end
    local skill={};for key,value in pairs(config:GetTable('CombatSkillTable'):Get(7))do skill[key]=value end
    -- Reuse the real constant-four damage instruction to isolate routing from weapon balance.
    skill.effectIds={1212};skill.damageScale=1;skill.hitChance=80;skill.range=10;skill.shots=3
    skill.trajectory='direct';skill.guided=false;skill.maxTargets=1;skill.splashRadius=0;skill.affectsContainers=true
    env.skill=skill
    function env:Program()
        local program={battle.gameEffects:Prepare(1212,self.source,self.target,self.skill)}
        return Shots.PrepareProgram(battle,self.source,self.skill,program)
    end
    function env:Profile()
        return Shots.Profile(battle,self.source,self.skill,battle.board:Find(self.target.Q,self.target.R),nil,self.target)
    end
    return env
end
local function sequence(values)
    local calls=0
    return function()calls=calls+1;return assert(values[calls],'Unexpected extra probability roll')end,function()return calls end
end

test('35/50 cover prediction matches stable near-to-far threshold rolls',function()
    local env=fixture();local friend=env:Actor(20,1,4,4);local enemy=env:Actor(21,2,6,4)
    env.base:Find(5,4).blocksSight=true;env:Bind()
    local p=env:Profile()
    assert(p.reachable and p.blockerCount==3 and p.friendlyRisk)
    assert(p.blockers[1].actor==friend and p.blockers[2].kind=='terrain' and p.blockers[3].actor==enemy)
    assert(p.blockers[1].chance==35 and p.blockers[2].chance==50 and p.blockers[3].chance==35)
    assert(math.abs(p.hitChance-80*.65*.5*.65)<1e-8 and math.abs(p.interceptChance-78.875)<1e-8)
    assert(env.rollCount==0 and friend.HP==20 and enemy.HP==20,'Read-only preview must not roll or damage')
    for _,sample in ipairs({{{34},1},{{35,49},2},{{35,50,34},3}})do
        local roll,calls=sequence(sample[1]);assert(Shots.Intercept(p,roll)==p.blockers[sample[2]] and calls()==sample[2])
    end
    local roll,calls=sequence({35,50,35,79})
    assert(Shots.Intercept(p,roll)==nil and Shots.Hit(p,roll) and calls()==4)
    roll=sequence({80});assert(not Shots.Hit(p,roll),'An uncovered target still uses its ordinary accuracy')
end)

test('locked and indestructible containers absorb a projectile without invoking durability Hit',function()
    for _,case in ipairs({{40,false},{0,true}})do
        local env=fixture();local container=env:Container(1,4,4,case[1],case[2]);env:Bind()
        local p=env:Profile();assert(p.blockerCount==1 and p.blockers[1].container==container and p.blockers[1].chance==50)
        local program=env:Program();env.rolls={0}
        Shots.ApplyProgram(env.battle,env.source,env.skill,program,1)
        assert(env.target.HP==20 and #env.state.hits==0 and container.physical.Durability==case[1])
        assert(#env.notifications==1 and env.notifications[1].kind=='intercepted' and env.rollCount==1)
    end
end)

test('container-primary burst hits an interceptor with each real shot index',function()
    local env=fixture();local friend=env:Actor(22,1,4,4);local container=env:Container(1,7,4,40,true);env:Bind()
    local ok,_,selected,cell,origin=env.combat:Target(env.source,env.skill,1,env.battle)
    assert(ok and selected==container)
    local plan=env.combat:Prepare(env.source,env.skill,container,cell,origin)
    env.combat:PrepareShots({plan},env.source,env.skill,env.battle)
    for shot=2,3 do env.combat:Apply({plan},env.source,env.skill,function()return 0 end,env.battle,shot)end
    local damage={};for _,event in ipairs(env.notifications)do if event.kind=='damage'then damage[#damage+1]=event end end
    assert(friend.HP==12 and #damage==2 and damage[1].targetId==friend.Id and damage[2].targetId==friend.Id)
    assert(damage[1].impact.shot==2 and damage[2].impact.shot==3 and #env.state.hits==0 and container.physical.Durability==40)
end)

test('a first projectile destroys cover and the next reaches the original target',function()
    local env=fixture();local container=env:Container(1,4,4,4,true);env:Bind()
    local program=env:Program();env.rolls={0,0}
    assert(env:Profile().blockerCount==1)
    Shots.ApplyProgram(env.battle,env.source,env.skill,program,1)
    assert(container.physical.Destroyed and container.physical.Durability==0 and #env.state.hits==1 and env.target.HP==20)
    assert(env:Profile().blockerCount==0,'Trace must read the current physical state on the next projectile')
    Shots.ApplyProgram(env.battle,env.source,env.skill,program,2)
    assert(env.target.HP==16 and #env.state.hits==1 and env.rollCount==2)
    local event=env.notifications[#env.notifications]
    assert(event.kind=='damage' and event.targetId==env.target.Id and event.impact.shot==2)
end)

test('large source footprint preserves the selected edge origin through preview, preparation and commit',function()
    local env=fixture();local container=env:Container(1,6,4,40,true)
    env.base:Find(3,4).blocksSight=true;env.skill.trajectory='sight';env:Bind()
    local center,edge,target=env.area:Find(2,4),env.area:Find(3,3),env.area:Find(6,4)
    assert(not env.area:CanSee(center,target) and env.area:CanSee(edge,target),'Fixture must expose only the outer firing position')
    function env.battle.stats.animals:Cells()return {center,edge}end
    local ok,_,selected,cell,origin=env.combat:Target(env.source,env.skill,1,env.battle)
    assert(ok and selected==container and origin==edge and cell==target)
    local wrong=Shots.Profile(env.battle,env.source,env.skill,cell,env.combat:ShotContext(env.source,env.battle,center))
    local right=Shots.Profile(env.battle,env.source,env.skill,cell,env.combat:ShotContext(env.source,env.battle,origin))
    assert(not wrong.reachable and right.reachable and right.blockerCount==0)
    local plan=env.combat:Prepare(env.source,env.skill,container,cell,origin)
    env.combat:PrepareShots({plan},env.source,env.skill,env.battle)
    env.combat:Apply({plan},env.source,env.skill,function()return 0 end,env.battle,1)
    assert(plan.origin==edge and #env.state.hits==1 and container.physical.Durability==36)
    local splash=env.combat:Splash(env.source,setmetatable({splashRadius=2},{__index=env.skill}),target,0,1,env.battle)
    assert(#splash==1 and splash[1].origin==edge,'Splash planning must preserve the same selected source footprint')
end)

config:OnShutdown()
print('Projectile interception: '..count..' checks passed')
