local Class=require('Core.Class')
local Base=require('UI.UIPanelCtrl')
local Rich=require('UI.RichText')
local Journal=Class('MissionJournalCtr',Base)
local categories={{'basic','基础'},{'main','主线'},{'side','支线'},{'recruit','招募'}}
local states={inactive='可接取',active='进行中',ready='待领取',completed='已完成'}
function Journal:Bind()
    self.story=self.context.systems:Get('Narrative');self.pool={};self.missionRows={};self.tabs={}
    for i=1,#categories do self.tabs[i]=self:CreateWidget('TabButton',self.view.Tabs) end
    self:Listen(self.view.Close,function() self.context.systems:Get('UI'):Close('MissionJournal') end)
    self:Listen(self.view.Companions,function() self.showCompanions=not self.showCompanions;self:Refresh() end)
end
function Journal:OnShow(args)
    self.demo=assert(args.demo);self.demo:SetStoryOpen(true)
    self.category='main';self.selected=nil;self.showCompanions=false
    self.view.Style:Prepare(self.demo.MainHudFont,1100);self:Refresh()
end
function Journal:SelectCategory(id)
    self.category=id;self.selected=nil;self.showCompanions=false;self:Refresh()
    self.view.MissionsScroll.verticalNormalizedPosition=1;self.view.Scroll.verticalNormalizedPosition=1
end
function Journal:Refresh()
    local rows={};local story=self.story;local font=self.demo.MainHudFont
    self.view.Title.text='任务手记'
    local minute=math.floor(story.data.Minutes%1440)
    self.view.Caption.text=string.format('第 %d 天 · %02d:%02d',math.floor(story.data.Minutes/1440)+1,minute//60,minute%60)
    for i,category in ipairs(categories) do
        self.tabs[i]:SetData(category[1],category[2],not self.showCompanions and self.category==category[1],font,function(id) self:SelectCategory(id) end)
    end
    self.view.CompanionsText.text=self.showCompanions and '返回任务' or '同行者'
    local missions={}
    for _,mission in ipairs(story:Rows()) do if mission.category==self.category then missions[#missions+1]=mission end end
    local selected
    for _,mission in ipairs(missions) do if mission.id==self.selected then selected=mission end end
    selected=selected or missions[1];self.selected=selected and selected.id
    self.view.MissionsScroll.gameObject:SetActive(not self.showCompanions)
    for i,mission in ipairs(missions) do
        if not self.missionRows[i] then self.missionRows[i]=self:CreateWidget('NarrativeEntry',self.view.Missions) end
        local id=mission.id
        self.missionRows[i]:SetData({title=Rich.Escape(mission.name),body=states[mission.status],selected=id==self.selected},font,function()
            self.selected=id;self:Refresh();self.view.Scroll.verticalNormalizedPosition=1
        end)
    end
    for i=#missions+1,#self.missionRows do self.missionRows[i]:SetData(nil) end
    if self.showCompanions then
        self.view.DetailTitle.DefaultText='同行者与城镇居民';self.view.Description.DefaultText='关系、所属阵营与当前日程'
        for _,npc in ipairs(story.rules.npcs:All()) do
            local siteId=story.npcs.locations[npc.id];local site=siteId and story.adventure.sites[siteId]
            local recruited=story.data:GetValue('recruited:'..npc.id)~=0
            rows[#rows+1]={title=Rich.Escape(npc.name)..(recruited and ' · 已入队' or ''),body=Rich.Escape(npc.description)..'\n好感 '..story.data:GetValue('relation:'..npc.id)..' · '..Rich.Escape(story.rules.factions:Get(npc.factionId).name)..'声望 '..story.data:GetValue('reputation:'..npc.factionId)..'\n'..Rich.Escape(site and site.name or '本地图没有该 NPC 的出生地点')..' · '..Rich.Escape(story.npcs:Schedule(npc.id).activity)}
        end
    elseif selected then
        self.view.DetailTitle.DefaultText=Rich.Escape(selected.name)..'  <size=65%>'..states[selected.status]..'</size>'
        self.view.Description.DefaultText=Rich.Escape(selected.description)
        local id=selected.id
        if selected.status=='inactive' or selected.status=='ready' then
            rows[#rows+1]={title=selected.status=='inactive' and '接取任务' or '领取任务奖励',body=Rich.Escape(selected.reason),available=selected.status~='ready' or selected.claimable,
                action=function() self.demo:SendCommand(selected.status=='inactive' and 'mission_accept' or 'mission_claim',id,0) end}
        end
        for _,quest in ipairs(selected.quests) do
            local qid=quest.id;local complete=quest.status=='completed';local active=quest.status=='active'
            local title=Rich.Escape(quest.name)
            if complete then title='<s><color=#849184>'..title..'</color></s>'
            elseif active then title='<size=115%><b>'..title..'</b></size>' end
            local claim=quest.status=='ready' and not story.rules.quests:Get(qid).autoComplete
            rows[#rows+1]={title=title..'  <size=70%>'..states[quest.status]..'</size>',body=complete and '' or Rich.Escape(quest.description)..(active and quest.reason~='' and '\n'..Rich.Escape(quest.reason) or ''),
                action=claim and function() self.demo:SendCommand('quest_claim',qid,0) end or nil}
        end
        if #rows==0 then rows[1]={title='',body=selected.status=='completed' and '这段旅程已经完成。' or '尚未激活任务阶段。',plain=true} end
    else
        self.view.DetailTitle.DefaultText='暂无任务';self.view.Description.DefaultText='此分类下还没有可接取或已接取的任务。'
    end
    for i,row in ipairs(rows) do
        if not self.pool[i] then self.pool[i]=self:CreateWidget('NarrativeEntry',self.view.Content) end
        self.pool[i]:SetData(row,font,row.action)
    end
    for i=#rows+1,#self.pool do self.pool[i]:SetData(nil) end
    self.view.Hint.text=self.demo.LastError or '';self.revision=story.data.Revision;self.demoRevision=self.demo.BattleHUDRevision
end
function Journal:Tick() if self.revision~=self.story.data.Revision or self.demoRevision~=self.demo.BattleHUDRevision then self:Refresh() end end
function Journal:OnHide() if self.demo then self.demo:SetStoryOpen(false);self.demo=nil end end
return Journal
