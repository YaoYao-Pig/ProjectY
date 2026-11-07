local L=require('Language')
local Rules={};Rules.__index=Rules
local function state()return CS.ProjectY.Data.TitleState end
local targets={kill='CombatUnitTable',legend='LegendaryEncounterTable',mission='MissionTable',quest='QuestTable',town='TownMissionTable'}
function Rules.New(config)
    local self=setmetatable({config=config,definitions=config:GetTable('TitleTable'),requirements=config:GetTable('TitleRequirementTable'),
        attributes=config:GetTable('GrowthAttributeTable'),bonuses={},customCache=setmetatable({},{__mode='k'}),
        forge=require('Game.Progression.TitleForgeRules').New(config)},Rules)
    for _,row in ipairs(self.requirements:All())do
        assert(targets[row.kind] or row.kind=='rescue','Unknown title requirement: '..row.kind)
        assert(row.targetId>=0 and row.required>0,'Invalid title requirement')
        if row.kind=='rescue' then assert(row.targetId==0,'Rescue titles use the personal rescue count')
        elseif row.targetId>0 then config:GetTable(targets[row.kind]):Get(row.targetId)end
    end
    for _,row in ipairs(self.definitions:All())do
        assert(#row.requirementIds>0 and (row.mode=='all' or row.mode=='any'),'Title needs all/any requirements')
        local seen={};for _,id in ipairs(row.requirementIds)do self.requirements:Get(id);assert(not seen[id],'Repeated title requirement');seen[id]=true end
        assert(#row.attributeIds==#row.attributeValues,'Title attribute arrays differ')
        local bonus={}
        for i,id in ipairs(row.attributeIds)do
            local name=self.attributes:Get(id).code
            assert(bonus[name]==nil,'Duplicate title attribute');bonus[name]=row.attributeValues[i]
        end
        self.bonuses[row.id]=bonus
    end
    return self
end
function Rules:Bonus(actor,name)
    local id=state().Equipped(actor)
    if id<0 then return self:Custom(actor,id).bonuses[name] or 0 end
    return id==0 and 0 or (assert(self.bonuses[id],'Unknown equipped title')[name] or 0)
end
function Rules:Custom(actor,id)
    local entries=self.customCache[actor]
    if not entries then entries={};self.customCache[actor]=entries end
    if not entries[id] then entries[id]=self.forge:Read(actor,id)end
    return entries[id]
end
function Rules:Equipped(actor)
    local id=state().Equipped(actor)
    return id<0 and self:Custom(actor,id) or id>0 and self.definitions:Get(id) or nil
end
function Rules:Effect(actor,kind)
    local id=state().Equipped(actor)
    return id<0 and (self:Custom(actor,id).effects[kind] or 0) or 0
end
function Rules:Progress(actor,requirement,bonds)
    if requirement.kind=='rescue' then return bonds:RescueCount(actor.Id)end
    return state().Counter(actor,requirement.kind..':'..requirement.targetId)
end
function Rules:Eligible(actor,row,bonds)
    local passed=0
    for _,id in ipairs(row.requirementIds)do
        local requirement=self.requirements:Get(id)
        if self:Progress(actor,requirement,bonds)>=requirement.required then passed=passed+1 end
    end
    return row.mode=='all' and passed==#row.requirementIds or row.mode=='any' and passed>0
end
function Rules:Rows(actor,bonds)
    local rows={};local current=state().Equipped(actor)
    for i=0,state().CustomCount(actor)-1 do
        local id=state().CustomAt(actor,i);local row=self:Custom(actor,id)
        rows[#rows+1]={id=id,title=string.format(L.TitleListEntry,row.name,current==id and L.TitleEquipped or L.TitleOwned),
            body=string.format(L.TitleForgeOwnedDescription,state().CustomCost(actor,id),row.description),owned=true,equipped=current==id,color='805723'}
    end
    for _,row in ipairs(self.definitions:All())do
        local owned=state().Owns(actor,row.id);local details={row.description,'',row.mode=='all' and L.TitleAllRequirements or L.TitleAnyRequirements}
        for _,id in ipairs(row.requirementIds)do
            local requirement=self.requirements:Get(id)
            details[#details+1]=string.format(L.TitleRequirementProgress,requirement.description,self:Progress(actor,requirement,bonds),requirement.required)
        end
        details[#details+1]='';details[#details+1]=L.TitleBonusHeading
        for i,id in ipairs(row.attributeIds)do details[#details+1]=string.format(L.TitleAttributeBonus,self.attributes:Get(id).name,row.attributeValues[i])end
        if row.damagePercent~=0 then details[#details+1]=string.format(L.TitleAttackBonus,row.damagePercent)end
        if row.moraleMaximum~=0 then details[#details+1]=string.format(L.TitleMoraleBonus,row.moraleMaximum)end
        rows[#rows+1]={id=row.id,title=string.format(L.TitleListEntry,row.name,current==row.id and L.TitleEquipped or owned and L.TitleOwned or L.TitleLocked),
            body=table.concat(details,'\n'),owned=owned,equipped=current==row.id,color=owned and '805723' or '596459'}
    end
    return rows
end
function Rules:ValidateSaved(actor)
    for i=0,state().Count(actor)-1 do self.definitions:Get(state().At(actor,i))end
    for i=0,state().CustomCount(actor)-1 do self:Custom(actor,state().CustomAt(actor,i))end
    for i=0,state().CounterCount(actor)-1 do
        local key=state().CounterKeyAt(actor,i);local kind,id=key:match('^([a-z]+):(%d+)$');id=tonumber(id)
        assert(kind and targets[kind] and id,'Unknown saved title counter')
        if id>0 then self.config:GetTable(targets[kind]):Get(id)end
    end
end
return Rules
