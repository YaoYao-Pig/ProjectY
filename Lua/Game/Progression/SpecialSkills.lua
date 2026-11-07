local L=require('Language')
local Life=require('Game.Battle.ActorLife')
local Hex=require('Game.Map.HexGrid')
local Model={};Model.__index=Model
local function state()return CS.ProjectY.Data.SpecialSkillBattleState end
local function roster()return CS.ProjectY.Data.PartyRoster end
function Model.New(adventure)
    return setmetatable({adventure=adventure,stats=adventure.battle.stats,rules=adventure.battle.stats.specialSkills,
        skills=adventure.config:GetTable('CombatSkillTable'),chronicle=adventure.growth.chronicle},Model)
end
function Model:Start()
    local battle=self.adventure.battle
    assert(not self.unsubscribe and not battle.specialSkillObserver,'Special skill observer already started')
    battle.specialSkillObserver=self
    self.unsubscribe=battle.Changed:Subscribe(function(event)
        if event.kind=='battle_started' then state().Begin(self.adventure.data)end
    end)
end
function Model:Reset()state().Reset(self.adventure.data)end
function Model:Dispose()
    if self.unsubscribe then self.unsubscribe();self.unsubscribe=nil end
    if self.adventure.battle.specialSkillObserver==self then self.adventure.battle.specialSkillObserver=nil end
    self:Reset()
end
function Model:Name(actor)
    return self.stats.inspection and self.stats.inspection.targets:Name(actor) or self.stats:Template(actor).name
end
function Model:Location()
    local site=self.adventure.sites[self.adventure.data.SiteId]
    return site and site.name or L.SpecialSkillJourney
end
function Model:CanTeach(teacher,learner,id)
    local data=self.adventure.data
    if data.Phase~='map' and data.Phase~='area' then return false,L.SpecialSkillExploreOnly end
    if not teacher or not learner or teacher.Id==learner.Id or roster().Find(data,teacher.Id)~=teacher or roster().Find(data,learner.Id)~=learner
        or not Life.Alive(teacher) or not Life.Alive(learner)then return false,L.SpecialSkillLivingPair end
    local row=type(id)=='number' and math.tointeger(id) and self.rules.bySkill[id]
    if not row then return false,L.SpecialSkillUnknown end
    if not self.rules:Owns(teacher,id)then return false,L.SpecialSkillTeacherMissing end
    if not row.teachable then return false,L.SpecialSkillCannotTeach end
    if not row.reteachable and not self.rules:IsOriginal(teacher,id)then return false,L.SpecialSkillCannotReteach end
    if self.rules:Owns(learner,id)then return false,L.SpecialSkillAlreadyKnown end
    if data.PartyBonds:Score(teacher.Id,learner.Id)<row.relationMinimum then
        return false,string.format(L.SpecialSkillRelationshipRequired,row.relationMinimum)
    end
    return self.rules:Requirements(learner,id,self.stats)
end
function Model:Learn(actor,id)
    assert(actor.Growth.Initialized and actor.Growth:GrantSkill(id),'Special skill must be newly granted to an initialized actor')
    if self.adventure.personalGrowth then self.adventure.personalGrowth:RecordLearnedSkill(actor,id)end
end
function Model:Teach(teacherId,learnerId,id)
    local data=self.adventure.data
    local teacher,learner=roster().Find(data,teacherId),roster().Find(data,learnerId)
    local ok,reason=self:CanTeach(teacher,learner,id);if not ok then return false,reason end
    self:Learn(learner,id)
    local detail=string.format(L.SpecialSkillTeachingMemory,self:Name(teacher),self:Name(learner),self.skills:Get(id).name)
    self.chronicle:RecordPair('growth',learner,teacher,L.SpecialSkillTeachingTitle,detail,self:Location(),0)
    return true,detail
end
function Model:TeachingRows(learner,teacher)
    if not teacher or not learner or teacher.Id==learner.Id then return {}end
    local ids={}
    for id,row in pairs(self.rules.bySkill)do
        if row.teachable and (row.reteachable or self.rules:IsOriginal(teacher,id)) and self.rules:Owns(teacher,id)then ids[#ids+1]=id end
    end
    table.sort(ids)
    local rows={}
    for _,id in ipairs(ids)do
        local skill=self.skills:Get(id);local allowed,reason=self:CanTeach(teacher,learner,id)
        rows[#rows+1]={skillId=id,title=string.format(L.SpecialSkillTeachAction,skill.name),allowed=allowed,
            body=string.format(L.SpecialSkillTeachingBody,skill.description,allowed and L.SpecialSkillTeachingReady or reason)}
    end
    return rows
end
function Model:CanObserve(observer,source)
    local board=assert(self.adventure.battle.board,'Observing a skill requires the battle board')
    local origin=assert(board:Find(observer.Q,observer.R));local target=assert(board:Find(source.Q,source.R))
    if board.spellcasting and board.spellcasting:BlocksSight(board.spellBattle,origin,target)then return false end
    if board.area then
        return Hex.Distance(origin.q,origin.r,target.q,target.r)<=board.area.visionRadius and board.area:CanSee(origin,target)
    end
    if board.CanSee then return board:CanSee(origin,target)end
    -- The independent board has no area layout. Use the same two-offset hex ray as MapArea.CanSee.
    local distance=Hex.Distance(origin.q,origin.r,target.q,target.r)
    if distance<=1 then return true end
    local ax,_,az=Hex.ToWorld(origin.q,origin.r,0,1);local bx,_,bz=Hex.ToWorld(target.q,target.r,0,1)
    for _,epsilon in ipairs({-.000001,.000001})do
        for step=1,distance-1 do
            local t=step/distance
            local q,r=Hex.FromWorld(ax+(bx-ax)*t+epsilon,az+(bz-az)*t+epsilon,1)
            local cell=board:Find(q,r)
            if not cell or cell.blocked then return false end
        end
    end
    return true
end
-- This short-lived command snapshot has no authority until the command succeeds.
function Model:CaptureUse(source,id)
    local battle=self.adventure.battle
    if battle.data.Phase~='combat' or not self.rules.bySkill[id]then return nil end
    local observations={skillId=id,sourceName=self:Name(source)}
    for _,learner in ipairs(battle:Units())do
        if learner.Id~=source.Id and state().IsParticipant(self.adventure.data,learner) and Life.Alive(learner)
            and not self.rules:Owns(learner,id) and self:CanObserve(learner,source)then
            local chance=self.rules:ObservationChance(learner,id,self.stats)
            if chance>0 then observations[#observations+1]={learner=learner,chance=chance}end
        end
    end
    return observations
end
function Model:CommitUse(observations)
    if not observations then return end
    for _,row in ipairs(observations)do
        state().Observe(self.adventure.data,row.learner,observations.skillId,row.chance,observations.sourceName)
    end
end
function Model:Settle(result,location)
    assert(result=='victory' or result=='defeat' or result=='draw','Unknown special skill battle result')
    local data=self.adventure.data
    if not state().Consume(data)then return false end
    local observations=state().Observations(data)
    for i=0,observations.Length-1 do
        local row=observations[i];local learner=row.Learner;local id=row.SkillId
        if roster().Find(data,learner.Id)==learner and Life.Alive(learner) and not self.rules:Owns(learner,id)then
            if learner.Growth:NextRandom()<row.Chance then
                self:Learn(learner,id)
                self.chronicle:Record('growth',learner,L.SpecialSkillObservationTitle,
                    string.format(L.SpecialSkillObservationMemory,self:Name(learner),row.SourceName,self.skills:Get(id).name),location,false)
            end
        end
    end
    return true
end
return Model
