local Class=require('Core.Class')
local Widget=require('UI.UIWidgetCtrl')
local Bridge=CS.ProjectY.Samples.WorldMapOverviewBridge
local Hud=Class('WorldMapHud',Widget)
function Hud:Bind()
    self:Listen(self.view.Close,function() Bridge.Close(self.demo) end)
    self:Listen(self.view.Home,function() Bridge.Home(self.demo) end)
    self:Listen(self.view.Missions,function() self.demo:SendCommand('hud_missions') end)
end
function Hud:OnShow(args)
    self.demo=assert(args.demo)
    self.view.MarkerRoot.gameObject:SetActive(false)
end
function Hud:OnHide()
    self.view.MarkerRoot.gameObject:SetActive(false)
    self.demo=nil
end
return Hud
