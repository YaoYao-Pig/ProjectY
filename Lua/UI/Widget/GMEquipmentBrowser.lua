local Class=require('Core.Class')
local Base=require('UI.UIWidgetCtrl')
local LuaLanguage=require('Language')
local Browser=Class('GMEquipmentBrowser',Base)
function Browser:Bind()
    self.model=self.context.systems:Get('GM').equipment;self.rows={}
    self.list=self:AddWidget(require('UI.UIScrollList'),self.view.List)
    self.list:Configure({templates={Equipment=self.view.Template},spacing=6,overscan=80,
        onCreate=function(cell)
            self.list:Listen(cell.view.Add,function()self:Grant(assert(self.rows[cell.index],'Equipment list entry is no longer bound'))end)
        end,
        onBind=function(cell,index)
            local row=self.rows[index]
            cell.view.Title.font=self.font;cell.view.Detail.font=self.font;cell.view.AddText.font=self.font
            cell.view.Title.text=string.format(LuaLanguage.GMEquipmentRowTitle,row.name,row.id)
            cell.view.Detail.text=string.format(LuaLanguage.GMEquipmentRowDetail,
                row.kind=='weapon' and LuaLanguage.GMEquipmentWeapon or LuaLanguage.GMEquipmentWearable,row.width,row.height)
            cell.view.AddText.text=LuaLanguage.GMEquipmentAdd;cell.view.Add.interactable=true
        end})
    self:Listen(self.view.Back,function()self:ClosePage()end)
end
function Browser:OnShow(args)
    self.demo=assert(args.demo);self.font=assert(args.font)
    for _,key in ipairs({'Title','Help','SearchLabel','SearchText','Count','Result','BackText'})do self.view[key].font=self.font end
    self.view.Root.gameObject:SetActive(false);self.rows={};self.list:SetItemCount(0)
end
function Browser:Open()
    self.view.Root.gameObject:SetActive(true)
    self.view.Search.text='';self.view.Result.text='';self:Refresh()
end
function Browser:Refresh()
    self.query=self.view.Search.text;self.rows=self.model:Search(self.query)
    self.view.Count.text=#self.rows==0 and LuaLanguage.GMEquipmentEmpty or string.format(LuaLanguage.GMEquipmentCount,#self.rows)
    self.list:SetItemCount(#self.rows)
end
function Browser:Grant(row)
    local previous=self.demo.BattleHUDRevision
    self.demo:SendCommand('gm_grant_equipment',row.id,0)
    if self.demo.BattleHUDRevision==previous then self.view.Result.text=LuaLanguage.UIGMResultText3;return end
    local reason=self.demo.LastError
    self.view.Result.text=reason and reason~='' and reason or string.format(LuaLanguage.GMEquipmentGranted,row.name)
end
function Browser:Tick()
    if self.view.Root.gameObject.activeSelf and self.query~=self.view.Search.text then self:Refresh()end
end
function Browser:ClosePage()
    self.view.Root.gameObject:SetActive(false);self.rows={};self.list:SetItemCount(0)
end
function Browser:OnHide()self.demo=nil;self.font=nil end
return Browser
