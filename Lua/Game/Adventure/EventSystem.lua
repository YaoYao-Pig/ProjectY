local Class = require('Core.Class')
local System = require('Core.LuaSystem')
local Events = Class('AdventureEventSystem', System)
function Events:OnInit(context)
    System.OnInit(self, context)
    local config = context.systems:Get('Config')
    self.events = config:GetTable('AdventureEventTable')
    self.choices = config:GetTable('AdventureChoiceTable')
    self.encounters = config:GetTable('CombatEncounterTable')
    self.stats = context.systems:Get('Battle').stats
    self.data, self.player = context.services.Adventure, context.services.Player
    for _, row in ipairs(self.events:All()) do
        assert(#row.choiceIds > 0, 'Event must have choices: ' .. row.id)
        local seen = {}
        for _, id in ipairs(row.choiceIds) do assert(not seen[id], 'Duplicate event choice'); seen[id] = true end
    end
    for _, row in ipairs(self.choices:All()) do assert(#row.encounterIds <= 1, 'Choice allows at most one encounter') end
end
function Events:LivingParty()
    local result = {}
    for i = 0, self.data.PartyCount - 1 do
        local actor = self.data:GetPartyAt(i)
        if actor.HP > 0 then result[#result + 1] = actor end
    end
    return result
end
function Events:CanVisit(site)
    if self.data.Phase ~= 'map' then return false, '请先完成当前事件' end
    if self.data:HasVisited(site.id) and not self.events:Get(site.eventId).repeatable then return false, '这个地点已经探索过了' end
    return true
end
function Events:Begin(site)
    local ok, reason = self:CanVisit(site)
    if not ok then return false, reason end
    self.events:Get(site.eventId)
    self.data:BeginEvent(site.id, site.eventId)
    return true
end
function Events:CanChoose(choiceId)
    if self.data.Phase ~= 'event' then return false, '没有等待选择的事件' end
    local member = false
    for _, id in ipairs(self.events:Get(self.data.EventId).choiceIds) do if id == choiceId then member = true; break end end
    if not member then return false, '这个选项不属于当前事件' end
    local choice = self.choices:Get(choiceId)
    if self.player.Coins < choice.costCoins then return false, '金币不足，需要 ' .. choice.costCoins end
    local party, scouting = self:LivingParty(), 0
    for _, actor in ipairs(party) do scouting = math.max(scouting, self.stats:Get(actor, 'scouting')) end
    if scouting < choice.minScouting then return false, '侦察不足，需要 ' .. choice.minScouting end
    if #choice.encounterIds > 0 and #party == 0 then return false, '队伍已倒地，请先到营地休整' end
    if #choice.traitIds > 0 and #party == 0 and not choice.healParty then return false, '没有可获得特质的存活角色' end
    return true
end
function Events:AwardTraits(ids)
    if #ids == 0 then return end
    local actor = assert(self:LivingParty()[1], 'Trait reward needs a living recipient')
    for _, id in ipairs(ids) do self.stats.traits:Get(id); actor:AddTrait(id) end
    actor:SetMaxHP(self.stats:MaximumHP(actor))
end
function Events:Choose(choiceId)
    local ok, reason = self:CanChoose(choiceId)
    if not ok then return false, reason end
    local choice = self.choices:Get(choiceId)
    assert(self.player.Coins - choice.costCoins + choice.rewardCoins <= 2147483647, 'Coin reward overflow')
    -- 先离开可选择状态；重复提交同一按钮不会重复扣费或发奖。
    self.data:ResolveChoice(choiceId)
    assert(self.player:TrySpendCoins(choice.costCoins), 'Coins changed during event resolution')
    if choice.healParty then
        for i = 0, self.data.PartyCount - 1 do self.data:GetPartyAt(i):Restore() end
    end
    self.player:AddCoins(choice.rewardCoins)
    self:AwardTraits(choice.traitIds)
    return true, choice
end
return Events
