-- Real data, configured models and authored workbench in an isolated Edit Mode host.
local registry=require('Core.SystemRegistry')(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('Battle',require('Game.Battle.BattleSystem'),{'Config'})
registry:Register('Equipment',require('Game.Equipment.EquipmentSystem'),{'Config'})
registry:Register('UI',require('UI.UISystem'),{'Config'})
local report
local ok,err=xpcall(function()
    registry:Start();local data=Services.Adventure;data:Reset(4623)
    local battle,eq,ui=registry:Get('Battle'),registry:Get('Equipment'),registry:Get('UI')
    local actor=data:AddPartyActor(1,1);actor:SetMaxHP(battle.stats:MaximumHP(actor));actor:Restore()
    eq.data.Grid:Configure(12,10)
    local choices,attachment={},nil
    for _,definition in ipairs(eq.rules.weapons:All())do
        local count=#definition.socketIds
        if count==2 or count==3 then choices[count]=choices[count] or definition end
        if count==4 and not choices[4] then
            local slot=eq.rules.sockets:Get(definition.socketIds[4])
            for _,rune in ipairs(eq.rules.runes:All())do if rune.slotKind==slot.kind then choices[4]=definition;attachment=rune;break end end
        end
    end
    assert(choices[2] and choices[3] and choices[4] and attachment,'Need configured two/three/four-slot weapon samples')
    for _,count in ipairs({4,2,3})do assert(eq:Grant(choices[count].id,1))end
    assert(eq:Grant(attachment.id,1))
    local function weapon(itemId)
        for i=0,eq.data.WeaponCount-1 do local row=eq.data:GetWeaponAt(i);if row.ItemId==itemId then return row end end
        error('Missing isolated weapon')
    end
    local adapter={snapshots=0}
    function adapter:SetEquipmentOpen(value)self.open=value end
    function adapter:SendCommand(command)assert(command=='snapshot');self.snapshots=self.snapshots+1 end
    local panel=ui:Open('EquipmentWorkbench',{demo=adapter})
    local four=weapon(choices[4].id);panel.weaponId=four.Id;panel.socketId=0;panel:Refresh()
    CheckWorkbenchCallouts(panel.view.Workbench,4)
    panel.view.Socket4.onClick:Invoke()
    local fourth=choices[4].socketIds[4]
    assert(panel.socketId==fourth and panel.view.SocketText4.text:find('● ',1,true)==1)
    local option
    for _,entry in ipairs(panel.options)do if entry.row and entry.row.value==attachment.id then option=entry end end
    assert(option and option.row.enabled);option.view.Button.onClick:Invoke()
    assert(four:GetRune(fourth)==attachment.id and eq.data:CountItem(attachment.id)==0 and adapter.snapshots==1)
    assert(panel.view.Remove.interactable and panel.view.Stats.text:find(attachment.description,1,true))
    local visual=eq.rules:WeaponVisual(four)
    assert(visual.sockets[4].asset.id==eq.rules.items:Get(attachment.id).assetId,'Fourth attachment missing from actual weapon snapshot')
    CheckWorkbenchCallouts(panel.view.Workbench,4)
    for _,count in ipairs({2,3,4})do
        panel.weaponId=weapon(choices[count].id).Id;panel.socketId=0;panel:Refresh()
        CheckWorkbenchCallouts(panel.view.Workbench,count)
        for i=count+1,4 do assert(not panel.view['Socket'..i].gameObject.activeSelf and panel.view['SocketText'..i].text=='')end
    end
    panel.view.Socket4.onClick:Invoke();assert(panel.socketId==fourth)
    panel.view.Remove.onClick:Invoke()
    assert(four:GetRune(fourth)==0 and eq.data:CountItem(attachment.id)==1 and adapter.snapshots==2)
    ui:Close('EquipmentWorkbench');assert(not adapter.open and not Services.UI.IsWorldPaused)
    report='PASS real fourth button selection/attachment/snapshot; 4 -> 2 -> 3 -> 4 callout visibility, spacing and cleanup'
end,debug.traceback)
registry:Shutdown();if not ok then error(err,0)end
return report
