-- 移动前的近战反应；只查询当前占位，不保存交战关系或另一份行动预算。
local Trajectory=require('Game.Battle.SkillTrajectory')
local Projectiles=require('Game.Battle.ProjectileCombat')
local Context=require('Game.Battle.SkillContext')
local Attacks={}
function Attacks.Validate(battle,skill)
    if not skill.opportunityAttack then return end
    assert(skill.target=='enemy' and skill.range==1 and skill.minRange<=1 and skill.trajectory=='sight'
        and skill.shots==1 and skill.ammoPerShot==0 and skill.catalystKind=='none' and Context(skill,'battle')
        and not battle.stats.animals.bySkill[skill.id], 'Opportunity attack requires an ordinary melee skill: '..skill.id)
    local damage=false
    for _,id in ipairs(skill.effectIds) do
        local effect=battle.effects:Get(id)
        if effect.kind=='damage' and effect.recipient~='source' then damage=true end
    end
    assert(damage,'Opportunity attack needs target damage: '..skill.id)
end
function Attacks.Skill(battle,source,target)
    if source.HP<=0 or target.HP<=0 or source.AnimalOwnerId~=0 or not battle:IsHostile(source,target)
        or battle.stats.buffs:Skipping(source) or battle.stats.animals:Distance(source,target,battle.board)~=1 then return end
    local selected
    for _,id in ipairs(battle:SkillIds(source)) do
        if battle.skills:Get(id).opportunityAttack then
            local skill=battle:Skill(source,id)
            if skill.minRange<=1 and skill.range>=1 and battle.stats.equipment:CheckSkillEquipment(source,skill,battle.stats)
                and Trajectory.CanReach(battle.board,assert(battle.board:Find(source.Q,source.R)),
                    assert(battle.board:Find(target.Q,target.R)),skill.trajectory,nil,skill.guided) then
                -- 双持只追加一击，主手优先；相同类别按配置 ID 稳定选择。
                if not selected or skill.action=='main' and selected.action~='main'
                    or skill.action==selected.action and skill.id<selected.id then selected=skill end
            end
        end
    end
    return selected
end
function Attacks.Candidates(battle,target)
    local result={}
    if battle.data.Phase~='combat' or battle.data.Winner~='' or target.HP<=0 then return result end
    for _,source in ipairs(battle:Units()) do
        local skill=Attacks.Skill(battle,source,target)
        if skill then result[#result+1]={source=source,skill=skill} end
    end
    table.sort(result,function(a,b)return a.source.Id<b.source.Id end)
    return result
end
function Attacks.Execute(battle,source,target,skill)
    local program={}
    skill.professionReaction=true
    skill.name='借机攻击 · '..skill.name
    for _,id in ipairs(skill.effectIds) do program[#program+1]=battle.gameEffects:Prepare(id,source,target,skill) end
    Projectiles.PrepareProgram(battle,source,skill,program)
    -- 反应独立于回合 AP、主行动与冷却；武器使用磨损仍走原结算。
    battle.stats.equipment:Consume(source,skill)
    source:RecordAction(skill.actionTemplate,1,target.Q,target.R)
    battle:Emit('opportunity_attack',skill.name,source.Id,target.Id,0,target,false,{actionName=skill.name})
    battle:ApplyEffectProgram(source,skill,program,1)
end
function Attacks.Resolve(battle,target)
    local count=0
    for _,entry in ipairs(Attacks.Candidates(battle,target)) do
        -- 上一击可能令坐骑死亡、改变占地或状态，不能直接复用候选技能。
        local skill=Attacks.Skill(battle,entry.source,target)
        if skill then
            Attacks.Execute(battle,entry.source,target,skill);count=count+1
            if battle:CheckWinner() or target.HP<=0 or battle.stats.buffs:Skipping(target) then break end
        end
    end
    return count
end
return Attacks
