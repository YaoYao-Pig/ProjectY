local Class=require('Core.Class')
local Base=require('UI.UIPanelCtrl')
local Rich=require('UI.RichText')
local Panel=Class('WorldPartyCtr',Base)
function Panel:Bind()
    self.model=self.context.systems:Get('Adventure').parties;self.rows={}
    self:Listen(self.view.Close,function()self.demo:SendCommand('world_close')end)
end
function Panel:OnShow(args)
    self.demo=assert(args.demo);self.demo:SetStoryOpen(true)
    self.view.Style:Prepare(self.demo.MainHudFont,900);self:Refresh();self.view.Scroll.verticalNormalizedPosition=1
end
function Panel:Refresh()
    if not self.model.data.IsOpen then return end
    local snapshot=self.model:ContactSnapshot();local version,inventoryVersion=snapshot.version,snapshot.inventoryRevision
    self.view.Title.text=snapshot.name
    self.view.Caption.text=snapshot.caption..'  |  持有 '..snapshot.coins..' 金币'
    for i,row in ipairs(snapshot.rows) do
        if not self.rows[i] then self.rows[i]=self:CreateWidget('NarrativeEntry',self.view.Content) end
        local command,id=row.command,row.id
        self.rows[i]:SetData({title=Rich.Escape(row.name),body=row.body,available=row.available},self.demo.MainHudFont,
            function()self.demo:SendCommand(command,id,version,inventoryVersion)end)
    end
    for i=#snapshot.rows+1,#self.rows do self.rows[i]:SetData(nil) end
    self.view.Hint.text=self.demo.LastError~='' and self.demo.LastError or '关闭后时间保持暂停；按空格继续，1 / 2 / 3 调整流速。'
    self.revision=version;self.inventoryRevision=inventoryVersion;self.coins=snapshot.coins;self.demoRevision=self.demo.BattleHUDRevision
end
function Panel:Tick()
    if self.model.data.IsOpen and (self.revision~=self.model.data.Revision or self.inventoryRevision~=self.model.adventure.equipment.data.Revision or
        self.coins~=self.model.adventure.player.Coins or self.demoRevision~=self.demo.BattleHUDRevision) then self:Refresh() end
end
function Panel:OnHide()
    if self.model.data.IsOpen then self.model.data:Close() end
    if self.demo then self.demo:SetStoryOpen(false);self.demo=nil end
end
return Panel
