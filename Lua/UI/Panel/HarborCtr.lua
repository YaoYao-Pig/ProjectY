local L=require('Language')
local Class=require('Core.Class')
local Base=require('UI.UIPanelCtrl')
local Rich=require('UI.RichText')
local Panel=Class('HarborCtr',Base)
function Panel:Bind()
    self.model=self.context.systems:Get('Adventure').water;self.rows={}
    self:Listen(self.view.Close,function()self.demo:SendCommand('water_close')end)
end
function Panel:OnShow(args)
    self.demo=assert(args.demo);self.demo:SetStoryOpen(true)
    self.view.Style:Prepare(self.demo.MainHudFont,900);self:Refresh();self.view.Scroll.verticalNormalizedPosition=1
end
function Panel:Refresh()
    if not self.model.data.IsOpen then return end
    local snapshot=self.model:Menu();local version=snapshot.version
    self.view.Title.text=snapshot.name
    self.view.Caption.text=string.format(L.WaterMenuCaption,snapshot.caption,snapshot.coins)
    for i,row in ipairs(snapshot.rows) do
        if not self.rows[i] then self.rows[i]=self:CreateWidget('NarrativeEntry',self.view.Content) end
        local command,id=row.command,row.id
        self.rows[i]:SetData({title=Rich.Escape(row.name),body=row.body,available=row.available},self.demo.MainHudFont,
            function()self.demo:SendCommand(command,id,version)end)
    end
    for i=#snapshot.rows+1,#self.rows do self.rows[i]:SetData(nil) end
    self.view.Hint.text=self.demo.LastError~='' and self.demo.LastError or L.WaterControls
    self.revision=version;self.inventoryRevision=self.model.adventure.equipment.data.Revision
    self.coins=snapshot.coins;self.demoRevision=self.demo.BattleHUDRevision
end
function Panel:Tick()
    if self.model.data.IsOpen and (self.revision~=self.model.data.Revision or self.inventoryRevision~=self.model.adventure.equipment.data.Revision or
        self.coins~=self.model.adventure.player.Coins or self.demoRevision~=self.demo.BattleHUDRevision) then self:Refresh() end
end
function Panel:OnHide()
    if self.model.data.IsOpen then self.model:Close() end
    if self.demo then self.demo:SetStoryOpen(false);self.demo=nil end
end
return Panel
