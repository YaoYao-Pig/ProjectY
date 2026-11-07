package.path='Lua/?.lua;'..package.path
local Class=require('Core.Class')
local Base=require('UI.UIPanelCtrl')
local UI=require('UI.UISystem')
local Language=require('Language')
local Pause=require('UI.Panel.PauseMenuCtr')
local Save=require('Game.Adventure.CharacterSave')
local MainHud=require('UI.Panel.MainHudCtr')
local native=Services~=nil
local adventure={data={Phase='map'},parties={data={IsOpen=false}},camp={data={IsOpen=false}},shop={data={IsOpen=false}},
    economy={data={ActiveBankSite=0}},narrative={data={DialogueOpen=false}},equipment={worldLoot={session={Active=false}}}}
local stopped,saved,quit=0,0,0
local saveSuccess=true
local originalSave=Save.Write
Save.Write=function(value)assert(value==adventure);saved=saved+1;return saveSuccess,saveSuccess and '' or 'disk failure'end
local originalBind=Pause.Bind
function Pause:Bind()originalBind(self);self.bridge={Quit=function()quit=quit+1 end}end
local loadArgs
local Load=Class('PauseMenuLoadFixture',Base)
function Load:OnShow(args)loadArgs=args end
package.loaded['UI.Panel.StartMenuCtr']=Load
local host
if native then host=Services.UI else
    CS={UnityEngine={Vector2=function(x,y)return {x=x,y=y}end},ProjectY={Samples={CampaignMenu={}}}}
    local function signal()
        local s={listeners={}}
        function s:AddListener(f)self.listeners[f]=true end
        function s:RemoveListener(f)self.listeners[f]=nil end
        function s:Invoke()for f in pairs(self.listeners)do f()end end
        return s
    end
    local function object()return {activeSelf=true,SetActive=function(self,v)self.activeSelf=v end}end
    host={SceneVersion=0,IsWorldPaused=false,visible={}}
    function host:GetConfig(name)return {Layer='Popup',ControllerModule='UI.Panel.'..name..'Ctr',Cache=true,Modal=true,CloseOnBack=name=='PauseMenu',PauseWorldOnOpen=true,CloseOnSceneChange=true}end
    function host:CreateView()
        local v={}
        for _,key in ipairs({'Resume','Save','Load','Settings','Quit','QuitConfirm','QuitCancel'})do v[key]={onClick=signal()}end
        v.Hint={};v.Page={rect={width=640}};v.QuitDialog={gameObject=object()};v.Actions={}
        function v:Get(key)return self[key]end
        return v
    end
    function host:GetPanel(view)return view end
    function host:SetVisible(view,visible)self.visible[view]=visible;self.IsWorldPaused=false;for _,v in pairs(self.visible)do if v then self.IsWorldPaused=true end end end
    function host:SetOrder()end
    function host:SetInteractable()end
    function host:DestroyView()end
end
local ui=UI();local systems={}
function systems:Get(name)
    if name=='UI' then return ui elseif name=='Adventure' then return adventure elseif name=='MapArea' then return {Stop=function()stopped=stopped+1 end} end
    error('Unexpected system '..name)
end
local context={services={UI=host},systems=systems,log=error}
ui:OnInit(context)
local hud={context=context,demo={},view={Menu={gameObject={SetActive=function()end}}}}
local ok,err=xpcall(function()
    assert(MainHud.OnBack(hud));assert(ui:IsOpen('PauseMenu') and host.IsWorldPaused)
    local menu=ui.panels.PauseMenu.ctrl
    ui:Tick(0,.1);assert(menu.view.Page.anchoredPosition.x<0)
    ui:Tick(0,.1);assert(menu.view.Page.anchoredPosition.x==0)
    if CapturePauseMenu then CapturePauseMenu(menu.reference)end
    menu.view.Settings.onClick:Invoke();assert(ui:IsOpen('PauseMenu') and saved==0 and quit==0)
    menu.view.Save.onClick:Invoke();assert(saved==1 and menu.view.Hint.DefaultText==Language.PauseMenuSaved)
    saveSuccess=false;menu.view.Save.onClick:Invoke();assert(saved==2 and menu.view.Hint.DefaultText==string.format(Language.PauseMenuSaveFailed,'disk failure'))
    adventure.data.Phase='battle';menu.view.Save.onClick:Invoke();menu.view.Load.onClick:Invoke()
    assert(saved==2 and not loadArgs and menu.view.Hint.DefaultText==Language.CampaignFinishEvent)
    adventure.data.Phase='map';menu.view.Quit.onClick:Invoke();assert(menu.quitDialog and quit==0)
    assert(ui:Back() and not menu.quitDialog and ui:IsOpen('PauseMenu'))
    menu.view.Quit.onClick:Invoke();menu.view.QuitConfirm.onClick:Invoke();assert(quit==1)
    menu.view.QuitCancel.onClick:Invoke();menu.view.Resume.onClick:Invoke();assert(not ui:IsOpen('PauseMenu') and not host.IsWorldPaused)
    MainHud.OnBack(hud);menu.view.Quit.onClick:Invoke();menu.view.QuitCancel.onClick:Invoke()
    assert(ui:Back() and not ui:IsOpen('PauseMenu') and not host.IsWorldPaused)
    MainHud.OnBack(hud);adventure.data.Phase='area';menu.view.Load.onClick:Invoke()
    assert(stopped==1 and loadArgs.demo==hud.demo and loadArgs.mode=='load')
    assert(not ui:IsOpen('PauseMenu') and ui:IsOpen('StartMenu') and host.IsWorldPaused)
    assert(not ui:Back(),'Non-closeable load modal must not fall through')
    ui:Close('StartMenu');assert(not host.IsWorldPaused)
    MainHud.OnBack(hud);ui:OnSceneChanged();assert(not ui:IsOpen('PauseMenu') and not host.IsWorldPaused)
end,debug.traceback)
ui:OnShutdown();Save.Write=originalSave;Pause.Bind=originalBind
assert(ok,err)
print('PASS ESC menu: slide, resume/Back, settings placeholder, save feedback/restrictions, load pause handoff, quit confirmation and scene cleanup')
return 'PASS pause menu interactions and lifecycle'
