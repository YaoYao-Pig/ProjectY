-- 离线定向检查：真实配置、地形投影、角色命令及探索/战斗容器共用弹道。
package.path='Lua/?.lua;'..package.path
local Hex=require('Game.Map.HexGrid')
local Layout=require('Game.MapArea.MapAreaLayout')
local Board=require('Game.Battle.BattleBoard')
local Trajectory=require('Game.Battle.SkillTrajectory')
local Projectiles=require('Game.Battle.ProjectileCombat')
local EmptyGrowth=assert(loadfile('Tools/Tests/growth_empty.lua'))()
local Gear=assert(loadfile('Tools/Tests/equipment_read_fixture.lua'))()
-- These fixtures have no worn armor; physical wear remains observable on the configured gun.
CS.ProjectY.Data.EquipmentCombatState={
    DamageArmor=function(data)assert(data.WearableCount==0);return 0 end,
    RefreshMaximum=function(unit,maximum)unit.MaxHP=maximum;unit.HP=math.min(unit.HP,maximum)end,
    DamageWeapon=function(data,id,amount)local weapon=data:GetWeapon(id);weapon.condition.Current=weapon.condition.Current-amount;return amount end,
}
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local count=0
local function test(name,run) run();count=count+1;print('PASS '..name) end
local function flat()
    local area=Layout.New({id=999,name='Trajectory',areaType=1,width=12,height=12,hexRadius=1,
        visionRadius=9,moveStepSeconds=.1},1,{}, {wallHeight=3})
    for _,cell in ipairs(area.cells) do cell.height=0;cell.blocked=false;cell.blocksSight=false;cell.kind='floor' end
    return area
end
local function board(area) return Board.FromArea(area,5,5,8) end
local function clear(board,origin,target,mode,occupied)
    local trace=Trajectory.Trace(board,origin,target,mode,occupied or {})
    return trace.reachable and #trace.blockers==0
end
local function profile(battle,skillId,target)
    local source=battle:Active()
    return Projectiles.Profile(battle,source,battle:Skill(source,skillId),battle.board:Find(target.Q,target.R),nil,target)
end
local function actor(id,template,team,q,r)
    local unit={Id=id,TemplateId=template,Team=team,Q=q,R=r,HP=100,AP=8,MainUsed=false,Moved=false,
        AnimalOwnerId=0,Growth=EmptyGrowth(),TraitCount=0,Effects={Count=0,Find=function()return nil end},Guard=0,MaxHP=100}
    function unit:GetCooldown() return 0 end
    function unit:SpendAction(kind,cost) self.AP=self.AP-cost;self.Moved=true;if kind=='main' then self.MainUsed=true end end
    function unit:SetCooldown() end
    function unit:RecordAction() end
    function unit:Damage(amount) self.HP=self.HP-amount;return amount end
    return unit
end
local function battleFixture(area)
    local source,target=actor(1,3,1,2,4),actor(101,4,2,5,4)
    local units={source,target}
    local battle=require('Game.Battle.BattleSystem')()
    -- Keep the real spell's catalyst rule: the shooter holds an actual configured staff.
    local staff=Gear(1,1,source.Id)
    local inventory={WearableCount=0,Equipped=function(_,id)return id==source.Id and staff or nil end,
        Offhand=function()return nil end,Worn=function()return nil end}
    battle.board=board(area);battle.stats=require('Game.Battle.CombatStats')(config,inventory)
    battle.skills=config:GetTable('CombatSkillTable')
    battle.effects=config:GetTable('CombatEffectTable')
    battle.data={Phase='combat',Winner='',ActiveId=1,UnitCount=2,GetUnitAt=function(_,i)return units[i+1] end,
        AddLog=function()end,RollPercent=function()return 0 end}
    battle.Changed={Emit=function()end}
    battle.gameEffects=require('Game.Battle.GameEffects').New(battle.stats,config:GetTable('CombatEffectTable'),function()end,{roll=function()return 99 end})
    -- 将真实火花技能的配置弹道切换，验证法术也走配置，不靠武器种类分支。
    local mode='direct';local skills=battle.skills
    battle.stats.equipment.skills={Get=function(_,id)
        local original=skills:Get(id)
        if id~=3 then return original end
        local row={};for key,value in pairs(original) do row[key]=value end;row.trajectory=mode;return row
    end}
    local function add(unit) units[#units+1]=unit;battle.data.UnitCount=#units end
    return battle,source,target,add,function(value)mode=value end
end

test('exported bow/gun modes, unchanged skills and equipment resolution',function()
    local battle,source=battleFixture(flat());local stats=require('Game.Battle.CombatStats')(config,battle.stats.equipment.data)
    for _,id in ipairs({2,105,106}) do assert(stats.equipment:Skill(source,id,stats).trajectory=='lobbed') end
    for _,id in ipairs({6,7,8}) do assert(stats.equipment:Skill(source,id,stats).trajectory=='direct') end
    for _,id in ipairs({1,3,4,5,201,301}) do assert(stats.equipment:Skill(source,id,stats).trajectory=='sight') end
    assert(not pcall(Trajectory.Description,'invalid'),'Unknown modes must fail explicitly')
end)

test('six directions: near/far terrain, both blockers, adjacent targets and reverse rays',function()
    for direction=1,6 do
        local area=flat();local origin=area:Find(5,5)
        local q,r=Hex.Neighbor(5,5,direction);local near=area:Find(q,r)
        q,r=Hex.Neighbor(q,r,direction);local far=area:Find(q,r)
        q,r=Hex.Neighbor(q,r,direction);local target=area:Find(q,r);local grid=board(area)
        local function open(mode,a,b)return clear(grid,a or origin,b or target,mode,{}) end
        assert(open('direct') and open('lobbed'))
        near.blocksSight=true
        assert(open('direct') and not open('lobbed') and not area:CanSee(origin,target))
        assert(not open('direct',target,origin) and open('lobbed',target,origin),'Distance must be measured from the shooter')
        assert(open('direct',origin,near) and open('lobbed',origin,near),'The target cell is not an intermediate blocker')
        far.blocksSight=true;assert(not open('direct') and not open('lobbed'))
        near.blocksSight=false;assert(not open('direct') and open('lobbed'))
        far.blocksSight=false;near.height=3
        assert(open('direct') and not open('lobbed'),'Raised near terrain follows the same distance rule')
        near.height=0;far.height=3
        assert(not open('direct') and open('lobbed'))
    end
end)

test('off-path neighbors do not block and both sides of a vertex ray are checked',function()
    local area=flat();local grid=board(area);local origin,target=area:Find(4,4),area:Find(5,5)
    area:Find(3,4).blocksSight=true
    assert(clear(grid,origin,target,'lobbed'))
    for _,cell in ipairs({area:Find(5,4),area:Find(4,5)}) do
        cell.blocksSight=true
        assert(not clear(grid,origin,target,'lobbed'),'Vertex-side obstacle was missed')
        assert(clear(grid,origin,target,'direct'))
        cell.blocksSight=false
    end
end)

test('construction and container overlays obey distance rules and update after destruction',function()
    local base=flat();local near,far=base:Find(3,4),base:Find(4,4)
    local records={};local construction={definitions=config:GetTable('ConstructionTable')}
    function construction:Record(_,index)return records[index] end
    function construction:Records()return records end
    local area=require('Game.MapArea.ConstructionTerrain').Wrap(Layout.Freeze(base),construction,1)
    local function open(mode)return clear(board(area),area:Find(2,4),area:Find(5,4),mode,{}) end
    records[near.index]={SkillId=302}
    assert(open('direct') and not open('lobbed'))
    records[near.index]=nil;records[far.index]={SkillId=302}
    assert(not open('direct') and open('lobbed'))
    records[far.index]={SkillId=301};assert(open('direct') and open('lobbed'),'Fence must preserve its non-sight-blocking rule')
    records[far.index]=nil
    local physical={Configured=true,Destroyed=false,CellCount=1,GetCellAt=function()return far.index end}
    local loot={Physical=function()return physical end,rules={containers={Get=function()return {blocksSight=true,blocksMovement=true} end}}}
    area=require('Game.Loot.ContainerTerrain').Wrap(area,loot,{LootCount=1,GetLootAt=function()return {Id=1,TableId=1,Name='test crate'} end})
    assert(not open('direct') and open('lobbed'))
    physical.Destroyed=true;assert(open('direct') and open('lobbed'))
    assert(area:CanSee(area:Find(2,4),area:Find(5,4)))
end)

test('layered geometry filters intermediate columns while keeping endpoint floors solid',function()
    local area=flat();area.layeredVisibility=true;area.layerCount=2
    local origin,target=area:Find(2,4),area:Find(5,4)
    area:Find(3,4).blocksSight=true
    assert(clear(area,origin,target,'direct') and not clear(area,origin,target,'lobbed'))
    area:Find(3,4).blocksSight=false;area:Find(4,4).blocksSight=true
    assert(not clear(area,origin,target,'direct') and clear(area,origin,target,'lobbed'))
    local upper=area:AddLayerCell(2,4,1,3);upper.deckThickness=.2
    assert(not Trajectory.CanReach(area,origin,upper,'direct',{}) and not Trajectory.CanReach(area,origin,upper,'lobbed',{}))
end)

test('actual skill commands allow interception and friendly fire; corpses do not intercept',function()
    local area=flat();local battle,source,target,add,mode=battleFixture(area)
    local friend=actor(2,1,1,4,4);add(friend)
    local hp=target.HP;local risk=profile(battle,3,target)
    assert(risk.reachable and risk.blockerCount==1 and risk.friendlyRisk and risk.hitChance<risk.baseHitChance)
    assert(battle:TrySkill(3,target.Id))
    assert(source.AP==6 and source.MainUsed and target.HP==hp and friend.HP<100)
    source.AP=8;source.MainUsed=false;friend.Q=3
    assert(battle:CanUseSkill(3,target.Id) and profile(battle,3,target).blockerCount==0)
    mode('lobbed');assert(battle:CanUseSkill(3,target.Id) and profile(battle,3,target).blockerCount==1)
    friend.HP=0;assert(profile(battle,3,target).blockerCount==0,'A dead friend cannot intercept')
    friend.HP=100;friend.Team=2;assert(profile(battle,3,target).blockerCount==1,'An enemy must intercept identically')
    friend.TemplateId=201;friend.Team=0;assert(profile(battle,3,target).blockerCount==1,'A neutral animal must intercept')
    friend.AnimalOwnerId=source.Id;assert(profile(battle,3,target).blockerCount==0,'An attached animal is not a separate blocker')
    friend.AnimalOwnerId=0;friend.HP=0
    assert(battle:TrySkill(3,target.Id));assert(source.AP==6 and source.MainUsed and target.HP<hp)
end)

test('full footprints, target exclusion, external occupants and independent boards',function()
    local area=flat();local battle,source,target,add,mode=battleFixture(area)
    local animal=actor(201,201,0,3,4);add(animal)
    local species={};for key,value in pairs(battle.stats.animals.byUnit[201]) do species[key]=value end
    species.footprintQ={0,1};species.footprintR={0,0};battle.stats.animals.byUnit[201]=species
    assert(battle:CanUseSkill(3,target.Id) and profile(battle,3,target).blockerCount==1,'Far footprint cell must intercept direct fire')
    mode('lobbed');assert(battle:CanUseSkill(3,target.Id) and profile(battle,3,target).blockerCount==1,'Near footprint cell must intercept lobbed fire')
    animal.HP=0;mode('direct')
    target.TemplateId=201;species.footprintQ={-1,0}
    assert(battle:CanUseSkill(3,target.Id) and profile(battle,3,target).blockerCount==0,'No part of the target may intercept its own shot')
    target.TemplateId=4;battle.board.externalOccupied={['4:4']=true}
    assert(battle:CanUseSkill(3,target.Id) and profile(battle,3,target).blockerCount==1)
    mode('lobbed');assert(battle:CanUseSkill(3,target.Id) and profile(battle,3,target).blockerCount==0)
    local standalone=Board.Create(4,1,0);standalone:Find(0,0).blocked=true
    local origin,destination=standalone:Find(-2,0),standalone:Find(1,0)
    assert(Trajectory.CanReach(standalone,origin,destination,'direct',{}) and not clear(standalone,origin,destination,'direct'))
    assert(clear(standalone,origin,destination,'lobbed'))
    assert(Trajectory.CanReach(standalone,origin,destination,'sight',{}),'Legacy non-projectile board rules must stay unchanged')
end)

test('an intercepted configured gun shot spends AP, ammunition and cooldown once on its actual recipient',function()
    local area=flat();local battle,source,target,add=battleFixture(area)
    local friend=actor(2,1,1,4,4);add(friend)
    local weapon=Gear(1,2,source.Id);weapon.MagazineId=1
    local magazine={Rounds=12,Capacity=12};local cooldowns=0
    local inventory={WearableCount=0,Equipped=function()return weapon end,Offhand=function()end,Worn=function()end,
        GetWeapon=function(_,id)assert(id==weapon.Id);return weapon end,
        GetMagazine=function()return magazine end,SpendAmmo=function(_,_,amount)magazine.Rounds=magazine.Rounds-amount end}
    battle.stats=require('Game.Battle.CombatStats')(config,inventory)
    battle.gameEffects=require('Game.Battle.GameEffects').New(battle.stats,config:GetTable('CombatEffectTable'),function()end)
    source.SetCooldown=function()cooldowns=cooldowns+1 end
    assert(battle:TrySkill(7,target.Id))
    assert(source.AP==6 and source.MainUsed and magazine.Rounds==11 and cooldowns==1 and target.HP==100 and friend.HP<100)
    source.AP=8;source.MainUsed=false;friend.Q=3;assert(battle:TrySkill(7,target.Id))
    assert(source.AP==6 and source.MainUsed and magazine.Rounds==10 and cooldowns==2 and target.HP<100)
end)

test('enemy AI obeys the configured trajectory through the normal skill command',function()
    local area=flat();local battle,source,target,add,mode=battleFixture(area)
    -- Isolate this AI's one tested projectile from the staff's separately tested alternate spells.
    function battle:SkillIds()return {3,4}end
    source.Team=2;target.Team=1;source.Moved=true
    function source:SetGuard(value) self.Guard=value end
    local ally=actor(102,4,2,4,4);add(ally)
    battle.EndTurn=function()return true end
    assert(battle:StepAI());assert(target.HP==100 and ally.HP<100,'AI must use the same friendly interception settlement')
    source.AP=8;source.MainUsed=false;mode('lobbed')
    assert(battle:StepAI());assert(target.HP<100,'AI did not use a legal lobbed shot over a distant ally')
end)

test('area occupancy reads current battle positions, animals and NPCs on the correct layer',function()
    local area=flat();area:AddLayerCell(4,4,1,3)
    local battle,source,target=battleFixture(area)
    local friend=actor(2,1,1,4,4);local animal=actor(201,201,0,3,4)
    local party={source,friend};local enemies={target,animal}
    local npcs={{Present=true,CellIndex=area:Find(4,4,1).index},{Present=false,CellIndex=area:Find(6,4).index}}
    local group={EnemyCount=2,GetEnemyAt=function(_,i)return enemies[i+1] end}
    local state={MemberCount=2,EncounterCount=1,NpcCount=2,GetEncounterAt=function()return group end,
        GetMemberIdAt=function(_,i)return party[i+1].Id end,GetMemberCellAt=function(_,i)return area:Find(i==0 and 2 or 7,4).index end,
        GetNpcAt=function(_,i)return npcs[i+1] end}
    local areas=require('Game.MapArea.MapAreaSystem')()
    areas.data={Active=state,ActiveSiteId=1};areas.layouts={[1]=area};areas.combatStats=battle.stats
    areas.adventure={PartyCount=2,GetPartyAt=function(_,i)return party[i+1] end}
    local current=areas:ShotOccupancy(source.Id,target.Id,battle,0)
    assert(current['4:4'] and current['3:4'] and not current['2:4'] and not current['5:4'] and not current['7:4'])
    friend.HP=0;animal.HP=0;current=areas:ShotOccupancy(source.Id,target.Id,battle,0)
    assert(not current['4:4'] and not current['3:4'] and not current['6:4'])
    assert(areas:ShotOccupancy(source.Id,target.Id,nil,1)['4:4'],'Present upstairs NPC should occupy only its own layer')
    friend.HP=100;current=areas:ShotOccupancy(source.Id,target.Id,nil,0)
    assert(current['7:4'] and not current['4:4'],'Exploration uses squad positions, not stale combat coordinates')
end)

test('container targeting and splash use the same projectile rules in battle and exploration',function()
    local area=flat();local battle,source,_,_,mode=battleFixture(area)
    local target=area:Find(5,4);local physical={MaxDurability=40,Destroyed=false,Unlocked=true,CellCount=1,GetCellAt=function()return target.index end}
    local container={Id=1,TableId=201,Name='box'}
    local state={Revision=1,VisibleCount=1,GetVisibleAt=function()return target.index end,LootCount=1,GetLootAt=function()return container end,
        MemberCount=1,GetMemberIdAt=function()return source.Id end,GetMemberCellAt=function()return area:Find(2,4).index end}
    area.containerState=state
    local occupied={['4:4']=true}
    local areas={data={Active=state},ActiveLayout=function()return area end,ShotOccupancy=function()return occupied end}
    local loot={Find=function()return container end,SyncLock=function()return physical end,Physical=function()return physical end,
        session={Active=false},rules={containers=config:GetTable('EquipmentLootTable')}}
    local adventure={areas=areas,battle=battle,data={Areas={ActiveSiteId=1},Phase='area'}}
    local combat=setmetatable({adventure=adventure,loot=loot},{__index=require('Game.Loot.ContainerCombat')})
    battle.board.shotOccupancy=function()return occupied end
    assert(combat:CanArea(source,3,1) and combat:CanBattle(battle,3,1))
    assert(not clear(area,area:Find(2,4),target,'direct',occupied),'The selectable container must still carry interception risk')
    mode('lobbed');assert(combat:CanArea(source,3,1) and combat:CanBattle(battle,3,1))
    local skill=battle:Skill(source,3);skill.splashRadius=2
    assert(#combat:Splash(source,skill,area:Find(6,4),0,2,battle)==1)
    occupied={['3:4']=true};assert(combat:CanArea(source,3,1) and #combat:Splash(source,skill,target,0,2,battle)==1)
    assert(not clear(area,area:Find(2,4),target,'lobbed',occupied),'Near cover must remain in the lobbed shot profile')
    mode('direct');assert(combat:CanArea(source,3,1) and combat:CanBattle(battle,3,1))
    state.GetVisibleAt=function()return area:Find(0,0).index end;state.Revision=2
    assert(not combat:CanArea(source,3,1),'Ballistics must not reveal hidden containers')
end)

config:OnShutdown()
print('Skill trajectory: '..count..' checks passed')
