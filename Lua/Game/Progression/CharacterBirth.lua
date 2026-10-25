-- 一次性的角色基础属性；随机源只取创建上下文种子与稳定角色 ID，不推进任何玩法随机序列。
local Birth = {}; Birth.__index = Birth
local Random = require('Game.Map.SeededRandom')
local primary = { vitality=true, endurance=true, intellect=true, strength=true, speed=true, defense=true }
local function integer(value)
    return type(value)=='number' and value>=0 and value<=2147483647 and value==math.floor(value)
end
function Birth.New(config)
    local self=setmetatable({},Birth)
    self.rule=config:GetTable('CharacterBirthRuleTable'):Get(1)
    self.units=config:GetTable('CombatUnitTable')
    self.professions=config:GetTable('ProfessionTable')
    self.names,self.registered,self.templates,self.byProfession={},{},{},{}
    local rule=self.rule
    for _,name in ipairs({'primaryMin','primaryMax','secondaryVariance'}) do
        assert(integer(rule[name]),'Invalid character birth range: '..name)
    end
    assert(rule.primaryMin<=rule.primaryMax,'Invalid character birth primary range')
    assert(self.professions:Get(rule.defaultProfessionId).baseProfession,'Character birth default must be a base profession')
    local attributes=config:GetTable('GrowthAttributeTable')
    for _,attribute in ipairs(attributes:All()) do
        local name=attribute.code
        assert(type(name)=='string' and name~='' and not self.registered[name],'Invalid character birth attribute')
        self.names[#self.names+1]=name;self.registered[name]=true
    end
    for name in pairs(primary) do assert(self.registered[name],'Missing character birth primary attribute: '..name) end
    table.sort(self.names)
    for _,profession in ipairs(self.professions:All()) do self.byProfession[profession.id]={} end
    local seenModifiers={}
    for _,row in ipairs(config:GetTable('ProfessionAttributeTable'):All()) do
        local name=attributes:Get(row.attributeId).code
        local rows=assert(self.byProfession[row.professionId],'Unknown profession attribute owner')
        local key=row.professionId..':'..name
        assert(not seenModifiers[key],'Duplicate profession attribute: '..key)
        assert(integer(row.fixedBonus) and integer(row.randomMin) and integer(row.randomMax) and row.randomMin<=row.randomMax
            and row.fixedBonus<=2147483647-row.randomMax,'Invalid profession attribute range: '..key)
        rows[#rows+1]={code=name,fixedBonus=row.fixedBonus,randomMin=row.randomMin,randomMax=row.randomMax}
        seenModifiers[key]=true
    end
    for _,rows in pairs(self.byProfession) do table.sort(rows,function(a,b)return a.code<b.code end) end
    for _,unit in ipairs(self.units:All()) do
        assert(#unit.attributeNames==#unit.attributeValues,'Unit attribute arrays differ: '..unit.id)
        local values={}
        for i,name in ipairs(unit.attributeNames) do
            local value=unit.attributeValues[i]
            assert(self.registered[name] and not primary[name] and values[name]==nil and integer(value),
                'Invalid character birth template attribute: '..tostring(name))
            assert(value<=2147483647-rule.secondaryVariance,'Character birth secondary range exceeds int32')
            values[name]=value
        end
        self.templates[unit.id]=values
    end
    return self
end
function Birth:Initialize(actor,seed,professionId)
    if actor.InitialAttributesAssigned then
        assert(not professionId or not actor.HasInitialAttributes or actor.InitialProfessionId==professionId,
            'Cannot change an assigned character birth profession')
        return
    end
    local unit=self.units:Get(actor.TemplateId)
    if not unit.bodyInjuries then CS.ProjectY.Data.CharacterBirthState.UseTemplate(actor);return end
    professionId=professionId or self.rule.defaultProfessionId
    self.professions:Get(professionId)
    assert(type(seed)=='number' and seed>=0 and seed<=0xffffffff and seed==math.floor(seed),'Character birth seed must be a uint32')
    assert(integer(actor.Id) and actor.Id>0,'Character birth requires a stable actor ID')
    local random=Random((seed ~ actor.Id ~ 0xb17a5eed)&0xffffffff)
    local rule,base,values=self.rule,assert(self.templates[actor.TemplateId]),{}
    for i,name in ipairs(self.names) do
        local minimum,maximum
        if primary[name] then
            minimum,maximum=rule.primaryMin,rule.primaryMax
        else
            local value=base[name] or 0
            minimum,maximum=math.max(0,value-rule.secondaryVariance),value+rule.secondaryVariance
        end
        values[i]=random:Integer(minimum,maximum)
    end
    CS.ProjectY.Data.CharacterBirthState.Initialize(actor,professionId,self.names,values)
    self:EnsureProfession(actor,seed,professionId)
end
function Birth:EnsureProfession(actor,seed,professionId)
    local rows=assert(self.byProfession[professionId],'Unknown character profession attribute owner')
    if actor:HasProfessionAttributes(professionId) then return end
    assert(type(seed)=='number' and seed>=0 and seed<=0xffffffff and seed==math.floor(seed),'Profession attribute seed must be a uint32')
    assert(integer(actor.Id) and actor.Id>0,'Profession attributes require a stable actor ID')
    -- 职业通常只有一项随机收益；先混合相邻角色 ID，避免 LCG 首次采样聚集。
    local mixed=(seed ~ actor.Id ~ (professionId*104729) ~ 0x6c8e9cf5)&0xffffffff
    mixed=((mixed ~ (mixed>>16))*0x45d9f3b)&0xffffffff
    mixed=((mixed ~ (mixed>>16))*0x45d9f3b)&0xffffffff
    local random=Random((mixed ~ (mixed>>16))&0xffffffff)
    local names,values={},{}
    for i,row in ipairs(rows) do
        names[i]=row.code;values[i]=row.fixedBonus+random:Integer(row.randomMin,row.randomMax)
    end
    CS.ProjectY.Data.CharacterBirthState.AssignProfession(actor,professionId,names,values)
end
function Birth:Validate(actor)
    local unit=self.units:Get(actor.TemplateId)
    if not actor.HasInitialAttributes then
        -- AnimalMountSave 的旧格式只保存模板语义；校验不可补写持久状态。
        assert(actor.InitialAttributesAssigned or not unit.bodyInjuries,'Saved character birth attributes were not assigned')
        assert(actor.InitialAttributeCount==0 and actor.InitialProfessionId==0,'Invalid template character birth state')
    else
        assert(actor.InitialAttributesAssigned,'Saved character birth attributes were not assigned')
        self.professions:Get(actor.InitialProfessionId)
        assert(actor.InitialAttributeCount==#self.names,'Saved character birth attribute set differs from configuration')
        local seen={}
        for i=0,actor.InitialAttributeCount-1 do
            local name=actor:GetInitialAttributeNameAt(i)
            assert(self.registered[name] and not seen[name],'Unknown or duplicate saved character birth attribute')
            -- 当前随机范围只约束新角色，调整配置不能否定已经保存的历史结果。
            assert(integer(actor:GetInitialAttribute(name)),'Invalid saved character birth attribute value')
            seen[name]=true
        end
        assert(actor:HasProfessionAttributes(actor.InitialProfessionId),'Saved initial profession attribute record is missing')
        for i=0,actor.Growth.ProfessionCount-1 do
            assert(actor:HasProfessionAttributes(actor.Growth:GetProfessionAt(i)),'Saved joined profession attribute record is missing')
        end
    end
    local allowedProfessions,professions={},{}
    if actor.InitialProfessionId>0 then allowedProfessions[actor.InitialProfessionId]=true end
    for i=0,actor.Growth.ProfessionCount-1 do allowedProfessions[actor.Growth:GetProfessionAt(i)]=true end
    for i=0,actor.ProfessionAttributeSetCount-1 do
        local professionId=actor:GetProfessionAttributeProfessionAt(i)
        self.professions:Get(professionId)
        assert(allowedProfessions[professionId],'Saved profession attribute record has no joined or initial profession')
        assert(not professions[professionId],'Duplicate saved profession attribute record')
        professions[professionId]=true
        local names={}
        for j=0,actor:GetProfessionAttributeCount(professionId)-1 do
            local name=actor:GetProfessionAttributeNameAt(professionId,j)
            assert(self.registered[name] and not names[name],'Unknown or duplicate saved profession attribute')
            assert(integer(actor:GetProfessionAttribute(professionId,name)),'Invalid saved profession attribute value')
            names[name]=true
        end
    end
end
return Birth
