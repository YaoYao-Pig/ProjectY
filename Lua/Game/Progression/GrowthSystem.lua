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
function Growth:Initialize(actor)
    local profile = assert(self.rules.profileByUnit[actor.TemplateId], 'Missing growth profile')
    local rule = self.rules.settings
    actor.Growth:Initialize((self.data.Seed+actor.Id*104729)%4294967296,rule.initialAttributePoints,rule.initialTalentPoints,profile.potential)
    for _, id in ipairs(profile.treeIds) do actor.Growth:UnlockTree(id) end
    for _, id in ipairs(profile.traitIds) do actor:AddTrait(id) end
    self.chronicle:Record('growth',actor,'旅程伊始','带着自己的来历，加入这次远征。','营地',false)
end
function Growth:Editable(id)
    if self.data.Phase ~= 'map' and self.data.Phase ~= 'area' then return nil, '请在探索间隙进行养成' end
    local actor = self:Actor(id)
    if not actor then return nil, '未知队员' end
    return actor
end
function Growth:PrepareOffers(actor)
    local growth = actor.Growth
    while growth.PendingCount > 0 and growth.OfferCount == 0 do
        local ids = self.rules:Draw(actor, self.stats)
        if #ids > 0 then for _, id in ipairs(ids) do growth:AddOffer(id) end; return end
        self.chronicle:Record('growth',actor,'技能研习','等级 '..growth.PendingLevel..' 的可用技能池已全部掌握或尚未达到门槛。','旅途中',false)
        growth:FinishEmptyOffer()
    end
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
    -- 候选只在获得学习机会/选完上一轮时生成；UI 打开不消耗随机数。
    self:PrepareOffers(actor)
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
    local found = false
    for i=0,actor.Growth.OfferCount-1 do if actor.Growth:GetOfferAt(i)==skillId then found=true end end
    if not found then return false, '此技能不在当前学习候选中' end
    actor.Growth:LearnOffer(skillId)
    self.chronicle:Record('growth',actor,'主动技能','学会「'..self.rules.skills:Get(skillId).name..'」。','旅途中',false)
    self:PrepareOffers(actor)
    return true
end
return Growth
