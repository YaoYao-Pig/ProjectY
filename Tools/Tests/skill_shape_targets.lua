-- Real TrySkill target selection; effect execution and resources are isolated boundaries.
package.path='Lua/?.lua;'..package.path
local Projectiles=require('Game.Battle.ProjectileCombat')
local originalPrepare=Projectiles.PrepareProgram
Projectiles.PrepareProgram=function()end
local battle=require('Game.Battle.BattleSystem')()
local source={Id=1,Team=1,Q=-3,R=0,HP=100,AP=10}
function source:SpendAction(_,cost)self.AP=self.AP-cost end
function source:SetCooldown()end
function source:RecordAction()end
local units={source,{Id=2,Team=2,Q=0,R=0},{Id=3,Team=2,Q=1,R=0},{Id=4,Team=2,Q=2,R=0},{Id=5,Team=2,Q=1,R=1}}
local skill={id=99,rangeShape='hex',splashShape='ring',splashRadius=2,maxTargets=8,effectIds={1},shots=1,action='main',cost=1,cooldownTurns=0}
battle.stats={animals={rule={tameSkillId=-1},bySkill={}}}
battle.spellcasting={UseRecovery=function()end}
battle.beasts={Handles=function()return false end}
battle.professions={rows={Find=function()end},PrepareProgram=function()end,Commit=function()end,ConsumeEquipment=function()end}
battle.gameEffects={Prepare=function(_,_,_,victim)return {target=victim}end}
function battle:Active()return source end
function battle:Skill()return skill end
function battle:Units()return units end
function battle:FindUnit(id)for _,unit in ipairs(units)do if unit.Id==id then return unit end end end
function battle:CanUseSkill(_,id)return self:FindUnit(id).Team==2 end
function battle:CheckWinner()end
local hit={}
function battle:ApplyEffectProgram(_,_,program)for _,plan in ipairs(program)do hit[plan.target.Id]=true end end
assert(battle:TrySkill(99,2))
assert(not hit[2] and not hit[3] and hit[4] and hit[5],'Ring impacts must exclude the center and inner cells')
skill.splashShape='line';hit={};assert(battle:TrySkill(99,2))
assert(hit[2] and hit[3] and hit[4] and not hit[5],'Line impacts must exclude off-axis secondary targets')
skill.splashShape='hex';skill.maxTargets=2;hit={};assert(battle:TrySkill(99,2))
assert(hit[2] and hit[3] and not hit[4] and not hit[5],'Ordinary AoE must retain its target cap and stable nearest order')
skill.manualTargets=true;skill.splashShape='ring';hit={};assert(battle:TrySkill(99,2,{2,3}))
assert(hit[2] and hit[3] and not hit[4],'Explicit tracking targets must not inherit splash geometry')
assert(source.AP==6,'Each cast must commit its cost exactly once')
Projectiles.PrepareProgram=originalPrepare
print('PASS actual ring/line/hex target programs, hollow centers, target caps, manual tracking and single resource commits')
