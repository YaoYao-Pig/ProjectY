-- Shared, read-only shot queries and per-projectile interception. Mutable health stays in C# Data.
local Trajectory=require('Game.Battle.SkillTrajectory')
local Instructions=require('Game.Battle.EffectInstructions')
local VisualEffects=require('Game.Presentation.VisualEffects')
local LuaLanguage=require('Language')
local Shots={}
local function needsHit(battle,source,skill,victim)
    if skill.target=='enemy' then return true end
    if skill.target~='any' or not victim then return false end
    if battle.IsAllied then return not battle:IsAllied(source,victim)end
    return source.Team~=victim.Team
end
function Shots.Profile(battle,source,skill,target,context,victim)
    local board=context and context.board or battle.board
    local origin=context and context.origin or assert(board:Find(source.Q,source.R))
    local occupied={}
    if skill.trajectory~='sight' and not skill.guided then
        occupied=context and context.occupied(victim) or battle:ShotOccupancy(source,victim)
    end
    local trace=Trajectory.Trace(board,origin,target,skill.trajectory,occupied,skill.guided)
    local hostile=needsHit(battle,source,skill,victim)
    local chance=hostile and skill.hitChance or 100
    if hostile and (board.area or board.CanTrace) then chance=battle.stats.heightAdvantage:HitChance(origin,target,skill) end
    local reach=1;local friendly=false;local names={}
    for _,blocker in ipairs(trace.blockers)do
        local rule=battle.stats.projectileCover
        blocker.chance=blocker.kind=='actor' and rule.actorChance or rule.objectChance
        reach=reach*(1-blocker.chance/100)
        if blocker.chance>0 and blocker.actor then
            local inBattle=board==battle.board and battle.IsAllied
            local allied=inBattle and battle:IsAllied(source,blocker.actor) or not inBattle and blocker.actor.Team==source.Team
            if allied then friendly=true end
        end
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
function Shots.Intercept(profile,roll,onCheck)
    assert(profile.reachable,'Cannot resolve a shot outside its valid geometry')
    for _,blocker in ipairs(profile.blockers)do
        local value=blocker.chance>0 and blocker.chance<100 and roll() or nil
        local passed=blocker.chance==100 or blocker.chance>0 and value<blocker.chance
        if onCheck then onCheck(blocker,value,passed)end
        if passed then return blocker end
    end
end
function Shots.Hit(profile,roll,onCheck)
    local value=profile.baseHitChance~=100 and roll() or nil
    local passed=profile.baseHitChance==100 or value<profile.baseHitChance
    if onCheck then onCheck(value,passed)end
    return passed
end
function Shots.ApplyActor(battle,source,program,impact)
    local professionSkill=program[1] and program[1].skill
    local professionContext
    if battle.professions and professionSkill then
        local target=program[1].hitTarget or program[1].target
        local actual=battle.professions:Redirect(source,professionSkill,target)
        if actual~=target then
            local redirected={}
            for _,effect in ipairs(program)do
                if effect.definition.kind=='profession' then local entry={};for k,v in pairs(effect)do entry[k]=v end;entry.target=actual;entry.hitTarget=actual;redirected[#redirected+1]=entry
                else redirected[#redirected+1]=battle.gameEffects:Prepare(effect.definition.id,source,actual,professionSkill,effect.distance)end
            end
            program=redirected;target=actual
        end
        professionContext=battle.professions:BeforeHit(source,professionSkill,target)
        impact.professionContext=professionContext
    end
    -- Resolve once per projectile/victim after a successful hit, never once per attached effect.
    local skill
    for _,effect in ipairs(program)do
        if effect.definition.kind=='damage' and effect.definition.duration=='instant' and effect.target~=source and effect.target.HP>0 then
            skill=effect.skill;break
        end
    end
    if skill and skill.criticalChance>0 then
        local value=skill.criticalChance<100 and battle.data:RollPercent() or nil
        impact.critical=skill.criticalChance==100 or value<skill.criticalChance
        if battle.checks then
            battle.checks(source,program[1].hitTarget or program[1].target,skill,LuaLanguage.DiceCritical,skill.criticalChance,value,impact.critical,
                {shot=impact.shot,successLabel=LuaLanguage.DiceCritical,failureLabel=LuaLanguage.DiceNormalHit})
        end
    end
    -- A successful hit authorizes all effects for this projectile, including source benefits after a lethal hit.
    for _,effect in ipairs(program)do
        if source.HP<=0 then break end
        if effect.definition.kind=='profession' then -- The profession program owns this no-effect action.
        elseif effect.target.HP>0 then battle.gameEffects:ApplyPrepared(effect,impact)
        elseif effect.definition.kind=='apply_buff' then
            battle.gameEffects:Report('effect_blocked',effect,{statusName=battle.stats.buffs:Get(effect.definition.buffId).name,reason='目标已倒地'})
        end
    end
    if professionContext then battle.professions:AfterHit(professionContext)end
    if battle.beasts and professionSkill then battle.beasts:OnHit(source,program[1].hitTarget or program[1].target,professionSkill)end
    return program[1] and (program[1].hitTarget or program[1].target)
end
function Shots.ApplyBlocker(battle,source,skill,blocker,prepared,impact,context,visualSource)
    local name=blocker.actor and battle.stats:Template(blocker.actor).name or blocker.name or '障碍物'
    battle:Emit('intercepted',skill.name..' 被 '..name..' 拦截',source.Id,blocker.actor and blocker.actor.Id,0,blocker.actor,false,
        {actionName=skill.name,targetName=name,shot=impact and impact.shot})
    local actual=blocker.actor
    if blocker.kind=='actor' then
        actual=Shots.ApplyActor(battle,source,assert(prepared[blocker.key],'Unprepared interception target'),impact)
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
    local impactCell=blocker.cell;if actual then impactCell=nil end
    VisualEffects.Skill(battle,visualSource or source,skill,actual,impact and impact.shot,'hit',impactCell)
end
function Shots.PrepareProgram(battle,source,skill,program)
    program.vfxSource=VisualEffects.Source(source)
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
            if not needsHit(battle,source,skill,victim) then
                local actual=Shots.ApplyActor(battle,source,group.effects,{shot=shot})
                VisualEffects.Skill(battle,program.vfxSource,skill,actual or victim,shot,'cast')
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
                local blocker=profile.reachable and Shots.Intercept(profile,roll,battle.checks and function(row,value,passed)
                    battle.checks(source,row.actor,skill,'拦截',row.chance,value,passed,
                        {targetName=row.actor and battle.stats:Template(row.actor).name or row.name,shot=shot,successLabel='拦截',failureLabel='穿过'})
                end)
                if blocker then Shots.ApplyBlocker(battle,source,skill,blocker,assert(group.interceptions),{shot=shot},nil,program.vfxSource)
                elseif profile.reachable and Shots.Hit(profile,roll,battle.checks and function(value,passed)
                    battle.checks(source,victim,skill,'命中',profile.baseHitChance,value,passed,{shot=shot,successLabel='命中',failureLabel='落空'})
                end)then
                    local actual=Shots.ApplyActor(battle,source,group.effects,{shot=shot})
                    VisualEffects.Skill(battle,program.vfxSource,skill,actual or victim,shot,'hit')
                else
                    battle:Emit('miss',battle.stats:Template(source).name..' · '..skill.name..' 未命中 '..battle.stats:Template(victim).name,source.Id,victim.Id,0,victim,false,{actionName=skill.name,shot=shot})
                    VisualEffects.Skill(battle,program.vfxSource,skill,victim,shot,'miss')
                end
            end
        end
    end
end
return Shots
