local L=require('Language')
local Life=require('Game.Battle.ActorLife')
local Rules=require('Game.Adventure.PeopleRules')
local People={};People.__index=People
local function bridge()return CS.ProjectY.Data.PeopleState end
local function roster()return CS.ProjectY.Data.PartyRoster end
local function residentKey(site,id)return 'resident:'..site..':'..id end
function People.New(adventure)
    return setmetatable({adventure=adventure,rules=Rules.New(adventure.config)},People)
end
function People:Data()return bridge().Get(self.adventure.data)end
function People:Find(key)return self:Data():Find(key)end
function People:ForActor(actor)return self:Data():FindActor(actor.Id)end
function People:Name(person)
    if person.NameId>0 then return self.rules.names:Get(person.NameId).name end
    local npcId=person.Key:match('^npc:(%d+)$')
    if npcId then return self.adventure.config:GetTable('NpcTable'):Get(tonumber(npcId)).name end
    return self.adventure.battle.stats:Template(person.Actor).name
end
function People:ResidentJoined(site,id)
    local person=self:Find(residentKey(site,id));return person~=nil and person.Joined
end
function People:EnsureResident(definition,siteId,linking)
    assert(not definition.narrativeId,'Authored NPCs use their authored recruitment')
    local key=residentKey(siteId,assert(definition.stableId));local person=self:Find(key)
    if not person then
        local profile,name=self.rules:Cast(self.adventure.data.Seed,siteId,definition.stableId,definition.templateId)
        person=self:Data():CreateResident(siteId,definition.stableId,self.rules.mappings:Get(definition.templateId).unitId,profile,name,'')
        self.adventure.growth:PrepareActor(person.Actor,person.Actor.TemplateId==1202 and 4 or 12)
        self.adventure.characterAppearances:Party(person.Actor,self.adventure.data.Seed)
        person.Actor:SetMaxHP(self.adventure.battle.stats:MaximumHP(person.Actor));person.Actor:Restore()
    end
    if not linking and person.BondKey=='' and Rules.FreeResident(definition) then
        local candidates={}
        for _,npc in ipairs(self.adventure.areas:ActiveLayout().npcs)do if Rules.FreeResident(npc)then candidates[#candidates+1]=npc end end
        table.sort(candidates,function(a,b)return a.stableId<b.stableId end)
        for index,npc in ipairs(candidates)do if npc.stableId==definition.stableId then
            local other=candidates[index%2==1 and index+1 or index-1]
            if other then
                local bond=self:EnsureResident(other,siteId,true);person:SetBond(bond.Key)
                if bond.BondKey=='' then bond:SetBond(person.Key)end
            end
            break
        end end
    end
    return person
end
function People:EnsureTarget(target)
    local found=self:ForActor(target.actor);if found then return found end
    local adventure=self.adventure;local actor=target.actor
    if target.kind=='resident' then
        local site,stable=target.key:match('^resident:(%d+):(%d+)$')
        for _,npc in ipairs(adventure.areas:ActiveLayout().npcs)do
            if npc.stableId==tonumber(stable)then return self:EnsureResident(npc,tonumber(site))end
        end
        error('Visible resident lost its definition')
    end
    assert(adventure.battle.stats:Template(actor).bodyInjuries and actor.AnimalOwnerId==0,'Only human actors participate in person recruitment')
    local owned=roster().Find(adventure.data,actor.Id)~=nil
    local origin=owned and 'party' or adventure.data.Phase=='map' and 'world' or 'area'
    local profile=owned and (actor.Growth.CurrentProfessionId==3 and 2 or actor.Growth.CurrentProfessionId==12 and 1 or 3) or 4
    if not actor.Growth.Initialized then adventure.growth:PrepareActor(actor);actor:SetMaxHP(adventure.battle.stats:MaximumHP(actor))end
    local names=self.rules.names:All();local nameId=owned and 0 or names[Rules.Hash(adventure.data.Seed,0,actor.Id)%#names+1].id
    local person=bridge().Bind(adventure.data,target.key,actor,origin,origin=='area' and adventure.data.Areas.ActiveSiteId or 0,0,profile,nameId,'')
    if origin=='world' then
        local party=assert(adventure.parties.data:Find(adventure.parties.data.ContactId))
        adventure.parties.lod:Calibrate(party);adventure.factions:InvalidatePower()
    end
    return person
end
function People:ResidentDefinition(person)
    local adventure=self.adventure
    if adventure.data.Phase~='area' or adventure.data.Areas.ActiveSiteId~=person.SiteId then return nil end
    for _,npc in ipairs(adventure.areas:ActiveLayout().npcs)do if npc.stableId==person.ResidentId then return npc end end
end
function People:CanTalk(person)
    local adventure=self.adventure;local data=adventure.data
    if data.Phase~='map' and data.Phase~='area' then return false,L.PeopleExplorationOnly end
    if not Life.Alive(person.Actor)then return false,L.PeopleUnavailable end
    if person.Joined then return roster().Find(data,person.Actor.Id)~=nil,L.PeopleUnavailable end
    if person.OriginKind=='resident' then
        local npc=self:ResidentDefinition(person);if not npc then return false,L.PeopleComeCloser end
        if not Rules.FreeResident(npc)then return false,L.PeopleDuty end
        local allowed,reason=adventure.factions:ServiceAllowed(person.SiteId);if not allowed then return false,reason end
        local state=data.Areas.Active;local live=state:GetNpcAt(npc.id-1)
        local path=live.Present and adventure.areas:ActiveLayout():FindPath(state.CellIndex,live.CellIndex)
        return path and #path<=1 or false,L.PeopleComeCloser
    end
    if data.Phase=='map' then
        local contactId=adventure.parties.data.ContactId
        if adventure.peopleDialogue:Active()then contactId=data.Narrative.DialogueLocalNpcId end
        local party=adventure.parties.data:Find(contactId)
        if not party or party.BattleSiteId>0 or not adventure.parties:Near(party)then return false,L.PeopleComeCloser end
        for i=0,party.MemberCount-1 do if party:GetMemberAt(i).Id==person.Actor.Id then return true end end
    end
    return false,L.PeopleWorldParleyOnly
end
function People:CanOpen(key)
    local adventure=self.adventure
    if adventure.data.Narrative.DialogueOpen then return false,L.PeopleDialogueBusy end
    if adventure.data.Phase~='map' and adventure.data.Phase~='area' then return false,L.PeopleExplorationOnly end
    local target=adventure.inspection.targets:Find(key)
    if not target or not Life.Alive(target.actor) or not adventure.battle.stats:Template(target.actor).bodyInjuries then return false,L.PeopleUnavailable end
    local person=self:ForActor(target.actor)
    if person then return self:CanTalk(person)end
    if target.owned then return true end
    if target.kind=='npc' or key:match('^npc:')then return false,L.PeopleAuthoredNpc end
    if target.kind=='resident' then
        local site,stable=key:match('^resident:(%d+):(%d+)$')
        assert(site and stable,'Invalid visible resident identity')
        for _,npc in ipairs(adventure.areas:ActiveLayout().npcs)do if npc.stableId==tonumber(stable)then
            if not Rules.FreeResident(npc)then return false,L.PeopleDuty end
            local live=adventure.data.Areas.Active:GetNpcAt(npc.id-1)
            local path=live.Present and adventure.areas:ActiveLayout():FindPath(adventure.data.Areas.Active.CellIndex,live.CellIndex)
            return path and #path<=1 or false,L.PeopleComeCloser
        end end
    end
    if adventure.data.Phase=='map' then
        local party=adventure.parties.data:Find(adventure.parties.data.ContactId)
        if party and party.BattleSiteId==0 and adventure.parties:Near(party)then
            for i=0,party.MemberCount-1 do if party:GetMemberAt(i).Id==target.actor.Id then return true end end
        end
    end
    return false,L.PeopleWorldParleyOnly
end
function People:Facts(person)
    local adventure=self.adventure;local story=adventure.data.Narrative
    local mentor,level=0,0
    for i=0,roster().Count(adventure.data)-1 do local actor=roster().At(adventure.data,i)
        if Life.Alive(actor)then mentor=math.max(mentor,actor.Growth.SkillCount);level=math.max(level,actor.Growth.Level)end
    end
    local bond=person.BondKey~='' and self:Find(person.BondKey)
    return {coins=adventure.player.Coins,trust=person.Trust,
        helped=story:GetValue('flag:people_help:'..person.SiteId..':'..person.ResidentId),
        townHelped=story:GetValue('flag:people_safe:'..person.SiteId),mentorSkills=mentor,level=level,
        victories=story:GetValue('flag:people_victories'),targetLevel=person.Actor.Growth.Level,bondJoined=bond and bond.Joined or false}
end
function People:Describe(person)
    local profile=self.rules.profiles:Get(person.ProfileId);local bond=person.BondKey~='' and self:Find(person.BondKey)
    return {name=self:Name(person),caption=string.format(L.PeopleCaption,profile.name,person.Trust),
        opening=string.format(L.PeopleOpening,profile.background,profile.opening,bond and string.format(L.PeopleBond,self:Name(bond)) or L.PeopleNoBond)}
end
function People:Outstanding(person)
    local missions=self.adventure.narrative.townMissions.data
    for i=0,missions.Count-1 do local mission=missions:GetAt(i)
        if mission.SiteId==person.SiteId and mission.NpcId==person.ResidentId and (mission.State=='active' or mission.State=='ready')then return true end
    end
    return false
end
function People:PrepareRecruit(person)
    local allowed,reason=self:CanTalk(person);if not allowed then return nil,reason end
    if person.Joined then return nil,L.PeopleAlreadyJoined end
    if roster().Count(self.adventure.data)>=roster().ActiveLimit+roster().ReserveLimit then return nil,L.RosterRecruitFull end
    if self:Outstanding(person)then return nil,L.PeopleFinishCommission end
    local failure=bridge().RecruitReason(self.adventure.data,person.Key)
    if failure~='' then return nil,assert(L[failure],'Missing person recruitment localization')end
    local recruit={actor=person.Actor,actorId=person.Actor.Id,reserve=self.adventure.data.PartyCount>=roster().ActiveLimit}
    local deployment;deployment,reason=self.adventure.narrative.npcs:PrepareDeployment({recruit})
    if not deployment then return nil,reason end
    return deployment
end
function People:Options(person)
    local profile=self.rules.profiles:Get(person.ProfileId)
    local rows={{id=10,text=L.PeopleAskBackground,available=true,reason=''}, {id=11,text=L.PeopleAskWish,available=true,reason=''}}
    if person.Joined then
        for _,choice in ipairs(self.adventure.personalGrowth:Choices(person.Actor.Id))do
            rows[#rows+1]={id=10000+choice.id,text=choice.title,available=choice.available,
                reason=choice.available and choice.body or string.format(L.PeopleGrowthOption,choice.reason,choice.body)}
        end
        return rows
    end
    if person.OriginKind=='resident' and self.adventure.narrative.townMissions:HasPublisher(person.SiteId,person.ResidentId)then
        rows[#rows+1]={id=12,text=L.PeopleAskCommissions,available=true,reason=''}
    end
    local facts=self:Facts(person);local deployment,why=self:PrepareRecruit(person)
    for _,route in ipairs(self.rules:Routes(profile,facts))do
        local text,reason
        if route.gate=='coins' then text=string.format(L.PeopleOfferAdvance,route.cost);reason=string.format(L.PeopleNeedCoins,route.cost)
        elseif route.gate=='help' then text=L.PeopleOfferTrust;reason=string.format(L.PeopleNeedTrust,profile.trustRequired,person.Trust)
        elseif route.gate=='mentor' then text=L.PeopleOfferMentor;reason=string.format(L.PeopleNeedMentor,profile.mentorSkills,facts.mentorSkills)
        elseif route.gate=='sponsor' then text=string.format(L.PeopleOfferSponsor,route.cost);reason=string.format(L.PeopleNeedSponsor,route.cost)
        elseif route.gate=='town' then text=L.PeopleOfferSafety;reason=L.PeopleNeedSafety
        elseif route.gate=='bond' then text=L.PeopleOfferBond;reason=string.format(L.PeopleNeedBond,profile.trustRequired)
        else text=string.format(L.PeopleOfferRespect,route.cost);reason=string.format(L.PeopleNeedRespect,profile.victories,profile.fee,facts.targetLevel,facts.victories,facts.level)end
        rows[#rows+1]={id=100+route.id,text=text,available=deployment~=nil and route.ready,reason=not deployment and why or not route.ready and reason or ''}
    end
    return rows
end
function People:Act(person,id)
    local allowed,reason=self:CanTalk(person);if not allowed then return false,reason end
    if id==10 then return true,self:Describe(person).opening end
    if id==11 then
        if not person.Joined then return true,self.rules.profiles:Get(person.ProfileId).request end
        local summary=assert(self.adventure.personalGrowth:Summary(person.Actor.Id))
        return true,string.format(L.PeopleGrowthSummary,summary.title,summary.body,summary.progress)
    end
    if person.Joined and id>=10000 then return self.adventure.personalGrowth:Choose(person.Actor.Id,id-10000)end
    if id==12 then
        if person.Joined or person.OriginKind~='resident' or not self.adventure.narrative.townMissions:HasPublisher(person.SiteId,person.ResidentId)then return false,L.PeopleDialogueStale end
        return true,L.PeopleCommissionsOpening,'commissions'
    end
    local selected
    for _,row in ipairs(self:Options(person))do if row.id==id then selected=row;break end end
    if not selected then return false,L.PeopleDialogueStale end
    if not selected.available then return false,selected.reason end
    local profile=self.rules.profiles:Get(person.ProfileId);local route
    for _,candidate in ipairs(self.rules:Routes(profile,self:Facts(person)))do if id==100+candidate.id then route=candidate;break end end
    assert(route and route.ready,'Recruitment route changed during commit')
    local deployment;deployment,reason=self:PrepareRecruit(person);if not deployment then return false,reason end
    if route.cost>0 and self.adventure.player.Coins<route.cost then return false,string.format(L.PeopleNeedCoins,route.cost)end
    bridge().ValidateRecruit(self.adventure.data,person.Key)
    if route.cost>0 then assert(self.adventure.player:TrySpendCoins(route.cost),'Validated recruitment funds unavailable')end
    local actor=bridge().Recruit(self.adventure.data,person.Key)
    self.adventure.factions:InvalidatePower()
    self.adventure.narrative.npcs:ApplyDeployment(deployment)
    if person.BondKey~='' then local bond=assert(self:Find(person.BondKey));bond:AddTrust(20)end
    self.adventure.growth.chronicle:Record('growth',actor,L.PeopleJoinedTitle,string.format(L.PeopleJoinedMemory,self:Name(person),profile.name,selected.text),L.PeopleJourney,false)
    return true,profile.joinedText
end
function People:CommissionCompleted(mission)
    local story=self.adventure.data.Narrative
    local key='flag:people_help:'..mission.SiteId..':'..mission.NpcId
    story:SetValue(key,story:GetValue(key)+1)
    local kind=self.adventure.narrative.townMissions.definitions:Get(mission.DefinitionId).kind
    if kind=='clear' or kind=='escort' then key='flag:people_safe:'..mission.SiteId;story:SetValue(key,story:GetValue(key)+1)end
    local person=self:Find(residentKey(mission.SiteId,mission.NpcId))
    if person then
        person:AddTrust(40)
        if person.BondKey~='' then assert(self:Find(person.BondKey)):AddTrust(20)end
    end
end
function People:Start()
    assert(not self.unsubscribe,'People are already subscribed')
    self.unsubscribe=self.adventure.battle.Changed:Subscribe(function(event)
        if event.kind~='battle_started' or CS.ProjectY.Data.ProfessionDuelState.Active(self.adventure.data)then return end
        local story=self.adventure.data.Narrative;story:SetValue('flag:people_battle_seq',story:GetValue('flag:people_battle_seq')+1)
        for _,actor in ipairs(self.adventure.battle:Units())do
            if roster().Find(self.adventure.data,actor.Id) and self.adventure.battle.stats:Template(actor).bodyInjuries then
                self:EnsureTarget({key=self.adventure.inspection.targets:Key(actor),actor=actor,owned=true})
            end
        end
    end)
end
function People:BattleToken()return tostring(self.adventure.data.Narrative:GetValue('flag:people_battle_seq'))end
function People:Victory()
    local story=self.adventure.data.Narrative;story:SetValue('flag:people_victories',story:GetValue('flag:people_victories')+1)
    local participants=self.adventure.data.PartyBonds
    for i=0,participants.ParticipantCount-1 do local actor=participants:GetParticipantAt(i)
        if roster().Find(self.adventure.data,actor.Id) and Life.Alive(actor) and self:ForActor(actor)then
            self.adventure.personalGrowth:RecordBattleVictory(actor,self:BattleToken())
        end
    end
end
function People:CanParley(party)
    if party.BattleSiteId>0 or party.LivingCount<=1 or self.adventure.parties.legends:Find(party.DefinitionId)then return false end
    for i=0,party.MemberCount-1 do local actor=party:GetMemberAt(i)
        if Life.Alive(actor) and self.adventure.battle.stats:Template(actor).bodyInjuries then return true end
    end
    return false
end
function People:Dispose()if self.unsubscribe then self.unsubscribe();self.unsubscribe=nil end end
function People:ValidateSaved(prepared,stats,effects)
    local data=bridge().Prepared(prepared)
    for i=0,data.Count-1 do local person=data:GetAt(i);local actor=person.Actor
        self.rules.profiles:Get(person.ProfileId)
        if person.NameId>0 then self.rules.names:Get(person.NameId)end
        assert(stats.units:Get(actor.TemplateId).bodyInjuries and stats.growth.profileByUnit[actor.TemplateId],L.PeopleSaveInvalid)
        stats.birth:Validate(actor);stats.titles:ValidateSaved(actor);effects:ValidateSaved(actor)
        for j=0,actor.TraitCount-1 do stats.growth.traits:Get(actor:GetTraitAt(j))end
        for j=0,actor.Growth.SkillCount-1 do stats.growth.skills:Get(actor.Growth:GetSkillAt(j))end
        assert(stats:MaximumHP(actor)==actor.MaxHP,L.PeopleSaveInvalid)
    end
    self.adventure.personalGrowth:ValidateSaved(prepared)
end
return People
