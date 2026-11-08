local L=require('Language')
local Rules={};Rules.__index=Rules
local runtimeBase=1000000000
local function state()return CS.ProjectY.Data.SkillCraftState end
local function copy(row)local result={};for k,v in pairs(row)do result[k]=v end;return result end
local function array(values)local result={};for i=0,values.Length-1 do result[#result+1]=values[i]end;return result end
function Rules.IsCustom(id)return type(id)=='number' and id>=runtimeBase end
function Rules.New(config,professions)
    local self=setmetatable({skills=config:GetTable('CombatSkillTable'),effects=config:GetTable('CombatEffectTable'),
        bodies=config:GetTable('SkillCraftBodyTable'),modifiers=config:GetTable('SkillCraftModifierTable'),
        policy=config:GetTable('SkillCraftRuleTable'):Get(1),professions=professions,cache=setmetatable({},{__mode='k'})},Rules)
    self.maximum=(self.policy.masteryLevel-1)*self.policy.practicePerLevel
    for _,skill in ipairs(self.skills:All())do assert(skill.id<runtimeBase,'Static skill ID overlaps runtime handles')end
    for _,row in ipairs(self.bodies:All())do
        local skill=self.skills:Get(row.id)
        assert(professions.bySkill[row.id] and skill.target=='enemy' and skill.shots==1 and not skill.selectBodyPart,'Unsupported craft body')
        for _,id in ipairs(skill.effectIds)do local effect=self.effects:Get(id)
            assert(effect.kind=='damage' or effect.kind=='apply_buff','Craft body requires ordinary damage/status effects')
        end
    end
    for _,row in ipairs(self.modifiers:All())do
        assert(professions.bySkill[row.skillId],'Craft material must have a profession course')
        if row.kind=='status' then assert(self.effects:Get(row.effectId).kind=='apply_buff' and row.damageType=='','Invalid craft status')
        else assert(row.effectId==0 and (row.damageType=='fire' or row.damageType=='water'),'Invalid craft element')end
    end
    return self
end
function Rules:Progress(actor,professionId)
    local points=math.min(self.maximum,state().Points(actor,professionId))
    return math.min(self.policy.masteryLevel,1+math.floor(points/self.policy.practicePerLevel)),points
end
function Rules:ProgressText(actor,professionId)
    local level,points=self:Progress(actor,professionId)
    return string.format(level>=self.policy.masteryLevel and L.SkillCraftMastered or L.SkillCraftProgress,
        self.professions.professions:Get(professionId).name,level,
        math.floor((points%self.policy.practicePerLevel)*100/self.policy.practicePerUse)/100,self.policy.practicePerLevel/self.policy.practicePerUse)
end
function Rules:Origins(actor,skillId,mastered)
    local result={}
    if not actor.Growth:HasSkill(skillId)then return result end
    for _,course in ipairs(self.professions.bySkill[skillId] or {})do
        if actor.Growth:HasProfession(course.professionId) and (not mastered or self:Progress(actor,course.professionId)>=self.policy.masteryLevel)then
            result[#result+1]=course.professionId
        end
    end
    table.sort(result);return result
end
function Rules:Eligible(actor,skillId,professionId)
    for _,id in ipairs(self:Origins(actor,skillId,true))do if id==professionId then return true end end
    return false
end
function Rules:Recipe(actor,id)
    local saved=state().Find(actor,id)
    if not saved then return nil end
    return {id=id,bodyId=saved.bodyId,bodyProfessionId=saved.bodyProfessionId,name=saved.name,
        modifierIds=array(saved.modifierIds),modifierProfessionIds=array(saved.modifierProfessionIds)}
end
function Rules:Compile(actor,recipe)
    local body=self.bodies:Find(recipe.bodyId)
    if not body or not self:Eligible(actor,recipe.bodyId,recipe.bodyProfessionId)then return nil,L.SkillCraftBodyLocked end
    if #recipe.modifierIds<1 or #recipe.modifierIds>self.policy.maxModifiers or #recipe.modifierIds~=#recipe.modifierProfessionIds then return nil,L.SkillCraftSlots end
    local skill=copy(self.skills:Get(body.id));skill.effectIds={};local buffs={};local seen={};local element
    for _,id in ipairs(self.skills:Get(body.id).effectIds)do skill.effectIds[#skill.effectIds+1]=id
        local effect=self.effects:Get(id);if effect.kind=='apply_buff' then buffs[effect.buffId]=true end
    end
    skill.craftCastingCost=0;skill.craftParts={};skill.visualSkillId=body.id;local details={}
    for i,id in ipairs(recipe.modifierIds)do
        local row=self.modifiers:Find(id)
        if not row or not self:Eligible(actor,row.skillId,recipe.modifierProfessionIds[i])then return nil,L.SkillCraftModifierLocked end
        if seen[id]then return nil,L.SkillCraftConflict end;seen[id]=true
        if row.kind=='element' then
            if element then return nil,L.SkillCraftConflict end
            element=row.damageType;skill.craftDamageType=element;skill.visualSkillId=row.skillId
        else
            local buff=self.effects:Get(row.effectId).buffId
            if buffs[buff]then return nil,L.SkillCraftConflict end
            buffs[buff]=true;skill.effectIds[#skill.effectIds+1]=row.effectId
        end
        skill.cost=skill.cost+row.apCost;skill.cooldownTurns=skill.cooldownTurns+row.cooldown
        skill.craftCastingCost=skill.craftCastingCost+row.castingCost;skill.craftParts[#skill.craftParts+1]=row.name
        details[#details+1]=row.description
    end
    if buffs[10004] and buffs[12019] or element=='fire' and buffs[12019] or element=='water' and buffs[10004] then return nil,L.SkillCraftConflict end
    -- Added effects share the body's one damage budget; broad attacks pay per extra recipient.
    skill.craftWide=skill.maxTargets>1 or skill.splashRadius>0
    if skill.craftWide then skill.cost=skill.cost+1;skill.damageScale=skill.damageScale*.8 end
    skill.id=recipe.id or 0;skill.sourceSkillId=body.id;skill.crafted=true
    skill.name=require('Game.Presentation.SkillTipCatalog').Escape(recipe.name or '')
    skill.description=string.format(L.SkillCraftDescription,skill.name,self.skills:Get(body.id).name,table.concat(skill.craftParts,L.SkillCraftSeparator))
    skill.description=string.format(L.SkillCraftEffectDetails,skill.description,self.skills:Get(body.id).description,table.concat(details,'\n'))
    skill.opportunityAttack=false;skill.contexts={'battle'};skill.affectsContainers=false
    return skill
end
function Rules:Cache(actor)
    local revision=state().Revision(actor);local cache=self.cache[actor]
    if not cache or cache.revision~=revision or cache.growthRevision~=actor.Growth.Revision then
        cache={revision=revision,growthRevision=actor.Growth.Revision,definitions={}};self.cache[actor]=cache
    end
    return cache
end
function Rules:FindDefinition(actor,id)
    if not Rules.IsCustom(id)then return self.skills:Find(id)end
    local cache=self:Cache(actor)
    local entry=cache.definitions[id]
    if not entry then
        local recipe=self:Recipe(actor,id);local definition,reason
        if recipe then definition,reason=self:Compile(actor,recipe)else reason=L.SkillCraftUnknown end
        entry={definition=definition,reason=reason};cache.definitions[id]=entry
    end
    return entry.definition,entry.reason
end
function Rules:Definition(actor,id)
    local definition,reason=self:FindDefinition(actor,id)
    return assert(definition,reason or 'Unknown skill definition')
end
function Rules:AddSkills(actor,ids)
    local cache=self:Cache(actor)
    if not cache.ids then
        cache.ids={}
        for i=0,state().Count(actor)-1 do
            local saved=state().At(actor,i);local id=runtimeBase+saved.id
            if self:FindDefinition(actor,id)then cache.ids[#cache.ids+1]=id end
        end
    end
    for _,id in ipairs(cache.ids)do ids[#ids+1]=id end
    return ids
end
function Rules:CaptureUse(actor,id,phase)
    if not actor or not actor.Growth.Initialized or phase~='combat' then return nil end
    local origins={}
    if Rules.IsCustom(id)then
        local recipe=assert(self:Recipe(actor,id));local found={[recipe.bodyProfessionId]=true}
        for _,p in ipairs(recipe.modifierProfessionIds)do found[p]=true end
        for p in pairs(found)do origins[#origins+1]=p end;table.sort(origins)
    else origins=self:Origins(actor,id,false)end
    return #origins>0 and {actor=actor,origins=origins} or nil
end
function Rules:CommitUse(use)
    if use then state().Practice(use.actor,use.origins,self.policy.practicePerUse,self.maximum)end
end
function Rules:Save(actor,phase,recipe)
    if phase~='map' and phase~='area' then return false,L.SkillCraftExploreOnly end
    if type(recipe)~='table' or type(recipe.modifierIds)~='table' or type(recipe.modifierProfessionIds)~='table' then return false,L.SkillCraftSlots end
    local name=recipe.name
    if type(name)~='string' or #name>128 or name:find('[%c]') or name:match('^%s*$') or not utf8.len(name) or utf8.len(name)>32 then return false,L.SkillCraftNameInvalid end
    local units=0;for _,code in utf8.codes(name)do units=units+(code>65535 and 2 or 1)end
    if units>32 then return false,L.SkillCraftNameInvalid end
    local skill,reason=self:Compile(actor,recipe);if not skill then return false,reason end
    local function signature(r)
        local ids={};for _,id in ipairs(r.modifierIds)do ids[#ids+1]=id end;table.sort(ids)
        return r.bodyId..':'..table.concat(ids,',')
    end
    local signatureKey=signature(recipe)
    for i=0,state().Count(actor)-1 do local saved=state().At(actor,i);local id=runtimeBase+saved.id
        if id~=(recipe.id or 0) and signature(self:Recipe(actor,id))==signatureKey then return false,L.SkillCraftDuplicate end
    end
    if (recipe.id or 0)==0 and state().Count(actor)>=128 then return false,L.SkillCraftFull end
    if (recipe.id or 0)>0 and not self:Recipe(actor,recipe.id)then return false,L.SkillCraftUnknown end
    local id=state().Save(actor,recipe.id or 0,name,recipe.bodyId,recipe.bodyProfessionId,recipe.modifierIds,recipe.modifierProfessionIds)
    return true,L.SkillCraftSaved,id
end
return Rules
