package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=file:read('*a');file:close();return bytes
end}})
local Hex=require('Game.Map.HexGrid');local Board=require('Game.Battle.BattleBoard')
local Generator=require('Game.MapArea.MapAreaGenerator')(config)
local battlefieldType=config:GetEnum('MapArea','E_MapAreaType').Battlefield
Generator:Register(battlefieldType,require('Game.MapArea.BattlefieldGenerator'),'MapAreaBattlefieldTable','MapAreaBattlefieldThemeTable')
local definition=config:GetConstant('Loot','EventBattlefieldAreaId')
local source={regionId=5,regionConfigId=5,regionType=5,q=0,r=0,height=0,biomeWeights={{regionType=5,weight=1}},encounterId=204,obstacleChance=.4,propIds={1,2}}
local levels,signatures={},{ }
local function signature(area)
    local result={};for _,cell in ipairs(area.cells)do result[#result+1]=cell.q..':'..cell.r..':'..cell.height..':'..tostring(cell.blocked)end
    return table.concat(result,'|')
end
for seed=1,12 do
    local area=Generator:Generate(definition,seed,2,source)
    levels[area.highland.levels]=true;signatures[signature(area)]=true
    assert(area.highland.levels>=2 and area.highland.levels<=3)
    local highest=assert(area:Find(area.highland.q,area.highland.r));local maximum=area.highland.levels*area.highland.heightStep
    assert(highest.height==maximum and not highest.blocked)
    local board=Board.FromArea(area,0,0,32)
    local starts={area.cells[area.entryIndex],area.cells[area.goalIndex]}
    for _,cell in ipairs(area.encounterPlans[1].cells)do starts[#starts+1]=cell end
    for _,start in ipairs(starts)do
        assert(not start.blocked)
        local _,distance=board:Search(start.q,start.r,{},10000)
        for _,cell in ipairs(area.cells)do assert(cell.blocked or distance[cell],'A walkable hillside is cut off from a deployment position')end
        assert(distance[highest] and area:FindPath(start.index,highest.index),'The summit cannot be reached through the actual navigation graph')
    end
    local seen={}
    for _,cell in ipairs(area.cells)do
        assert(cell.layer==0 and cell.height==cell.elevation*area.highland.heightStep,'Elevation must affect the actual standing surface, not a separate layer')
        if not cell.blocked then seen[cell.elevation]=true end
        for _,other in ipairs(area:Neighbors(cell))do assert(math.abs(other.height-cell.height)<=area.highland.heightStep+.00001,'Adjacent cells form an unclimbable multi-level cliff')end
        if Hex.Distance(cell.q,cell.r,highest.q,highest.r)<=1 then assert(not cell.blocked,'Summit platform contains an obstacle')end
    end
    for elevation=0,area.highland.levels do assert(seen[elevation],'The terrain skipped an intermediate walkable terrace')end
    if seed==1 then assert(signature(area)==signature(Generator:Generate(definition,seed,2,source)),'Identical terrain seed changed')end
end
assert(levels[2] and levels[3],'The deterministic seed sample must exercise both two- and three-level battlefields')
local variations=0;for _ in pairs(signatures)do variations=variations+1 end;assert(variations>1)
print('PASS 12 real random battlefields: 2/3 levels, actual height fields, no cliffs, usable summit, both deployments reach every walkable cell, repeatable varied seeds')

-- Exercise minimum and maximum supported board sizes with the same elevation algorithm.
local Elevation=require('Game.MapArea.BattlefieldElevation');local Random=require('Game.Map.SeededRandom')
for _,radius in ipairs({3,7})do for _,peak in ipairs({2,3})do
    local board=Board.Create(radius,97,.4)
    Elevation.Apply(board,{heightStep=1,minElevation=peak,maxElevation=peak,plateauRadius=1},Random(97))
    local _,distance=board:Search(-radius,0,{},10000)
    for _,cell in ipairs(board.cells)do
        assert(cell.blocked or distance[cell])
        for _,nextCell in ipairs(board:Neighbors(cell))do assert(math.abs(nextCell.height-cell.height)<=1)end
    end
end end
print('PASS 3- and 7-radius geometry boundaries remain connected at both supported peak heights')

local height=require('Game.Battle.HeightAdvantage').New(config)
local ranged={id=101,name='test ranged attack',target='enemy',range=3,minRange=0,fixedRange=false,hitChance=80,trajectory='sight'}
local melee={target='enemy',range=1,hitChance=80}
for level=0,4 do
    local origin,target={height=level,layer=0},{height=0,layer=0}
    assert(height:RangeBonus(origin,target,ranged)==math.min(level,3))
    assert(height:HitChance(origin,target,ranged)==80+5*math.min(level,3))
    assert(height:HitChance(origin,target,melee)==80+5*math.min(level,3) and height:RangeBonus(origin,target,melee)==0)
    assert(height:RangeBonus(target,origin,ranged)==0 and height:HitChance(target,origin,ranged)==80)
end
assert(height:HitChance({height=3},{height=0},{target='enemy',range=3,hitChance=95})==100)
assert(height:HitChance({height=3},{height=0},{target='ally',range=3,hitChance=80})==80)
assert(height:RangeBonus({height=3,layer=1},{height=0,layer=0},ranged)==0)
assert(height:Description(ranged):find('远程射程',1,true) and not height:Description(melee):find('远程射程',1,true))
print('PASS configured high-ground accuracy, ranged-only distance, cap, no uphill penalty/damage change and same-layer boundary')

-- Verify the real attack eligibility and hit resolution, not only the arithmetic helper.
local Layout=require('Game.MapArea.MapAreaLayout')
local area=Layout.New({id=1,name='height combat',areaType=4,width=12,height=11,hexRadius=1,visionRadius=10,moveStepSeconds=.1},1,{}, {})
for _,cell in ipairs(area.cells)do cell.blocked=false;cell.blocksSight=false;cell.height=math.min(3,math.max(0,5-cell.q))end
local battle=require('Game.Battle.BattleSystem')();battle.board=Board.FromArea(area,5,5,12)
local attacker={Id=1,Team=1,Q=2,R=5,HP=100};local target={Id=2,Team=2,Q=8,R=5,HP=100}
battle.stats={heightAdvantage=height,animals={rule={tameSkillId=-1},bySkill={},Distance=function(_,a,b)return Hex.Distance(a.Q,a.R,b.Q,b.R)end},Template=function()return {name='test'}end}
function battle:SkillBudget()return true end
function battle:Skill()return ranged end
function battle:Active()return attacker end
function battle:FindUnit(id)return id==1 and attacker or target end
function battle:Emit()end
battle.construction={RangeBonus=function()return 1 end,RangeBonusAt=function()return 1 end}
assert(battle:CanUseSkill(101,2),'Natural high ground did not extend the real attack range')
target.Q=9;assert(not battle:CanUseSkill(101,2),'Construction and natural elevation were double-counted');target.Q=8
local hits=0;battle.data={RollPercent=function()return 90 end};battle.gameEffects={ApplyPrepared=function()hits=hits+1 end}
local program={{target=target,definition={kind='damage'}}}
battle:ApplyEffectProgram(attacker,ranged,program,1);assert(hits==1,'Height did not affect real hit resolution')
area:Find(attacker.Q,attacker.R).height=0
battle:ApplyEffectProgram(attacker,ranged,program,1);assert(hits==1,'The same roll should miss without high ground')
print('PASS real BattleSystem target range and per-target hit resolution, including no double-stacked construction bonus')

-- Scene containers must use the same elevated shot eligibility and chance as living targets.
area:Find(attacker.Q,attacker.R).height=3;ranged.affectsContainers=true
local cell=area:Find(target.Q,target.R)
local physical={MaxDurability=40,Destroyed=false,Unlocked=true,CellCount=1,GetCellAt=function()return cell.index end}
local container={Id=1,TableId=201,Name='height test crate'}
local state={Revision=1,VisibleCount=1,GetVisibleAt=function()return cell.index end}
area.containerState=state
function battle.stats.animals:Cells(_,board,q,r)return {board:Find(q,r)}end
local adventure={battle=battle,data={Areas={ActiveSiteId=1}},areas={data={Active=state},ActiveLayout=function()return area end}}
local combat=setmetatable({adventure=adventure,loot={Find=function()return container end,SyncLock=function()return physical end}},
    {__index=require('Game.Loot.ContainerCombat')})
assert(combat:Target(attacker,ranged,1,battle),'The high-ground shot could not reach a scene container')
local durabilityLoss=0
CS={ProjectY={Data={ContainerState={Hit=function(_,id,amount)assert(id==1);durabilityLoss=durabilityLoss+amount;return amount end}}}}
local plans={{container=container,physical=physical,effects={5}}}
combat:Apply(plans,attacker,ranged,function()return 90 end,battle);assert(durabilityLoss==5)
area:Find(attacker.Q,attacker.R).height=0
assert(not combat:Target(attacker,ranged,1,battle))
combat:Apply(plans,attacker,ranged,function()return 90 end,battle);assert(durabilityLoss==5)
print('PASS scene container range and hit resolution share the same high-ground advantage')
config:OnShutdown()
