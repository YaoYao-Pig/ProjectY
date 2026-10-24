-- Optional encounter-owned policy; mutable health, movement and action budgets remain on actors.
local Hex=require('Game.Map.HexGrid')
local Preservation={}
local function distance(parts,others)
    local nearest=math.huge
    for _,a in ipairs(parts) do for _,b in ipairs(others) do
        nearest=math.min(nearest,Hex.Distance(a.q,a.r,b.q,b.r))
    end end
    return nearest
end
local function guardSkill(battle,actor)
    local selected
    for _,id in ipairs(battle:SkillIds(actor)) do
        local skill=battle:Skill(actor,id)
        if (skill.target=='self' or skill.target=='ally' or skill.target=='any') and battle:CanUseSkill(id,actor.Id) then
            for _,effectId in ipairs(skill.effectIds) do
                if battle.effects:Get(effectId).kind=='guard' then
                    if not selected or skill.cost<selected.cost or skill.cost==selected.cost and skill.id<selected.id then selected=skill end
                    break
                end
            end
        end
    end
    return selected
end
function Preservation.Step(battle,actor,enemies)
    local profiles=battle.board.aiProfiles
    local profile=profiles and profiles[actor.Id]
    if not profile or not profile.selfPreservation or actor.Team==1 or not battle:IsAllied(1,actor) then return false end
    local ratio=profile.retreatHealthRatio
    assert(type(ratio)=='number' and ratio>0 and ratio<=1,'Self-preservation requires retreatHealthRatio in (0,1]')
    if actor.HP>actor.MaxHP*ratio then return false end
    local round=battle.data.Round
    local guard=guardSkill(battle,actor)
    local moveCost=CS.ProjectY.Data.BattleMovement.Spent(actor)==0 and battle.stats:Template(actor).moveCost or 0
    -- Retreat never provokes known melee reactions and preserves the AP needed to guard afterwards.
    if #battle:OpportunityAttackers(actor)==0 and (not guard or actor.AP>=moveCost+guard.cost) then
        local allies,hostiles={},{}
        for _,other in ipairs(battle:Units()) do
            if other.HP>0 and other.Id~=actor.Id and battle:IsAllied(actor,other) then
                for _,cell in ipairs(assert(battle.stats.animals:Cells(other,battle.board))) do allies[#allies+1]=cell end
            end
        end
        for _,enemy in ipairs(enemies) do
            for _,cell in ipairs(assert(battle.stats.animals:Cells(enemy,battle.board))) do hostiles[#hostiles+1]=cell end
        end
        if #allies>0 then
            local origin=assert(battle.stats.animals:Cells(actor,battle.board))
            local allyDistance,enemyDistance=distance(origin,allies),distance(origin,hostiles)
            local reachable,costs=battle:Reachable()
            local best,bestAlly,bestEnemy,bestCost
            for _,cell in ipairs(reachable) do
                local parts=assert(battle.stats.animals:Cells(actor,battle.board,cell.q,cell.r,cell.layer))
                local nearAlly,nearEnemy=distance(parts,allies),distance(parts,hostiles)
                local cost=costs[cell]
                if nearAlly<allyDistance and nearEnemy>=enemyDistance and
                    (not best or nearAlly<bestAlly or nearAlly==bestAlly and
                        (nearEnemy>bestEnemy or nearEnemy==bestEnemy and
                            (cost<bestCost or cost==bestCost and (cell.q<best.q or cell.q==best.q and cell.r<best.r)))) then
                    best,bestAlly,bestEnemy,bestCost=cell,nearAlly,nearEnemy,cost
                end
            end
            if best then
                battle:TryMove(best.q,best.r)
                if battle.data.Winner~='' or battle.data.ActiveId~=actor.Id or battle.data.Round~=round then return true end
            end
        end
    end
    if guard and battle:CanUseSkill(guard.id,actor.Id) then battle:TrySkill(guard.id,actor.Id) end
    if battle.data.Winner=='' and battle.data.ActiveId==actor.Id and battle.data.Round==round then battle:EndTurn() end
    return true
end
return Preservation
