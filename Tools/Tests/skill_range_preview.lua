package.path='Lua/?.lua;'..package.path
CS={ProjectY={Data={DeathDoorState={Alive=function(actor)return actor.HP>0 end}}}}
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local Hex=require('Game.Map.HexGrid')
local area=require('Game.MapArea.MapAreaLayout').New({id=1,name='range fixture',areaType=4,width=12,height=11,hexRadius=1,visionRadius=10,moveStepSeconds=.1},1,{}, {})
for _,cell in ipairs(area.cells)do cell.blocked=false;cell.blocksSight=false;cell.height=0 end
local board=require('Game.Battle.BattleBoard').FromArea(area,5,5,12)
local battle=require('Game.Battle.BattleSystem')();battle.board=board
local source={Id=1,Team=1,Q=2,R=5,HP=100};local target={Id=2,Team=2,Q=5,R=5,HP=100}
local skill={id=3,target='enemy',range=3,rangeShape='hex',minRange=1,trajectory='sight'}
local origins={area:Find(2,5)}
battle.stats={heightAdvantage=require('Game.Battle.HeightAdvantage').New(config),animals={rule={tameSkillId=-1},bySkill={},
    Cells=function(_,actor,_,q,r)
        if q then return {area:Find(q,r)}end
        return actor==source and origins or {area:Find(actor.Q,actor.R)}
    end,Distance=function(_,a,b)return Hex.Distance(a.Q,a.R,b.Q,b.R)end}}
battle.beasts={Handles=function()return false end};battle.professions={CanUse=function()return true end}
function battle:Active()return source end
function battle:Skill()return skill end
function battle:SkillBudget()return true end
function battle:FindUnit()return target end
function battle:IsHostile()return true end
function battle:ShotOccupancy()return {} end
local function contains(q,r)
    local cell=assert(area:Find(q,r))
    for _,value in ipairs(battle:SkillRangeCells(3))do if value==cell then return true end end
    return false
end
assert(contains(5,5) and battle:CanUseSkill(3,2),'Preview must include a legal maximum-range target')
target.Q=6;assert(not contains(6,5) and not battle:CanUseSkill(3,2),'Preview must exclude targets beyond range')
assert(not contains(2,5),'Minimum range must exclude the source cell')
skill.minRange=2;target.Q=3;assert(not contains(3,5) and not battle:CanUseSkill(3,2),'Spear dead zone must match command validation')
skill.minRange=1;target.Q=5
local wall=area:Find(3,5);wall.blocked=true;wall.blocksSight=true
assert(not contains(5,5) and not battle:CanUseSkill(3,2),'Sight skills must not highlight cells through a wall')
skill.trajectory='direct';assert(contains(5,5) and battle:CanUseSkill(3,2),'Projectile interception is a risk, not a forbidden range cell')
wall.blocked=false;wall.blocksSight=false;skill.trajectory='sight'
origins[1].height=3;target.Q=8
battle.construction={RangeBonusAt=function()return 1 end}
assert(contains(8,5) and battle:CanUseSkill(3,2),'High-ground maximum range must match gameplay')
target.Q=9;assert(not contains(9,5) and not battle:CanUseSkill(3,2),'Natural and construction range must not double stack')
skill.fixedRange=true;assert(not contains(8,5),'Fixed-range skills must not inherit high-ground range')
skill.fixedRange=false;battle.construction=nil;origins[1].height=0
skill.rangeShape='line';target.Q=5;target.R=5
assert(contains(5,5) and battle:CanUseSkill(3,2),'An aligned endpoint must remain selectable')
target.Q=4;target.R=6
assert(not contains(4,6) and not battle:CanUseSkill(3,2),'Line preview and submission must reject off-axis targets')
skill.rangeShape='ring'
assert(contains(4,6) and battle:CanUseSkill(3,2),'The outer ring must include non-axial edge cells')
target.Q=4;target.R=5
assert(not contains(4,5) and not battle:CanUseSkill(3,2),'Ring skills must reject inner cells')
function battle:SkillIds()return {3}end
local approaches=battle:ApproachCells(source,target)
assert(#approaches>0)
for _,cell in ipairs(approaches)do assert(Hex.Distance(cell.q,cell.r,target.Q,target.R)==3,'AI must seek ring distance instead of adjacent cells')end
skill.target='cell';battle.spellcasting={CanUseAt=function()return true end}
assert(not battle:CanUseSkillAt(3,4,5) and battle:CanUseSkillAt(3,5,5),'Ground handlers must respect configured shapes')
skill.target='enemy';skill.rangeShape='hex';target.Q=5;target.R=5
origins[2]=area:Find(3,5);assert(contains(6,5),'Coverage must originate from the complete source footprint')
skill.target='self';local cells=battle:SkillRangeCells(3)
assert(#cells==2 and cells[1]==origins[1] and cells[2]==origins[2],'Self skills must show only their own footprint')
skill.target='cell'
function battle:CanUseSkillAt(_,q,r)return q==4 and r==5 end
cells=battle:SkillRangeCells(3);assert(#cells==1 and cells[1]==area:Find(4,5),'Ground skills must reuse real landing eligibility')
config:OnShutdown()
local Shape=require('Game.Battle.SkillShape')
for shape,expected in pairs({hex=90,line=30,ring=30})do
    local count=0
    for q=-5,5 do for r=-5,5 do if Shape.Contains(shape,0,0,q,r,5,1)then count=count+1 end end end
    assert(count==expected,shape..' radius 5 has incorrect coverage')
end
assert(not pcall(Shape.Contains,'unknown',0,0,1,0,5,0),'Bad shape configuration must fail loudly')
local center=area:Find(6,5)
battle.spellcasting={recipes={Find=function()end}}
local impactSkill={id=3,maxTargets=8,splashShape='ring',splashRadius=2}
local impacts=battle:SkillImpactCells(impactSkill,center)
assert(#impacts==12,'A radius-two impact ring must contain twelve cells')
for _,cell in ipairs(impacts)do assert(Hex.Distance(center.q,center.r,cell.q,cell.r)==2)end
impactSkill.splashShape='hex';assert(#battle:SkillImpactCells(impactSkill,center)==19)
impactSkill.splashShape='line';assert(#battle:SkillImpactCells(impactSkill,center)==13)
impactSkill.manualTargets=true;assert(#battle:SkillImpactCells(impactSkill,center)==0,'Manual tracking must not promise splash damage')
impactSkill.manualTargets=false;impactSkill.maxTargets=1
assert(#battle:SkillImpactCells(impactSkill,center)==0,'Single target skills must not promise splash damage')
battle.spellcasting.recipes.Find=function()return {fieldKind='fire'}end
assert(#battle:SkillImpactCells(impactSkill,center)==13,'Persistent ground fields must project their impact shape')
-- Use the real container eligibility path without unrelated character-growth state.
origins[2]=nil;skill.target='enemy';skill.affectsContainers=true;skill.rangeShape='line';skill.range=3;skill.minRange=1
local state={Revision=1};local container={Id=1}
local physical={MaxDurability=20,Destroyed=false,Unlocked=true,CellCount=1,GetCellAt=function()return area:Find(target.Q,target.R).index end}
area.containerState=state
local areas={data={Active=state},ActiveLayout=function()return area end}
local combat=setmetatable({adventure={data={Areas={ActiveSiteId=1}},areas=areas,battle=battle},
    loot={Find=function()return container end,SyncLock=function()return physical end},visibleState=state,visibleRevision=1,visibleCells={}},require('Game.Loot.ContainerCombat'))
for _,cell in ipairs(area.cells)do combat.visibleCells[cell.index]=true end
target.Q=5;target.R=5;assert(combat:Target(source,skill,1,battle))
target.Q=4;target.R=6;assert(not combat:Target(source,skill,1,battle),'Containers must reject off-axis line casts')
skill.rangeShape='ring';assert(combat:Target(source,skill,1,battle))
target.Q=4;target.R=5;assert(not combat:Target(source,skill,1,battle),'Containers must reject inner ring cells')
skill.rangeShape='hex';skill.minRange=2;target.Q=3;assert(not combat:Target(source,skill,1,battle),'Container dead zones must remain enforced')
target.Q=4;assert(combat:Target(source,skill,1,battle),'Container minimum-range boundary must remain usable')
print('PASS shapes, six rays, ring boundaries, AI/ground/actor agreement, minimum range, sight, projectiles, high ground and footprints')
