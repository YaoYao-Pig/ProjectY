-- Actual registered panel/widgets and native UI components, with an isolated campaign-command adapter.
-- Host supplies Services (PreviewScene UIHost) and MenuFixtureFont. Never creates a real world/save.
local registry=require('Core.SystemRegistry')(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('UI',require('UI.UISystem'),{'Config'})
local Menu=require('UI.Panel.StartMenuCtr');local originalBind=Menu.Bind
local demo={session=false,opened=0,closed=0,random=0,created=0,loaded=0,error='',succeed=false}
local saves={Length=3,
    [0]={Id='alpha',SavedAt='2026-10-20 09:10:11',Seed=4294967295,TargetCells=10000,RecipeId=3,PartyCount=3,PartySummary='3名队员 · Lv1 / Lv2 / Lv3',CanLoad=true,Error='',Legacy=false,HasWorld=true},
    [1]={Id='legacy',SavedAt='2026-10-19 20:10:11',Seed=0,TargetCells=0,PartyCount=2,PartySummary='2名队员 · Lv1 / Lv1',CanLoad=true,Error='',Legacy=true,HasWorld=false},
    [2]={Id='bad',SavedAt='2026-10-18 08:10:11',Seed=0,TargetCells=0,PartyCount=0,PartySummary='无法读取队伍',CanLoad=false,Error='损坏档错误：<bad>',Legacy=false,HasWorld=false}}
local failList=false
local adapter={Font=function(value)assert(value==demo);return MenuFixtureFont end,
    HasSession=function(value)assert(value==demo);return value.session end,
    RandomSeed=function()demo.random=demo.random+1;return '4294967295'end,
    Saves=function(value)assert(value==demo);if failList then error('测试目录不可读')end;return saves end,
    NewGame=function(value,seed,size,startId)assert(value==demo);value.created=value.created+1;value.seed=seed;value.size=size;value.startId=startId;value.error='测试生成失败';return value.succeed end,
    Load=function(value,id)assert(value==demo);value.loaded=value.loaded+1;value.id=id;value.error='测试读取失败';return value.succeed end,
    LastError=function(value)return value.error end,
    OnOpen=function(value)value.opened=value.opened+1 end,OnClose=function(value)value.closed=value.closed+1 end}
function Menu:Bind()originalBind(self);self.bridge=adapter end
local messages={};local function test(name,run)run();messages[#messages+1]='PASS '..name end
local ok,err=xpcall(function()
    registry:Start();local ui=registry:Get('UI');local menu=ui:Open('StartMenu',{demo=demo,mode='home'})
    test('saved menu opens before any HUD/world and cannot be closed by Back',function()
        assert(menu.view.Title.text=='远征' and menu.view.HomePage.gameObject.activeSelf)
        assert(not menu.view.NewPage.gameObject.activeSelf and not menu.view.LoadPage.gameObject.activeSelf)
        assert(not menu.view.Resume.gameObject.activeSelf and not menu.view.Back.gameObject.activeSelf)
        assert(menu.view.Style.Font==MenuFixtureFont and Services.UI.IsWorldPaused)
        assert(not ui:Back() and ui:IsOpen('StartMenu') and demo.opened==1)
        assert(menu.view.Size.options.Count==4 and menu.view.Size.value==1)
    end)
    test('new-world form accepts uint endpoints, rejects invalid seeds and maps all four sizes',function()
        menu.view.Start.onClick:Invoke();assert(menu.mode=='new' and menu.view.Back.gameObject.activeSelf)
        assert(menu.view.Seed.text=='4294967295' and menu.view.Create.interactable)
        assert(#menu.startRows==12 and menu.selectedStart==1 and menu.view.StartName.DefaultText=='退伍步卒')
        for i,row in ipairs(menu.startRows) do
            row.view.Button.onClick:Invoke();assert(menu.selectedStart==i)
            local preview=require('Game.Adventure.CampaignStarts').Preview(registry:Get('Config'),i)
            assert(menu.view.StartName.DefaultText==preview.name and menu.itemRows[1].row.amount==preview.coins)
            for n,item in ipairs(preview.equipmentRows) do
                local card=menu.itemRows[n+1];assert(card.row.itemId==item.itemId and card.row.amount==item.count)
                if item.iconPath~='' then assert(card.view.Icon.enabled and not card.view.Glyph.gameObject.activeSelf) end
            end
        end
        menu.startRows[4].view.Button.onClick:Invoke();assert(menu.view.StartParty.DefaultText:find('洛恩',1,true))
        if CaptureStartMenu then CaptureStartMenu() end
        for _,value in ipairs({'','-1','4294967296'})do
            menu.view.Seed.text=value;menu:ValidateSeed();assert(not menu.view.Create.interactable)
            local calls=demo.created;menu.view.Create.onClick:Invoke();assert(demo.created==calls)
        end
        menu.view.Seed.text='0';assert(menu:ValidateSeed())
        local calls=demo.random;menu.view.RandomSeed.onClick:Invoke();assert(demo.random==calls+1 and menu.view.Seed.text=='4294967295')
        for index,size in ipairs({2500,10000,30000,100000})do
            menu.view.Size.value=index-1;menu.view.Create.onClick:Invoke()
            assert(demo.seed=='4294967295' and demo.size==size and demo.startId==4 and ui:IsOpen('StartMenu'))
            assert(menu.view.Hint.text=='测试生成失败')
        end
        demo.succeed=true;menu.view.Create.onClick:Invoke()
        assert(not ui:IsOpen('StartMenu') and not Services.UI.IsWorldPaused and demo.closed==1)
    end)
    demo.succeed=false;menu=ui:Open('StartMenu',{demo=demo,mode='load'})
    test('scroll list shows readable save metadata and disables corrupt entries',function()
        assert(menu.mode=='load' and #menu.rows==3 and not menu.view.Empty.gameObject.activeSelf)
        assert(menu.rows[1].view.Body.DefaultText:find('4294967295',1,true))
        assert(menu.rows[1].view.Body.DefaultText:find('10000 格',1,true) and menu.rows[1].view.Body.DefaultText:find('3名队员',1,true))
        assert(menu.rows[2].view.Title.DefaultText:find('旧版存档',1,true))
        assert(not menu.rows[3].view.Button.interactable and menu.rows[3].view.Body.DefaultText:find('损坏档错误',1,true))
        menu.rows[3].view.Button.onClick:Invoke();assert(demo.loaded==0,'Invoked disabled row must not submit a corrupt save')
        menu.rows[1].view.Button.onClick:Invoke();assert(demo.loaded==1 and demo.id=='alpha' and menu.view.Hint.text=='测试读取失败')
        demo.succeed=true;menu.rows[2].view.Button.onClick:Invoke();assert(demo.id=='legacy' and not ui:IsOpen('StartMenu'))
    end)
    demo.succeed=false;demo.session=true;menu=ui:Open('StartMenu',{demo=demo,mode='home'})
    test('cached menu resumes a session, exposes directory errors and does not duplicate listeners',function()
        assert(menu.view.Resume.gameObject.activeSelf)
        menu.view.Start.onClick:Invoke();assert(menu.selectedStart==4);local random=demo.random;menu.view.RandomSeed.onClick:Invoke();assert(demo.random==random+1)
        menu.view.Back.onClick:Invoke();assert(menu.mode=='home')
        failList=true;menu.view.Load.onClick:Invoke();assert(menu.view.Empty.text=='无法读取存档列表' and menu.view.Hint.text:find('测试目录不可读',1,true))
        for _,row in ipairs(menu.rows)do assert(not row.view.Root.gameObject.activeSelf)end
        failList=false;saves={Length=0};menu.view.Back.onClick:Invoke();menu.view.Load.onClick:Invoke()
        assert(menu.view.Empty.gameObject.activeSelf and menu.view.Empty.text:find('还没有存档',1,true))
        menu.view.Resume.onClick:Invoke();assert(not ui:IsOpen('StartMenu') and demo.opened==demo.closed and not Services.UI.IsWorldPaused)
    end)
end,debug.traceback)
registry:Shutdown();Menu.Bind=originalBind
if not ok then error(err)end
return table.concat(messages,'\n')
