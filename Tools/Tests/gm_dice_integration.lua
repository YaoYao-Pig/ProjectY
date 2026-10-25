-- Run with Tools/GM/run_checks.cs, replacing its Lua path with this file. No Play or player saves.
local registry=require('Core.SystemRegistry')(Services)
require('Game.Systems')(registry)
local Language=require('Language')
local messages={};local function test(name,run)run();messages[#messages+1]='PASS '..name end
function CloseGMPreview()registry:Shutdown();CloseGMPreview=nil;ShowGMDicePreview=nil;RevealGMDicePreview=nil end
local ok,err=xpcall(function()
    registry:Start()
    local gm,ui=registry:Get('GM'),registry:Get('UI')
    local demo={SelectedCharacterId=0,BattleHUDRevision=0,LastError=''}
    function demo:SetGMOpen(value)self.open=value end
    local panel=ui:Open('GM',{demo=demo,font=GMFont})
    local dice
    test('saved controls open the page, change each die and enforce the shared six-die limit',function()
        assert(not panel.view.DiceSettings.gameObject.activeSelf)
        panel.view.DiceOpen.onClick:Invoke();assert(panel.view.DiceSettings.gameObject.activeSelf and panel:DiceCount()==1)
        panel.view.DiceClear.onClick:Invoke();assert(panel:DiceCount()==0 and not panel.view.DiceThrow.interactable)
        local state=gm.dice.random.state;panel:RollDice();assert(gm.dice.random.state==state and not ui:IsOpen('DiceRoll'))
        for _,kind in ipairs(gm.dice.Kinds)do
            panel.view['Dice'..kind..'Plus'].onClick:Invoke()
            if kind~='D100' then assert(panel.diceCounts[kind]==1)end
        end
        assert(panel:DiceCount()==6 and not panel.view.DiceD100Plus.interactable and panel.diceCounts.D100==nil)
        panel.view.DiceD6Minus.onClick:Invoke();assert(panel.diceCounts.D6==0 and not panel.view.DiceD6Minus.interactable)
        panel.view.DiceD6Minus.onClick:Invoke();assert(panel:DiceCount()==5)
        panel.view.DiceD6Plus.onClick:Invoke();assert(panel:DiceCount()==6)
        assert(panel.view.DiceThrow.interactable)
    end)
    test('actual mixed-dice physics plays to settlement without consuming combat randomness or party state',function()
        local battle=Services.Adventure.Battle;local coins=Services.Player.Coins;local party=Services.Adventure.PartyCount
        battle:SetRandomSeed(876);local expected=battle:RollPercent();battle:SetRandomSeed(876)
        panel.view.DiceThrow.onClick:Invoke();assert(ui:IsOpen('DiceRoll'))
        assert(not panel.view.Frame.gameObject.activeSelf)
        dice=ui.panels.DiceRoll.ctrl
        assert(dice.check.kind=='roll' and #dice.check.dice==6 and not dice.view.Dice.Settled and dice.view.Result.text=='')
        assert(not ui:Back() and Services.UI.IsWorldPaused)
        local state=gm.dice.random.state;panel:RollDice();assert(gm.dice.random.state==state and dice.check.count==6)
        for _=1,40 do ui:Tick(0,.075)end
        assert(dice.view.Dice.Settled and dice.view.Continue.interactable and dice.view.Result.text==dice.check.reading)
        assert(battle:RollPercent()==expected and Services.Player.Coins==coins and Services.Adventure.PartyCount==party)
        dice.view.Continue.onClick:Invoke()
        ui:Tick(0,0);assert(panel.view.Frame.gameObject.activeSelf)
        assert(not ui:IsOpen('DiceRoll') and ui:IsOpen('GM') and Services.UI.IsWorldPaused)
    end)
    test('repeated dice and percentile tens use exact catalog faces, and reveal never rerolls',function()
        panel.view.DiceClear.onClick:Invoke()
        for _,kind in ipairs({'D6','D6','D20','D20','D100','D100'})do panel.view['Dice'..kind..'Plus'].onClick:Invoke()end
        panel.view.DiceThrow.onClick:Invoke();dice=ui.panels.DiceRoll.ctrl
        local reading=dice.check.reading;local state=gm.dice.random.state;local sum=0
        for _,die in ipairs(dice.check.dice)do
            if die.kind=='D100' then assert(die.value%10==0 and die.value>=0 and die.value<=90)end
            sum=sum+die.value
        end
        assert(sum==dice.check.sum)
        dice.view.Continue.onClick:Invoke();assert(ui:IsOpen('DiceRoll') and not dice.view.Dice.Settled)
        dice.view.Reveal.onClick:Invoke()
        assert(dice.view.Dice.Settled and dice.view.Result.text==reading and gm.dice.random.state==state)
        dice.view.Continue.onClick:Invoke();ui:Tick(0,0)
        assert(panel:DiceCount()==6 and panel.view.DiceSettings.gameObject.activeSelf and panel.view.Frame.gameObject.activeSelf)
    end)
    test('normal success and failure checks keep their result wording after a free roll',function()
        local Checks=require('Game.Presentation.DiceChecks')
        dice=ui:Open('DiceRoll',{check=Checks.Percent('Regression',43,70,true,'inclusive')})
        dice:Enqueue(Checks.Percent('Regression',80,70,false,'inclusive'))
        dice.view.Reveal.onClick:Invoke();assert(dice.view.Result.text:find(Language.DiceSuccess,1,true))
        assert(dice.view.Result.fontSize==dice.resultFontSize)
        dice.view.Continue.onClick:Invoke();dice.view.Reveal.onClick:Invoke()
        assert(dice.view.Result.text:find(Language.DiceFailure,1,true))
        dice.view.Continue.onClick:Invoke()
    end)
    test('returning, cached reopen and scene cleanup preserve choices and release all pause leases',function()
        panel.view.DiceBack.onClick:Invoke();assert(not panel.view.DiceSettings.gameObject.activeSelf)
        panel.view.Close.onClick:Invoke();assert(not Services.UI.IsWorldPaused and not demo.open)
        panel=ui:Open('GM',{demo=demo,font=GMFont});panel.view.DiceOpen.onClick:Invoke();assert(panel:DiceCount()==6)
        panel.view.DiceThrow.onClick:Invoke();ui:OnSceneChanged()
        assert(not ui:IsOpen('DiceRoll') and not ui:IsOpen('GM') and not Services.UI.IsWorldPaused)
        panel=ui:Open('GM',{demo=demo,font=GMFont});panel.view.DiceOpen.onClick:Invoke()
        panel.view.DiceClear.onClick:Invoke()
        for _,kind in ipairs({'D6','D6','D20','D20','D100','D100'})do panel.view['Dice'..kind..'Plus'].onClick:Invoke()end
    end)
    function ShowGMDicePreview()
        panel.view.DiceThrow.onClick:Invoke();ui:Tick(0,.75)
    end
    function RevealGMDicePreview()
        local ctrl=ui.panels.DiceRoll.ctrl;ctrl.view.Reveal.onClick:Invoke()
        CS.UnityEngine.Canvas.ForceUpdateCanvases();ctrl.view.Result:ForceMeshUpdate()
        assert(ctrl.view.Result.preferredHeight<=ctrl.view.Result.rectTransform.rect.height+.1,'GM result text must fit its saved panel')
    end
end,debug.traceback)
if not ok then CloseGMPreview();error(err,0)end
return 'GM dice integration: '..#messages..' checks passed\n'..table.concat(messages,'\n')
