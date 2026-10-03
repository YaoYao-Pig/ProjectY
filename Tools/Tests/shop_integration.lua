-- 独立 Edit Mode LuaEnv，真实配表、C# 状态、城镇和 Panel；存档路径由宿主提供临时文件。
local registry=require('Main')
local adventure=registry:Get('Adventure');local story=registry:Get('Narrative');local ui=registry:Get('UI')
local messages={}
local function test(name,body) body();messages[#messages+1]='PASS '..name end
local function signature(stock)
    local rows={};for i=0,stock.Count-1 do local row=stock:GetAt(i);rows[#rows+1]=row.EntryId..':'..row.Count end;return table.concat(rows,',')
end
test('atomic C# purchase rejects insufficient coins, full bag, stale clicks, wrong entries and sold-out stock',function()
    local shop=CS.ProjectY.Data.ShopData();local equipment=CS.ProjectY.Data.EquipmentData();local player=CS.ProjectY.Data.PlayerData()
    equipment.Grid:Define(31,1,1);equipment.Grid:Define(81,1,1);equipment.Grid:Define(21,1,1);equipment.Grid:Define(40,1,1);equipment.Grid:Define(51,1,1);equipment.Grid:Configure(1,1)
    local stock=shop:Refresh(1,1,1,1,0,{1},{31},{2},{3});shop:Open(stock)
    local version=shop.Revision
    assert(shop:Buy(1,1,version,equipment,player,'ammo',0,0,0)=='金币不足')
    assert(shop.Revision==version and stock:Find(1).Count==2 and equipment:CountItem(31)==0)
    player:AddCoins(100);equipment:AddStack(81,1)
    assert(shop:Buy(1,1,version,equipment,player,'ammo',0,0,0):find('背包空间不足'))
    assert(player.Coins==100 and stock:Find(1).Count==2 and shop.Revision==version)
    equipment:Clear();equipment.Grid:Configure(1,1)
    assert(shop:Buy(99,1,version,equipment,player,'ammo',0,0,0)~='')
    assert(shop:Buy(1,3,version,equipment,player,'ammo',0,0,0)~='')
    assert(shop:Buy(1,0,version,equipment,player,'ammo',0,0,0)~='')
    assert(shop:Buy(1,1,version,equipment,player,'ammo',0,0,0)=='')
    assert(player.Coins==97 and equipment:CountItem(31)==1 and stock:Find(1).Count==1)
    assert(shop:Buy(1,1,version,equipment,player,'ammo',0,0,0)~='')
    assert(shop:Buy(1,1,shop.Revision,equipment,player,'ammo',0,0,0)=='','Stack purchase should fit an occupied same-item cell')
    assert(player.Coins==94 and equipment:CountItem(31)==2 and stock:Find(1).Count==0)
    assert(shop:Buy(1,1,shop.Revision,equipment,player,'ammo',0,0,0)~='')
    shop:Close();assert(shop:Buy(1,1,shop.Revision,equipment,player,'ammo',0,0,0)~='')
    for index,kind in ipairs({'weapon','wearable','magazine'}) do
        equipment:Clear();equipment.Grid:Configure(1,1)
        local item=({40,51,21})[index]
        shop:Open(shop:Refresh(1,1,1,1,1,{index},{item},{1},{0}))
        assert(shop:Buy(index,1,shop.Revision,equipment,player,kind,31,12,8)=='')
        assert(equipment.Grid.Count==1 and player.Coins==94)
        if kind=='magazine' then assert(equipment:GetMagazineAt(0).Rounds==8 and equipment:GetMagazineAt(0).Capacity==12) end
        shop:Close()
    end
end)
adventure:Start(412)
local siteId
for _,site in ipairs(adventure.sites) do if site.areaConfigId==2 then siteId=site.id;break end end
assert(siteId and adventure:Visit(siteId))
local shop=adventure.shop
local function merchant()
    for _,npc in ipairs(adventure.areas:ActiveLayout().npcs) do if shop.rules:Resolve(adventure.areas:ActiveLayout(),npc) then return npc end end
    error('Generated market has no merchant')
end
local function approach(npc)
    local layout,state=adventure.areas:ActiveLayout(),adventure.data.Areas.Active
    local target=state:GetNpcAt(npc.id-1).CellIndex;local anchor
    for _,cell in ipairs(layout:Neighbors(layout.cells[target])) do if not state:IsNpcOccupied(cell.index) then anchor=cell.index;break end end
    assert(anchor);local ids={};for i=0,adventure.data.PartyCount-1 do ids[#ids+1]=adventure.data:GetPartyAt(i).Id end
    local cells=require('Game.MapArea.SquadMovement').Deploy(layout,anchor,#ids,function(cell)return not state:IsNpcOccupied(cell.index) end)
    state:Stop();state:DeployMembers(ids,cells)
end
local npc=merchant()
test('real town merchant enforces distance and routes NPC interaction to stock',function()
    assert(not shop:Open(npc.id),'Town entrance must not remotely open the merchant')
    approach(npc);assert(adventure:AreaCommand('area_interact',2,npc.id));assert(shop.data.IsOpen)
    local minutes=story.data.Minutes;story:Tick(1);assert(story.data.Minutes==minutes)
    assert(not adventure:AreaCommand('area_leave'))
end)
local purchased,stockSignature
test('model purchase and close/reopen/reentry preserve the exact remaining stock',function()
    adventure.player:AddCoins(1000)
    local stock=shop.data.Active;local ammo=adventure.equipment.data:CountItem(31);local money=adventure.player.Coins
    local entry=stock:Find(1);local remaining=entry.Count;local version=shop.data.Revision
    assert(shop:Buy(1,version,1));assert(not shop:Buy(1,version,1))
    assert(entry.Count==remaining-1 and adventure.player.Coins==money-entry.Price and adventure.equipment.data:CountItem(31)==ammo+1)
    purchased=entry.Count;stockSignature=signature(stock)
    assert(shop:Close());assert(shop:Open(npc.id));assert(signature(shop.data.Active)==stockSignature)
    shop:Close();assert(adventure:AreaCommand('area_leave'));assert(adventure:Visit(siteId));npc=merchant();approach(npc)
    assert(shop:Open(npc.id));assert(signature(shop.data.Active)==stockSignature)
end)
test('real shop Panel binds entries and buy/close buttons, pauses, handles cache reopen and Back',function()
    local demo={MainHudFont=ShopFont,LastError='',BattleHUDRevision=0,SetStoryOpen=function(self,value)self.storyOpen=value end}
    function demo:SendCommand(command,a,b,c)
        local ok,reason
        if command=='shop_buy' then ok,reason=shop:Buy(a,b,c)
        elseif command=='shop_close' then ok,reason=shop:Close();ui:Close('Shop')
        else error(command) end
        self.LastError=ok and '' or reason;self.BattleHUDRevision=self.BattleHUDRevision+1
    end
    local original=CS.UnityEngine.Time.timeScale
    ui:Open('Shop',{demo=demo});assert(Services.UI.IsWorldPaused and CS.UnityEngine.Time.timeScale==0)
    local ctrl=ui.panels.Shop.ctrl;assert(#ctrl.rows==shop.data.Active.Count and ctrl.rows[1].view.Button.interactable)
    local count=shop.data.Active:Find(1).Count
    ctrl.rows[1].view.Button.onClick:Invoke();ctrl:Tick();assert(shop.data.Active:Find(1).Count==count-1 and demo.LastError=='')
    assert(ctrl.view.Caption.text:find('金币'));ctrl.view.Close.onClick:Invoke()
    assert(not ui:IsOpen('Shop') and not shop.data.IsOpen and not Services.UI.IsWorldPaused and CS.UnityEngine.Time.timeScale==original)
    assert(shop:Open(npc.id));ui:Open('Shop',{demo=demo});assert(ui.panels.Shop.ctrl==ctrl);ui:Back()
    assert(not shop.data.IsOpen and not demo.storyOpen and not Services.UI.IsWorldPaused)
end)
test('save v4 roundtrip preserves stock and clock; old versions migrate; malformed stock is rejected',function()
    local save=require('Game.Adventure.CharacterSave')
    local before=signature(shop.data:Find(1,siteId,npc.id));assert(save.Write(adventure))
    local prepared=adventure.characterSaves:Prepare(adventure.equipment.data);save.Validate(adventure,prepared)
    assert(signature(CS.ProjectY.Data.ShopData.Prepared(prepared):GetAt(0))==before)
    local original=assert(io.open(adventure.characterSaves.FilePath,'rb'));local document=original:read('*a');original:close()
    local function write(value)local f=assert(io.open(adventure.characterSaves.FilePath,'wb'));f:write(value);f:close()end
    local legacy,n=document:gsub('"version": 4','"version": 3',1);assert(n==1);write(legacy)
    assert(CS.ProjectY.Data.ShopData.Prepared(adventure.characterSaves:Prepare(adventure.equipment.data)).Count==0)
    local corrupt,m=document:gsub('"count": (%d+)','"count": -1',1);assert(m==1);write(corrupt)
    assert(not pcall(function()adventure.characterSaves:Prepare(adventure.equipment.data)end));write(document)
    assert(save.Read(adventure));assert(adventure:Visit(siteId));npc=merchant();approach(npc);assert(shop:Open(npc.id))
    assert(signature(shop.data.Active)==before);assert(not save.Write(adventure));assert(not save.Read(adventure));shop:Close()
end)
test('new game-day period refreshes once and does not share stock between merchants',function()
    local old=shop.data:Find(1,siteId,npc.id);local period=old.Period
    story.data:AdvanceMinutes((period+1)*1440-story.data.Minutes)
    assert(shop:Open(npc.id));local current=shop.data.Active;assert(current.Period==period+1 and current~=old)
    local signatureNow=signature(current);shop:Close();assert(shop:Open(npc.id));assert(signature(shop.data.Active)==signatureNow);shop:Close()
    local independent=shop.data:Refresh(1,siteId+100,npc.id,1,period+1,{1},{31},{5},{1})
    assert(independent~=current and signature(current)==signatureNow)
end)
registry:Shutdown()
return table.concat(messages,'\n')
