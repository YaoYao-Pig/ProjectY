-- Deterministic casting and recruitment gates. Persistent facts belong to PeopleData.
local Rules={};Rules.__index=Rules
function Rules.New(config)
    local self=setmetatable({profiles=config:GetTable('PeopleProfileTable'),names=config:GetTable('PeopleNameTable'),
        mappings=config:GetTable('UnitInspectionNpcTable')},Rules)
    self.byResident={}
    for _,row in ipairs(self.profiles:All())do
        assert(row.id>=1 and row.id<=4 and row.fee>=0 and row.mentorSkills>=0 and row.victories>=0,'Invalid person profile')
        for _,id in ipairs(row.residentTemplateIds)do
            self.mappings:Get(id)
            local pool=self.byResident[id] or {};self.byResident[id]=pool;pool[#pool+1]=row.id
        end
    end
    for id=1,4 do self.profiles:Get(id)end
    assert(self.names.Count>=12,'People need at least twelve configured names')
    return self
end
function Rules.Hash(seed,siteId,residentId)
    return ((seed ~ (siteId*73856093) ~ (residentId*19349663)) & 0x7fffffff)
end
function Rules:Cast(seed,siteId,residentId,templateId)
    local pool=assert(self.byResident[templateId],'Resident has no recruitment profile')
    local hash=Rules.Hash(seed,siteId,residentId)
    local names=self.names:All()
    return pool[hash%#pool+1],names[(hash//7)%#names+1].id
end
function Rules.FreeResident(definition)
    return not definition.narrativeId and not definition.facilityId and not definition.dockId and
        definition.stableId~=nil and definition.stableId>=100000
end
function Rules:Routes(profile,facts)
    assert(facts.trust and facts.helped and facts.townHelped and facts.mentorSkills and facts.victories and facts.level,'Incomplete recruitment facts')
    if profile.kind=='livelihood' then return {{id=1,ready=facts.coins>=profile.fee,cost=profile.fee,gate='coins'},
        {id=2,ready=facts.helped>0 or facts.trust>=profile.trustRequired,cost=0,gate='help'}} end
    if profile.kind=='apprentice' then return {{id=1,ready=facts.mentorSkills>=profile.mentorSkills,cost=0,gate='mentor'},
        {id=2,ready=facts.helped>0 and facts.coins>=profile.fee,cost=profile.fee,gate='sponsor'}} end
    if profile.kind=='guardian' then return {{id=1,ready=facts.townHelped>0,cost=0,gate='town'},
        {id=2,ready=facts.bondJoined==true and facts.trust>=profile.trustRequired,cost=0,gate='bond'}} end
    assert(profile.kind=='respect','Unknown recruitment motive')
    return {{id=1,ready=facts.victories>=profile.victories and facts.level>=facts.targetLevel and facts.coins>=profile.fee,
        cost=profile.fee,gate='respect'}}
end
return Rules
