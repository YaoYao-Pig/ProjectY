-- Shared, read-only shot queries and per-projectile interception. Mutable health stays in C# Data.
local Trajectory=require('Game.Battle.SkillTrajectory')
local Instructions=require('Game.Battle.EffectInstructions')
local Shots={}
function Shots.Profile(battle,source,skill,target,context,victim)
    local board=context and context.board or battle.board
    local origin=context and context.origin or assert(board:Find(source.Q,source.R))
    local occupied={}
    if skill.trajectory~='sight' and not skill.guided then
        occupied=context and context.occupied(victim) or battle:ShotOccupancy(source,victim)
    end
    local trace=Trajectory.Trace(board,origin,target,skill.trajectory,occupied,skill.guided)
    local chance=skill.target=='enemy' and skill.hitChance or 100
    if skill.target=='enemy' and (board.area or board.CanTrace) then chance=battle.stats.heightAdvantage:HitChance(origin,target,skill) end
    local reach=1;local friendly=false;local names={}
    for _,blocker in ipairs(trace.blockers)do
        local rule=battle.stats.projectileCover
        blocker.chance=blocker.kind=='actor' and rule.actorChance or rule.objectChance
        reach=reach*(1-blocker.chance/100)
        if blocker.chance>0 and blocker.actor and blocker.actor.Team==source.Team then friendly=true end
        names[#names+1]=blocker.actor and battle.stats:Template(blocker.actor).name or blocker.name or '障碍物'
    end
    local effective=trace.reachable and chance*reach or 0
    local description=string.format('命中目标 %.1f%%',effective)
    if #trace.blockers>0 then
        description=description..string.format(' · 被拦截 %.1f%%：%s',(1-reach)*100,table.concat(names,'、'))
        if friendly then description=description..' · 可能误伤友军' end
    elseif skill.guided then description=description..' · 追踪绕过遮挡' end
    return {reachable=trace.reachable,blockers=trace.blockers,baseHitChance=chance,hitChance=effective,
        interceptChance=(1-reach)*100,blockerCount=#trace.blockers,friendlyRisk=friendly,description=description}
end
function Shots.ObjectDamage(battle,source,skill,defense)
    local values={defense=defense,guard=0,distance=0,proficiency=battle.stats:Get(source,skill.proficiency)}
    setmetatable(values,{__index=function(_,name)
        if name=='sourceMissingHealth' then return math.max(0,source.MaxHP-source.HP) end
        if name=='sourceHealthPercent' then return 100*source.HP/source.MaxHP end
    end})
    for _,name in ipairs({'vitality','endurance','intellect','strength','speed'})do values[name]=battle.stats:Get(source,name) end
    local amounts={}
    for _,id in ipairs(skill.effectIds)do local effect=battle.gameEffects.definitions:Get(id)
        if Instructions.ContainerDamage(effect)then amounts[#amounts+1]=battle.gameEffects:Magnitude(effect,values,skill) end
    end
    return amounts
end
function Shots.PrepareBlockers(battle,source,skill,profile)
    local prepared={}
    for _,blocker in ipairs(profile.blockers)do
        local plan={}
        if blocker.kind=='actor' then
            for _,id in ipairs(skill.effectIds)do plan[#plan+1]=battle.gameEffects:Prepare(id,source,blocker.actor,skill) end
        elseif blocker.kind=='container' then
            plan=assert(battle.containerCombat,'Container projectile needs its combat adapter'):Prepare(source,skill,blocker.container)
        elseif blocker.kind=='construction' then plan=Shots.ObjectDamage(battle,source,skill,0) end
        prepared[blocker.key]=plan
    end
    return prepared
end
function Shots.Intercept(profile,roll)
    assert(profile.reachable,'Cannot resolve a shot outside its valid geometry')
    for _,blocker in ipairs(profile.blockers)do
        if blocker.chance==100 or blocker.chance>0 and roll()<blocker.chance then return blocker end
    end
end
function Shots.Hit(profile,roll) return profile.baseHitChance==100 or roll()<profile.baseHitChance end
function Shots.ApplyActor(battle,source,program,impact)
    -- A successful hit authorizes all effects for this projectile, including source benefits after a lethal hit.
    for _,effect in ipairs(program)do
        if source.HP<=0 then break end
        if effect.target.HP>0 then battle.gameEffects:ApplyPrepared(effect,impact) end
    end
end
function Shots.ApplyBlocker(battle,source,skill,blocker,prepared,impact,context)
    local name=blocker.actor and battle.stats:Template(blocker.actor).name or blocker.name or '障碍物'
    battle:Emit('intercepted',skill.name..' 被 '..name..' 拦截',source.Id,blocker.actor and blocker.actor.Id)
    if blocker.kind=='actor' then
        Shots.ApplyActor(battle,source,assert(prepared[blocker.key],'Unprepared interception target'),impact)
    elseif blocker.kind=='container' then
        battle.containerCombat:ApplyDamage(assert(prepared[blocker.key]),source,skill,battle)
    elseif blocker.kind=='construction' then
        local board=context and context.board or battle.board
        local construction=assert((board.area or board).construction)
        for _,amount in ipairs(assert(prepared[blocker.key]))do
            if amount>0 and not blocker.record.Removed and blocker.record.MaxHP>0 then
                local actual=construction.data:Damage(blocker.record.SiteId,blocker.record.CellIndex,amount)
                battle:Emit('construction',name..' 受到 '..actual..' 点结构伤害'..(blocker.record.Removed and '，已破坏' or ''),source.Id)
            end
        end
    end
end
function Shots.PrepareProgram(battle,source,skill,program)
    local groups,byId={},{}
    for _,effect in ipairs(program)do
        local victim=effect.hitTarget or effect.target;local group=byId[victim.Id]
        if not group then group={victim=victim,effects={}};byId[victim.Id]=group;groups[#groups+1]=group end
        group.effects[#group.effects+1]=effect
    end
    if skill.target=='enemy' and (skill.trajectory=='direct' or skill.trajectory=='lobbed') and not skill.guided then
        for _,group in ipairs(groups)do
            local profile=Shots.Profile(battle,source,skill,assert(battle.board:Find(group.victim.Q,group.victim.R)),nil,group.victim)
            assert(profile.reachable,'Prepared skill target became unreachable')
            group.interceptions=Shots.PrepareBlockers(battle,source,skill,profile)
        end
    end
    program.shotGroups=groups;return program
end
function Shots.ApplyProgram(battle,source,skill,program,shot)
    local groups=program.shotGroups or Shots.PrepareProgram(battle,source,skill,program).shotGroups
    for _,group in ipairs(groups)do
        if source.HP<=0 then break end
        local victim=group.victim
        if victim.HP>0 then
            if skill.target~='enemy' then Shots.ApplyActor(battle,source,group.effects,{shot=shot})
            else
                local profile
                if (skill.trajectory=='direct' or skill.trajectory=='lobbed') and not skill.guided then
                    profile=Shots.Profile(battle,source,skill,assert(battle.board:Find(victim.Q,victim.R)),nil,victim)
                else
                    local chance=skill.hitChance
                    if battle.board.area then chance=battle.stats.heightAdvantage:HitChance(battle.board:Find(source.Q,source.R),battle.board:Find(victim.Q,victim.R),skill) end
                    profile={reachable=true,blockers={},baseHitChance=chance}
                end
                local roll=function()return battle.data:RollPercent()end
                local blocker=profile.reachable and Shots.Intercept(profile,roll)
                if blocker then Shots.ApplyBlocker(battle,source,skill,blocker,assert(group.interceptions),{shot=shot})
                elseif profile.reachable and Shots.Hit(profile,roll)then Shots.ApplyActor(battle,source,group.effects,{shot=shot})
                else battle:Emit('miss',battle.stats:Template(source).name..' · '..skill.name..' 未命中 '..battle.stats:Template(victim).name,source.Id,victim.Id) end
            end
        end
    end
end
return Shots
