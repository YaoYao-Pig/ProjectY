-- Run through the existing Tools/GM/run_checks.cs in an isolated Edit Mode host; no player saves.
local registry=require('Core.SystemRegistry')(Services);require('Game.Systems')(registry)
local Language=require('Language')
local messages={};local function test(name,run)run();messages[#messages+1]='PASS '..name end
function CloseGMPreview()registry:Shutdown();CloseGMPreview=nil end
local ok,err=xpcall(function()
    registry:Start()
    local adventure,gm,ui=registry:Get('Adventure'),registry:Get('GM'),registry:Get('UI')
    local equipment=adventure.equipment;local data=equipment.data;local items=equipment.rules.items
    local weapon,filler,expected= nil,nil,0
    for _,item in ipairs(items:All())do
        if item.kind=='weapon' or item.kind=='wearable' then expected=expected+1 end
        if item.kind=='weapon' and not equipment.acquisition.definitions:Find(item.id) then weapon=weapon or item end
        if item.kind=='wearable' and item.width==1 and item.height==1 and equipment.rules.wearables:Get(item.id).slot=='ring'
            and not equipment.acquisition.definitions:Find(item.id) then filler=filler or item end
    end
    assert(weapon and filler)
    assert(not gm:Execute('grant_equipment',weapon.id))
    adventure:Start(412)
    local actor=adventure.data:GetPartyAt(0)
    local demo={BattleHUDRevision=0,SelectedCharacterId=actor.Id,LastError=''}
    function demo:SetGMOpen(value)self.open=value end
    function demo:SendCommand(command,id)
        self.command=command;self.itemId=id
        local success,why=gm:Execute(command:sub(4),id)
        self.LastError=success and '' or why;self.BattleHUDRevision=self.BattleHUDRevision+1
    end
    local panel=ui:Open('GM',{demo=demo,font=GMFont})
    local browser=panel.equipmentBrowser
    local function cellFor(id)
        browser.view.Search.text=tostring(id);browser:Tick()
        for index,row in ipairs(browser.rows)do if row.id==id then
            browser.list:ScrollTo(index,0);return assert(browser.list:GetVisibleCell(index))
        end end
        error('Catalog entry missing: '..id)
    end
    test('saved browser opens the full catalog without granting and virtualizes its rows',function()
        local revision=data.Revision
        panel.view.EquipmentOpen.onClick:Invoke();ui:Tick(0,0)
        assert(browser.view.Root.gameObject.activeSelf and #browser.rows==expected and data.Revision==revision)
        local first,last=browser.list:GetVisibleRange();assert(first==1 and last<expected)
        local distant=expected
        browser.list:ScrollTo(distant,0);local cell=assert(browser.list:GetVisibleCell(distant))
        assert(cell.view.Title.text:find(tostring(browser.rows[distant].id),1,true))
        browser.view.Search.text='not-a-real-equipment-name';browser:Tick()
        assert(#browser.rows==0 and browser.view.Count.text==Language.GMEquipmentEmpty)
        browser.view.Search.text=weapon.name;browser:Tick();assert(#browser.rows>0)
        assert(data.Revision==revision and Services.UI.IsWorldPaused)
    end)
    test('weapon and wearable buttons add one real unequipped instance without spending coins',function()
        local coins=adventure.player.Coins;local weapons,wearables=data.WeaponCount,data.WearableCount
        cellFor(weapon.id).view.Add.onClick:Invoke()
        assert(demo.command=='gm_grant_equipment' and demo.itemId==weapon.id and demo.LastError=='')
        assert(data.WeaponCount==weapons+1 and data.WearableCount==wearables)
        local added=data:GetWeaponAt(data.WeaponCount-1)
        assert(added.ItemId==weapon.id and added.OwnerActorId==0 and data.Grid:Find('w'..added.Id))
        cellFor(filler.id).view.Add.onClick:Invoke()
        assert(data.WearableCount==wearables+1 and adventure.player.Coins==coins)
        local gear=data:GetWearableAt(data.WearableCount-1)
        assert(gear.ItemId==filler.id and gear.OwnerActorId==0 and data.Grid:Find('g'..gear.Id))
        assert(browser.view.Result.text==string.format(Language.GMEquipmentGranted,filler.name))
    end)
    test('actual full grids reject both equipment kinds atomically and show the full-bag message',function()
        for _=1,data.Grid.Width*data.Grid.Height do
            if not equipment:CanGrant({filler.id},{1}) then break end
            assert(gm:Execute('grant_equipment',filler.id))
        end
        assert(not equipment:CanGrant({filler.id},{1}))
        local revision,count,wearables,weapons=data.Revision,data.Grid.Count,data.WearableCount,data.WeaponCount
        for _,id in ipairs({weapon.id,filler.id})do
            cellFor(id).view.Add.onClick:Invoke()
            assert(demo.LastError==Language.EquipmentGrantBagFull and browser.view.Result.text==Language.EquipmentGrantBagFull)
            assert(data.Revision==revision and data.Grid.Count==count and data.WearableCount==wearables and data.WeaponCount==weapons)
        end
        assert(not data:Worn(actor.Id,'leftRing'))
        local ring=data:GetWearableAt(data.WearableCount-1);assert(ring.ItemId==filler.id)
        assert(data:Wear(actor.Id,'leftRing',ring.Id))
        cellFor(filler.id).view.Add.onClick:Invoke()
        assert(demo.LastError=='' and data.WearableCount==wearables+1,'Grant must recover after one legal slot is freed')
        cellFor(weapon.id).view.Add.onClick:Invoke()
        assert(browser.view.Result.text==Language.EquipmentGrantBagFull)
    end)
    test('back, cached reopen and closing release views and preserve inventory',function()
        local revision=data.Revision
        browser.view.Back.onClick:Invoke();assert(not browser.view.Root.gameObject.activeSelf)
        panel.view.Close.onClick:Invoke();assert(not Services.UI.IsWorldPaused and not demo.open)
        panel=ui:Open('GM',{demo=demo,font=GMFont});browser=panel.equipmentBrowser
        panel.view.EquipmentOpen.onClick:Invoke();assert(#browser.rows==expected and data.Revision==revision)
        cellFor(weapon.id).view.Add.onClick:Invoke();assert(browser.view.Result.text==Language.EquipmentGrantBagFull)
        browser.view.Search.text='';browser:Tick()
    end)
end,debug.traceback)
if not ok then CloseGMPreview();error(err,0)end
return 'GM equipment integration: '..#messages..' checks passed\n'..table.concat(messages,'\n')
