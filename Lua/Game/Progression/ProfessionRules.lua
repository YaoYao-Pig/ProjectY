-- 职业只约束学习目录；已学技能和装备使用不依赖当前职业。
local Rules={};Rules.__index=Rules
function Rules.New(config)
    local self=setmetatable({professions=config:GetTable('ProfessionTable'),courses=config:GetTable('ProfessionSkillTable'),
        skills=config:GetTable('CombatSkillTable'),byProfession={},bySkill={}},Rules)
    local attributes={};for _,row in ipairs(config:GetTable('GrowthAttributeTable'):All()) do attributes[row.code]=true end
    for _,row in ipairs(self.professions:All()) do
        self.byProfession[row.id]={}
        for _,id in ipairs(row.treeIds) do config:GetTable('TalentTreeTable'):Get(id) end
        for _,id in ipairs(row.initialSkillIds) do self.skills:Get(id) end
    end
    for _,row in ipairs(self.courses:All()) do
        local courses=assert(self.byProfession[row.professionId],'Unknown course profession')
        local skill=self.skills:Get(row.skillId)
        assert(skill.skillKind~='item','Item actions cannot be learned')
        assert(not courses[row.skillId] and #row.attributeNames==#row.attributeValues,'Invalid profession course')
        for i,name in ipairs(row.attributeNames) do assert(attributes[name] and row.attributeValues[i]>=0,'Invalid course attribute') end
        courses[row.skillId]=row
        self.bySkill[row.skillId]=self.bySkill[row.skillId] or {};table.insert(self.bySkill[row.skillId],row)
    end
    for _,profession in ipairs(self.professions:All()) do
        for _,id in ipairs(profession.initialSkillIds) do assert(self.byProfession[profession.id][id],'Initial skill must belong to profession') end
    end
    return self
end
function Rules:Requirements(actor,id,stats,atlas,owned)
    local growth=actor.Growth
    if growth:HasSkill(id) then return false,'已经掌握此技能' end
    for _,skillId in ipairs(stats:Template(actor).skillIds) do if skillId==id then return false,'这是角色的固有技能' end end
    local courses=assert(self.byProfession[growth.CurrentProfessionId],'Missing current profession')
    local course=courses[id]
    if not course then return false,self.bySkill[id] and '请先转入对应职业研习' or '此技能由特殊途径获取' end
    if growth.Level<course.minLevel then return false,'需要角色等级 '..course.minLevel end
    for i,name in ipairs(course.attributeNames) do
        if stats:Get(actor,name,not stats.growth.settings.includeEquipment)<course.attributeValues[i] then
            return false,'需要'..stats.growth.attributeByCode[name].name..' '..course.attributeValues[i]
        end
    end
    if not atlas:Prerequisites(id,owned or atlas:Owned(actor,stats)) then return false,'尚未满足技能前置' end
    return true,'满足学习条件'
end
function Rules:CanLearn(actor,id,stats,atlas)
    local ok,reason=self:Requirements(actor,id,stats,atlas)
    if not ok then return false,reason end
    if actor.Growth.PendingCount<1 then return false,'没有可用学习机会，升级后可继续研习' end
    return true,'消耗 1 次学习机会'
end
function Rules:Source(id)
    local names={}
    for _,course in ipairs(self.bySkill[id] or {}) do names[#names+1]=self.professions:Get(course.professionId).name end
    return table.concat(names,' / ')
end
return Rules
