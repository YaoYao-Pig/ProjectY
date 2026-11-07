local Rules={};Rules.__index=Rules
function Rules.New(config)
    local self=setmetatable({settings=config:GetTable('PartyStoryRuleTable'):Get(1),stages={},
        honors=config:GetTable('PartyHonorTable'),traits=config:GetTable('CombatTraitTable')},Rules)
    local settings=self.settings
    assert(settings.rescueHealthPercent>0 and settings.rescueHealthPercent<100,'Invalid rescue health threshold')
    assert(settings.rescueBond>0 and settings.rescueBond<=100 and settings.victoryBond>0 and settings.victoryBond<=100,'Invalid bond reward')
    local removed={}
    for _,id in ipairs(settings.removeTraitIds) do self.traits:Get(id);assert(not removed[id],'Duplicate rescue trait');removed[id]=true end
    local seen={}
    for _,row in ipairs(config:GetTable('PartyBondStageTable'):All()) do
        assert(row.minimum>=-100 and row.minimum<=100 and not seen[row.minimum],'Invalid bond stage threshold')
        seen[row.minimum]=true;self.stages[#self.stages+1]=row
    end
    assert(seen[-100],'Bond stages need the lowest stage')
    assert(settings.deathDoorBond>=settings.rescueBond and settings.healBond>0 and settings.healLimit>0 and settings.cooperationLimit>0,'Invalid relationship rewards')
    assert(settings.minimumHealPercent>0 and settings.minimumHealPercent<=100 and settings.romanceMinimum>=30 and settings.romanceMinimum<=100,'Invalid relationship thresholds')
    table.sort(self.stages,function(a,b) return a.minimum<b.minimum end)
    for _,row in ipairs(self.honors:All()) do
        assert(row.counter=='rescue_count' and row.required>0,'Unknown party honor counter or threshold')
    end
    return self
end
function Rules:Stage(score)
    assert(score>=-100 and score<=100,'Invalid bond score')
    local stage=self.stages[1]
    for _,row in ipairs(self.stages) do if score>=row.minimum then stage=row else break end end
    return stage
end
function Rules:Crossed(before,after)
    local rows={}
    for _,row in ipairs(self.stages) do if before<row.minimum and after>=row.minimum then rows[#rows+1]=row end end
    return rows
end
function Rules:IsRescue(event,phase,source,target)
    if event.kind~='heal' or phase~='combat' or not source or not target or source.Id==target.Id or source.Team~=1 or target.Team~=1 then return false end
    assert(type(event.hpBefore)=='number' and type(event.hpAfter)=='number' and type(event.periodic)=='boolean','Incomplete heal metadata')
    return not event.periodic and event.amount>0 and event.hpBefore>=0 and event.hpAfter>event.hpBefore and
        event.hpBefore*100<=target.MaxHP*self.settings.rescueHealthPercent
end
function Rules:Help(event,phase,source,target,credit,debt)
    if phase~='combat' or event.kind~='heal' or not source or source.Id==target.Id or source.Team~=1 or target.Team~=1 or event.periodic then return end
    assert(type(event.hpBefore)=='number' and type(event.hpAfter)=='number','Incomplete heal metadata')
    if credit<=0 or event.hpAfter<=event.hpBefore then return end
    local effectiveBefore=event.hpBefore+debt
    if effectiveBefore==0 then return 'rescue',self.settings.deathDoorBond end
    if credit*100<target.MaxHP*self.settings.minimumHealPercent then return end
    if effectiveBefore*100<=target.MaxHP*self.settings.rescueHealthPercent then return 'rescue',self.settings.rescueBond end
    local amount=self.settings.healBond
    for _,id in ipairs(self.settings.removeTraitIds) do if target:HasTrait(id) then amount=math.max(1,amount-1);break end end
    return 'heal',amount
end
function Rules:Harm(event,target)
    local damage=event.impact and event.impact.incomingDamage or event.amount
    if damage<=0 then return end
    local penalty=math.min(self.settings.maximumHarm,math.max(self.settings.minimumHarm,math.ceil(damage*100/target.MaxHP/2)))
    if event.hpAfter==0 then penalty=self.settings.maximumHarm end
    return -penalty,math.ceil(penalty/2)
end
return Rules
