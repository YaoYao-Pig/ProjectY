-- 配置解释与一次性分配；实际外观字符串归 CombatActorData，不依赖显示刷新。
local Random=require('Game.Map.SeededRandom')
local Appearance={};Appearance.__index=Appearance
local function weighted(random,ids,weights)
    assert(#ids>0 and #ids==#weights,'Appearance pool arrays differ')
    local total=0;for _,weight in ipairs(weights) do assert(weight>0,'Appearance weight must be positive');total=total+weight end
    local pick=random:Integer(1,total)
    for i,id in ipairs(ids) do pick=pick-weights[i];if pick<=0 then return id end end
    error('Appearance random value outside range')
end
function Appearance.New(config,service)
    assert(service,'Character appearance service is unavailable; compile and regenerate xLua bindings')
    local self=setmetatable({pools=config:GetTable('CharacterAppearancePoolTable'),service=service,templates={}},Appearance)
    for _,row in ipairs(config:GetTable('PawnTemplateTable'):All()) do self.templates[row.unitId]=row end
    for _,row in ipairs(self.pools:All()) do
        assert(#row.raceIds>0 and #row.raceIds==#row.raceWeights and #row.sexIds>0 and #row.sexIds==#row.sexWeights,'Invalid appearance pool: '..row.id)
        for i,race in ipairs(row.raceIds) do assert(service:HasRace(race) and row.raceWeights[i]>0,'Invalid configured race: '..race) end
        for i,sex in ipairs(row.sexIds) do assert((sex=='male' or sex=='female') and row.sexWeights[i]>0,'Invalid configured sex') end
    end
    return self
end
function Appearance:Group(poolId,seed)
    local pool=self.pools:Get(poolId);local random=Random(seed)
    return {pool=pool,random=random,race=pool.sameRace and weighted(random,pool.raceIds,pool.raceWeights) or nil}
end
function Appearance:Assign(actor,group)
    local pool,random=group.pool,group.random
    local race=group.race or weighted(random,pool.raceIds,pool.raceWeights)
    local sex=weighted(random,pool.sexIds,pool.sexWeights)
    self.service:Create(actor,random:Integer(0,2147483647),race,sex)
end
function Appearance:Party(actor,seed)
    local row=assert(self.templates[actor.TemplateId],'Party appearance template is missing')
    self:Assign(actor,self:Group(row.appearancePoolId,(seed ~ (actor.Id*104729)) & 0xffffffff))
end
return Appearance
