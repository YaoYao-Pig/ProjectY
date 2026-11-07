local L=require('Language')
-- Special skills retain ordinary CombatSkill identities; this module only owns acquisition rules.
local Rules={};Rules.__index=Rules
local function integer(value)
    return type(value)=='number' and value>=-2147483648 and value<=2147483647 and value==math.floor(value)
end
local function finite(value)
    return type(value)=='number' and value==value and value>-math.huge and value<math.huge
end
local function contains(values,id)
    for _,value in ipairs(values)do if value==id then return true end end
    return false
end
function Rules.New(config)
    local self=setmetatable({skills=config:GetTable('CombatSkillTable'),units=config:GetTable('CombatUnitTable'),
        npcs=config:GetTable('NpcTable'),bySkill={},byTemplate={},byActor={},attributeByCode={}},Rules)
    for _,row in ipairs(config:GetTable('GrowthAttributeTable'):All())do
        assert(type(row.code)=='string' and row.code~='' and not self.attributeByCode[row.code],'Invalid special skill attribute registry')
        self.attributeByCode[row.code]=row
    end
    local courses={}
    for _,row in ipairs(config:GetTable('ProfessionSkillTable'):All())do courses[row.skillId]=true end
    for _,row in ipairs(config:GetTable('SpecialSkillTable'):All())do
        assert(integer(row.id) and row.id>0 and not self.bySkill[row.id],'Invalid or duplicate special skill')
        local skill=self.skills:Get(row.id)
        assert(skill.skillKind=='active' and contains(skill.contexts,'battle'),'Special skills must be battle active skills')
        assert(not courses[row.id],'Special skills cannot belong to profession courses')
        assert(type(row.teachable)=='boolean' and type(row.reteachable)=='boolean','Invalid special skill teaching flags')
        assert(integer(row.relationMinimum),'Invalid special skill relationship requirement')
        assert(#row.attributeNames==#row.attributeValues,'Special skill attribute arrays differ')
        local seen={}
        for i,name in ipairs(row.attributeNames)do
            assert(self.attributeByCode[name] and not seen[name],'Invalid or duplicate special skill requirement attribute')
            assert(integer(row.attributeValues[i]) and row.attributeValues[i]>=0,'Invalid special skill attribute requirement')
            seen[name]=true
        end
        assert(self.attributeByCode[row.observationAttribute],'Unknown special skill observation attribute')
        assert(integer(row.observationMinimum) and row.observationMinimum>=0,'Invalid special skill observation minimum')
        assert(finite(row.observationBaseChance) and row.observationBaseChance>=0 and row.observationBaseChance<=1,'Invalid special skill observation base chance')
        assert(finite(row.observationPerPoint) and row.observationPerPoint>=0,'Invalid special skill observation increase')
        assert(finite(row.observationMaxChance) and row.observationMaxChance>=row.observationBaseChance and row.observationMaxChance<=1,'Invalid special skill observation maximum')
        self.bySkill[row.id]=row
    end
    local holderIds={}
    for _,row in ipairs(config:GetTable('SpecialSkillHolderTable'):All())do
        assert(integer(row.id) and row.id>0 and not holderIds[row.id],'Invalid or duplicate special skill holder id')
        holderIds[row.id]=true
        assert(integer(row.unitTemplateId) and row.unitTemplateId>=0 and integer(row.npcId) and row.npcId>=0,'Invalid special skill holder reference')
        assert((row.unitTemplateId>0)~=(row.npcId>0),'Special skill holder requires exactly one unit template or NPC')
        local index,key
        if row.unitTemplateId>0 then
            self.units:Get(row.unitTemplateId);index,key=self.byTemplate,row.unitTemplateId
        else
            assert(row.npcId<=89999,'Special skill NPC id exceeds authored actor identity range')
            local npc=self.npcs:Get(row.npcId);self.units:Get(npc.actorTemplateId)
            index,key=self.byActor,10000+row.npcId
        end
        assert(not index[key],'Duplicate special skill holder target')
        local seen={}
        for _,id in ipairs(row.skillIds)do
            assert(self.bySkill[id] and not seen[id],'Unknown or duplicate held special skill')
            seen[id]=true
        end
        index[key]=row
    end
    return self
end
function Rules:InitialSkills(actor)
    local result,seen={},{}
    local function append(ids)
        for _,id in ipairs(ids)do
            if self.bySkill[id] and not seen[id]then result[#result+1]=id;seen[id]=true end
        end
    end
    append(self.units:Get(actor.TemplateId).skillIds)
    local template=self.byTemplate[actor.TemplateId]
    if template then append(template.skillIds)end
    local npc=self.byActor[actor.Id]
    if npc and self.npcs:Get(npc.npcId).actorTemplateId==actor.TemplateId then append(npc.skillIds)end
    table.sort(result)
    return result
end
function Rules:IsOriginal(actor,id)
    if not self.bySkill[id]then return false end
    if contains(self.units:Get(actor.TemplateId).skillIds,id)then return true end
    local template=self.byTemplate[actor.TemplateId]
    if template and contains(template.skillIds,id)then return true end
    local npc=self.byActor[actor.Id]
    return npc~=nil and self.npcs:Get(npc.npcId).actorTemplateId==actor.TemplateId and contains(npc.skillIds,id)
end
function Rules:Owns(actor,id)
    return self:IsOriginal(actor,id) or actor.Growth:HasSkill(id)
end
function Rules:Requirements(actor,id,stats)
    local row=assert(self.bySkill[id],'Unknown special skill')
    for i,name in ipairs(row.attributeNames)do
        if stats:Get(actor,name,true)<row.attributeValues[i]then
            return false,string.format(L.SpecialSkillAttributeRequired,self.attributeByCode[name].name,row.attributeValues[i])
        end
    end
    return true,L.SpecialSkillRequirementsMet
end
function Rules:ObservationChance(actor,id,stats)
    local row=assert(self.bySkill[id],'Unknown special skill')
    if not self:Requirements(actor,id,stats)then return 0 end
    local value=stats:Get(actor,row.observationAttribute,true)
    if value<row.observationMinimum then return 0 end
    return math.max(0,math.min(row.observationMaxChance,row.observationBaseChance+(value-row.observationMinimum)*row.observationPerPoint))
end
function Rules:Description(id,stats)
    local row=assert(self.bySkill[id],'Unknown special skill')
    local parts={L.SpecialSkillSource}
    for i,name in ipairs(row.attributeNames)do
        parts[#parts+1]=string.format(L.SpecialSkillAttributeRequired,self.attributeByCode[name].name,row.attributeValues[i])
    end
    parts[#parts+1]=row.teachable and string.format(L.SpecialSkillTeachingRule,row.relationMinimum,
        row.reteachable and L.SpecialSkillReteachable or L.SpecialSkillOriginalOnly) or L.SpecialSkillCannotTeach
    parts[#parts+1]=string.format(L.SpecialSkillObserveRule,self.attributeByCode[row.observationAttribute].name,
        row.observationMinimum,row.observationBaseChance*100,row.observationPerPoint*100,row.observationMaxChance*100)
    parts[#parts+1]=L.SpecialSkillObserveBasis
    return table.concat(parts,'\n')
end
return Rules
