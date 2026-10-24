local Class=require('Core.Class')
local Base=require('UI.UIPanelCtrl')
local LuaLanguage=require('Language')
local Rich=require('UI.RichText')
local Settlement=Class('MissionSettlementCtr',Base)
function Settlement:Bind()
    self.pool={}
    self:Listen(self.view.Confirm,function()
        if #self.queue>0 then self:Present(table.remove(self.queue,1))
        else self:Close() end
    end)
end
function Settlement:OnShow(args)
    self.font=assert(args.font);self.queue={}
    self.view.Style:Prepare(self.font,820)
    self:Present(assert(args.receipt))
end
function Settlement:Enqueue(receipt)
    self.queue[#self.queue+1]=receipt;self:UpdateConfirm()
end
function Settlement:UpdateConfirm()
    self.view.ConfirmText.DefaultText=#self.queue>0 and string.format(LuaLanguage.MissionSettlementNext,#self.queue) or LuaLanguage.Confirm
end
function Settlement:Present(receipt)
    self.receipt=receipt
    self.view.Title.DefaultText=LuaLanguage.MissionSettlementTitle
    self.view.MissionName.DefaultText=Rich.Escape(receipt.title)
    self.view.Caption.DefaultText=#receipt.rows>0 and LuaLanguage.MissionSettlementReceived or LuaLanguage.MissionSettlementEmpty
    for i,row in ipairs(receipt.rows) do
        if not self.pool[i] then self.pool[i]=self:CreateWidget('MissionReward',self.view.Rewards) end
        self.pool[i]:SetData(row,self.font)
    end
    for i=#receipt.rows+1,#self.pool do self.pool[i]:SetData(nil) end
    self.view.Scroll.verticalNormalizedPosition=1
    self.view.Footer.DefaultText=LuaLanguage.MissionSettlementSaved
    self:UpdateConfirm()
end
function Settlement:OnHide() self.queue=nil;self.receipt=nil end
return Settlement
