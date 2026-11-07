local L=require('Language')
local Rules={};Rules.__index=Rules
local kinds={attribute=true,damage_percent=true,kill_heal_percent=true,kill_morale=true,
    low_health_damage_percent=true,turn_heal_percent=true,damage_taken_percent=true}
local function state()return CS.ProjectY.Data.TitleState end
function Rules.New(config)
    local self=setmetatable({effects=config:GetTable('TitleForgeEffectTable'),policy=config:GetTable('ReputationRuleTable'):Get(1)},Rules)
    local attributes,covered={},{}
    for _,row in ipairs(config:GetTable('GrowthAttributeTable'):All())do attributes[row.code]=true end
    for _,row in ipairs(self.effects:All())do
        assert(kinds[row.kind] and row.cost>0 and row.maxRank>0 and row.amount~=0,'Invalid title forge effect')
        if row.kind=='attribute' then
            assert(attributes[row.attribute],'Unknown title attribute')
            if not row.negative then assert(row.amount>0,'Positive title attribute must increase');covered[row.attribute]=true end
        else assert(row.attribute=='' and row.amount>0,'Invalid non-attribute title effect')end
    end
    for name in pairs(attributes)do assert(covered[name],'Title forge must cover attribute: '..name)end
    return self
end
function Rules:Rows()
    local rows={}
    for _,row in ipairs(self.effects:All())do
        rows[#rows+1]={id=row.id,name=row.name,description=row.description,category=row.category,
            cost=row.cost,maxRank=row.maxRank,negative=row.negative}
    end
    return rows
end
function Rules:Quote(name,ranks)
    local result={valid=false,reason='',name='',positive=0,discount=0,cost=0,description='',serialized=''}
    if type(ranks)~='table' then result.reason=L.TitleForgeInvalidEffects;return result end
    for id,rank in pairs(ranks)do
        local row=type(id)=='number' and math.tointeger(id) and self.effects:Find(id)
        if not row or type(rank)~='number' or not math.tointeger(rank) or rank<0 or rank>row.maxRank then
            result.reason=L.TitleForgeInvalidEffects;return result
        end
    end
    local reduction,details,serialized=0,{},{}
    for _,row in ipairs(self.effects:All())do
        local rank=ranks[row.id] or 0
        if rank>0 then
            if row.negative then reduction=reduction+row.cost*rank else result.positive=result.positive+row.cost*rank end
            serialized[#serialized+1]=row.id..':'..rank
            details[#details+1]=string.format(L.TitleForgeEffectSummary,row.name,rank,row.description)
        end
    end
    result.discount=math.min(reduction,math.floor(result.positive*self.policy.discountPercent/100))
    result.cost=result.positive-result.discount;result.description=table.concat(details,'\n')
    result.serialized=table.concat(serialized,',')
    if type(name)~='string' or not state().ValidName(name) then result.reason=L.TitleForgeInvalidName;return result end
    result.name=state().NormalizeName(name)
    if result.positive==0 then result.reason=L.TitleForgeNeedPositive;return result end
    result.valid=true
    return result
end
function Rules:SavedRanks(actor,id)
    local ranks={}
    for i=0,state().EffectCount(actor,id)-1 do
        local effect=state().EffectIdAt(actor,id,i);local rank=state().EffectRankAt(actor,id,i)
        local row=self.effects:Get(effect)
        assert(rank>0 and rank<=row.maxRank and not ranks[effect],'Invalid saved title effect rank')
        ranks[effect]=rank
    end
    return ranks
end
function Rules:Read(actor,id)
    local ranks=self:SavedRanks(actor,id)
    local quote=self:Quote(state().CustomName(actor,id),ranks)
    assert(quote.valid,quote.reason)
    local result={id=id,name=quote.name,description=quote.description,damagePercent=0,moraleMaximum=0,bonuses={},effects={},custom=true}
    for effect,rank in pairs(ranks)do
        local row=self.effects:Get(effect);local amount=row.amount*rank
        if row.kind=='attribute' then result.bonuses[row.attribute]=(result.bonuses[row.attribute] or 0)+amount
        else result.effects[row.kind]=(result.effects[row.kind] or 0)+amount end
    end
    result.damagePercent=result.effects.damage_percent or 0
    return result
end
return Rules
