package.path='Lua/?.lua;'..package.path
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
local skill={id=3,target='enemy',range=3,minRange=1,trajectory='sight'}
local origins={area:Find(2,5)}
battle.stats={heightAdvantage=require('Game.Battle.HeightAdvantage').New(config),animals={rule={tameSkillId=-1},bySkill={},
    Cells=function()return origins end,Distance=function(_,a,b)return Hex.Distance(a.Q,a.R,b.Q,b.R)end}}
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
origins[2]=area:Find(3,5);assert(contains(6,5),'Coverage must originate from the complete source footprint')
skill.target='self';local cells=battle:SkillRangeCells(3)
assert(#cells==2 and cells[1]==origins[1] and cells[2]==origins[2],'Self skills must show only their own footprint')
skill.target='cell'
function battle:CanUseSkillAt(_,q,r)return q==4 and r==5 end
cells=battle:SkillRangeCells(3);assert(#cells==1 and cells[1]==area:Find(4,5),'Ground skills must reuse real landing eligibility')
config:OnShutdown()
print('PASS range/command agreement, minimum range, sight walls, projectile risk, high ground, fixed range, footprints and ground/self targets')
