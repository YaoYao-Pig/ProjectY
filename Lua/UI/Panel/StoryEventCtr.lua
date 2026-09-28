local Class=require('Core.Class')
local Base=require('UI.UIPanelCtrl')
local Widgets=require('UI.GrowthWidgets')
local Event=Class('StoryEventCtr',Base)
function Event:Bind()
    self.adventure=self.context.systems:Get('Adventure');self.view.Style:Prepare()
    self:Listen(self.view.Continue,function() self.demo:SendCommand('return',0,0) end)
end
function Event:OnShow(args)
    self.demo=assert(args.demo);self.demo:SetStoryOpen(true);self:Refresh()
end
function Event:Refresh()
    local data=self.adventure.data;local events=self.adventure.events
    local event=events.events:Get(data.EventId)
    self.view.Title.text=event.name;self.view.Style:SetArt(self.view.Illustration,event.illustration)
    self.view.Caption.text=data.EventLocation..'  ·  '..self.adventure.battle.stats:Template(events:Subject()).name
    self.view.Description.text=data.Phase=='result' and data.ResultText or events:Text(event.description)
    self.view.Continue.gameObject:SetActive(data.Phase=='result')
    self.view.ContinueText.text=data.EventReturnPhase=='area' and '继续探索' or '返回旅途'
    local choices={}
    if data.Phase=='event' then for _,id in ipairs(event.choiceIds) do
        local row=events.choices:Get(id);local ok,reason=events:CanChoose(id)
        local rewards={}
        if row.costCoins>0 then rewards[#rewards+1]='消耗 '..row.costCoins..' 金币' end
        for i,itemId in ipairs(row.itemIds) do rewards[#rewards+1]=events.equipment.rules.items:Get(itemId).name..' ×'..row.itemCounts[i] end
        if row.experience>0 then rewards[#rewards+1]='经验 +'..row.experience end
        if #row.unlockTreeIds>0 then rewards[#rewards+1]='开启新的天赋道路' end
        if row.potentialPoints>0 then rewards[#rewards+1]='可能唤醒潜力' end
        choices[#choices+1]={id=id,title=events:Text(row.label),body=ok and table.concat(rewards,' · ') or reason,available=ok}
    end end
    Widgets.Rows(self,'Choices','StoryChoice',choices,function(row) self.demo:SendCommand('choose',row.id,0) end)
    self.view.Hint.text=self.demo.LastError or '';self.revision=self.demo.BattleHUDRevision
end
function Event:Tick() if self.revision~=self.demo.BattleHUDRevision then self:Refresh() end end
function Event:OnHide() if self.demo then self.demo:SetStoryOpen(false);self.demo=nil end end
return Event
