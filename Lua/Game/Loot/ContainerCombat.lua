-- 容器是场景目标，不伪装为战斗角色；共用技能预算、伤害公式和原库存。
local Hex=require('Game.Map.HexGrid')
local Random=require('Game.Map.SeededRandom')
local Combat={};Combat.__index=Combat
function Combat.New(adventure)
    local self=setmetatable({adventure=adventure,loot=adventure.equipment.worldLoot},Combat)
    local config=adventure.config
    for _,row in ipairs(self.loot.rules.containers:All()) do
        assert(#row.footprintQ>0 and #row.footprintQ==#row.footprintR and row.footprintQ[1]==0 and row.footprintR[1]==0,'Invalid container footprint')
        local seen={}
        for i,q in ipairs(row.footprintQ) do local key=Hex.Key(q,row.footprintR[i]);assert(not seen[key],'Duplicate container footprint');seen[key]=true end
        assert(row.interaction~='break' or row.maxDurability>0,'Break-only container needs durability')
        assert(row.interaction~='tool' or row.toolTag~='','Tool container needs a tool tag')
        if row.toolTag~='' then adventure.equipment.rules.tags:Get(row.toolTag) end
        for _,id in ipairs({row.assetId,row.openedAssetId,row.brokenAssetId,row.emptyAssetId}) do if id>0 then adventure.equipment.rules.assets:Get(id) end end
    end
    for _,skill in ipairs(config:GetTable('CombatSkillTable'):All()) do if skill.affectsContainers then
        assert(skill.target=='enemy','Container damage requires an attack skill')
        local damage=false
        for _,id in ipairs(skill.effectIds) do local effect=config:GetTable('CombatEffectTable'):Get(id)
            if effect.kind=='damage' and effect.duration=='instant' then damage=true end
        end
        assert(damage,'Container attack requires immediate damage: '..skill.id)
    end end
    return self
end
local function visible(self,state,physical)
    -- 技能栏会查询多种技能/容器；同一版本只跨桥接读取一次可见集合。
    local revision=state.Revision
    if self.visibleState~=state or self.visibleRevision~=revision then
        local cells={};for i=0,state.VisibleCount-1 do cells[state:GetVisibleAt(i)]=true end
        self.visibleState=state;self.visibleRevision=revision;self.visibleCells=cells
    end
    for j=0,physical.CellCount-1 do if self.visibleCells[physical:GetCellAt(j)] then return true end end
    return false
end
function Combat:Origin(actor,battle)
    local areas=self.adventure.areas;local area,state=areas:ActiveLayout(),areas.data.Active
    if battle then return battle.board:Find(actor.Q,actor.R) end
    for i=0,state.MemberCount-1 do if state:GetMemberIdAt(i)==actor.Id then return area.cells[state:GetMemberCellAt(i)] end end
end
function Combat:Target(actor,skill,id,battle)
    if not skill.affectsContainers then return false,'此技能不能破坏容器' end
    if self.adventure.data.Areas.ActiveSiteId==0 then return false,'当前没有可攻击的场景容器' end
    local areas=self.adventure.areas;local area,state=areas:ActiveLayout(),areas.data.Active
    if battle and (not battle.board.area or battle.board.area.containerState~=state) then return false,'当前战场没有可破坏容器' end
    local container=self.loot:Find(areas,id)
    if not container then return false,'请选择容器' end
    local physical=self.loot:SyncLock(state,container)
    if physical.MaxDurability==0 or physical.Destroyed then return false,'这个容器不能继续破坏' end
    if not physical.Unlocked then return false,'清除守卫后才能打开或破坏这个容器' end
    if not visible(self,state,physical) then return false,'容器不在当前视野内' end
    local origin=self:Origin(actor,battle)
    if not origin then return false,'角色没有参与当前探索' end
    local board=battle and battle.board or area
    local parts=assert(self.adventure.battle.stats.animals:Cells(actor,board,origin.q,origin.r,origin.layer))
    local best,distance
    for i=0,physical.CellCount-1 do local target=area.cells[physical:GetCellAt(i)]
        if target.layer==origin.layer and (not battle or battle.board.byIndex[target.index]) then
            local bonus=battle and battle.construction and battle.construction:RangeBonusAt(battle.board,actor,target,skill) or 0
            for _,part in ipairs(parts) do local range=Hex.Distance(part.q,part.r,target.q,target.r)
                if range<=skill.range+bonus and area:CanSee(part,target) and (not distance or range<distance) then best,distance=target,range end
            end
        end
    end
    if not best then return false,'容器超出射程、位于其他楼层或被遮挡' end
    return true,nil,container,best
end
function Combat:Prepare(actor,skill,container)
    local battle=self.adventure.battle;local definition=self.loot.rules.containers:Get(container.TableId)
    local values={defense=definition.structuralDefense,guard=0,distance=0,proficiency=battle.stats:Get(actor,skill.proficiency)}
    for _,name in ipairs({'vitality','endurance','intellect','strength','speed'}) do values[name]=battle.stats:Get(actor,name) end
    local effects={}
    for _,id in ipairs(skill.effectIds) do local effect=battle.gameEffects.definitions:Get(id)
        if effect.kind=='damage' and effect.duration=='instant' then effects[#effects+1]=battle.gameEffects:Magnitude(effect,values,skill) end
    end
    return {container=container,physical=self.loot:Physical(container),effects=effects}
end
function Combat:Splash(actor,skill,center,exceptId,limit,battle)
    local plans={}
    if skill.splashRadius<=0 or limit<=0 then return plans end
    local area,state=self.adventure.areas:ActiveLayout(),self.adventure.areas.data.Active
    local candidates={}
    for i=0,state.LootCount-1 do local container=state:GetLootAt(i)
        if container.Id~=exceptId then
            local ok,_,_,cell=self:Target(actor,skill,container.Id,battle)
            if ok and cell.layer==center.layer then
                local distance=math.huge;local physical=self.loot:Physical(container)
                for j=0,physical.CellCount-1 do local part=area.cells[physical:GetCellAt(j)]
                    distance=math.min(distance,Hex.Distance(center.q,center.r,part.q,part.r))
                end
                if distance<=skill.splashRadius then candidates[#candidates+1]={container=container,distance=distance} end
            end
        end
    end
    table.sort(candidates,function(a,b)return a.distance<b.distance or a.distance==b.distance and a.container.Id<b.container.Id end)
    for i=1,math.min(limit,#candidates) do plans[#plans+1]=self:Prepare(actor,skill,candidates[i].container) end
    return plans
end
function Combat:Apply(plans,actor,skill,roll,battle)
    local state=self.adventure.areas.data.Active
    for _,plan in ipairs(plans) do
        for _,amount in ipairs(plan.effects) do if not plan.physical.Destroyed then
            local hit=skill.hitChance==100 or roll()<skill.hitChance
            if hit then
                local actual=CS.ProjectY.Data.ContainerState.Hit(state,plan.container.Id,amount)
                if plan.physical.Destroyed and not plan.container.Looted then
                    local remaining=false
                    for i=0,plan.container.ItemCount-1 do if plan.container:GetCountAt(i)>0 then remaining=true;break end end
                    if not remaining then state:Loot(plan.container.Id) end
                end
                if battle then battle:Emit('container_damage',skill.name..' → '..plan.container.Name..'（耐久 -'..actual..'）'..(plan.physical.Destroyed and ' 已破坏' or ''),actor.Id) end
            elseif battle then battle:Emit('miss',skill.name..' 未命中 '..plan.container.Name,actor.Id) end
        end end
    end
end
function Combat:CanBattle(battle,skillId,id)
    local ok,reason=battle:SkillBudget(skillId);if not ok then return false,reason end
    return self:Target(battle:Active(),battle:Skill(battle:Active(),skillId),id,battle)
end
function Combat:Battle(battle,skillId,id)
    local ok,reason,container,cell=self:CanBattle(battle,skillId,id);if not ok then return false,reason end
    local actor=battle:Active();local skill=battle:Skill(actor,skillId)
    local plans={self:Prepare(actor,skill,container)}
    for _,plan in ipairs(self:Splash(actor,skill,cell,id,skill.maxTargets-1,battle)) do plans[#plans+1]=plan end
    local program={};local remaining=skill.maxTargets-#plans
    if remaining>0 and skill.splashRadius>0 then
        local targets={}
        for _,unit in ipairs(battle:Units()) do
            if battle:CanUseSkill(skillId,unit.Id) and Hex.Distance(cell.q,cell.r,unit.Q,unit.R)<=skill.splashRadius then targets[#targets+1]=unit end
        end
        table.sort(targets,function(a,b)
            local da,db=Hex.Distance(cell.q,cell.r,a.Q,a.R),Hex.Distance(cell.q,cell.r,b.Q,b.R)
            return da<db or da==db and a.Id<b.Id
        end)
        for i=1,math.min(remaining,#targets) do for _,effect in ipairs(skill.effectIds) do
            program[#program+1]=battle.gameEffects:Prepare(effect,actor,targets[i],skill)
        end end
    end
    actor:SpendAction(skill.action,skill.cost);battle.stats.equipment:Consume(actor,skill);actor:SetCooldown(skillId,skill.cooldownTurns)
    actor:RecordAction(skill.actionTemplate,skill.shots,cell.q,cell.r)
    for shot=1,skill.shots do
        self:Apply(plans,actor,skill,function()return battle.data:RollPercent()end,battle)
        for _,effect in ipairs(program) do if effect.target.HP>0 and (effect.definition.kind~='damage' or skill.hitChance==100 or battle.data:RollPercent()<skill.hitChance) then
            battle.gameEffects:ApplyPrepared(effect,{shot=shot})
        end end
    end
    battle:CheckWinner();return true
end
function Combat:CanArea(actor,skillId,id)
    local adventure=self.adventure;local battle=adventure.battle
    if adventure.data.Phase~='area' or self.loot.session.Active then return false,'当前不能攻击容器' end
    if actor.HP<=0 then return false,'角色已倒地' end
    local owns=false;for _,skill in ipairs(battle:SkillIds(actor)) do if skill==skillId then owns=true;break end end
    if not owns then return false,'角色没有这个技能' end
    local skill=battle:Skill(actor,skillId)
    if not require('Game.Battle.SkillContext')(skill,'life') then return false,'此技能不能用于探索' end
    if actor:GetCooldown(skillId)>0 then return false,'技能仍在冷却中' end
    local ok,reason=battle.stats.equipment:CheckAmmo(actor,skill);if not ok then return false,reason end
    return self:Target(actor,skill,id)
end
function Combat:Area(actor,skillId,id)
    local ok,reason,container,cell=self:CanArea(actor,skillId,id);if not ok then return false,reason end
    local adventure=self.adventure;local battle,areas=adventure.battle,adventure.areas;local skill=battle:Skill(actor,skillId)
    local plans={self:Prepare(actor,skill,container)}
    for _,plan in ipairs(self:Splash(actor,skill,cell,id,skill.maxTargets-1)) do plans[#plans+1]=plan end
    local random=Random((areas:ActiveLayout().seed ~ (areas.data.Active.WorldRound*65537) ~ actor.Id*719 ~ id*104729) & 0xffffffff)
    areas:Stop();battle.stats.equipment:Consume(actor,skill);actor:RecordAction(skill.actionTemplate,skill.shots,cell.q,cell.r)
    for _=1,skill.shots do self:Apply(plans,actor,skill,function()return random:Integer(0,9999)/100 end) end
    areas:SpendWorkRounds(1);actor:SetCooldown(skillId,skill.cooldownTurns)
    if areas:RefreshLivingSquad() then areas:RevealSquad(areas:ActiveLayout(),areas.data.Active) end
    return true
end
function Combat:Targets(actor,skillId,battle)
    local result={}
    if self.adventure.data.Areas.ActiveSiteId==0 then return result end
    if not self.adventure.battle.skills:Get(skillId).affectsContainers then return result end
    local state=self.adventure.areas.data.Active
    for i=0,state.LootCount-1 do local container=state:GetLootAt(i)
        local ok=battle and self:CanBattle(battle,skillId,container.Id) or not battle and self:CanArea(actor,skillId,container.Id)
        if ok then result[#result+1]=container.Id end
    end
    return result
end
return Combat
