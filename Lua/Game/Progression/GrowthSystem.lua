local Class = require('Core.Class')
local System = require('Core.LuaSystem')
local Growth = Class('GrowthSystem', System)
function Growth:OnInit(context)
    System.OnInit(self, context)
    self.stats = context.systems:Get('Battle').stats
    self.rules = self.stats.growth
    self.data = context.services.Adventure
    self.chronicle = require('Game.Progression.Chronicle').New(context.systems:Get('Config'),self.data,self.stats)
end
function Growth:Actor(id)
    for i=0,self.data.PartyCount-1 do local actor=self.data:GetPartyAt(i); if actor.Id==id then return actor end end
end
function Growth:PrepareActor(actor)
    local profile = assert(self.rules.profileByUnit[actor.TemplateId], 'Missing growth profile')
    local rule = self.rules.settings
    actor.Growth:Initialize((self.data.Seed+actor.Id*104729)%4294967296,rule.initialAttributePoints,rule.initialTalentPoints,profile.potential)
    for _, id in ipairs(profile.treeIds) do actor.Growth:UnlockTree(id) end
    for _, id in ipairs(profile.traitIds) do actor:AddTrait(id) end
    for _, id in ipairs(self.stats.units:Get(actor.TemplateId).traitIds) do actor:AddTrait(id) end
    self:InitializeProfession(actor)
    for _=1,rule.initialLearningOpportunities do actor.Growth:AddLearningOpportunity(1) end
end
function Growth:InitializeProfession(actor)
    assert(actor.Growth.CurrentProfessionId==0,'Profession already initialized')
    local profile=assert(self.rules.profileByUnit[actor.TemplateId],'Missing growth profile')
    local profession=self.rules.professions.professions:Get(profile.initialProfessionId)
    actor.Growth:JoinProfession(profession.id)
    for _,id in ipairs(profession.treeIds) do actor.Growth:UnlockTree(id) end
    for _,id in ipairs(profession.initialSkillIds) do actor.Growth:GrantSkill(id) end
end
function Growth:RecordJoined(actor,location)
    self.chronicle:Record('growth',actor,'旅程伊始','带着自己的来历，加入这次远征。',location,false)
end
function Growth:Initialize(actor)
    self:PrepareActor(actor)
    self:RecordJoined(actor,'营地')
end
function Growth:Editable(id)
    if self.data.Phase ~= 'map' and self.data.Phase ~= 'area' then return nil, '请在探索间隙进行养成' end
    local actor = self:Actor(id)
    if not actor then return nil, '未知队员' end
    return actor
end
function Growth:PrepareOffers(actor)
    -- 保留旧调用入口；主动选学不抽取候选，空目录也不消耗机会或随机数。
    assert(actor.Growth.Initialized,'Growth is not initialized')
end
function Growth:AddExperience(actor, amount, location)
    if amount == 0 then return end
    actor.Growth:AddExperience(amount)
    local growth = actor.Growth
    while growth.Level < self.rules.maxLevel do
        local level = self.rules.levels:Get(growth.Level+1)
        if growth.Experience < level.experience then break end
        growth:AdvanceLevel(level.experience,level.attributePoints,level.talentPoints,level.learnSkill)
        self.chronicle:Record('growth',actor,'新的成长','升至 '..growth.Level..' 级，获得 '..level.attributePoints..' 属性点、'..level.talentPoints..' 被动天赋点。',location,false)
    end
end
function Growth:InvestAttribute(actorId, attributeId)
    local actor, reason = self:Editable(actorId); if not actor then return false, reason end
    local row = self.rules.attributes:Find(attributeId); if not row then return false, '未知属性' end
    if actor.Growth.AttributePoints < row.pointCost then return false, '属性点不足' end
    if actor.Growth:GetAttribute(row.code)+row.amount > row.maximumInvestment then return false, '已达到此属性的投入上限' end
    actor.Growth:InvestAttribute(row.code,row.pointCost,row.amount); actor:SetMaxHP(self.stats:MaximumHP(actor))
    self.chronicle:Record('growth',actor,'属性提升',row.name..' +'..row.amount,'旅途中',false)
    return true
end
function Growth:InvestTalent(actorId, nodeId)
    local actor, reason = self:Editable(actorId); if not actor then return false, reason end
    local ok; ok,reason = self.rules:CanInvest(actor,nodeId); if not ok then return false, reason end
    local node = self.rules.nodes:Get(nodeId)
    actor.Growth:InvestTalent(nodeId,node.pointCost); actor:SetMaxHP(self.stats:MaximumHP(actor))
    self.chronicle:Record('growth',actor,'被动天赋',self.rules.passives:Get(node.passiveId).name..' 提升至 '..actor.Growth:GetRank(nodeId)..' 阶。','旅途中',false)
    return true
end
function Growth:Learn(actorId, skillId)
    local actor, reason = self:Editable(actorId); if not actor then return false, reason end
    local ok;ok,reason=self.rules.professions:CanLearn(actor,skillId,self.stats,self.rules.atlas)
    if not ok then return false,reason end
    actor.Growth:LearnSelected(skillId)
    self.chronicle:Record('growth',actor,'主动技能','学会「'..self.rules.skills:Get(skillId).name..'」。','旅途中',false)
    return true
end
function Growth:ChangeProfession(actorId,professionId)
    local actor,reason=self:Editable(actorId);if not actor then return false,reason end
    local profession=self.rules.professions.professions:Find(professionId)
    if not profession then return false,'未知职业' end
    if actor.Growth.CurrentProfessionId==professionId then return false,'当前已经在研习此职业' end
    actor.Growth:JoinProfession(professionId)
    for _,id in ipairs(profession.treeIds) do actor.Growth:UnlockTree(id) end
    self.chronicle:Record('growth',actor,'职业研习','转入「'..profession.name..'」，保留此前掌握的全部技艺。','旅途中',false)
    return true
end
return Growth
