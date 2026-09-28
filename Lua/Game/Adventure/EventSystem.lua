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
    self.growth = context.systems:Get('Growth')
    self.equipment = context.systems:Get('Equipment')
    self.chronicle = self.growth.chronicle
    self.data, self.player = context.services.Adventure, context.services.Player
    for _, row in ipairs(self.events:All()) do
        assert(#row.choiceIds > 0, 'Event must have choices: ' .. row.id)
        assert(self.chronicle.templates[row.logKind], 'Unknown event log template')
        assert(row.actorAttribute == '' or self.growth.rules.attributeByCode[row.actorAttribute], 'Unknown story cast attribute')
        if row.presentation == 'simple' then
            assert(#row.choiceIds == 1, 'Simple event requires one automatic outcome')
            assert(#self.choices:Get(row.choiceIds[1]).encounterIds == 0, 'Simple event cannot start a battle')
        else assert(row.illustration ~= '', 'Complex event needs an illustration') end
        local seen = {}
        for _, id in ipairs(row.choiceIds) do assert(not seen[id], 'Duplicate event choice'); seen[id] = true end
    end
    for _, row in ipairs(self.choices:All()) do
        assert(#row.encounterIds <= 1, 'Choice allows at most one encounter')
        assert(#row.itemIds==#row.itemCounts,'Event item arrays differ')
        for _,count in ipairs(row.itemCounts) do assert(count>0,'Event item count must be positive') end
    end
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
    local event=self.events:Get(site.eventId)
    if event.presentation=='simple' then return self:CheckRequirements(self.choices:Get(event.choiceIds[1]),self:Cast(event)) end
    return true
end
function Events:Cast(event)
    local party=self:LivingParty()
    local actor=party[1] or self.data:GetPartyAt(0)
    if event.actorAttribute~='' then
        for _,candidate in ipairs(party) do
            if self.stats:Get(candidate,event.actorAttribute)>self.stats:Get(actor,event.actorAttribute) then actor=candidate end
        end
    end
    return actor
end
function Events:Begin(site)
    local ok, reason = self:CanVisit(site)
    if not ok then return false, reason end
    local event = self.events:Get(site.eventId)
    local actor = self:Cast(event)
    self.data:BeginEvent(site.id, site.eventId)
    self.data:SetEventContext(actor.Id, site.name)
    return true
end
function Events:Subject() return assert(self.growth:Actor(self.data.EventActorId), 'Missing event subject') end
function Events:BeginArea(eventId,key,location)
    if self.data.Phase~='area' then return false,'当前不在探索区域' end
    local event=self.events:Get(eventId);local actor=self:Cast(event)
    if event.presentation=='simple' then
        local ok,reason=self:CheckRequirements(self.choices:Get(event.choiceIds[1]),actor)
        if not ok then return false,reason end
    end
    self.data:BeginAreaEvent(eventId,key);self.data:SetEventContext(actor.Id,location)
    return true
end
function Events:Text(text)
    return require('Game.Progression.Chronicle').Format(text,self.chronicle:Values(self:Subject(),self.data.EventLocation,'',''))
end
function Events:CanChoose(choiceId)
    if self.data.Phase ~= 'event' then return false, '没有等待选择的事件' end
    local member = false
    for _, id in ipairs(self.events:Get(self.data.EventId).choiceIds) do if id == choiceId then member = true; break end end
    if not member then return false, '这个选项不属于当前事件' end
    local choice = self.choices:Get(choiceId)
    return self:CheckRequirements(choice,self:Subject())
end
function Events:CheckRequirements(choice,subject)
    for _, id in ipairs(choice.requiredTraitIds) do if not subject:HasTrait(id) then return false, '需要特质「'..self.stats.traits:Get(id).name..'」' end end
    for _, id in ipairs(choice.forbiddenTraitIds) do if subject:HasTrait(id) then return false, '特质「'..self.stats.traits:Get(id).name..'」不允许此选择' end end
    if self.player.Coins < choice.costCoins then return false, '金币不足，需要 ' .. choice.costCoins end
    if #choice.itemIds>0 and not self.equipment:CanGrant(choice.itemIds,choice.itemCounts) then return false,'背包空间不足，请先整理背包' end
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
    for _, id in ipairs(ids) do
        local row = self.stats.traits:Get(id)
        if not actor:HasTrait(id) then
            actor:AddTrait(id)
            self.chronicle:Record('trait',actor,'获得特质','获得「'..row.name..'」。','战斗之后',false)
        end
    end
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
    if #choice.itemIds>0 then
        local items={}
        for i,id in ipairs(choice.itemIds) do
            assert(self.equipment:Grant(id,choice.itemCounts[i]))
            items[#items+1]=self.equipment.rules.items:Get(id).name..' ×'..choice.itemCounts[i]
        end
        self.chronicle:Record('loot',self:Subject(),'获得物品',table.concat(items,'、'),self.data.EventLocation,true,self.data.EventId,choice.id)
    end
    local recipients = {}
    if choice.recipient == 'party' then
        for i=0,self.data.PartyCount-1 do recipients[#recipients+1]=self.data:GetPartyAt(i) end
    else recipients[1] = self:Subject() end
    local event = self.events:Get(self.data.EventId)
    self.chronicle:Record(event.logKind,self:Subject(),event.name,choice.result,self.data.EventLocation,true,event.id,choice.id)
    for _, actor in ipairs(recipients) do
        for _, id in ipairs(choice.removeTraitIds) do
            if actor:RemoveTrait(id) then self.chronicle:Record('trait',actor,'特质改变','不再具有「'..self.stats.traits:Get(id).name..'」。',self.data.EventLocation,false,event.id,choice.id) end
        end
        for _, id in ipairs(choice.traitIds) do
            if not actor:HasTrait(id) then
                actor:AddTrait(id); self.chronicle:Record('trait',actor,'获得特质','获得「'..self.stats.traits:Get(id).name..'」。',self.data.EventLocation,false,event.id,choice.id)
            end
        end
        for _, id in ipairs(choice.unlockTreeIds) do
            if actor.Growth:UnlockTree(id) then self.chronicle:Record('growth',actor,'新的道路','解锁「'..self.growth.rules.trees:Get(id).name..'」天赋树。',self.data.EventLocation,false,event.id,choice.id) end
        end
        if choice.potentialPoints > 0 then
            local unlocked = actor.Growth:UnlockPotential(choice.potentialPoints)
            if unlocked > 0 then self.chronicle:Record('growth',actor,'潜力觉醒','释放 '..unlocked..' 点潜力，转为被动天赋点。',self.data.EventLocation,false,event.id,choice.id) end
        end
        actor:SetMaxHP(self.stats:MaximumHP(actor))
        self.growth:AddExperience(actor,choice.experience,self.data.EventLocation)
    end
    return true, choice
end
return Events
