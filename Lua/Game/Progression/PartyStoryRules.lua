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
        assert(row.minimum>=0 and row.minimum<=100 and not seen[row.minimum],'Invalid bond stage threshold')
        seen[row.minimum]=true;self.stages[#self.stages+1]=row
    end
    assert(seen[0],'Bond stages need the starting stage')
    table.sort(self.stages,function(a,b) return a.minimum<b.minimum end)
    for _,row in ipairs(self.honors:All()) do
        assert(row.counter=='rescue_count' and row.required>0,'Unknown party honor counter or threshold')
    end
    return self
end
function Rules:Stage(score)
    assert(score>=0 and score<=100,'Invalid bond score')
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
    return not event.periodic and event.amount>0 and event.hpBefore>0 and event.hpAfter>event.hpBefore and
        event.hpBefore*100<=target.MaxHP*self.settings.rescueHealthPercent
end
return Rules
