local LuaLanguage = require('Language')
local Class=require('Core.Class')
local Base=require('UI.UIPanelCtrl')
local Rich=require('UI.RichText')
local Shop=Class('ShopCtr',Base)
function Shop:Bind()
    self.model=self.context.systems:Get('Adventure').shop;self.rows={}
    self:Listen(self.view.Close,function() self.demo:SendCommand('shop_close',0,0) end)
end
function Shop:OnShow(args)
    self.demo=assert(args.demo);self.demo:SetStoryOpen(true)
    self.view.Style:Prepare(self.demo.MainHudFont,900);self:Refresh();self.view.Scroll.verticalNormalizedPosition=1
end
function Shop:Refresh()
    if not self.model.data.IsOpen then return end
    local snapshot=self.model:Snapshot();local version=snapshot.version
    self.view.Title.text=string.format(LuaLanguage.UIShopTitleText, (snapshot.name))
    self.view.Caption.text=string.format(LuaLanguage.UIShopCaptionText,snapshot.template,snapshot.coins,snapshot.refreshDay)
    local rows=snapshot.rows
    if #rows==0 then rows={{name=LuaLanguage.UIShopName,empty=true}} end
    for i,row in ipairs(rows) do
        if not self.rows[i] then self.rows[i]=self:CreateWidget('NarrativeEntry',self.view.Content) end
        local id=row.id
        local body=row.empty and LuaLanguage.UIShopBody3 or string.format(LuaLanguage.UIShopBody2,
            row.price,row.count,row.width,row.height,row.reason~='' and row.reason or LuaLanguage.UIShopBody)
        local action
        if not row.empty then action=function() self.demo:SendCommand('shop_buy',id,version,1) end end
        self.rows[i]:SetData({title=Rich.Escape(row.name),body=body,available=row.available},self.demo.MainHudFont,action)
    end
    for i=#rows+1,#self.rows do self.rows[i]:SetData(nil) end
    self.view.Hint.text=self.demo.LastError~='' and self.demo.LastError or LuaLanguage.UIShopHintText
    self.revision=version;self.equipmentRevision=self.model.adventure.equipment.data.Revision
    self.coins=snapshot.coins;self.demoRevision=self.demo.BattleHUDRevision
end
function Shop:Tick()
    if not self.model.data.IsOpen then return end
    if self.revision~=self.model.data.Revision or self.equipmentRevision~=self.model.adventure.equipment.data.Revision or
        self.coins~=self.model.adventure.player.Coins or self.demoRevision~=self.demo.BattleHUDRevision then self:Refresh() end
end
function Shop:OnHide()
    if self.model.data.IsOpen then self.model:Close() end
    if self.demo then self.demo:SetStoryOpen(false);self.demo=nil end
end
return Shop
