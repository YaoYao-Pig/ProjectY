local L=require('Language')
local Rules={};Rules.__index=Rules
local function state()return CS.ProjectY.Data.DeathDoorState end
function Rules.New(config,stats)
    local self=setmetatable({stats=stats,rule=config:GetTable('DeathDoorRuleTable'):Get(1),attributes={}},Rules)
    local rule=self.rule;assert(rule.fullMoraleDeathPercent<=rule.emptyMoraleDeathPercent and rule.diceSides==20,'Invalid death-door odds')
    for _,id in ipairs(rule.penaltyAttributeIds)do
        local code=config:GetTable('GrowthAttributeTable'):Get(id).code
        assert(code~='vitality' and code~='endurance' and code~='courage' and not self.attributes[code],'Invalid death-door penalty attribute')
        self.attributes[code]=true
    end
    return self
end
function Rules:Penalty(actor)return math.min(self.rule.maximumPenalty,state().Survived(actor)*self.rule.penaltyPerSurvival)end
function Rules:Attribute(actor,name,value)
    return self.attributes[name] and math.max(0,math.floor(value*(100-self:Penalty(actor))/100)) or value
end
function Rules:Odds(current,maximum)
    assert(maximum>0 and current>=0 and current<=maximum,'Invalid death-door morale')
    local rule=self.rule;local chance=rule.fullMoraleDeathPercent+(rule.emptyMoraleDeathPercent-rule.fullMoraleDeathPercent)*(1-current/maximum)
    local faces=math.ceil(chance/5-1e-9)
    return faces,faces*5
end
function Rules:Resolve(effects,target,hpBefore,usedBefore,incoming,sourceId)
    if not state().Enabled(target) or state().Dead(target) or target.HP>0 or incoming<=0 then return end
    local name=self.stats:Template(target).name
    if hpBefore>0 and not usedBefore then
        effects:Notify('death_door_entered',string.format(L.DeathDoorEnteredLog,name),sourceId,target,0,false)
        return
    end
    local morale=self.stats.morale;local current,maximum=morale:Projection(target)
    local faces,chance=self:Odds(current,maximum)
    local raw=assert(effects.roll,'Death door requires an authoritative combat random stream')()
    assert(raw>=0 and raw<100 and math.tointeger(raw),'Death-door RNG must be 0..99')
    local roll=math.floor(raw/5)+1;local survived=roll>faces
    if survived then
        state().Survive(target)
        if not CS.ProjectY.Data.MoraleState.Active(target)then CS.ProjectY.Data.MoraleState.Begin(target,maximum,current,morale:Stage(current,maximum))end
        morale:Change(assert(effects.battle,'Death door requires its battle owner'),target,-math.ceil(maximum*self.rule.survivalMoraleLossPercent/100),L.DeathDoorSurvivalPressure)
    else state().Kill(target)end
    effects:Notify('death_door_check',string.format(L.DeathDoorCheckLog,name,roll,faces,chance,survived and L.DeathDoorSurvived or L.DeathDoorDied),sourceId,target,0,false,
        {checkName=string.format(L.DeathDoorCheckTitle,name),dieSides=20,roll=roll,deathFaces=faces,deathChance=chance,
         passed=survived,morale=current,moraleMaximum=maximum,penalty=self:Penalty(target),incomingDamage=incoming})
end
return Rules
