local Class=require('Core.Class')
local Base=require('UI.UIPanelCtrl')
local Language=require('Language')
local Preparation=require('Game.Adventure.CampaignPreparation')
local Save=require('Game.Adventure.CharacterSave')
local Menu=Class('PauseMenuCtr',Base)

function Menu:Bind()
    self.adventure=self.context.systems:Get('Adventure')
    self.bridge=CS.ProjectY.Samples.CampaignMenu
    self:Listen(self.view.Resume,function()self:Close()end)
    self:Listen(self.view.Save,function()self:SaveGame()end)
    self:Listen(self.view.Load,function()self:LoadGame()end)
    self:Listen(self.view.Quit,function()self:SetQuitDialog(true)end)
    self:Listen(self.view.QuitCancel,function()self:SetQuitDialog(false)end)
    self:Listen(self.view.QuitConfirm,function()self.bridge.Quit()end)
    -- Settings is intentionally a placeholder with no action.
end
function Menu:OnShow(args)
    self.demo=assert(args.demo)
    self:SetQuitDialog(false)
    self.view.Hint.DefaultText=Preparation.Check(self.adventure) or Language.PauseMenuHint
    self.elapsed=0
    self.view.Page.anchoredPosition=CS.UnityEngine.Vector2(-self.view.Page.rect.width,0)
end
function Menu:Tick(_,unscaledDt)
    if self.elapsed==nil then return end
    self.elapsed=math.min(.2,self.elapsed+unscaledDt)
    local remaining=1-self.elapsed/.2
    self.view.Page.anchoredPosition=CS.UnityEngine.Vector2(-self.view.Page.rect.width*remaining^3,0)
    if self.elapsed==.2 then self.elapsed=nil end
end
function Menu:SaveGame()
    local reason=Preparation.Check(self.adventure)
    if reason then self.view.Hint.DefaultText=reason;return end
    local success,message=Save.Write(self.adventure)
    self.view.Hint.DefaultText=success and Language.PauseMenuSaved or string.format(Language.PauseMenuSaveFailed,message)
end
function Menu:LoadGame()
    local reason=Preparation.Check(self.adventure)
    if reason then self.view.Hint.DefaultText=reason;return end
    if self.adventure.data.Phase=='area' then self.context.systems:Get('MapArea'):Stop()end
    -- Acquire the load page's pause lease before releasing this menu's lease.
    self.context.systems:Get('UI'):Open('StartMenu',{demo=self.demo,mode='load'})
    self:Close()
end
function Menu:SetQuitDialog(visible)
    self.quitDialog=visible
    self.view.QuitDialog.gameObject:SetActive(visible)
    self.view.Actions.interactable=not visible
end
function Menu:OnBack()
    if self.quitDialog then self:SetQuitDialog(false);return true end
    return false
end
function Menu:OnHide()
    self.elapsed=nil;self.demo=nil;self:SetQuitDialog(false)
end
return Menu
