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
    self.stats = require('Game.Battle.CombatStats')(config,assert(adventure.Equipment,'Equipment data requires regenerated xLua bindings'))
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
    self.data:SetRandomSeed(seed)
    self.board = board
    for i, unit in ipairs(party) do self.data:AddUnit(unit, 1, -board.radius, i - 1) end
    for i, templateId in ipairs(encounter.enemyIds) do
        local unit = self.data:AddEnemy(100 + i, templateId, board.radius, 1 - i)
        unit:SetMaxHP(self.stats:MaximumHP(unit)); unit:Restore()
    end
    self:Emit('battle_started', encounter.name)
    self:NewRound()
end
-- 地牢保持双方真实位置与角色实例；首版只接单层地牢，不折叠桥上/桥下坐标。
function Battle:StartArea(encounterId, board, party, enemies)
    local encounter = self.encounters:Get(encounterId)
    assert(board.area and #party > 0 and #party <= 4 and #enemies > 0 and #enemies <= 4, 'Invalid area battle deployment')
    for _, cell in ipairs(board.cells) do assert(cell.layer == 0, 'Layered area combat is not supported') end
    local occupied, ids = {}, {}
    local function check(actor, q, r)
        local cell = assert(board:Find(q, r), 'Actor outside area battle window')
        local key = Hex.Key(q, r)
        assert(actor.HP > 0 and not cell.blocked and not occupied[key] and not ids[actor.Id], 'Invalid area combat position')
        occupied[key], ids[actor.Id] = true, true
    end
    for _, row in ipairs(party) do check(row.actor, row.q, row.r) end
    for _, actor in ipairs(enemies) do check(actor, actor.Q, actor.R) end
    self.data:Reset(encounterId, encounter.maxRounds); self.board = board
    self.data:SetRandomSeed((board.area.seed + enemies[1].Id * 1009)%4294967296)
    for _, row in ipairs(party) do self.data:AddUnit(row.actor, 1, row.q, row.r) end
    for _, actor in ipairs(enemies) do self.data:AddUnit(actor, 2, actor.Q, actor.R) end
    self:Emit('battle_started', encounter.name); self:NewRound()
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
    if self.board.externalOccupied then
        for key in pairs(self.board.externalOccupied) do occupied[key] = true end
    end
    for _, unit in ipairs(self:Units()) do
        if unit.HP > 0 and unit.Id ~= exceptId then occupied[Hex.Key(unit.Q, unit.R)] = unit end
    end
    return occupied
end
function Battle:Reachable()
    if self.data.Winner ~= '' then return {} end
    local unit = self:Active(); local template = self.stats:Template(unit)
    if unit.Moved or unit.AP < template.moveCost then return {} end
    local cells = self.board:Search(unit.Q, unit.R, self:Occupied(unit.Id), template.moveRange,
        unit.Team == 1 and self.board.allowed or nil)
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
function Battle:SkillIds(actor) return self.stats.equipment:SkillIds(actor,self.stats:Template(actor)) end
function Battle:Skill(actor,skillId) return self.stats.equipment:Skill(actor,skillId) end
function Battle:SkillBudget(skillId)
    if self.data.Winner ~= '' then return false, '战斗已经结束' end
    local source=self:Active();local skill=self:Skill(source,skillId)
    local owns = false
    for _, id in ipairs(self:SkillIds(source)) do if id == skillId then owns = true; break end end
    if not owns then return false, '角色没有这个技能' end
    if skill.action == 'main' and source.MainUsed then return false, '本回合主要行动已使用' end
    if source.AP < skill.cost then return false, '行动点不足' end
    if skill.cooldownTurns>0 and source:GetCooldown(skillId)>0 then return false,'技能冷却中：'..source:GetCooldown(skillId) end
    return self.stats.equipment:CheckAmmo(source,skill)
end
function Battle:CanUseSkill(skillId, targetId)
    local ok,reason=self:SkillBudget(skillId)
    if not ok then return false,reason end
    local source=self:Active();local skill=self:Skill(source,skillId)
    local target = self:FindUnit(targetId)
    if not target or target.HP <= 0 then return false, '请选择存活的目标' end
    if skill.target == 'self' and target.Id ~= source.Id then return false, '只能对自己使用' end
    if skill.target == 'enemy' and target.Team == source.Team then return false, '请选择敌人' end
    if skill.target == 'ally' and target.Team ~= source.Team then return false, '请选择友军' end
    if Hex.Distance(source.Q, source.R, target.Q, target.R) > skill.range then return false, '目标超出射程' end
    if self.board.area and not self.board.area:CanSee(assert(self.board:Find(source.Q, source.R)), assert(self.board:Find(target.Q, target.R))) then
        return false, '墙壁或陈设遮挡了目标'
    end
    return true
end
function Battle:TrySkill(skillId, targetId)
    local ok, reason = self:CanUseSkill(skillId, targetId)
    if not ok then return false, reason end
    local source, target = self:Active(), self:FindUnit(targetId)
    local skill = self:Skill(source,skillId)
    local targets={target}
    if skill.maxTargets>1 then
        local others={}
        for _,unit in ipairs(self:Units()) do
            if unit.Id~=target.Id and Hex.Distance(target.Q,target.R,unit.Q,unit.R)<=skill.splashRadius
                and self:CanUseSkill(skillId,unit.Id) then others[#others+1]=unit end
        end
        table.sort(others,function(a,b)
            local da,db=Hex.Distance(target.Q,target.R,a.Q,a.R),Hex.Distance(target.Q,target.R,b.Q,b.R)
            return da==db and a.Id<b.Id or da<db
        end)
        for i=1,math.min(#others,skill.maxTargets-1) do targets[#targets+1]=others[i] end
    end
    local program={}
    -- 先完整校验效果，配置错误不会在扣除行动点后才暴露。
    for _,victim in ipairs(targets) do
      local values=self.stats:EffectVariables(source,victim,skill)
      for _, id in ipairs(skill.effectIds) do
        local effect = self.effects:Get(id)
        local amount = effect.amount:Evaluate(values)
        assert(amount >= 0 and amount <= 1000000 and amount == math.floor(amount), 'Invalid effect amount: ' .. id)
        assert(effect.kind == 'damage' or effect.kind == 'heal' or effect.kind == 'guard' or effect.kind=='reload', 'Unknown combat effect: ' .. effect.kind)
        if effect.kind=='damage' and amount>0 then amount=math.max(1,math.floor(amount*skill.damageScale)) end
        program[#program + 1] = {kind = effect.kind, amount = amount,target=victim}
      end
    end
    source:SpendAction(skill.action, skill.cost)
    self.stats.equipment:Consume(source,skill)
    source:SetCooldown(skillId,skill.cooldownTurns)
    source:RecordAction(skill.actionTemplate,skill.shots,target.Q,target.R)
    for shot=1,skill.shots do
    for _, effect in ipairs(program) do
      local target=effect.target
      if target.HP>0 then
        local wasAlive = target.HP > 0
        local amount = effect.amount
        local hit=effect.kind~='damage' or skill.hitChance==100 or self.data:RollPercent()<skill.hitChance
        if not hit then self:Emit('miss',self.stats:Template(source).name..' · '..skill.name..' 未命中 '..self.stats:Template(target).name,source.Id,target.Id)
        else
        if effect.kind == 'damage' then amount = target:Damage(amount)
        elseif effect.kind == 'heal' then amount = target:Heal(amount)
        elseif effect.kind=='guard' then target:SetGuard(amount)
        else amount=self.stats.equipment:Loaded(self.stats.equipment:Weapon(source)).Rounds end
        local verb = ({damage = '伤害', heal = '治疗', guard = '防御',reload='装入子弹'})[effect.kind]
        self:Emit(effect.kind, self.stats:Template(source).name .. ' · ' .. skill.name .. ' → ' .. self.stats:Template(target).name .. '（' .. verb .. ' ' .. amount .. '）', source.Id, target.Id, amount)
        if wasAlive and target.HP == 0 then self:Emit('defeated', self.stats:Template(target).name .. ' 倒地', source.Id, target.Id) end
        end
      end
    end
    end
    self:CheckWinner(); return true
end
-- AI 也通过同一套移动/技能命令执行，每次调用只推进一个敌方角色的回合。
function Battle:StepAI()
    if self.data.Winner ~= '' then return false, '战斗已经结束' end
    local actor = self:Active()
    if actor.Team ~= 2 then return false, '等待玩家行动' end
    local function attack()
        for _, skillId in ipairs(self:SkillIds(actor)) do
            if self:Skill(actor,skillId).target == 'enemy' then
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
    for _, skillId in ipairs(self:SkillIds(actor)) do
        if self:Skill(actor,skillId).target == 'self' and self:CanUseSkill(skillId, actor.Id) then self:TrySkill(skillId, actor.Id); break end
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
