local LuaLanguage = require('Language')
local Class=require('Core.Class')
local Base=require('UI.UIPanelCtrl')
local Rich=require('UI.RichText')
local Journal=Class('MissionJournalCtr',Base)
local categories={{'town','UIMissionJournalCategories5'},{'basic','UIMissionJournalCategories4'},{'main','UIMissionJournalCategories3'},{'side','UIMissionJournalCategories2'},{'recruit','UIMissionJournalCategories'}}
local states=require('Config.LanguageProxy').Map(LuaLanguage,{inactive='UIMissionJournalInactive',active='UIMissionJournalActive',ready='UIMissionJournalReady',completed='UIMissionJournalCompleted',failed='UIMissionJournalFailed'})
local stateColors={inactive='#E6C477',active='#8BC6F2',ready='#8EDBB0',completed='#9DA99F',failed='#EA9B91'}
local function statusText(status) return '<color='..assert(stateColors[status])..'>'..states[status]..'</color>' end
function Journal:Bind()
    self.story=self.context.systems:Get('Narrative');self.pool={};self.missionRows={};self.tabs={};self.rewardRows={}
    for i=1,#categories do self.tabs[i]=self:CreateWidget('TabButton',self.view.Tabs) end
    self:Listen(self.view.Close,function() self.context.systems:Get('UI'):Close('MissionJournal') end)
    self:Listen(self.view.Companions,function() self.showCompanions=not self.showCompanions;self:Refresh() end)
    self:Listen(self.view.PrimaryAction,function() assert(self.primaryAction)() end)
end
function Journal:OnShow(args)
    self.demo=assert(args.demo);self.demo:SetStoryOpen(true)
    self.townSiteId=args.townSiteId;self.townNpcId=args.townNpcId
    self.category=self.townSiteId and 'town' or 'main';self.selected=nil;self.showCompanions=false
    self.view.Style:Prepare(self.demo.MainHudFont,1100);self:Refresh()
end
function Journal:SelectCategory(id)
    self.category=id;self.selected=nil;self.showCompanions=false;self:Refresh()
    self.view.MissionsScroll.verticalNormalizedPosition=1;self.view.Scroll.verticalNormalizedPosition=1
end
function Journal:Refresh()
    local rows={};local story=self.story;local font=self.demo.MainHudFont
    self.view.Title.text=self.townSiteId and LuaLanguage.UIMissionJournalTitleText2 or LuaLanguage.UIMissionJournalTitleText
    local minute=math.floor(story.data.Minutes%1440)
    self.view.Caption.text=string.format(LuaLanguage.UIMissionJournalCaptionText,math.floor(story.data.Minutes/1440)+1,minute//60,minute%60)
    for i,category in ipairs(categories) do
        self.tabs[i]:SetData(category[1],LuaLanguage[category[2]],not self.showCompanions and self.category==category[1],font,function(id) self:SelectCategory(id) end)
    end
    self.view.CompanionsText.text=self.showCompanions and LuaLanguage.UIMissionJournalCompanionsTextText2 or LuaLanguage.UIMissionJournalCompanionsTextText
    local missions={}
    for _,mission in ipairs(story:Rows()) do if mission.category==self.category then missions[#missions+1]=mission end end
    if self.category=='town' then missions=story.townMissions:Rows(self.townSiteId,self.townNpcId) end
    local selected
    for _,mission in ipairs(missions) do if mission.id==self.selected then selected=mission end end
    selected=selected or missions[1];self.selected=selected and selected.id
    self.view.MissionsScroll.gameObject:SetActive(not self.showCompanions)
    for i,mission in ipairs(missions) do
        if not self.missionRows[i] then self.missionRows[i]=self:CreateWidget('NarrativeEntry',self.view.Missions) end
        local id=mission.id
        self.missionRows[i]:SetData({title=Rich.Escape(mission.name),body=statusText(mission.status),selected=id==self.selected,tone=mission.status},font,function()
            self.selected=id;self:Refresh();self.view.Scroll.verticalNormalizedPosition=1
        end)
    end
    for i=#missions+1,#self.missionRows do self.missionRows[i]:SetData(nil) end
    self.view.Objective.gameObject:SetActive(false)
    self.view.RewardTitle.gameObject:SetActive(false);self.view.Rewards.gameObject:SetActive(false)
    self.primaryAction=nil;self.view.PrimaryAction.gameObject:SetActive(false);self.view.PrimaryHint.DefaultText=''
    if self.showCompanions then
        self.view.DetailTitle.DefaultText=LuaLanguage.UIMissionJournalDetailTitleDefaultText2;self.view.Description.DefaultText=LuaLanguage.UIMissionJournalDescriptionDefaultText2
        for _,npc in ipairs(story.rules.npcs:All()) do
            local siteId=story.npcs.locations[npc.id];local site=siteId and story.adventure.sites[siteId]
            local location=npc.locationKind=='world_party' and LuaLanguage.UIMissionJournalLocation2 or (site and site.name or LuaLanguage.UIMissionJournalLocation)
            local activity=npc.locationKind=='world_party' and LuaLanguage.UIMissionJournalActivity or story.npcs:Schedule(npc.id).activity
            local recruited=story.data:GetValue('recruited:'..npc.id)~=0
            rows[#rows+1]={title=Rich.Escape(npc.name)..(recruited and LuaLanguage.UIMissionJournalTitle8 or ''),body=string.format(LuaLanguage.UIMissionJournalBody8, (Rich.Escape(npc.description)), (story.data:GetValue('relation:'..npc.id)), (Rich.Escape(story.rules.factions:Get(npc.factionId).name)), (story.data:GetValue('reputation:'..npc.factionId)), (Rich.Escape(location)), (Rich.Escape(activity)))}
        end
    elseif selected then
        self.view.DetailTitle.DefaultText=Rich.Escape(selected.name)..'\n<size=60%>'..statusText(selected.status)..'</size>'
        self.view.Description.DefaultText=Rich.Escape(selected.description)
        local objective={}
        if selected.objective then
            objective[#objective+1]='<color=#E6C477><b>'..LuaLanguage.MissionObjective..'</b></color>\n'..Rich.Escape(selected.objective)
            objective[#objective+1]='<size=90%><color=#B5C3BA>'..Rich.Escape(string.format(LuaLanguage.MissionPublisher,selected.publisher,selected.location))..'</color></size>'
        end
        local hint=selected.status=='completed' and LuaLanguage.MissionClaimedHint or selected.turnInHint
        if hint then objective[#objective+1]='<color='..(selected.status=='ready' and '#8EDBB0' or '#B5C3BA')..'>'..Rich.Escape(hint)..'</color>' end
        self.view.Objective.DefaultText=table.concat(objective,'\n');self.view.Objective.gameObject:SetActive(#objective>0)
        local rewards=selected.rewards
        self.view.RewardTitle.DefaultText=LuaLanguage.MissionRewards
        self.view.RewardTitle.gameObject:SetActive(#rewards>0);self.view.Rewards.gameObject:SetActive(#rewards>0)
        self.view.Rewards.sizeDelta=CS.UnityEngine.Vector2(0,math.ceil(#rewards/3)*112)
        for i,reward in ipairs(rewards) do
            if not self.rewardRows[i] then self.rewardRows[i]=self:CreateWidget('MissionReward',self.view.Rewards) end
            self.rewardRows[i]:SetData(reward,font)
        end
        for i=#rewards+1,#self.rewardRows do self.rewardRows[i]:SetData(nil) end
        local id=selected.id
        if selected.status=='inactive' or selected.status=='ready' then
            local command=selected.status=='inactive' and 'mission_accept' or 'mission_claim'
            if selected.contractId then command=selected.status=='inactive' and 'town_mission_accept' or 'town_mission_claim';id=selected.contractId end
            local reason=selected.reason or ''
            if reason=='' then reason=selected.status=='inactive' and LuaLanguage.MissionAcceptHint or LuaLanguage.MissionClaimHint end
            self.view.PrimaryText.DefaultText=selected.status=='inactive' and LuaLanguage.UIMissionJournalTitle7 or selected.contractId and LuaLanguage.UIMissionJournalTitle6 or LuaLanguage.UIMissionJournalTitle5
            self.view.PrimaryHint.DefaultText=Rich.Escape(reason)
            self.view.PrimaryAction.gameObject:SetActive(true);self.view.PrimaryAction.interactable=selected.status~='ready' or selected.claimable
            self.primaryAction=function() self.demo:SendCommand(command,id,0) end
        end
        if selected.contractId and selected.status=='active' and selected.kind=='escort' then
            local escort=story.townMissions.escort:Snapshot(selected.contractId)
            local function command(name)
                local demo,ui=self.demo,self.context.systems:Get('UI')
                demo:SendCommand(name,selected.contractId,0)
                if (demo.LastError or '')=='' and ui:IsOpen('MissionJournal') then ui:Close('MissionJournal') end
            end
            rows[#rows+1]={title=escort.attached and LuaLanguage.UIMissionJournalTitle4 or LuaLanguage.UIMissionJournalTitle3,
                body=escort.waiting and LuaLanguage.UIMissionJournalBody7 or escort.attached and LuaLanguage.UIMissionJournalBody6 or LuaLanguage.UIMissionJournalBody5,
                available=escort.attached or escort.canAttach,action=function() command(escort.attached and 'town_mission_detach' or 'town_mission_attach') end}
            if not escort.attached then rows[#rows+1]={title=LuaLanguage.UIMissionJournalTitle2,body=LuaLanguage.UIMissionJournalBody4,available=story.adventure.data.Phase=='map',
                action=function()
                    local demo=self.demo;self.context.systems:Get('UI'):Close('MissionJournal')
                    demo:SendCommand('world_pursue',escort.partyId,0)
                end} end
            if escort.inBattle then rows[#rows+1]={title=LuaLanguage.UIMissionJournalTitle,body=LuaLanguage.UIMissionJournalBody3,available=escort.canJoin,
                action=function() command('town_mission_join') end} end
        end
        if #selected.quests>0 then rows[#rows+1]={title=LuaLanguage.MissionStages,body='',plain=true} end
        for _,quest in ipairs(selected.quests) do
            local qid=quest.id;local complete=quest.status=='completed';local active=quest.status=='active'
            local title=Rich.Escape(quest.name)
            if complete then title='<s><color=#849184>'..title..'</color></s>'
            elseif active then title='<size=115%><b>'..title..'</b></size>' end
            local claim=quest.status=='ready' and not story.rules.quests:Get(qid).autoComplete
            rows[#rows+1]={title=title..'  <size=70%>'..statusText(quest.status)..'</size>',body=complete and '' or Rich.Escape(quest.description)..(active and quest.reason~='' and '\n\n<color=#8BC6F2>'..Rich.Escape(quest.reason)..'</color>' or ''),tone=quest.status,
                action=claim and function() self.demo:SendCommand('quest_claim',qid,0) end or nil}
        end
        if #rows==0 and not selected.contractId then rows[1]={title='',body=selected.status=='completed' and LuaLanguage.UIMissionJournalBody2 or LuaLanguage.UIMissionJournalBody,plain=true} end
    else
        self.view.DetailTitle.DefaultText=LuaLanguage.UIMissionJournalDetailTitleDefaultText;self.view.Description.DefaultText=LuaLanguage.UIMissionJournalDescriptionDefaultText
    end
    for i,row in ipairs(rows) do
        if not self.pool[i] then self.pool[i]=self:CreateWidget('NarrativeEntry',self.view.Content) end
        self.pool[i]:SetData(row,font,row.action)
    end
    for i=#rows+1,#self.pool do self.pool[i]:SetData(nil) end
    self.view.Hint.text=self.demo.LastError or '';self.revision=story.data.Revision;self.demoRevision=self.demo.BattleHUDRevision
end
function Journal:Tick() if self.revision~=self.story.data.Revision or self.demoRevision~=self.demo.BattleHUDRevision then self:Refresh() end end
function Journal:OnHide()
    if self.townSiteId and self.story.adventure.data.Phase=='area' then self.story.adventure.areas:CloseInteraction() end
    self.townSiteId=nil;self.townNpcId=nil
    if self.demo then self.demo:SetStoryOpen(false);self.demo=nil end
end
return Journal
