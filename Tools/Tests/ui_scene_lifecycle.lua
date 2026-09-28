package.path='Lua/?.lua;'..package.path
local Class=require('Core.Class')
local UI=require('UI.UISystem')
package.preload['Test.SceneLifecyclePanel']=function() return Class('SceneLifecyclePanel',require('UI.UIPanelCtrl')) end
local host={SceneVersion=0,destroyed=0}
function host:GetConfig(name) return {Layer='Main',ControllerModule='Test.SceneLifecyclePanel',Cache=true,CloseOnSceneChange=name~='Persistent'} end
function host:CreateView() return {} end
function host:GetPanel(view) return view end
function host:SetVisible() end
function host:SetOrder() end
function host:SetInteractable() end
function host:DestroyView() self.destroyed=self.destroyed+1 end
local ui=UI();ui:OnInit({services={UI=host},log=error})
local old=ui:Open('Old');local persistent=ui:Open('Persistent')
host.SceneVersion=1
local main=ui:Open('MainHud') -- 模拟 sceneLoaded 已发生，但本帧还未跑 UI Tick。
assert(old.disposed and ui.panels.Old==nil and host.destroyed==1)
ui:Tick(0,.016)
assert(main.visible and not main.disposed and ui.panels.MainHud.ctrl==main)
assert(persistent.visible and not persistent.disposed)
print('PASS new-scene HUD survives the first Tick; old-scene panels are disposed before opening')
host.SceneVersion=2;ui:Tick(0,.016)
assert(main.disposed and persistent.visible and host.destroyed==2)
print('PASS subsequent scene changes still close opted-in HUDs and preserve persistent panels')
ui:OnShutdown();assert(host.destroyed==3)
