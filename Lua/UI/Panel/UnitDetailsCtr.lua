local Class=require('Core.Class')
local Base=require('UI.UIPanelCtrl')
local L=require('Language')
local Identity=require('Game.Presentation.CharacterIdentity')
local Panel=Class('UnitDetailsCtr',Base)
function Panel:Bind()
    self.adventure=self.context.systems:Get('Adventure')
    self.inspection=self.adventure.inspection
    self.rows={}
    self:Listen(self.view.Close,function()self:Close()end)
    self:Listen(self.view.Talk,function()
        if not self.targetKey then return end
        local ok,reason=self.adventure.peopleDialogue:OpenTarget(self.targetKey)
        if not ok then self.error=reason;self:Refresh();return end
        self:Close()
    end)
    self:Listen(self.view.Observe,function()
        if not self.targetKey then return end
        local ok,reason=self.inspection:Observe(self.targetKey,self.observerId)
        self.error=not ok and reason or nil
        self.demo:SendCommand('snapshot')
        self:Refresh()
    end)
    self:Listen(self.view.PreviousObserver,function()self:CycleObserver(-1)end)
    self:Listen(self.view.NextObserver,function()self:CycleObserver(1)end)
end
function Panel:CycleObserver(offset)
    for index,row in ipairs(self.observers)do if row.id==self.observerId then
        self.observerId=self.observers[(index-1+offset)%#self.observers+1].id
        self.error=nil;self:Refresh();return
    end end
end
function Panel:OnShow(args)
    self.demo=assert(args.demo)
    CS.ProjectY.Samples.UnitInspectionInput.SetOpen(self.demo,true)
    self.view.Style:Prepare(self.demo.MainHudFont,1100)
    self.targetKey=args.key;self.observerId=self.demo.SelectedCharacterId;self.error=nil
    if args.actorId then
        for _,row in ipairs(self.inspection:Targets())do
            if row.actor.Id==args.actorId then self.targetKey=row.key;break end
        end
    end
    self:Refresh()
    self.view.TargetScroll.verticalNormalizedPosition=1
end
function Panel:Select(key)
    self.targetKey=key;self.error=nil;self:Refresh()
    self.view.AttributeScroll.verticalNormalizedPosition=1
    self.view.TraitScroll.verticalNormalizedPosition=1
end
function Panel:Refresh()
    local targets=self.inspection:Targets()
    local selected
    for _,row in ipairs(targets)do if row.key==self.targetKey then selected=row;break end end
    if not selected then selected=targets[1];self.targetKey=selected and selected.key or nil end
    for index,row in ipairs(targets)do
        if not self.rows[index] then self.rows[index]=self:CreateWidget('InspectionTarget',self.view.TargetRows)end
        self.rows[index]:SetData(row,row.key==self.targetKey,function(key)self:Select(key)end)
    end
    for index=#targets+1,#self.rows do self.rows[index]:SetData(nil)end
    self.observers=self.inspection:Observers()
    local valid=false
    for _,row in ipairs(self.observers)do if row.id==self.observerId then valid=true;break end end
    if not valid then self.observerId=self.observers[1] and self.observers[1].id or 0 end
    local battle=self.adventure.data.Phase=='battle'
    self.view.PreviousObserver.interactable=not battle and #self.observers>1
    self.view.NextObserver.interactable=not battle and #self.observers>1
    local model=self.targetKey and self.inspection:Build(self.targetKey,self.observerId)
    self.view.Observe.interactable=model~=nil and model.canObserve
    local canTalk,talkReason=self.adventure.people:CanOpen(self.targetKey)
    self.view.Talk.interactable=canTalk
    self.view.TalkText.DefaultText=selected and selected.owned and L.PeopleDialogueTalkOwned or L.PeopleDialogueTalkOther
    self.view.Subtitle.DefaultText=canTalk and L.PeopleDialogueInspectionHint or talkReason or L.InspectionSubtitle
    self.view.TargetName.DefaultText=selected and Identity.Format(Identity.Read(self.adventure.battle.stats,selected.actor,selected.name),25,14,'805723') or L.InspectionSelect
    self.view.Cost.DefaultText=model and not model.owned and model.cost or ''
    self.view.Result.DefaultText=self.error or (model and model.result or '')
    self.view.Reason.DefaultText=model and model.reason or ''
    self.view.ObserverLabel.DefaultText=string.format(L.InspectionObserver,model and model.observerName or L.InspectionUnknown)
    local attributes,traits={},{}
    if model then
        for _,row in ipairs(model.attributes)do attributes[#attributes+1]=row.known and string.format(L.InspectionAttributeLine,row.name,row.value)or L.InspectionUnknown end
        for _,row in ipairs(model.traits)do traits[#traits+1]=row.known and string.format(L.InspectionTraitBlock,row.title,row.body)or L.InspectionUnknown end
        if #traits==0 then traits[1]=L.InspectionNoTraits end
        traits[#traits+1]=L.InspectionSkills
        for _,row in ipairs(model.skills)do
            traits[#traits+1]=row.known and string.format(L.InspectionSkillBlock,row.title,row.body)or L.InspectionUnknown
        end
        if #model.skills==0 then traits[#traits+1]=L.InspectionNoSkills end
    end
    self.view.Attributes.DefaultText=table.concat(attributes,'\n\n')
    self.view.Traits.DefaultText=table.concat(traits,'\n\n')
end
function Panel:OnHide()
    CS.ProjectY.Samples.UnitInspectionInput.SetOpen(self.demo,false)
    self.demo:SendCommand('snapshot')
    self.targetKey=nil
end
return Panel
