local Model={};Model.__index=Model
function Model.New(adventure)
    return setmetatable({adventure=adventure,data=adventure.data.PartyBonds,
        rules=require('Game.Progression.PartyStoryRules').New(adventure.config),stats=adventure.battle.stats,
        chronicle=adventure.growth.chronicle},Model)
end
function Model:Start()
    assert(not self.unsubscribe,'Party story already subscribed')
    self.unsubscribe=self.adventure.battle.Changed:Subscribe(function(event) self:OnBattleEvent(event) end)
end
function Model:Reset() self.data:ResetBattle() end
function Model:Dispose() if self.unsubscribe then self.unsubscribe();self.unsubscribe=nil end end
function Model:Actor(id)
    local data=self.adventure.data
    for i=0,data.PartyCount-1 do local actor=data:GetPartyAt(i);if actor.Id==id then return actor end end
end
function Model:Location() return assert(self.adventure.sites[self.adventure.data.SiteId],'Battle has no adventure location').name end
function Model:Milestones(first,second,before,location)
    for _,stage in ipairs(self.rules:Crossed(before,self.data:Score(first.Id,second.Id))) do
        self.chronicle:RecordPair('relationship',first,second,'关系 · '..stage.name,
            '关系达到「'..stage.name..'」。'..stage.description,location,0)
    end
end
function Model:Honors(actor,other,location)
    for _,honor in ipairs(self.rules.honors:All()) do
        if not self.data:HasHonor(actor.Id,honor.id) and self.data:RescueCount(actor.Id)>=honor.required then
            self.data:AwardHonor(actor.Id,honor.id)
            self.chronicle:RecordPair('honor',actor,other,'荣誉 · '..honor.name,
                '完成 '..honor.required..' 次真实危急救援，获得「'..honor.name..'」。',location,0)
        end
    end
end
function Model:OnBattleEvent(event)
    local battle=self.adventure.battle
    if event.kind=='battle_started' then
        self.data:BeginBattle()
        for _,actor in ipairs(battle:Units()) do if actor.Team==1 and self:Actor(actor.Id) then self.data:AddParticipant(actor) end end
        return
    end
    if event.kind~='heal' then return end
    local source,target=self:Actor(event.sourceId),self:Actor(event.targetId)
    if not source or not target or not self.data:IsParticipant(source.Id) or not self.data:IsParticipant(target.Id) then return end
    if not self.rules:IsRescue(event,battle.data.Phase,source,target) then return end
    local before=self.data:Score(source.Id,target.Id)
    if not self.data:TryRescue(source.Id,target.Id,self.rules.settings.rescueBond) then return end
    local location=self:Location();local delta=self.data:Score(source.Id,target.Id)-before
    self.chronicle:RecordPair('relationship',source,target,'危急援手',
        self.stats:Template(source).name..'救助了生命濒危的'..self.stats:Template(target).name..'，恢复 '..event.amount..' 点生命。关系 +'..delta..'。',location,delta)
    for _,id in ipairs(self.rules.settings.removeTraitIds) do
        if target:RemoveTrait(id) then
            target:SetMaxHP(self.stats:MaximumHP(target))
            self.chronicle:RecordPair('trait',target,source,'学会依靠同伴',
                '被'..self.stats:Template(source).name..'从危险中救助后，克服了「'..self.rules.traits:Get(id).name..'」。',location,0)
        end
    end
    self:Milestones(source,target,before,location);self:Honors(source,target,location)
end
function Model:Settle(result,location)
    assert(result=='victory' or result=='defeat' or result=='draw','Unknown battle result')
    local pairs={}
    if result=='victory' then
        for i=0,self.data.ParticipantCount-1 do
            local first=self.data:GetParticipantAt(i)
            for j=i+1,self.data.ParticipantCount-1 do
                local second=self.data:GetParticipantAt(j)
                if first.HP>0 and second.HP>0 then pairs[#pairs+1]={first=first,second=second,before=self.data:Score(first.Id,second.Id)} end
            end
        end
    end
    if not self.data:SettleBattle(result=='victory',self.rules.settings.victoryBond) then return false end
    for _,pair in ipairs(pairs) do
        local delta=self.data:Score(pair.first.Id,pair.second.Id)-pair.before
        self.chronicle:RecordPair('relationship',pair.first,pair.second,'并肩取胜','共同战胜了敌人，关系 +'..delta..'。',location,delta)
        self:Milestones(pair.first,pair.second,pair.before,location)
    end
    return true
end
function Model:OverviewRows(actor)
    local rows={};local adventure=self.adventure.data
    for i=0,adventure.PartyCount-1 do
        local other=adventure:GetPartyAt(i)
        if actor.Id~=other.Id then
            local score=self.data:Score(actor.Id,other.Id);local bond=self.data:Find(actor.Id,other.Id);local stage=self.rules:Stage(score)
            local name=self.stats:Template(other).name;local short=name:match('^(.-)%s*·') or name
            rows[#rows+1]={title='◇ '..short..' · '..stage.name,
                body='关系 '..score..' / 100\n共同取胜 '..(bond and bond.SharedBattles or 0)..' 次 · 彼此救援 '..(bond and bond.Rescues or 0)..' 次\n'..stage.description,color='354739'}
        end
    end
    for _,honor in ipairs(self.rules.honors:All()) do
        local earned=self.data:HasHonor(actor.Id,honor.id);local count=self.data:RescueCount(actor.Id)
        rows[#rows+1]={title=(earned and '★ 荣誉 · ' or '☆ 挑战 · ')..honor.name,
            body=honor.description..'\n危急救援 '..count..' / '..honor.required..(earned and ' · 已获得' or ' · 尚未达成'),color=earned and '805723' or '354739'}
    end
    return rows
end
function Model:ValidateSaved(prepared)
    local data=assert(prepared.PartyBonds,'Prepared save is missing party story')
    for i=0,data.HonorCount-1 do
        local honor=data:GetHonorAt(i);local row=self.rules.honors:Get(honor.HonorId)
        assert(data:RescueCount(honor.ActorId)>=row.required,'保存的荣誉不满足挑战次数')
    end
end
return Model
