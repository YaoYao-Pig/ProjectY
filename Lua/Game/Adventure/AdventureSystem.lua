local Class = require('Core.Class')
local System = require('Core.LuaSystem')
local Hex = require('Game.Map.HexGrid')
local Adventure = Class('AdventureSystem', System)
function Adventure:OnInit(context)
    System.OnInit(self, context)
    local config = context.systems:Get('Config')
    self.recipe = config:GetTable('AdventureDemoTable'):Get(1)
    self.appearances = require('Game.Adventure.PawnAppearance').New(config)
    self.mapSystem = context.systems:Get('Map')
    self.battle = context.systems:Get('Battle')
    self.events = context.systems:Get('AdventureEvents')
    self.data, self.player = context.services.Adventure, context.services.Player
    self.areas = context.systems:Get('MapArea')
    assert(self.recipe.maxPartySize<=4 and #self.recipe.partyIds > 0 and #self.recipe.partyIds <= self.recipe.maxPartySize, 'Invalid demo party size')
    assert(#self.recipe.buildingIds == #self.recipe.buildingEventIds, 'Building event mapping differs')
end
function Adventure:Start(seed)
    seed = seed or self.recipe.seed
    local map = self.mapSystem:Generate(seed, self.recipe.regionIds)
    local sites, dry = {}, {}
    for _, cell in ipairs(map:GetCells()) do
        if not cell.waterLevel and not cell.buildingId then dry[#dry + 1] = cell end
    end
    assert(#dry > #self.recipe.wildEventIds, 'Map needs dry cells for adventure sites')
    local function addSite(eventId, cell, name)
        local x, y, z = map:GetCellWorldPosition(cell.q, cell.r)
        sites[#sites + 1] = {id = #sites + 1, eventId = eventId, q = cell.q, r = cell.r,
            name = name or self.events.events:Get(eventId).name, x = x, y = y, z = z}
    end
    local camp, closest
    for _, cell in ipairs(dry) do
        local distance = Hex.Distance(0, 0, cell.q, cell.r)
        if not closest or distance < closest then camp, closest = cell, distance end
    end
    addSite(self.recipe.campEventId, camp)
    for _, eventId in ipairs(self.recipe.wildEventIds) do
        local selected, furthest
        for _, cell in ipairs(dry) do
            local nearest = math.huge
            for _, site in ipairs(sites) do nearest = math.min(nearest, Hex.Distance(cell.q, cell.r, site.q, site.r)) end
            if not furthest or nearest > furthest then selected, furthest = cell, nearest end
        end
        assert(furthest > 0, 'Adventure sites overlap')
        addSite(eventId, selected)
    end
    local areaTowns={}
    for _,site in ipairs(self.areas:Entrances(map)) do
        site.id=#sites+1;sites[#sites+1]=site;areaTowns[site.pointId]=true
    end
    local mapping = {}
    for i, id in ipairs(self.recipe.buildingIds) do mapping[id] = self.recipe.buildingEventIds[i] end
    for _, building in ipairs(map:GetBuildings()) do
        local eventId = mapping[building.configId]
        if eventId and not areaTowns[building.townId] and #sites < 10 then addSite(eventId, building.cell) end
    end
    self.areas:Clear();self.data:Reset(seed)
    self.map, self.sites = map, sites
    for i, id in ipairs(self.recipe.partyIds) do
        local actor = self.data:AddPartyActor(i, id)
        actor:SetMaxHP(self.battle.stats:MaximumHP(actor)); actor:Restore()
    end
end
function Adventure:Visit(siteId)
    local site = self.sites[siteId]
    if not site then return false, '未知地点' end
    if site.areaConfigId then return self.areas:Enter(site,self.data.Seed) end
    return self.events:Begin(site)
end
function Adventure:AreaCommand(command,a,b)
    if command=='area_move' then return self.areas:MoveTo(a,b) end
    if command=='area_walk' then return self.areas:Walk(a) end
    if command=='area_interact' then return self.areas:Interact(a,b) end
    if command=='area_close' then return self.areas:CloseInteraction() end
    if command=='area_stop' then return self.areas:Stop() end
    if command=='area_leave' then return self.areas:Leave() end
    error('Unknown MapArea command: '..tostring(command))
end
function Adventure:Choose(choiceId)
    local ok, choice = self.events:Choose(choiceId)
    if not ok then return false, choice end
    if #choice.encounterIds == 1 then
        local seed = (self.data.Seed + self.data.SiteId * 7919) % 4294967296
        self.battle:Start(choice.encounterIds[1], self.events:LivingParty(), seed)
        self.data:BeginBattle()
    else
        self.data:Complete(choice.result)
    end
    return true
end
function Adventure:SettleBattle()
    local result = self.data.Battle.Winner
    if result == '' then return end
    assert(self.data.Phase == 'battle', 'Battle result already consumed')
    self.data:BeginSettlement()
    if result == 'victory' then
        local encounter = self.battle.encounters:Get(self.data.Battle.EncounterId)
        self.player:AddCoins(encounter.rewardCoins)
        self.events:AwardTraits(encounter.rewardTraitIds)
        self.data:Complete('胜利！带回 ' .. encounter.rewardCoins .. ' 金币。伤势保留，返回移动营地可休整。')
    elseif result == 'defeat' then
        self.data:Complete('队伍败退，本次没有战利品。返回地图后，请到移动营地休整。')
    else
        self.data:Complete('队伍撤回，本次没有战利品。可以返回移动营地休整。')
    end
end
function Adventure:BattleCommand(command, a, b)
    if self.data.Phase ~= 'battle' then return false, '当前不在战斗中' end
    local actor = self.battle:Active()
    if command ~= 'ai' and actor.Team ~= 1 then return false, '等待敌方行动' end
    local ok, reason
    if command == 'move' then ok, reason = self.battle:TryMove(a, b)
    elseif command == 'skill' then ok, reason = self.battle:TrySkill(a, b)
    elseif command == 'end_turn' then ok, reason = self.battle:EndTurn()
    elseif command == 'ai' then ok, reason = self.battle:StepAI()
    else error('Unknown battle command: ' .. tostring(command)) end
    if ok then self:SettleBattle() end
    return ok, reason
end
function Adventure:ReturnToMap()
    if self.data.Phase ~= 'result' then return false, '请先完成事件或战斗' end
    self.data:ReturnToMap(); self.battle.board = nil
    return true
end
function Adventure:MapSnapshot() return require('Game.Map.MapRenderSnapshot')(assert(self.map, 'Start an adventure first')) end
function Adventure:Snapshot()
    local result = {phase = self.data.Phase, coins = self.player.Coins, result = self.data.ResultText,
        sites = {}, party = {}, units = {}, cells = {}, reachable = {}, skills = {}, logs = {}, choices = {},
        eventTitle = '', eventText = '', encounter = '', round = 0, activeId = 0, radius = 0}
    -- cells 和 reachable 都由 C# ReadCell 读取，必须包含相同的值类型字段。
    local function cellView(cell) return {q = cell.q, r = cell.r, blocked = cell.blocked} end
    local function actorView(actor)
        local traits = {}
        for i = 0, actor.TraitCount - 1 do traits[#traits + 1] = self.battle.stats.traits:Get(actor:GetTraitAt(i)).name end
        return {id = actor.Id, name = self.battle.stats:Template(actor).name, team = actor.Team, hp = actor.HP,
            maxHP = actor.MaxHP, ap = actor.AP, q = actor.Q, r = actor.R, guard = actor.Guard,
            moved = actor.Moved, mainUsed = actor.MainUsed, traits = table.concat(traits, ' · ')}
    end
    for i = 0, self.data.PartyCount - 1 do
        local actor=self.data:GetPartyAt(i);local row=actorView(actor)
        row.appearance=self.appearances:Template(actor.TemplateId)
        result.party[#result.party + 1]=row
    end
    for _, site in ipairs(assert(self.sites, 'Start an adventure first')) do
        local available,reason
        if site.areaConfigId then available,reason=self.areas:CanEnter(site)
        else available,reason=self.events:CanVisit(site) end
        result.sites[#result.sites + 1] = {id = site.id, name = site.name, x = site.x, y = site.y, z = site.z,
            available = available, visited = self.data:HasVisited(site.id),areaConfigId=site.areaConfigId or 0,reason=reason or ''}
    end
    if self.data.Phase=='area' then result.area=self.areas:Snapshot() end
    if self.data.Phase == 'event' then
        local event = self.events.events:Get(self.data.EventId)
        result.eventTitle, result.eventText = event.name, event.description
        for _, id in ipairs(event.choiceIds) do
            local ok, reason = self.events:CanChoose(id)
            result.choices[#result.choices + 1] = {id = id, label = self.events.choices:Get(id).label, available = ok, reason = reason or ''}
        end
    end
    if self.data.Battle.UnitCount > 0 then
        result.encounter = self.battle.encounters:Get(self.data.Battle.EncounterId).name
        result.round, result.activeId, result.radius = self.data.Battle.Round, self.data.Battle.ActiveId, self.battle.board.radius
        for _, actor in ipairs(self.battle:Units()) do result.units[#result.units + 1] = actorView(actor) end
        for _, cell in ipairs(self.battle.board.cells) do result.cells[#result.cells + 1] = cellView(cell) end
        for _, cell in ipairs(self.battle:Reachable()) do result.reachable[#result.reachable + 1] = cellView(cell) end
        if self.data.Phase == 'battle' then
            for _, id in ipairs(self.battle.stats:Template(self.battle:Active()).skillIds) do
                local skill, targets = self.battle.skills:Get(id), {}
                for _, actor in ipairs(self.battle:Units()) do if self.battle:CanUseSkill(id, actor.Id) then targets[#targets + 1] = actor.Id end end
                result.skills[#result.skills + 1] = {id = id, name = skill.name, description = skill.description,
                    cost = skill.cost, action = skill.action, targets = targets}
            end
        end
        for i = 0, self.data.Battle.LogCount - 1 do result.logs[#result.logs + 1] = self.data.Battle:GetLogAt(i) end
    end
    return result
end
function Adventure:OnShutdown()
    self.map = nil; self.sites = nil
    -- 配方或依赖读取失败时可能尚未取得会话数据，仍须允许启动回滚。
    if self.data then self.data:Reset(0); self.data = nil end
end
return Adventure
