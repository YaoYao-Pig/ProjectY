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
    self.view.Title.text=snapshot.name..' · 商品'
    self.view.Caption.text=string.format('%s  |  持有 %d 金币  |  下次补货：第 %d 天',snapshot.template,snapshot.coins,snapshot.refreshDay)
    local rows=snapshot.rows
    if #rows==0 then rows={{name='本期没有商品',empty=true}} end
    for i,row in ipairs(rows) do
        if not self.rows[i] then self.rows[i]=self:CreateWidget('NarrativeEntry',self.view.Content) end
        local id=row.id
        local body=row.empty and '商人正在等待补货，请下次再来。' or string.format('%d 金币 / 件  ·  剩余 %d  ·  占格 %d × %d\n%s',
            row.price,row.count,row.width,row.height,row.reason~='' and row.reason or '点击购买 1 件')
        local action
        if not row.empty then action=function() self.demo:SendCommand('shop_buy',id,version,1) end end
        self.rows[i]:SetData({title=Rich.Escape(row.name),body=body,available=row.available},self.demo.MainHudFont,action)
    end
    for i=#rows+1,#self.rows do self.rows[i]:SetData(nil) end
    self.view.Hint.text=self.demo.LastError~='' and self.demo.LastError or '商品直接收入共享背包；售罄后需等待补货。'
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
