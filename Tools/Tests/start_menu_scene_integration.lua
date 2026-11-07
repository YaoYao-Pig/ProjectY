-- Actual panel, native widgets and offscreen stage. Only campaign commands use an adapter.
local registry=require('Core.SystemRegistry')(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('UI',require('UI.UISystem'),{'Config'})
local Menu=require('UI.Panel.StartMenuCtr');local originalBind=Menu.Bind
local demo={session=false,opened=0,closed=0,created=0,loaded=0,deleted=0,settings=0,quits=0,error='',succeed=false}
local saves={Length=3,
    [0]={Id='alpha',WorldName='晨风 <b>群岛</b>',SavedAt='2026-10-20 09:10:11',Seed=4294967295,TargetCells=10000,PartySummary='3名队员 · Lv1 / Lv2 / Lv3',CanLoad=true,Error='',Legacy=false,HasWorld=true},
    [1]={Id='legacy',WorldName='',SavedAt='2026-10-19 20:10:11',Seed=0,TargetCells=0,PartySummary='2名队员 · Lv1 / Lv1',CanLoad=true,Error='',Legacy=true,HasWorld=false},
    [2]={Id='bad',WorldName='',SavedAt='2026-10-18 08:10:11',Seed=0,TargetCells=0,PartySummary='无法读取队伍',CanLoad=false,Error='损坏档错误：<bad>',Legacy=false,HasWorld=false}}
local function preview()
    local result=CS.ProjectY.Data.WorldMenuSelection()
    result.Status=0;return result
end
local failList=false
local adapter={Font=function()return MenuFixtureFont end,HasSession=function()return demo.session end,
    RandomSeed=function()return '4294967295'end,Preview=preview,PreviewSave=preview,
    Saves=function()if failList then error('测试目录不可读')end;return saves end,
    NewGame=function(_,seed,size,startId,name)demo.created=demo.created+1;demo.seed=seed;demo.size=size;demo.startId=startId;demo.name=name;demo.error='测试生成失败';return demo.succeed end,
    Load=function(_,id)demo.loaded=demo.loaded+1;demo.id=id;demo.error='测试读取失败';return demo.succeed end,
    CanDelete=function(_,id)return not (demo.session and id=='alpha')end,
    Delete=function(_,id)demo.deleted=demo.deleted+1;demo.deletedId=id;local next={Length=0};for i=0,saves.Length-1 do if saves[i].Id~=id then next[next.Length]=saves[i];next.Length=next.Length+1 end end;saves=next;return true end,
    Volumes=function()return {[0]=.8,[1]=.45,[2]=.8}end,
    SetOptions=function(_,master,music,effects,reduced)demo.settings=demo.settings+1;demo.master=master;demo.music=music;demo.effects=effects;demo.reduced=reduced end,
    Quit=function()demo.quits=demo.quits+1 end,
    LastError=function()return demo.error end,
    OnOpen=function()demo.opened=demo.opened+1 end,OnClose=function()demo.closed=demo.closed+1 end}
function Menu:Bind()originalBind(self);self.bridge=adapter end
local menu,ui;local reports={}
local function click(button)button.onClick:Invoke();menu.view.Style:Advance(2)end
local function test(name,run)run();reports[#reports+1]='PASS '..name end
local ok,err=xpcall(function()
    registry:Start();ui=registry:Get('UI');menu=ui:Open('StartMenu',{demo=demo,mode='home'});menu.view.Style:RenderNow()
    test('home owns a real stage, explicit bindings and modal pause',function()
        assert(menu.view.HomePage.gameObject.activeSelf and not menu.view.NewPage.gameObject.activeSelf)
        assert(menu.view.Style.Font==MenuFixtureFont and Services.UI.IsWorldPaused and not ui:Back())
        assert(menu.view.Start~=nil and menu.view.Settings~=nil and menu.view.About~=nil and menu.view.Quit~=nil)
        if CaptureMenuScene then CaptureMenuScene('home')end
    end)
    test('camera transition gates repeated actions and returns to home',function()
        menu.view.Start.onClick:Invoke();assert(menu.view.Style.IsTransitioning)
        menu.view.Load.onClick:Invoke();assert(menu.mode=='new')
        menu.view.Create.onClick:Invoke();assert(demo.created==0)
        menu.view.Style:Advance(.55)
        if CaptureMenuScene then CaptureMenuScene('transition')end
        menu.view.Style:Advance(2);assert(not menu.view.Style.IsTransitioning and menu.view.NewPage.gameObject.activeSelf)
        click(menu.view.Back);assert(menu.mode=='home' and menu.view.HomePage.gameObject.activeSelf)
        CS.UnityEngine.PlayerPrefs.SetInt(CS.ProjectY.UI.StartMenuView.ReducedMotionPreference,1)
        menu.view.Load.onClick:Invoke();menu.view.Style:Advance(.35);assert(not menu.view.Style.IsTransitioning and menu.mode=='load')
        click(menu.view.Back);CS.UnityEngine.PlayerPrefs.SetInt(CS.ProjectY.UI.StartMenuView.ReducedMotionPreference,0)
    end)
    test('creation preserves twelve origins, kits, uint seeds and world sizes',function()
        click(menu.view.Start);assert(#menu.startRows==12)
        for i,row in ipairs(menu.startRows)do click(row.view.Button);assert(menu.selectedStart==i)end
        click(menu.startRows[4].view.Button);menu.view.WorldName.text='暮风群岛'
        for _,seed in ipairs({'','-1','4294967296'})do menu.view.Seed.text=seed;menu:ValidateSeed();local before=demo.created;click(menu.view.Create);assert(demo.created==before)end
        menu.view.Seed.text='0';assert(menu:ValidateSeed());click(menu.view.RandomSeed)
        for i,size in ipairs({2500,10000,30000,100000})do menu.view.Size.value=i-1;click(menu.view.Create);assert(demo.seed=='4294967295' and demo.size==size and demo.startId==4 and demo.name=='暮风群岛')end
        if CaptureMenuScene then CaptureMenuScene('create')end
        click(menu.view.Back)
    end)
    test('save selection is separate from load and corrupted entries stay visible',function()
        click(menu.view.Load);assert(#menu.rows==3 and not menu.rows[3].view.Button.interactable)
        assert(menu.rows[1].view.Title.DefaultText:find('&lt;',1,true) or not menu.rows[1].view.Title.DefaultText:find('<b>',1,true))
        click(menu.rows[2].view.Button);assert(demo.loaded==0 and menu.selectedSave.Id=='legacy')
        click(menu.view.LoadSelected);assert(demo.loaded==1 and demo.id=='legacy' and menu.view.Hint.text=='测试读取失败')
        click(menu.rows[1].view.Button)
        if CaptureMenuScene then CaptureMenuScene('load')end
    end)
    test('per-cell deletion confirms, cancellation is inert, corruption can be deleted',function()
        click(menu.rows[3].view.Delete);assert(menu.dialog=='delete' and demo.deleted==0)
        click(menu.view.DialogCancel);assert(demo.deleted==0 and not menu.view.Dialog.gameObject.activeSelf)
        click(menu.rows[3].view.Delete)
        if CaptureMenuScene then CaptureMenuScene('delete')end
        click(menu.view.DialogConfirm);assert(demo.deleted==1 and demo.deletedId=='bad' and saves.Length==2)
        assert(not menu.rows[3].view.Root.gameObject.activeSelf)
        demo.session=true;menu:RefreshSaves();assert(not menu.rows[1].view.Delete.interactable)
        click(menu.rows[1].view.Delete);assert(demo.deleted==1 and not menu.dialog)
        demo.session=false;click(menu.view.Back)
    end)
    test('settings apply explicitly; About and quit stay modal',function()
        click(menu.view.Settings);assert(menu.dialog=='settings')
        menu.view.MasterVolume.value=.3;menu.view.ReducedMotion.isOn=true
        click(menu.view.DialogCancel);assert(demo.settings==0)
        click(menu.view.Settings);menu.view.MasterVolume.value=.3;click(menu.view.DialogConfirm);assert(demo.settings==1 and math.abs(demo.master-.3)<.001)
        click(menu.view.About);assert(menu.dialog=='about' and menu.view.DialogText.text:find(CS.UnityEngine.Application.version,1,true));menu:Back();assert(not menu.dialog)
        click(menu.view.Quit);click(menu.view.DialogCancel);assert(demo.quits==0)
    end)
    test('directory errors, empty lists, cached reopen and release',function()
        failList=true;click(menu.view.Load);assert(menu.view.Empty.gameObject.activeSelf and menu.view.Hint.text:find('测试目录不可读',1,true))
        failList=false;saves={Length=0};click(menu.view.Back);click(menu.view.Load);assert(menu.view.Empty.gameObject.activeSelf and not menu.view.LoadSelected.gameObject.activeSelf)
        ui:Close('StartMenu');assert(not Services.UI.IsWorldPaused)
        menu=ui:Open('StartMenu',{demo=demo,mode='home'});click(menu.view.Settings);click(menu.view.DialogConfirm);assert(demo.settings==2,'duplicated listeners')
        ui:Close('StartMenu');assert(demo.opened==demo.closed)
    end)
end,debug.traceback)
registry:Shutdown();Menu.Bind=originalBind
if not ok then error(err)end
return table.concat(reports,'\n')
