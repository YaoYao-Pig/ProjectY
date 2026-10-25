-- Actual battle/area entry points with in-memory state adapters; no Editor or saved player data.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
CS={ProjectY={Data={AnimalCompanionState={Bound=function(source)return source.MountedAnimal end},AnimalSpeechState={
    Modifier=function(target)return target.modifier end,
    Consume=function(target)target.consumed=target.consumed+1;target.modifier=0 end}}}}
local animals=require('Game.Animals.AnimalRules').New(config)
local skill=config:GetTable('CombatSkillTable'):Get(animals.rule.tameSkillId)
local Battle=require('Game.Battle.BattleSystem')
local Area=require('Game.MapArea.MapAreaSystem')
local function fixture(success)
    local source={Id=1,TemplateId=1,Team=1,HP=40,AP=10,Q=1,R=1,animalAffinity=5,charisma=3,spent=0,cooldowns=0}
    local target={Id=2,TemplateId=201,Team=0,HP=40,MaxHP=40,Q=2,R=1,AnimalOwnerId=0,TameRetryTurns=0,modifier=15,draws=0,consumed=0}
    function target:RollAnimalPercent()self.draws=self.draws+1;return success and self.draws==2 and 4299 or 9999 end
    function target:DelayTaming(turns)self.TameRetryTurns=turns end
    function source:TameAndRide(animal)assert(animal==target);self.MountedAnimal=animal;animal.AnimalOwnerId=self.Id end
    function source:SpendAction(action,cost)assert(action==skill.action);self.spent=self.spent+1;self.AP=self.AP-cost end
    function source:SetCooldown(id,turns)assert(id==skill.id and turns==skill.cooldownTurns);self.cooldowns=self.cooldowns+1 end
    local stats={animals=animals,Get=function(_,actor,attribute)return actor[attribute]end,
        Template=function(_,actor)return config:GetTable('CombatUnitTable'):Get(actor.TemplateId)end}
    return source,target,stats
end
for _,success in ipairs({true,false})do
    local source,target,stats=fixture(success)
    local checks,commits={},0
    local battle=setmetatable({stats=stats,beasts={Handles=function()return false end},
        professions={rows={Find=function()end},Commit=function()commits=commits+1 end}}, {__index=Battle})
    function battle:CanUseSkill()return animals:CanTame(source,target)end
    function battle:Active()return source end
    function battle:FindUnit(id)assert(id==target.Id);return target end
    function battle:Skill()return skill end
    function battle:IsHostile()return false end
    function battle:Emit()end
    function battle:CheckWinner()end
    battle.checks=function(_,_,_,_,chance,roll,passed,details)
        checks[#checks+1]=details;assert(passed==success and details.check.passed==success)
        assert(math.abs(chance-67.51)<1e-8 and #details.check.rolls==2)
    end
    assert(battle:TrySkill(skill.id,target.Id))
    assert(#checks==1 and target.draws==2 and target.consumed==1 and source.spent==1 and source.cooldowns==1 and commits==1)
    assert(source.AP==10-skill.cost and (source.MountedAnimal==target)==success and #battle.vfxEvents==1)
    assert(not battle:TrySkill(skill.id,target.Id))
    assert(target.draws==2 and source.spent==1 and commits==1,'Rejected repeat must not spend or reroll')
end
print('PASS battle taming spends one action/cooldown, consumes once, reports both rolls and rejects repeats')
for _,success in ipairs({true,false})do
    local source,target,stats=fixture(success)
    local checks,stops,deploys,reveals={},0,0,0
    local state={MemberCount=1,Stop=function()stops=stops+1 end,GetMemberIdAt=function()return source.Id end,
        GetMemberCellAt=function()return 1 end,DeployMembers=function(_,ids,cells)
            deploys=deploys+1;assert(#ids==1 and ids[1]==source.Id and cells[1]==2)
        end}
    local layout={Find=function()return {index=2}end}
    local system=setmetatable({combatStats=stats,data={Active=state},context={systems={Get=function(_,name)
        assert(name=='AdventureEvents');return {CheckResolved={Emit=function(_,check)checks[#checks+1]=check end}}
    end}}},{__index=Area})
    function system:CanTame()return animals:CanTame(source,target)end
    function system:PartyActor(id)assert(id==source.Id);return source end
    function system:FindAnimal(id)assert(id==target.Id);return target end
    function system:ActiveLayout()return layout end
    function system:RevealSquad()reveals=reveals+1 end
    local passed,reason=system:Tame(source.Id,target.Id)
    assert(passed==success and #checks==1 and #checks[1].rounds==2 and checks[1].passed==success)
    assert(target.draws==2 and target.consumed==1 and stops==1)
    assert(deploys==(success and 1 or 0) and reveals==deploys)
    if not success then assert(reason==string.format(require('Language').AnimalSpeechTameFailed,67.51,3))end
    assert(not system:Tame(source.Id,target.Id))
    assert(#checks==1 and target.draws==2 and stops==1,'Rejected area repeat must not replay or consume')
end
print('PASS exploration taming publishes one two-round check, settles ownership/deployment once and preserves rejection')
