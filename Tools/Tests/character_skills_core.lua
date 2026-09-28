package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local supports=require('Game.Battle.SkillContext')
assert(supports(config:GetTable('CombatSkillTable'):Get(201),'life'))
assert(supports(config:GetTable('CombatSkillTable'):Get(201),'battle'))
assert(not supports(config:GetTable('CombatSkillTable'):Get(1),'life'))
local charisma=config:GetTable('GrowthAttributeTable'):Get(19)
assert(charisma.code=='charisma' and charisma.category=='life' and not charisma.skillDirection)
assert(config:GetConstant('Global','ExplorationRoundSeconds')>0)
print('PASS charisma is a life attribute; taming has both contexts; other combat skills stay filtered')
local animals=require('Game.Animals.AnimalRules').New(config)
local party={{Id=1,HP=40,Team=1,skills={1,201}},{Id=2,HP=35,Team=1,skills={1}},{Id=3,HP=0,Team=1,skills={201}}}
local target={Id=101,TemplateId=201,HP=20,MaxHP=48,Team=0,AnimalOwnerId=0,TameRetryTurns=2,Q=5,R=0}
local group={EnemyCount=1,GetEnemyAt=function()return target end}
local state={EncounterCount=1,VisibleCount=1,GetEncounterAt=function()return group end,GetVisibleAt=function()return 7 end}
local data={Phase='area',PartyCount=#party,GetPartyAt=function(_,i)return party[i+1] end,Areas={Active=state}}
local calls=0
local area={Find=function()return {index=7} end}
local adventure={config=config,data=data,areas={ActiveLayout=function()return area end},battle={data={ActiveId=1}}}
function adventure.battle:SkillIds(actor) return actor.skills end
function adventure.areas:CanTame(actorId,targetId)
    return animals:CanTame(party[actorId],targetId==target.Id and target or nil)
end
function adventure.areas:Tame(actorId,targetId) calls=calls+1;assert(actorId==1 and targetId==101);return true end
local skills=require('Game.Adventure.CharacterSkills').New(adventure)
assert(#skills:Rows(0,'life')==0 and #skills:Rows(2,'life')==0)
local rows=skills:Rows(1,'life');assert(#rows==1 and rows[1].id==201 and rows[1].contexts=='生活 + 战斗')
assert(not rows[1].available and rows[1].reason:find('2 回合'))
assert(not skills:Use(1,201,101) and calls==0,'A disabled retry must not mutate gameplay')
target.TameRetryTurns=0
assert(skills:Rows(1,'life')[1].available)
assert(skills:Use(1,201,101) and calls==1)
assert(not skills:Use(2,201,101) and calls==1,'Selection cannot grant a skill to another actor')
assert(not skills:Use(1,1,101) and calls==1,'Combat-only skill cannot execute through exploration')
assert(not skills:Rows(3,'life')[1].available,'A defeated selected actor cannot cast')
data.Phase='map';assert(not skills:Rows(1,'life')[1].available and not skills:Use(1,201,101))
data.Phase='battle';adventure.battle.data.ActiveId=2
assert(not skills:Use(1,201,101),'A future shared skill bar must respect initiative')
adventure.battle.data.ActiveId=1
function adventure.battle:CanUseSkill(skillId,targetId) assert(skillId==201 and targetId==101);return true end
function adventure:BattleCommand(command,skillId,targetId) assert(command=='skill' and skillId==201 and targetId==101);calls=calls+1;return true end
assert(skills:Use(1,201,101) and calls==2)
print('PASS selection, owned-skill filtering, cooldown reasons, phase gates and shared battle command dispatch')
