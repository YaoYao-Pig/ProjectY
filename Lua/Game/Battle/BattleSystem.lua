local Class = require('Core.Class')
local System = require('Core.LuaSystem')
local Signal = require('Core.Signal')
local Hex = require('Game.Map.HexGrid')
local Board = require('Game.Battle.BattleBoard')
local Battle = Class('BattleSystem', System)
function Battle:OnInit(context)
    System.OnInit(self, context)
    local config = context.systems:Get('Config')
    local adventure = assert(context.services.Adventure,
        'FrameworkServices.Adventure is unavailable; exit Play, compile C# and run XLua/Generate Code before restarting')
    self.data = assert(adventure.Battle, 'FrameworkServices.Adventure.Battle is unavailable')
    self.stats = require('Game.Battle.CombatStats')(config)
    self.skills = config:GetTable('CombatSkillTable')
    self.effects = config:GetTable('CombatEffectTable')
    self.encounters = config:GetTable('CombatEncounterTable')
    self.Changed = Signal(context.log)
    for _, row in ipairs(self.skills:All()) do assert(#row.effectIds > 0, 'Skill needs effects: ' .. row.id) end
end
function Battle:Units()
    local units = {}
    for i = 0, self.data.UnitCount - 1 do units[#units + 1] = self.data:GetUnitAt(i) end
    return units
end
function Battle:FindUnit(id)
    for i = 0, self.data.UnitCount - 1 do
        local unit = self.data:GetUnitAt(i)
        if unit.Id == id then return unit end
    end
end
function Battle:Active() return assert(self:FindUnit(self.data.ActiveId), 'No active battle unit') end
function Battle:Emit(kind, message, sourceId, targetId, amount)
    self.data:AddLog(message)
    self.Changed:Emit({kind = kind, sourceId = sourceId, targetId = targetId, amount = amount})
end
function Battle:Start(encounterId, party, seed)
    local encounter = self.encounters:Get(encounterId)
    assert(#party > 0 and #party <= 4, 'Battle needs 1..4 living party members')
    assert(#encounter.enemyIds > 0 and #encounter.enemyIds <= 4, 'Encounter needs 1..4 enemies')
    local board = Board.Create(encounter.radius, seed, encounter.obstacleChance)
    for _, unit in ipairs(party) do assert(unit.HP > 0, 'Cannot deploy a defeated unit') end
    self.data:Reset(encounterId, encounter.maxRounds)
    self.board = board
    for i, unit in ipairs(party) do self.data:AddUnit(unit, 1, -board.radius, i - 1) end
    for i, templateId in ipairs(encounter.enemyIds) do
        local unit = self.data:AddEnemy(100 + i, templateId, board.radius, 1 - i)
        unit:SetMaxHP(self.stats:MaximumHP(unit)); unit:Restore()
    end
    self:Emit('battle_started', encounter.name)
    self:NewRound()
end
function Battle:NewRound()
    if self.data.Round >= self.data.MaxRounds then
        self.data:Finish('draw'); self:Emit('battle_ended', '战斗时间耗尽，队伍撤回。'); return
    end
    local order = {}
    for _, unit in ipairs(self:Units()) do if unit.HP > 0 then order[#order + 1] = unit end end
    table.sort(order, function(a, b)
        local sa, sb = self.stats:Get(a, 'speed'), self.stats:Get(b, 'speed')
        if sa == sb then return a.Id < b.Id end
        return sa > sb
    end)
    self.data:BeginRound()
    for _, unit in ipairs(order) do self.data:AddTurn(unit.Id) end
    self:BeginTurn(0)
end
function Battle:BeginTurn(index)
    self.data:SelectTurn(index)
    local unit = self:Active()
    unit:BeginTurn(self.stats:Template(unit).actionPoints)
    self:Emit('turn_started', self.stats:Template(unit).name .. ' 行动', unit.Id)
end
function Battle:CheckWinner()
    local alive = {[1] = 0, [2] = 0}
    for _, unit in ipairs(self:Units()) do if unit.HP > 0 then alive[unit.Team] = alive[unit.Team] + 1 end end
    if alive[1] > 0 and alive[2] > 0 then return false end
    local result = alive[1] > 0 and 'victory' or 'defeat'
    self.data:Finish(result)
    self:Emit('battle_ended', result == 'victory' and '敌人已被击退。' or '队伍失去战斗能力。')
    return true
end
function Battle:EndTurn()
    if self.data.Winner ~= '' then return false, '战斗已经结束' end
    local unit = self:Active()
    self:Emit('turn_ended', self.stats:Template(unit).name .. ' 结束行动', unit.Id)
    if self:CheckWinner() then return true end
    for i = self.data.TurnIndex + 1, self.data.TurnCount - 1 do
        if self:FindUnit(self.data:GetTurnAt(i)).HP > 0 then self:BeginTurn(i); return true end
    end
    self:NewRound(); return true
end
function Battle:Occupied(exceptId)
    local occupied = {}
    for _, unit in ipairs(self:Units()) do
        if unit.HP > 0 and unit.Id ~= exceptId then occupied[Hex.Key(unit.Q, unit.R)] = unit end
    end
    return occupied
end
function Battle:Reachable()
    if self.data.Winner ~= '' then return {} end
    local unit = self:Active(); local template = self.stats:Template(unit)
    if unit.Moved or unit.AP < template.moveCost then return {} end
    local cells = self.board:Search(unit.Q, unit.R, self:Occupied(unit.Id), template.moveRange)
    local result = {}
    for _, cell in ipairs(cells) do if cell.q ~= unit.Q or cell.r ~= unit.R then result[#result + 1] = cell end end
    return result
end
function Battle:TryMove(q, r)
    Hex.CheckCoordinate(q, r)
    for _, cell in ipairs(self:Reachable()) do
        if cell.q == q and cell.r == r then
            local unit = self:Active()
            unit:Move(q, r, self.stats:Template(unit).moveCost)
            self:Emit('moved', self.stats:Template(unit).name .. ' 移动', unit.Id)
            return true
        end
    end
    return false, '无法移动到这里：检查距离、占格、行动点和本回合移动次数'
end
function Battle:CanUseSkill(skillId, targetId)
    if self.data.Winner ~= '' then return false, '战斗已经结束' end
    local source, skill = self:Active(), self.skills:Get(skillId)
    local owns = false
    for _, id in ipairs(self.stats:Template(source).skillIds) do if id == skillId then owns = true; break end end
    if not owns then return false, '角色没有这个技能' end
    if skill.action == 'main' and source.MainUsed then return false, '本回合主要行动已使用' end
    if source.AP < skill.cost then return false, '行动点不足' end
    local target = self:FindUnit(targetId)
    if not target or target.HP <= 0 then return false, '请选择存活的目标' end
    if skill.target == 'self' and target.Id ~= source.Id then return false, '只能对自己使用' end
    if skill.target == 'enemy' and target.Team == source.Team then return false, '请选择敌人' end
    if skill.target == 'ally' and target.Team ~= source.Team then return false, '请选择友军' end
    if Hex.Distance(source.Q, source.R, target.Q, target.R) > skill.range then return false, '目标超出射程' end
    return true
end
function Battle:TrySkill(skillId, targetId)
    local ok, reason = self:CanUseSkill(skillId, targetId)
    if not ok then return false, reason end
    local source, target, skill = self:Active(), self:FindUnit(targetId), self.skills:Get(skillId)
    local values, program = self.stats:EffectVariables(source, target, skill), {}
    -- 先完整校验效果，配置错误不会在扣除行动点后才暴露。
    for _, id in ipairs(skill.effectIds) do
        local effect = self.effects:Get(id)
        local amount = effect.amount:Evaluate(values)
        assert(amount >= 0 and amount <= 1000000 and amount == math.floor(amount), 'Invalid effect amount: ' .. id)
        assert(effect.kind == 'damage' or effect.kind == 'heal' or effect.kind == 'guard', 'Unknown combat effect: ' .. effect.kind)
        program[#program + 1] = {kind = effect.kind, amount = amount}
    end
    source:SpendAction(skill.action, skill.cost)
    for _, effect in ipairs(program) do
        local wasAlive = target.HP > 0
        local amount = effect.amount
        if effect.kind == 'damage' then amount = target:Damage(amount)
        elseif effect.kind == 'heal' then amount = target:Heal(amount)
        else target:SetGuard(amount) end
        local verb = ({damage = '伤害', heal = '治疗', guard = '防御'})[effect.kind]
        self:Emit(effect.kind, self.stats:Template(source).name .. ' · ' .. skill.name .. ' → ' .. self.stats:Template(target).name .. '（' .. verb .. ' ' .. amount .. '）', source.Id, target.Id, amount)
        if wasAlive and target.HP == 0 then self:Emit('defeated', self.stats:Template(target).name .. ' 倒地', source.Id, target.Id) end
    end
    self:CheckWinner(); return true
end
-- AI 也通过同一套移动/技能命令执行，每次调用只推进一个敌方角色的回合。
function Battle:StepAI()
    if self.data.Winner ~= '' then return false, '战斗已经结束' end
    local actor = self:Active()
    if actor.Team ~= 2 then return false, '等待玩家行动' end
    local function attack()
        for _, skillId in ipairs(self.stats:Template(actor).skillIds) do
            if self.skills:Get(skillId).target == 'enemy' then
                for _, target in ipairs(self:Units()) do
                    if self:CanUseSkill(skillId, target.Id) then return self:TrySkill(skillId, target.Id) end
                end
            end
        end
        return false
    end
    if not attack() then
        local occupied = self:Occupied(actor.Id)
        local _, _, previous = self.board:Search(actor.Q, actor.R, occupied, #self.board.cells)
        local bestPath
        for _, target in ipairs(self:Units()) do
            if target.HP > 0 and target.Team ~= actor.Team then
                for _, cell in ipairs(self.board:Neighbors(assert(self.board:Find(target.Q, target.R)))) do
                    if previous[cell] then
                        local path, cursor = {}, cell
                        while previous[cursor] do table.insert(path, 1, cursor); cursor = previous[cursor] end
                        if not bestPath or #path < #bestPath then bestPath = path end
                    end
                end
            end
        end
        if bestPath then
            local destination = bestPath[math.min(#bestPath, self.stats:Template(actor).moveRange)]
            self:TryMove(destination.q, destination.r)
        end
        attack()
    end
    if self.data.Winner ~= '' then return true end
    for _, skillId in ipairs(self.stats:Template(actor).skillIds) do
        if self.skills:Get(skillId).target == 'self' and self:CanUseSkill(skillId, actor.Id) then self:TrySkill(skillId, actor.Id); break end
    end
    return self:EndTurn()
end
function Battle:OnShutdown()
    -- 注册器也会回收 OnInit 尚未完成的实例；只释放已经取得的资源。
    if self.Changed then self.Changed:Clear(); self.Changed = nil end
    self.board = nil
    if self.data then self.data:Clear(); self.data = nil end
end
return Battle
