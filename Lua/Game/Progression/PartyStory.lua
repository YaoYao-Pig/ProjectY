local Life=require('Game.Battle.ActorLife')
local L=require('Language')
local Model={};Model.__index=Model
local function state()return CS.ProjectY.Data.PartyRelationshipState end
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
function Model:Actor(id)return CS.ProjectY.Data.PartyRoster.Find(self.adventure.data,id)end
function Model:Name(actor)return self.stats.inspection and self.stats.inspection.targets:Name(actor) or self.stats:Template(actor).name end
function Model:Location()
    local data=self.adventure.data
    if data.SiteId>0 then return assert(self.adventure.sites[data.SiteId],'Party story has no adventure location').name end
    if data.Areas.ActiveSiteId>0 then return assert(self.adventure.sites[data.Areas.ActiveSiteId],'Party story has no area location').name end
    return self.adventure.camp.data.IsOpen and L.UICampTitleText or L.RelationshipOnRoad
end
function Model:StageName(a,b)
    if state().Romance(self.data,a,b) and (Life.Dead(self:Actor(a)) or Life.Dead(self:Actor(b))) then return L.RelationshipRememberedLove end
    if state().Romance(self.data,a,b) then return self.data:Score(a,b)>=self.rules.settings.romanceMinimum and state().Grievance(self.data,a,b)==0 and L.RelationshipLove or L.RelationshipLoveStrained end
    return self.rules:Stage(self.data:Score(a,b)).name
end
function Model:Milestones(first,second,before,location)
    local old=self.rules:Stage(before);local current=self.rules:Stage(self.data:Score(first.Id,second.Id))
    if old.id==current.id then return end
    self.chronicle:RecordPair('relationship',first,second,string.format(L.RelationshipStageTitle,current.name),
        string.format(L.RelationshipStageChanged,old.name,current.name,current.description),location,0)
end
function Model:Honors(actor,other,location)
    for _,honor in ipairs(self.rules.honors:All()) do
        if not self.data:HasHonor(actor.Id,honor.id) and self.data:RescueCount(actor.Id)>=honor.required then
            self.data:AwardHonor(actor.Id,honor.id)
            self.chronicle:RecordPair('honor',actor,other,string.format(L.RelationshipHonorTitle,honor.name),
                string.format(L.RelationshipHonorEarned,honor.required,honor.name),location,0)
        end
    end
end
function Model:Record(first,second,before,title,detail,location)
    location=location or self:Location()
    local delta=self.data:Score(first.Id,second.Id)-before
    self.chronicle:RecordPair('relationship',first,second,title,string.format(L.RelationshipEvent,detail,delta),location,delta)
    self:Milestones(first,second,before,location)
end
function Model:Rescued(source,target,event,before)
    if self.adventure.personalGrowth then self.adventure.personalGrowth:RecordRescue(source,self.adventure.people:BattleToken()..':'..target.Id)end
    self:Record(source,target,before,event.hpBefore==0 and L.RelationshipDeathRescue or L.RelationshipRescue,
        string.format(L.RelationshipRescueMemory,self:Name(source),self:Name(target),event.amount))
    for _,id in ipairs(self.rules.settings.removeTraitIds) do
        if target:RemoveTrait(id) then
            target:SetMaxHP(self.stats:MaximumHP(target))
            self.chronicle:RecordPair('trait',target,source,L.RelationshipReliance,
                string.format(L.RelationshipTraitMemory,self:Name(source),self.rules.traits:Get(id).name),self:Location(),0)
        end
    end
    self:Honors(source,target,self:Location())
end
function Model:OnBattleEvent(event)
    local battle=self.adventure.battle;local bridge=state();local settings=self.rules.settings
    if event.kind=='battle_started' then
        self.data:BeginBattle()
        for _,actor in ipairs(battle:Units()) do if actor.Team==1 and self:Actor(actor.Id) then self.data:AddParticipant(actor) end end
        return
    end
    if battle.data.Phase~='combat' or (event.kind~='heal' and event.kind~='damage') then return end
    local source=event.sourceId and self:Actor(event.sourceId)
    local target=event.targetId and self:Actor(event.targetId)
    local sourceIn=source and self.data:IsParticipant(source.Id)
    local targetIn=target and self.data:IsParticipant(target.Id)
    -- Mounted-animal health must not be interpreted as the rider's own injury.
    if event.impact and event.impact.healthActorId and event.impact.healthActorId~=event.targetId then return end
    if event.kind=='heal' then
        if not targetIn then return end
        local debt=bridge.FriendlyDebt(self.data,target.Id)
        local credit=bridge.CreditHealing(self.data,target.Id,event.amount)
        if not sourceIn or not Life.Alive(target) then return end
        local kind,amount=self.rules:Help(event,battle.data.Phase,source,target,credit,debt)
        if not kind then return end
        local before=self.data:Score(source.Id,target.Id)
        if bridge.Grievance(self.data,source.Id,target.Id)>0 then amount=math.max(1,math.floor(amount/2))end
        if kind=='rescue' then
            if self.data:TryRescue(source.Id,target.Id,amount) then self:Rescued(source,target,event,before)end
        else
            amount=math.max(1,amount-bridge.Count(self.data,source.Id,target.Id,'heal'))
            if bridge.Interact(self.data,source.Id,target.Id,'heal',amount,0,settings.healLimit) then
                self:Record(source,target,before,L.RelationshipCare,string.format(L.RelationshipCareMemory,self:Name(source),self:Name(target),credit))
            end
        end
    elseif sourceIn and targetIn then
        bridge.AddFriendlyDamage(self.data,target.Id,math.max(0,event.hpBefore-event.hpAfter))
        if source.Id==target.Id then return end
        local amount,grievance=self.rules:Harm(event,target)
        if not amount then return end
        local before=self.data:Score(source.Id,target.Id)
        if bridge.Interact(self.data,source.Id,target.Id,'harm',amount,grievance,1000000) then
            self:Record(source,target,before,L.RelationshipFriendlyFire,
                string.format(L.RelationshipHarmMemory,self:Name(source),self:Name(target),event.amount))
        end
    elseif sourceIn and event.target and battle:Relation(source,event.target)=='hostile' and event.amount>0 and event.attackHit and not event.periodic
        and not (event.impact and event.impact.legendaryDebt) then
        local partners=bridge.AttackPartners(self.data,source.Id,event.targetId,battle.data.Round)
        for i=0,partners.Length-1 do
            local other=assert(self:Actor(partners[i]));local before=self.data:Score(source.Id,other.Id)
            if Life.Alive(other) and bridge.Interact(self.data,source.Id,other.Id,'cooperate',settings.cooperationBond,0,settings.cooperationLimit) then
                self:Record(source,other,before,L.RelationshipCooperate,
                    string.format(L.RelationshipCooperateMemory,self:Name(other),self:Name(source),self:Name(event.target)))
            end
        end
    end
end
function Model:Settle(result,location)
    assert(result=='victory' or result=='defeat' or result=='draw','Unknown battle result')
    local pairs={}
    if result=='victory' then
        for i=0,self.data.ParticipantCount-1 do
            local first=self.data:GetParticipantAt(i)
            for j=i+1,self.data.ParticipantCount-1 do
                local second=self.data:GetParticipantAt(j)
                if Life.Alive(first) and Life.Alive(second) then pairs[#pairs+1]={first=first,second=second,before=self.data:Score(first.Id,second.Id)} end
            end
        end
    end
    if not self.data:SettleBattle(result=='victory',self.rules.settings.victoryBond) then return false end
    for _,pair in ipairs(pairs) do
        local harmed=state().Count(self.data,pair.first.Id,pair.second.Id,'harm')>0
        self:Record(pair.first,pair.second,pair.before,L.RelationshipVictory,harmed and L.RelationshipUneasyVictory or L.RelationshipVictoryMemory,location)
    end
    return true
end
function Model:PairBody(actor,other)
    local a,b=actor.Id,other.Id;local bridge=state();local bond=self.data:Find(a,b);local score=self.data:Score(a,b)
    local grievance=bridge.Grievance(self.data,a,b)
    local mood=grievance==0 and L.RelationshipCalm or L.RelationshipGrudge
    local lines={string.format(L.RelationshipDetails,score,grievance,mood,bond and bond.SharedBattles or 0,bond and bond.Rescues or 0,
        bridge.Support(self.data,a,b),bridge.Cooperation(self.data,a,b),bridge.FriendlyHits(self.data,a,b)),self.rules:Stage(score).description}
    local memories={};local data=self.adventure.data
    for i=data.JournalCount-1,0,-1 do
        local entry=data:GetJournalAt(i)
        if entry.Kind=='relationship' and ((entry.SubjectId==a and entry.ObjectId==b) or (entry.SubjectId==b and entry.ObjectId==a)) then
            memories[#memories+1]=string.format(L.RelationshipMemoryLine,entry.Day,entry.Title,entry.RelationDelta)
            if #memories==3 then break end
        end
    end
    lines[#lines+1]=#memories>0 and string.format(L.RelationshipMemories,table.concat(memories,'\n')) or L.RelationshipNoMemories
    return table.concat(lines,'\n\n')
end
function Model:OverviewRows(actor)
    local rows={};local adventure=self.adventure.data;local roster=CS.ProjectY.Data.PartyRoster
    for i=0,roster.Count(adventure)-1 do
        local other=roster.At(adventure,i)
        if actor.Id~=other.Id then
            local name=self:Name(other);local short=name:match('^(.-)%s*·') or name
            rows[#rows+1]={title=string.format(L.RelationshipTag,short,self:StageName(actor.Id,other.Id)),
                body=self:PairBody(actor,other),relationId=other.Id,color=self.data:Score(actor.Id,other.Id)<-20 and 'A53D37' or '354739'}
        end
    end
    for _,honor in ipairs(self.rules.honors:All()) do
        local earned=self.data:HasHonor(actor.Id,honor.id);local count=self.data:RescueCount(actor.Id)
        rows[#rows+1]={title=string.format(earned and L.RelationshipHonorOwned or L.RelationshipHonorChallenge,honor.name),
            body=string.format(L.RelationshipHonorProgress,honor.description,count,honor.required,earned and L.RelationshipEarned or L.RelationshipUnearned),color=earned and '805723' or '354739'}
    end
    return rows
end
function Model:CanSocial(a,b,kind)
    local data=self.adventure.data;local first,second=self:Actor(a),self:Actor(b)
    if (data.Phase~='map' and data.Phase~='area') or data.Narrative.DialogueOpen then return false,L.RelationshipRestOnly end
    if not first or not second or a==b or not Life.Alive(first) or (not Life.Alive(second) and kind~='friendship') then return false,L.RelationshipLivingPair end
    local bridge=state();local day=math.floor(data.Narrative.Minutes/1440)+1
    if bridge.SocialDay(self.data,a,b)>=day then return false,L.RelationshipDailyLimit end
    if kind=='chat' then return true end
    if kind=='apology' then return bridge.Grievance(self.data,a,b)>0,L.RelationshipNoGrudge end
    if kind=='romance' then
        if bridge.HasRomance(self.data,a) or bridge.HasRomance(self.data,b) then return false,L.RelationshipAlreadyPartnered end
        local bond=self.data:Find(a,b)
        if not bond or bond.Score<self.rules.settings.romanceMinimum or bond.SharedBattles<self.rules.settings.romanceBattles or bridge.Grievance(self.data,a,b)>0 then
            return false,string.format(L.RelationshipLoveRequirement,self.rules.settings.romanceMinimum,self.rules.settings.romanceBattles)
        end
        return true
    end
    if kind=='friendship' then return bridge.Romance(self.data,a,b),L.RelationshipNotPartners end
    error('Unknown relationship conversation: '..tostring(kind))
end
function Model:Social(a,b,kind)
    local allowed,reason=self:CanSocial(a,b,kind);if not allowed then return false,reason end
    local first,second=self:Actor(a),self:Actor(b);local before=self.data:Score(a,b);local settings=self.rules.settings
    local location=self:Location()
    local amount=kind=='chat' and settings.chatBond or kind=='apology' and settings.apologyBond or 0
    if kind=='chat' and state().Grievance(self.data,a,b)>0 then amount=1 end
    local relief=kind=='apology' and -settings.apologyRelief or kind=='chat' and -1 or 0
    assert(state().Social(self.data,a,b,math.floor(self.adventure.data.Narrative.Minutes/1440)+1,amount,relief),'Validated conversation rejected')
    if kind=='romance' or kind=='friendship' then state().SetRomance(self.data,a,b,kind=='romance')end
    local texts={chat={L.RelationshipChat,L.RelationshipChatMemory},apology={L.RelationshipApology,L.RelationshipApologyMemory},
        romance={L.RelationshipConfess,L.RelationshipLoveMemory},friendship={L.RelationshipRemainFriends,L.RelationshipFriendshipMemory}}
    if kind=='friendship' and Life.Dead(second) then texts.friendship={L.RelationshipRemember,L.RelationshipRememberMemory}end
    self:Record(first,second,before,texts[kind][1],string.format(texts[kind][2],self:Name(first),self:Name(second)),location)
    return true
end
function Model:ActionRows(actor,other)
    local rows={};local choices={{'chat',L.RelationshipChat,L.RelationshipChatHint},{'apology',L.RelationshipApology,L.RelationshipApologyHint},
        {'romance',L.RelationshipConfess,L.RelationshipLoveHint},{'friendship',L.RelationshipRemainFriends,L.RelationshipFriendshipHint}}
    if Life.Dead(other) then choices[4]={'friendship',L.RelationshipRemember,L.RelationshipRememberHint}end
    for _,choice in ipairs(choices) do
        local ok,reason=self:CanSocial(actor.Id,other.Id,choice[1])
        rows[#rows+1]={action=choice[1],title=choice[2],body=ok and choice[3] or reason,available=ok,color=ok and '354739' or '777777'}
    end
    return rows
end
function Model:ValidateSaved(prepared)
    local data=assert(prepared.PartyBonds,'Prepared save is missing party story')
    for i=0,data.HonorCount-1 do
        local honor=data:GetHonorAt(i);local row=self.rules.honors:Get(honor.HonorId)
        assert(data:RescueCount(honor.ActorId)>=row.required,'Saved honor does not meet its rescue threshold')
    end
end
return Model
