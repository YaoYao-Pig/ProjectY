local Class=require('Core.Class')
local Base=require('UI.UIPanelCtrl')
local Widgets=require('UI.GrowthWidgets')
local Journal=Class('AdventureJournalCtr',Base)
function Journal:Bind()
    self.growth=self.context.systems:Get('Growth');self.view.Style:Prepare()
    self:Listen(self.view.Growth,function() self.demo:OpenGrowth() end)
end
function Journal:OnShow(args) self.demo=assert(args.demo);self:Refresh() end
function Journal:Refresh()
    local rows={};local all=self.growth.chronicle:Rows()
    for i=1,math.min(#all,self.growth.rules.settings.logVisibleCount) do
        local row=all[i];rows[#rows+1]={title='【'..row.label..'】'..row.title,body=row.body,color=row.color}
    end
    Widgets.Rows(self,'Logs','GrowthRow',rows)
    self.count=self.growth.data.JournalCount
end
function Journal:Tick() if self.count~=self.growth.data.JournalCount then self:Refresh() end end
function Journal:OnHide() self.demo=nil end
return Journal
