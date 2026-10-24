local Class = require('Core.Class')
local System = require('Core.LuaSystem')
local Signal = require('Core.Signal')
local Actions = require('Game.Narrative.NarrativeActions')
local Rewards = require('Game.Narrative.MissionRewards')
local Story = Class('NarrativeSystem', System)

function Story:ctor()
    System.ctor(self)
    self.RewardSettled = Signal()
end

function Story:OnInit(context)
    System.OnInit(self,context)
    self.RewardSettled.log=context.log
    self.adventure = context.systems:Get('Adventure')
    self.data = assert(context.services.Adventure.Narrative, 'NarrativeData requires C# compilation and xLua bindings')
    self.conditions = context.systems:Get('Condition')
    self.rules = require('Game.Narrative.NarrativeRules').New(context.systems:Get('Config'))
    self.npcs = require('Game.Narrative.NpcSystem').New(self)
    self.dialogue = require('Game.Narrative.Dialogue').New(self)
    self.adventure.narrative = self; self.adventure.areas.narrative = self
    self.townMissions = require('Game.Narrative.TownMissions').New(self)
    require('Game.Narrative.NarrativeConditions')(self)
end
function Story:OnStart()
    self.unsubscribe = self.adventure.battle.Changed:Subscribe(function(event)
        if event.kind ~= 'defeated' then return end
        local target = event.target or assert(self.adventure.battle:FindUnit(event.targetId))
        local source=event.sourceId and self.adventure.battle:FindUnit(event.sourceId)
        if source and source.Team==1 and target.AnimalOwnerId==0 and self.adventure.battle:IsHostile(source,target) then
            self.data:RecordKill(target.TemplateId)
            self.townMissions:RecordKill()
            self.adventure.parties.legends:RecordDefeat(target)
        end
    end)
end
function Story:Start()
    self.lastBuffMinute=nil
    self.data:Clear(); self.data:AdvanceMinutes(self.rules.environment.startHour * 60)
    for _, npc in ipairs(self.rules.npcs:All()) do self.data:SetValue('relation:'..npc.id,npc.initialRelation) end
    for _, faction in ipairs(self.rules.factions:All()) do self.data:SetValue('reputation:'..faction.id,faction.initialValue) end
    self.npcs:BindWorld(self.adventure.sites); self:Refresh()
end
function Story:ItemCount(id)
    local data = self.adventure.data.Equipment
    local kind = self.rules.config:GetTable('EquipmentItemTable'):Get(id).kind
    if kind ~= 'weapon' and kind ~= 'magazine' and kind ~= 'wearable' then return data:CountItem(id) end
    -- “背包持有”不包含已装备、已装入武器的实例。
    local count = 0
    for i=0,data.Grid.Count-1 do if data.Grid:GetAt(i).ItemId == id then count = count + 1 end end
    return count
end
function Story:CanAccept(id)
    local row = self.rules.missions:Get(id)
    if self.data:Status('mission',id) ~= 'inactive' then return false,'任务已接取或已完成' end
    return self.conditions:Check(row.startConditionId,{})
end
function Story:Accept(id)
    if self.adventure.data.Phase ~= 'map' and self.adventure.data.Phase ~= 'area' then return false,'只能在探索时接取任务' end
    local ok,reason = self:CanAccept(id); if not ok then return false,reason end
    self.data:Begin('mission',id); self:Refresh(); return true
end
function Story:Claim(kind,id)
    if self.adventure.data.Phase ~= 'map' and self.adventure.data.Phase ~= 'area' then return false,'只能在探索时领取任务奖励' end
    local table = kind == 'mission' and self.rules.missions or self.rules.quests
    local row = table:Get(id)
    if self.data:Status(kind,id) ~= 'ready' then return false,'任务尚未就绪或已经领取' end
    local plan,reason = Actions.Prepare(self,row.actionIds); if not plan then return false,reason end
    local rewards = Actions.Apply(self,plan)
    self.data:Complete(kind,id)
    if #rewards > 0 or kind == 'mission' or not row.autoComplete then
        self.RewardSettled:Emit({title=row.name,kind=kind,id=id,rows=rewards})
    end
    return true
end
function Story:Refresh()
    if self.adventure.data.PartyCount == 0 then return end
    -- 战斗中只记录击杀；结算回到探索后才流转、发奖或加入新角色。
    if self.adventure.data.Phase ~= 'map' and self.adventure.data.Phase ~= 'area' then return end
    self.townMissions:Refresh()
    local transitions = 0
    while true do
        local before = self.data.Revision
        for _, mission in ipairs(self.rules.missions:All()) do
            if mission.autoAccept and self:CanAccept(mission.id) then self.data:Begin('mission',mission.id) end
            if self.data:Status('mission',mission.id) == 'active' then
                for _, quest in ipairs(self.rules.questsByMission[mission.id] or {}) do
                    local status = self.data:Status('quest',quest.id)
                    if status == 'inactive' and self.conditions:Check(quest.startConditionId,{kind='mission',id=mission.id}) then
                        self.data:Begin('quest',quest.id); status = 'active'
                    end
                    if status == 'active' and self.conditions:Check(quest.completeConditionId,{kind='quest',id=quest.id}) then
                        self.data:Ready('quest',quest.id); status = 'ready'
                    end
                    if status == 'ready' and quest.autoComplete then self:Claim('quest',quest.id) end
                end
                if self.conditions:Check(mission.completeConditionId,{kind='mission',id=mission.id}) then self.data:Ready('mission',mission.id) end
            end
            if mission.autoComplete and self.data:Status('mission',mission.id) == 'ready' then self:Claim('mission',mission.id) end
        end
        if self.data.Revision == before then break end
        transitions = transitions + 1
        assert(transitions <= self.rules.settings.maxTransitions, 'Narrative progression exceeded transition budget')
    end
end
function Story:Tick(dt)
    local ui=self.context.services.UI
    if not self.adventure.map then return end
    if self.adventure.data.Phase ~= 'map' and self.adventure.data.Phase ~= 'area' then return end
    local paused=(ui and ui.IsWorldPaused) or self.data.DialogueOpen or self.adventure.shop.data.IsOpen
    if not paused and self.adventure.data.Phase~='map' and self.rules.environment.autoCycle then self:AdvanceMinutes(dt * 1440 / self.rules.environment.cycleSeconds) end
    self:TickBuffs()
    if paused then return end
    local revision = self.data.Revision..':'..self.adventure.data.Equipment.Revision..':'..self.adventure.player.Coins..':'..math.floor(self.data.Minutes)
    if revision ~= self.lastRevision then self:Refresh(); self.lastRevision = revision end
end
function Story:AdvanceMinutes(minutes)
    self.data:AdvanceMinutes(minutes);self:TickBuffs()
end
function Story:TickBuffs()
    local now=self.data.Minutes
    if self.lastBuffMinute==now then return end
    self.lastBuffMinute=now
    local adventure=self.adventure;local changed={}
    local function visit(actor)
        local recovered=CS.ProjectY.Data.BodyHealth.AdvanceRecovery(actor,now)>0
        if adventure.battle.gameEffects:TickWorldActor(actor,now) or recovered then changed[#changed+1]=actor end
    end
    for i=0,adventure.data.PartyCount-1 do visit(adventure.data:GetPartyAt(i)) end
    if adventure.data.Phase=='area' then local state=adventure.data.Areas.Active
        for i=0,state.EncounterCount-1 do local group=state:GetEncounterAt(i)
            for j=0,group.EnemyCount-1 do local actor=group:GetEnemyAt(j);if actor.AnimalOwnerId==0 then visit(actor) end end
        end
    end
    if #changed>0 and adventure.data.Phase=='area' then
        adventure.equipment:GenerateActorDrops(adventure.areas,changed,adventure.battle.stats)
        adventure.areas:RefreshLivingSquad()
    end
end
function Story:Rows()
    local result = {}
    for _, row in ipairs(self.rules.missions:All()) do
        local status = self.data:Status('mission',row.id)
        local available,reason = self:CanAccept(row.id)
        if status ~= 'inactive' or available then
            local item = {id=row.id,name=row.name,description=row.description,category=row.category,status=status,reason='',quests={},rewards=Rewards.Preview(self,row.actionIds)}
            if status == 'ready' then local plan; plan,item.reason = Actions.Prepare(self,row.actionIds); item.claimable = plan ~= nil end
            for _, quest in ipairs(self.rules.questsByMission[row.id] or {}) do
                local questStatus = self.data:Status('quest',quest.id)
                if questStatus ~= 'inactive' then
                    local _,why = self.conditions:Check(quest.completeConditionId,{kind='quest',id=quest.id})
                    item.quests[#item.quests+1] = {id=quest.id,name=quest.name,description=quest.description,status=questStatus,reason=why,rewards=Rewards.Preview(self,quest.actionIds)}
                end
            end
            result[#result+1] = item
        end
    end
    return result
end
function Story:OnShutdown()
    if self.unsubscribe then self.unsubscribe(); self.unsubscribe=nil end
    self.RewardSettled:Clear()
    self.data:CloseDialogue()
    self.adventure.narrative=nil; self.adventure.areas.narrative=nil
end
return Story
