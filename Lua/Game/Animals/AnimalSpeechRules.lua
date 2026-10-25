-- Configuration queries only; the animal owns the pending result and random stream.
local Rules={};Rules.__index=Rules
function Rules.New(config)
    local self=setmetatable({rule=config:GetTable('AnimalSpeechRuleTable'):Get(1),
        approaches=config:GetTable('AnimalSpeechApproachTable')},Rules)
    assert(self.rule.minimumChance<=self.rule.maximumChance,'Invalid animal speech probability clamp')
    for _,row in ipairs(self.approaches:All()) do
        assert(row.successModifier>0 and row.failureModifier<0,'Animal conversation must have both outcomes')
    end
    return self
end
function Rules:Chance(source,stats,approach,hostile,legendary)
    local rule=self.rule
    local chance=rule.baseChance+stats:Get(source,'animalAffinity')*rule.affinityWeight
        +stats:Get(source,'charisma')*rule.charismaWeight+approach.chanceBonus
        +(hostile and approach.hostileBonus-rule.hostilePenalty or approach.friendlyBonus)
        -(legendary and rule.legendaryPenalty or 0)
    return math.floor(math.max(rule.minimumChance,math.min(rule.maximumChance,chance))*100)/100
end
return Rules
