-- Targeted presentation routing checks with isolated native-state adapters; no Editor or saves.
package.path='Lua/?.lua;'..package.path
local Visual=require('Game.Presentation.VisualEffects')
local Shots=require('Game.Battle.ProjectileCombat')
local Battle=require('Game.Battle.BattleSystem')
local Board=require('Game.Battle.BattleBoard')
local Hex=require('Game.Map.HexGrid')
local checks=0
local function test(name,run)run();checks=checks+1;print('PASS '..name)end
local function skill(id,target)
    return {id=id,name='skill '..id,target=target or 'enemy',effectIds={1,2},trajectory='sight',hitChance=80,
        maxTargets=1,splashRadius=0,shots=1,action='main',cost=2,cooldownTurns=1,actionTemplate='attack'}
end
local function fixture()
    local env={units={},rolls={},rollCount=0,effectCount=0,spent=0,consumed=0,notifications={}}
    local battle=Battle();env.battle=battle
    function env:Actor(id,team,q,r)
        local actor={Id=id,Team=team,Q=q,R=r,HP=20,MaxHP=20,AnimalOwnerId=0}
        function actor:SpendAction(_,cost)env.spent=env.spent+cost end
        function actor:SetCooldown()end
        function actor:RecordAction()end
        function actor:RelocateWithSkill(q,r)self.Q=q;self.R=r end
        self.units[#self.units+1]=actor;return actor
    end
    env.source=env:Actor(1,1,-3,0);env.target=env:Actor(2,2,3,0)
    battle.board=Board.Create(5,103,0)
    battle.data={UnitCount=2,ActiveId=1,Winner='',Phase='combat',GetUnitAt=function(_,i)return env.units[i+1]end,
        RollPercent=function()env.rollCount=env.rollCount+1;return assert(env.rolls[env.rollCount],'Unexpected RNG consumption')end,
        Finish=function(self,winner)self.Winner=winner;self.Phase='ended'end}
    battle.stats={Template=function(_,actor)return {name='actor '..actor.Id}end,Get=function()return 0 end,
        heightAdvantage={HitChance=function(_,_,_,row)return row.hitChance end,Levels=function()return 0 end,rule={hitPerLevel=5}},
        projectileCover={actorChance=35,objectChance=50},
        animals={rule={tameSkillId=201},bySkill={},Occupy=function(_,actor,_,occupied)occupied[Hex.Key(actor.Q,actor.R)]=actor end},
        equipment={Consume=function()env.consumed=env.consumed+1 end}}
    battle.gameEffects={
        Prepare=function(_,id,source,target,row)
            return {definition={kind=id==1 and 'damage' or 'guard'},source=source,target=target,hitTarget=target,skill=row}
        end,
        ApplyPrepared=function(_,plan)
            env.effectCount=env.effectCount+1
            if plan.definition.kind=='damage' then plan.target.HP=math.max(0,plan.target.HP-4) end
            return true
        end,Clear=function()end}
    function battle:CanUseSkill()return true end
    function battle:Skill(_,id)return assert(env.skills[id])end
    function battle:Emit(kind)env.notifications[#env.notifications+1]=kind end
    env.skills={};return env
end

test('queue is bounded, snapshots values, drains once and resets independently of gameplay',function()
    local battle={};local actor={Id=1,Q=2,R=3};local row=skill(7)
    for i=1,130 do Visual.Skill(battle,actor,row,actor,i,'hit') end
    actor.Q=99
    local events=Visual.Drain(battle)
    assert(#events==128 and events[1].sequence==3 and events[128].sequence==130 and events[1].sourceQ==2)
    assert(#Visual.Drain(battle)==0)
    Visual.Item(battle,91,actor,4,5,'pickup')
    local item=Visual.Drain(battle)[1]
    assert(item.sequence==131 and item.skillId==0 and item.itemId==91 and item.outcome=='pickup' and item.sourceQ==99 and item.targetQ==4)
    Visual.Clear(battle);assert(battle.vfxSequence==0 and #Visual.Drain(battle)==0)
    local ok=pcall(Visual.Skill,battle,actor,row,nil,1,'hit');assert(not ok,'An unknown impact position must fail explicitly')
end)

test('burst and multi-effect groups emit once per real target, preserve misses and keep lethal final events',function()
    local env=fixture();local battle=env.battle;local row=skill(7);row.shots=3;env.skills[7]=row
    env.target.HP=5;env.rolls={0,99,0}
    assert(battle:TrySkill(7,env.target.Id))
    local events=Visual.Drain(battle)
    assert(#events==3 and events[1].outcome=='hit' and events[2].outcome=='miss' and events[3].outcome=='hit')
    for i,event in ipairs(events)do assert(event.skillId==7 and event.shot==i and event.targetId==env.target.Id)end
    assert(env.rollCount==3 and env.effectCount==3 and env.target.HP==0 and battle.data.Winner=='victory')
    assert(#Visual.Drain(battle)==0)
end)

test('manual multiple targets keep one event per target instead of one per effect',function()
    local env=fixture();local row=skill(8);row.hitChance=100;env.skills[8]=row
    local other=env:Actor(3,2,2,1);env.battle.data.UnitCount=3
    assert(env.battle:TrySkill(8,env.target.Id,{env.target.Id,other.Id}))
    local events=Visual.Drain(env.battle)
    assert(#events==2 and events[1].targetId==env.target.Id and events[2].targetId==other.Id)
    assert(env.effectCount==4 and env.rollCount==0)
end)

test('interception targets the actual actor footprint cell and leaves the requested target untouched',function()
    local env=fixture();local row=skill(9);row.trajectory='direct';env.skills[9]=row
    local friend=env:Actor(3,1,0,1);env.battle.data.UnitCount=3
    function env.battle:ShotOccupancy()return {[Hex.Key(-1,0)]=friend}end
    env.rolls={0}
    assert(env.battle:TrySkill(9,env.target.Id))
    local events=Visual.Drain(env.battle)
    assert(#events==1 and events[1].targetId==friend.Id and events[1].targetQ==-1 and events[1].targetR==0)
    assert(events[1].outcome=='hit' and friend.HP==16 and env.target.HP==20 and env.rollCount==1)
end)

test('terrain interception records its actual cell without inventing a character target',function()
    local env=fixture();local row=skill(10);row.trajectory='direct';env.skills[10]=row
    env.battle.board:Find(-1,0).blocked=true;env.rolls={0}
    assert(env.battle:TrySkill(10,env.target.Id))
    local events=Visual.Drain(env.battle)
    assert(#events==1 and events[1].targetId==0 and events[1].targetQ==-1 and events[1].outcome=='hit')
    assert(env.effectCount==0 and env.target.HP==20 and env.rollCount==1)
end)

test('skill movement preserves the source position captured before relocation',function()
    local env=fixture();local row=skill(301);row.hitChance=100;env.skills[301]=row
    env.battle.stats.animals.bySkill[301]={movement='charge'}
    env.battle.stats.animals.Landing=function()return {q=2,r=0},5 end
    assert(env.battle:TrySkill(301,env.target.Id))
    local event=Visual.Drain(env.battle)[1]
    assert(env.source.Q==2 and event.sourceQ==-3 and event.targetQ==3 and event.skillId==301)
end)

test('all preparation identities and consumable skills emit one self cast with no duplicate item event',function()
    local env=fixture();local battle=env.battle
    for id=401,404 do
        local row=skill(id,'self');row.effectIds={2,3};env.skills[id]=row
        assert(battle:TrySkill(id,env.source.Id))
        local events=Visual.Drain(battle)
        assert(#events==1 and events[1].skillId==id and events[1].targetId==env.source.Id and events[1].outcome=='cast')
    end
    env.skills[701]=skill(701,'self');env.skills[701].effectIds={2,3}
    battle.consumables={Get=function()return {skillId=701,count=1}end}
    battle.stats.equipment.data={ConsumeStack=function(_,id,count)assert(id==91 and count==1);env.consumed=env.consumed+1 end}
    battle.stats.equipment.items={Get=function()return {name='medicine'}end}
    function battle:CanUseItem()return true end
    assert(battle:TryItem(91));local events=Visual.Drain(battle)
    assert(#events==1 and events[1].skillId==701 and events[1].itemId==0 and events[1].outcome=='cast')
    assert(env.rollCount==0 and env.consumed==5)
end)

test('disarm outcomes and weapon recovery retain skill identity without damage effects',function()
    for _,roll in ipairs({0,99})do
        local env=fixture();local battle=env.battle;env.skills[501]=skill(501);env.skills[503]=skill(503,'self')
        env.skills[501].hitChance=30;env.skills[501].effectIds={};env.skills[503].effectIds={};env.rolls={roll}
        battle.stats.equipment.Weapon=function()return {Id=7}end
        local disarmed=0
        battle.context={systems={Get=function(_,name)
            if name=='Equipment' then return {worldLoot={Disarm=function()disarmed=disarmed+1 end,Recover=function()return true,'sword'end}}end
            return {}
        end}}
        assert(battle:TrySkill(501,env.target.Id));local event=Visual.Drain(battle)[1]
        assert(event.skillId==501 and event.outcome==(roll==0 and 'hit' or 'miss') and disarmed==(roll==0 and 1 or 0))
        assert(battle:TrySkill(503,env.source.Id));event=Visual.Drain(battle)[1]
        assert(event.skillId==503 and event.targetId==env.source.Id and event.outcome=='cast' and env.rollCount==1)
    end
end)

test('battle taming records failed attempts and snapshots the source before mounting',function()
    for _,success in ipairs({false,true})do
        local env=fixture();local row=skill(201);env.skills[201]=row
        env.battle.stats.animals.Tame=function(_,source,target)
            if success then source.Q=target.Q;source.R=target.R end
            return success,50
        end
        assert(env.battle:TrySkill(201,env.target.Id))
        local event=Visual.Drain(env.battle)[1]
        assert(event.skillId==201 and event.sourceQ==-3 and event.targetId==env.target.Id and event.outcome==(success and 'hit' or 'miss'))
    end
end)

test('construction and cell movement record one cast at the chosen cell',function()
    local env=fixture();local battle=env.battle;env.skills[601]=skill(601,'cell');env.skills[302]=skill(302,'cell')
    function battle:CanUseSkillAt()return true end
    battle.construction={definitions={Find=function(_,id)return id==601 end},Apply=function()env.constructed=true end}
    battle.stats.animals.bySkill[302]={movement='jump'}
    assert(battle:TrySkillAt(601,0,1));local events=Visual.Drain(battle)
    assert(env.constructed and #events==1 and events[1].skillId==601 and events[1].targetQ==0 and events[1].targetR==1)
    assert(battle:TrySkillAt(302,1,1));events=Visual.Drain(battle)
    assert(#events==1 and events[1].sourceQ==-3 and events[1].targetQ==1 and env.source.Q==1)
end)

test('life taming reports failure truthfully and demolition uses area positions',function()
    local CharacterSkills=require('Game.Adventure.CharacterSkills')
    local env=fixture();local battle=env.battle;local actor=env.source
    local rows={[201]=skill(201),[606]=skill(606,'cell')};rows[201].effectIds={4};rows[606].effectIds={};rows[606].skillGroup='construction'
    local tableApi={Get=function(_,id)return assert(rows[id])end}
    local state={MemberCount=1,GetMemberIdAt=function()return actor.Id end,GetMemberCellAt=function()return 1 end}
    local area={cells={{q=4,r=5},{q=6,r=5}}}
    local adventure={battle=battle,data={Phase='area',PartyCount=1,GetPartyAt=function()return actor end},
        config={GetTable=function(_,name)return name=='CombatSkillTable' and tableApi or {Get=function()return {kind='tame'}end}end},
        areas={data={Active=state},ActiveLayout=function()return area end,FindAnimal=function()return env.target end,
            CanTame=function()return true end,Tame=function()return false,'failed actual roll'end},
        construction={CanDismantle=function()return true end,Dismantle=function()return true end,AreaTargets=function()return {2}end}}
    local service=CharacterSkills.New(adventure)
    function service:CanUse()return true end
    local success,reason=service:Use(actor.Id,201,env.target.Id)
    assert(not success and reason=='failed actual roll')
    local event=Visual.Drain(battle)[1]
    assert(event.outcome=='miss' and event.sourceQ==4 and event.sourceR==5 and event.targetId==env.target.Id)
    assert(service:Use(actor.Id,606,2));event=Visual.Drain(battle)[1]
    assert(event.skillId==606 and event.sourceQ==4 and event.targetQ==6 and event.targetId==0)
end)

test('container resolution emits a single hit or miss per shot at the physical target',function()
    local Container=require('Game.Loot.ContainerCombat')
    local env=fixture();local row=skill(11);local battle=env.battle
    local combat=setmetatable({adventure={battle=battle}}, {__index=Container})
    function combat:ShotContext()return {board=battle.board,origin=battle.board:Find(-3,0)}end
    function combat:ApplyDamage()env.containerHits=(env.containerHits or 0)+1 end
    local plan={physical={Destroyed=false},cell=battle.board:Find(3,0),interceptions={},vfxSource=Visual.Source(env.source),container={Name='crate'}}
    combat:Apply({plan},env.source,row,function()return 0 end,battle,1)
    combat:Apply({plan},env.source,row,function()return 99 end,battle,2)
    local events=Visual.Drain(battle)
    assert(#events==2 and events[1].outcome=='hit' and events[2].outcome=='miss' and env.containerHits==1)
    assert(events[1].targetId==0 and events[1].targetQ==3 and events[2].shot==2)
end)

test('shutdown clears pending presentation even on partially initialized systems',function()
    local battle=Battle();Visual.Skill(battle,{Id=1,Q=0,R=0},skill(1),nil,1,'hit',{q=1,r=0})
    battle:OnShutdown();assert(battle.vfxSequence==0 and #Visual.Drain(battle)==0)
    battle:OnShutdown()
end)
test('pickup follows a committed transfer and uses actual layered exploration coordinates',function()
    local Loot=require('Game.Loot.MapLoot');local battle={}
    local actor={Id=9,Q=99,R=99}
    local entry={Count=2,Kind='material',Revealed=true,ItemId=81,ContainerId=1}
    local container={Id=1,CellIndex=2}
    local state={LootCount=1,GetLootAt=function()return container end,GetMemberIdAt=function()return 9 end,GetMemberCellAt=function()return 1 end}
    local cells={{q=4,r=5,layer=2},{q=5,r=5,layer=2}}
    local areas={data={Active=state},PartyActor=function()return actor end,ActiveLayout=function()return {cells=cells} end}
    local accept=false
    local session={Active=true,Area=state,Find=function()return entry end,Take=function()if accept then entry.Count=0;return true end return false end}
    local equipment={adventure={Phase='area'},data={},rules={items={Get=function()return {name='wood'} end}},context={systems={Get=function()return battle end}}}
    local loot=setmetatable({session=session,equipment=equipment},{__index=Loot})
    assert(not loot:Take(areas,'item',0,0,false));assert(#Visual.Drain(battle)==0)
    accept=true;assert(loot:Take(areas,'item',0,0,false))
    local events=Visual.Drain(battle);assert(#events==1)
    local event=events[1]
    assert(event.itemId==81 and event.sourceQ==4 and event.sourceR==5 and event.targetQ==5 and event.targetR==5)
    assert(event.sourceLayer==2 and event.targetLayer==2 and event.outcome=='pickup')
end)
print('Visual effect events: '..checks..' checks passed')
