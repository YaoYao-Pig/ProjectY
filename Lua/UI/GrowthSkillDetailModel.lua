local LuaLanguage=require('Language')
local Catalog=require('Game.Presentation.SkillTipCatalog')
local Model={};Model.__index=Model

-- Highlight visible numbers without rewriting TMP attributes or overriding an
-- authored color (including the color supplied by the shared term-link catalog).
function Model.HighlightNumbers(text)
    assert(type(text)=='string','Skill detail text must be a string')
    local result={};local cursor=1;local colorDepth,boldDepth=0,0
    local function visible(value)
        return (value:gsub('(%d+)(%.?)(%d*)(%%?)',function(integer,dot,fraction,percent)
            local suffix=''
            if dot=='.' and fraction=='' then suffix='.';dot='' end
            local number=integer..dot..fraction..percent
            if boldDepth==0 then number='<b>'..number..'</b>' end
            if colorDepth==0 then number='<color=#A45C22>'..number..'</color>' end
            return number..suffix
        end))
    end
    while cursor<=#text do
        local first,last=text:find('<[^>]*>',cursor)
        if not first then result[#result+1]=visible(text:sub(cursor));break end
        result[#result+1]=visible(text:sub(cursor,first-1))
        local tag=text:sub(first,last);local lower=tag:lower()
        result[#result+1]=tag
        if lower:match('^<color[=%s]') then colorDepth=colorDepth+1
        elseif lower=='</color>' then colorDepth=math.max(0,colorDepth-1)
        elseif lower=='<b>' then boldDepth=boldDepth+1
        elseif lower=='</b>' then boldDepth=math.max(0,boldDepth-1) end
        cursor=last+1
    end
    return table.concat(result)
end

function Model.New(config)
    return setmetatable({catalog=Catalog.New(config)},Model)
end

local function condition(kind,text,met,fields)
    local row=fields or {};row.kind=kind;row.text=text;row.met=met==true
    if row.blocking==nil then row.blocking=true end
    return row
end

local function courseRoute(course,actor,stats)
    local rules=stats.growth;local growth=actor.Growth
    local name=rules.professions.professions:Get(course.professionId).name
    local rows={condition('level',string.format(LuaLanguage.GrowthSkillDetailLevel,course.minLevel,growth.Level),growth.Level>=course.minLevel,
        {required=course.minLevel,current=growth.Level})}
    local met=rows[1].met
    for i,code in ipairs(course.attributeNames) do
        local value=stats:Get(actor,code,not rules.settings.includeEquipment)
        local required=course.attributeValues[i]
        local row=condition('attribute',string.format(LuaLanguage.GrowthSkillDetailAttribute,rules.attributeByCode[code].name,required,value),value>=required,
            {attribute=code,required=required,current=value,includeEquipment=rules.settings.includeEquipment})
        rows[#rows+1]=row;met=met and row.met
    end
    return {professionId=course.professionId,name=name,current=course.professionId==growth.CurrentProfessionId,conditions=rows,met=met}
end

-- A read-only learning projection. The command remains GrowthSystem.Learn;
-- course alternatives and granted skills must not become extra learning gates.
function Model:Build(actor,stats,phase,skillId,owned)
    local rules=stats.growth;local professions=rules.professions;local atlas=rules.atlas
    local growth=actor.Growth;local skill=rules.skills:Get(skillId);local node=atlas.nodes:Get(skillId)
    owned=owned or atlas:Owned(actor,stats)
    local learned=growth:HasSkill(skillId);local inherent=false
    for _,id in ipairs(stats:Template(actor).skillIds) do if id==skillId then inherent=true;break end end
    local special=stats.specialSkills and stats.specialSkills.bySkill[skillId]
    if special and stats.specialSkills:IsOriginal(actor,skillId) then inherent=true end
    local description=self.catalog:Description(skillId,'#286C81')
    local kind=skill.skillKind=='preparation' and LuaLanguage.UICharacterGrowthKind2
        or skill.skillKind=='item' and LuaLanguage.UISkillAtlasKind or LuaLanguage.UICharacterGrowthKind
    local tags={{name=kind,textColor='#F2E8CF',backgroundColor='#635E4FE6'}}
    if special then tags[#tags+1]={name=LuaLanguage.SpecialSkillLabel,textColor='#F2E8CF',backgroundColor='#805723E6'} end
    for _,tag in ipairs(description.tags) do tags[#tags+1]=tag end
    local available,reason=professions:CanLearn(actor,skillId,stats,atlas)
    local phaseAllowed=phase=='map' or phase=='area'
    local _,sourceText=atlas:State(skillId,actor,stats,owned)
    local currentCourse=professions.byProfession[growth.CurrentProfessionId][skillId]
    local courses=professions.bySkill[skillId]
    local recipe=stats.spellcasting and stats.spellcasting.recipes:Find(skillId)
    local automatic=recipe~=nil and #recipe.ingredientIds>0
    local sourceKind=special and 'special' or automatic and 'recipe' or learned and 'learned' or inherent and 'inherent'
        or atlas.universal[skillId] and 'universal'
        or owned[skillId] and (stats.animals and stats.animals.bySkill[skillId] and 'animal' or 'equipment')
        or currentCourse and 'course' or courses and 'other_profession' or 'special'
    local statusText=reason
    if learned or inherent or automatic or not courses then statusText=sourceText
    elseif available and not phaseAllowed then statusText=LuaLanguage.GrowthSkillDetailPhase end
    local result={id=skillId,name=skill.name,body=Model.HighlightNumbers(description.body),tags=tags,conditions={},courseRoutes={},
        canLearn=phaseAllowed and available,learned=learned,inherent=inherent,owned=owned[skillId]==true,sourceKind=sourceKind,
        statusText=statusText,sourceText=sourceText,
        equipmentText=atlas:EquipmentCondition(skill,actor,stats) or '',attributeIncludesEquipment=rules.settings.includeEquipment,
        attributeBasisText=rules.settings.includeEquipment and LuaLanguage.GrowthSkillDetailAttributeWithEquipment or LuaLanguage.GrowthSkillDetailAttributeWithoutEquipment}
    -- Ownership is a status, never an inverted red "not yet learned" condition.
    result.buttonText=result.canLearn and LuaLanguage.UICharacterGrowthInvestTextText5
        or learned and LuaLanguage.UICharacterGrowthInvestTextText4
        or inherent and LuaLanguage.UISkillAtlasText7 or LuaLanguage.UICharacterGrowthInvestTextText3
    local rows=result.conditions
    if special then
        result.body=result.body..'\n\n'..stats.specialSkills:Description(skillId,stats)
        result.attributeIncludesEquipment=false
        result.attributeBasisText=LuaLanguage.SpecialSkillObserveBasis
    end
    local learningAction=courses~=nil and not learned and not inherent and not automatic
    if learningAction then
        rows[#rows+1]=condition('phase',LuaLanguage.GrowthSkillDetailPhase,phaseAllowed)
        rows[#rows+1]=condition('opportunity',string.format(LuaLanguage.GrowthSkillDetailOpportunity,growth.PendingCount),growth.PendingCount>=1,
            {required=1,current=growth.PendingCount})
    end
    if courses then
        for _,course in ipairs(courses) do result.courseRoutes[#result.courseRoutes+1]=courseRoute(course,actor,stats) end
        table.sort(result.courseRoutes,function(a,b)return a.professionId<b.professionId end)
        if currentCourse then
            rows[#rows+1]=condition('profession',string.format(LuaLanguage.GrowthSkillDetailProfession,professions.professions:Get(growth.CurrentProfessionId).name),true,
                {professionId=growth.CurrentProfessionId})
            for _,route in ipairs(result.courseRoutes) do if route.current then
                for _,row in ipairs(route.conditions) do rows[#rows+1]=row end
            end end
        else
            local names={};for _,route in ipairs(result.courseRoutes) do names[#names+1]=route.name end
            rows[#rows+1]=condition('profession_any',string.format(LuaLanguage.GrowthSkillDetailProfessionAny,table.concat(names,' / ')),false,
                {mode='any',options=result.courseRoutes})
            for _,route in ipairs(result.courseRoutes) do
                local labels={};for _,row in ipairs(route.conditions) do labels[#labels+1]=row.text end
                rows[#rows+1]=condition('course_route',string.format(LuaLanguage.GrowthSkillDetailRoute,route.name)..'：'..table.concat(labels,'；'),route.met,
                    {alternative=true,blocking=false,professionId=route.professionId,conditions=route.conditions})
            end
        end
    end
    if #node.prerequisiteIds>0 then
        if node.prerequisiteMode=='any' then
            local names,options={},{}
            for _,id in ipairs(node.prerequisiteIds) do
                local name=rules.skills:Get(id).name;names[#names+1]=name;options[#options+1]={id=id,name=name,met=owned[id]==true}
            end
            rows[#rows+1]=condition('prerequisite_any',string.format(LuaLanguage.GrowthSkillDetailPrerequisiteAny,table.concat(names,' / ')),atlas:Prerequisites(skillId,owned),
                {mode='any',options=options})
        else
            for _,id in ipairs(node.prerequisiteIds) do
                rows[#rows+1]=condition('prerequisite',string.format(LuaLanguage.GrowthSkillDetailPrerequisite,rules.skills:Get(id).name),owned[id],{skillId=id})
            end
        end
    end
    -- Previously acquired skills are retained even when current values or the
    -- profession change; these rows describe today's values, not past history.
    if learned or inherent then for _,row in ipairs(rows) do row.blocking=false end end
    return result
end

return Model
