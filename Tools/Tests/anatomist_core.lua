-- Production command/shot/selection rules with real content; only actor state and effect application cross a fake C# boundary.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local f=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=f:read('*a');f:close();return bytes
end}})
local function copy(row)local result={};for k,v in pairs(row)do result[k]=v end;return result end
local visual={Source=function(a)return a end,Skill=function()end}
package.loaded['Game.Presentation.VisualEffects']=visual
local Battle=require('Game.Battle.BattleSystem')
local Shots=require('Game.Battle.ProjectileCombat')
local Injury=require('Game.Battle.InjuryRules')
local Profession=require('Game.Battle.ProfessionCombat')
local skills=config:GetTable('CombatSkillTable')
local anatomy=skills:Get(2601)
assert(anatomy.selectBodyPart and anatomy.cost==skills:Get(1).cost and anatomy.effectIds[1]==skills:Get(1).effectIds[1])
assert(config:GetTable('ProfessionTable'):Get(15).initialSkillIds[1]==2601)
assert(config:GetTable('ProfessionSkillTable'):Get(1502601).skillId==2601)
assert(config:GetTable('TalentNodeTable'):Get(2605).passiveId==2605)
assert(config:GetTable('SkillAtlasTable'):Get(2601).categoryId==18)
assert(config:GetTable('SkillDescriptionTable'):Get(2601).body~='')
local state={MaximumHP=function(a,i)return a.disabled==i and 0 or 20 end}
CS={ProjectY={Data={BodyHealth=state,DeathDoorState={Alive=function(a)return a.HP>0 end}}}}
local source={Id=1,Team=1,Q=0,R=0,HP=100,MaxHP=100,AP=10,TraitCount=0,AnimalOwnerId=0}
local target={Id=2,Team=2,Q=1,R=0,HP=100,MaxHP=100,AnimalOwnerId=0,bodyInjuries=true}
local other={Id=3,Team=2,Q=2,R=0,HP=100,MaxHP=100,AnimalOwnerId=0,bodyInjuries=false}
local parts=config:GetTable('BodyPartTable'):All()
local rolls,draws,hitParts,usedSkill,paid,events={},0,{},nil,0,0
local learned=false
source.Growth={TalentCount=1,GetTalentAt=function()return 2605 end,GetRank=function()return learned and 1 or 0 end}
function source:SpendAction(_,cost)self.AP=self.AP-cost;paid=paid+1 end
function source:SetCooldown()end
function source:RecordAction()end
local battle=Battle()
battle.skills=skills
battle.data={ActiveId=1,Phase='combat',Winner='',RollPercent=function()draws=draws+1;return assert(rolls[draws],'Unexpected draw '..draws)end}
battle.board=require('Game.Battle.BattleBoard').Create(4,1,0)
battle.stats={injuries=setmetatable({parts=parts},{__index=Injury}),growth={nodes=config:GetTable('TalentNodeTable'),passives=config:GetTable('PassiveSkillTable')},
    Template=function(_,a)return {name='unit-'..a.Id,bodyInjuries=a==source or a.bodyInjuries}end,
    animals={bySkill={},rule={tameSkillId=999},Distance=function()return 1 end},
    equipment={Skill=function(_,_,id)return copy(skills:Get(id))end},
    buffs={ApplySkillModifiers=function(_,_,skill)return skill end}}
battle.morale={Skill=function(_,_,skill)return skill end}
battle.spellcasting={Resolve=function(_,_,skill)return skill end,UseRecovery=function()end}
battle.beasts={Handles=function()return false end,OnHit=function()end}
battle.professions={battle=battle,rows=config:GetTable('ProfessionCombatTable'),HasPassive=Profession.HasPassive,
    Skill=function(_,_,skill)return skill end,CanUse=function()return true end,Commit=function()end,ConsumeEquipment=function()end,
    PrepareProgram=function()end,Redirect=function(_,_,_,a)return a end,BeforeHit=function()return {} end,AfterHit=function()end}
function battle:FindUnit(id)return id==1 and source or id==2 and target or id==3 and other end
function battle:SkillBudget()return source.AP>=2 end
function battle:CheckWinner()return false end
function battle:Emit()end
function battle:ShotOccupancy()return {} end
battle.Changed={Emit=function()events=events+1 end}
battle.gameEffects={Prepare=function(_,id,s,t,skill)
    return {definition={id=id,kind='damage',duration='instant'},source=s,target=t,hitTarget=t,skill=skill}
end,ApplyPrepared=function(_,effect,impact)
    usedSkill=effect.skill
    local recipient=effect.target.MountedAnimal or effect.target
    if recipient.bodyInjuries then
        local hit=battle.stats.injuries:SelectHit(recipient,function()return battle.data:RollPercent()end,effect.skill.targetBodyPartIndex)
        hitParts[#hitParts+1]=hit.part.index
    end
    recipient.HP=recipient.HP-(impact.critical and 20 or 10)
end}
local function reset(values)
    source.Team=1;source.AP=10;target.HP=100;target.MountedAnimal=nil;target.disabled=nil
    rolls=values or {};draws=0;paid=0;events=0;hitParts={};usedSkill=nil;learned=false
end
reset()
local options=battle:BodyPartOptions(2601,2)
assert(#options==6 and options[1].id==0 and options[6].id==5)
assert(#battle:BodyPartOptions(1,2)==0 and #battle:BodyPartOptions(2601,3)==0)
assert(not battle:TrySkill(2601,2) and source.AP==10 and draws==0 and paid==0 and events==0)
for _,invalid in ipairs({-1,6,1.5,'2'})do assert(not battle:TrySkillBodyPart(2601,2,invalid))end
assert(not battle:TrySkillBodyPart(1,2,0))
assert(not battle:TrySkillBodyPart(2601,3,0) and source.AP==10 and draws==0)
target.MountedAnimal=other
assert(not battle:CanUseSkill(2601,2) and #battle:BodyPartOptions(2601,2)==0)
target.MountedAnimal=nil;target.disabled=3
assert(#battle:BodyPartOptions(2601,2)==5 and not battle:TrySkillBodyPart(2601,2,3))
assert(not battle:TrySkill(2601,2,{2,3},nil,2) and source.AP==10)
print('PASS body selection, target restrictions, invalid commands and zero-cost cancellation')
for i=0,5 do
    reset();assert(battle:TrySkillBodyPart(2601,2,i))
    assert(hitParts[1]==i and draws==0 and paid==1 and source.AP==8 and events==1)
    assert(usedSkill.targetBodyPartIndex==i and skills:Get(2601).targetBodyPartIndex==nil)
    assert(battle:Skill(source,2601).targetBodyPartIndex==nil,'Selected part leaked into another action')
end
reset();source.Team=2;target.Team=1
assert(battle:TrySkill(2601,2) and hitParts[1]==3 and paid==1)
target.Team=2
local originalSkill=battle.Skill
function battle:Skill(actor,id)local skill=originalSkill(self,actor,id);skill.hitChance=50;return skill end
reset({99});assert(battle:TrySkillBodyPart(2601,2,2))
assert(draws==1 and #hitParts==0 and target.HP==100 and source.AP==8 and paid==1,'A miss still consumes the legal action without hitting a part')
battle.Skill=originalSkill
print('PASS every selected part, immutable skill data, AI targeting and normal miss cost')
local criticalSkill=copy(anatomy);criticalSkill.selectBodyPart=false;criticalSkill.criticalChance=0
reset();learned=true
assert(Shots.CriticalChance(battle,source,other,criticalSkill)==25)
assert(Shots.CriticalChance(battle,source,target,criticalSkill)==0)
learned=false;assert(Shots.CriticalChance(battle,source,other,criticalSkill)==0)
learned=true;criticalSkill.criticalChance=90
assert(Shots.CriticalChance(battle,source,other,criticalSkill)==100 and criticalSkill.criticalChance==90)
local lastCritical,lastChance
battle.checks=function(_,recipient,_,_,chance,_,critical)lastCritical=critical;lastChance=chance;assert(recipient==other)end
local function applyCrit(value,base,mounted)
    reset(value and {value} or {});learned=true;criticalSkill.criticalChance=base
    other.HP=100;target.MountedAnimal=mounted and other or nil
    local receiver=mounted and target or other
    local p={battle.gameEffects:Prepare(1,source,receiver,criticalSkill)}
    Shots.ApplyActor(battle,source,p,{shot=1})
end
applyCrit(24,0,false);assert(lastCritical and lastChance==25 and draws==1)
applyCrit(25,0,false);assert(not lastCritical and draws==1)
applyCrit(nil,90,false);assert(lastCritical and lastChance==100 and draws==0)
applyCrit(24,0,true);assert(lastCritical and lastChance==25 and draws==1)
reset({24});learned=true;criticalSkill.criticalChance=0
battle.professions.Redirect=function()return other end
local actual=Shots.ApplyActor(battle,source,{battle.gameEffects:Prepare(1,source,target,criticalSkill)},{shot=1})
assert(actual==other and lastCritical and lastChance==25 and draws==1,'A redirect uses the actual receiver for xenologist')
print('PASS learned-only xenologist, actual recipient/mount/redirect, 25-point boundary, cap and one critical draw')

local lookup,dropped,reported=0,0,0
battle.stats.equipment.HasDisabledHandEquipment=function()return false end
battle.context={systems={Get=function()error('Healthy actor must not request MapArea or loot services')end}}
battle:DropInjuredEquipment(source)
battle.stats.equipment.HasDisabledHandEquipment=function()return true end
battle.data.Phase='idle';battle:DropInjuredEquipment(source)
battle.data.Phase='combat'
local map={}
local equipment={worldLoot={DropInjuredHands=function(_,area,actor,stats)
    assert(area==map and actor==source and stats==battle.stats);dropped=dropped+1;return {'item'}
end}}
battle.context.systems.Get=function(_,name)lookup=lookup+1;return name=='Equipment' and equipment or map end
battle.Emit=function(_,kind)assert(kind=='injury_equipment_dropped');reported=reported+1 end
battle:DropInjuredEquipment(source)
assert(lookup==2 and dropped==1 and reported==1)
print('PASS injury drop phase/health guards and real loot delegation')
