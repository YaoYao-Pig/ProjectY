-- Existing Editor, isolated LuaEnv/services and an OS temporary save; no Play mode.
local registry=require('Main');local adventure=registry:Get('Adventure');local messages={}
local function test(name,body)body();messages[#messages+1]='PASS '..name end
test('atomic purchases, stack merging, stale clicks, physical equipment sale and cargo loot',function()
    local data=CS.ProjectY.Data.WorldPartiesData();local caravan=data:Add(1,0,0,1,431)
    caravan:SetCargo('货物',{31},{3},{'ammo'},{1},{1});data:Complete(0);data:Open(1);data:Trade()
    local bag=CS.ProjectY.Data.EquipmentData();local player=CS.ProjectY.Data.PlayerData()
    bag.Grid:Define(31,1,1);bag.Grid:Define(40,1,1);bag.Grid:Configure(1,1)
    local revision=data.Revision
    assert(data:Buy(0,revision,3,bag,player,0,0,0)=='金币不足');assert(caravan:GetCargoAt(0).Count==3)
    player:AddCoins(100)
    assert(data:Buy(0,revision,3,bag,player,0,0,0)=='');assert(bag:CountItem(31)==1 and player.Coins==97)
    assert(data:Buy(0,revision,3,bag,player,0,0,0)~='','Old click should be rejected')
    assert(data:Buy(0,data.Revision,3,bag,player,0,0,0)=='');assert(bag:CountItem(31)==2 and bag.Grid.Count==1)
    assert(data:Sell(0,data.Revision,bag.Revision-1,1,bag,player)~='');assert(bag:CountItem(31)==2)
    assert(data:Sell(0,data.Revision,bag.Revision,1,bag,player)=='');assert(bag:CountItem(31)==0)
    CS.ProjectY.Data.EquipmentAffixData.Define(bag,40,{1},{1})
    local weapon=bag:AddWeapon(40);local id=weapon.Id
    assert(data:Sell(0,data.Revision,bag.Revision,4,bag,player)=='');assert(bag.WeaponCount==0)
    assert(CS.ProjectY.Data.ExpeditionPersistence.GroundWeapon(caravan.Cargo,caravan.CargoCount-1).Id==id)
    local itemIndex=caravan.CargoCount-1
    assert(data:Buy(itemIndex,data.Revision,8,bag,player,0,0,0)=='');assert(bag:GetWeapon(id)==weapon,'Sold weapon instance changed')
    assert(data:Sell(0,data.Revision,bag.Revision,4,bag,player)=='')
    local area=CS.ProjectY.Data.MapAreaStateData(90,20,1);data:BeginBattle(1,90)
    assert(data:DropCargo(90,area,1)==1 and data:DropCargo(90,area,1)==0,'Cargo duplicated at settlement')
    local ground=area:GetLootAt(0);local found=false
    for i=0,CS.ProjectY.Data.ExpeditionPersistence.GroundCount(ground)-1 do local stored=CS.ProjectY.Data.ExpeditionPersistence.GroundWeapon(ground,i)
        if stored then assert(stored.Id==id);found=true end
    end
    assert(found,'Sold weapon was not present in defeated caravan cargo')
end)
adventure:Start(20261016,3,10000)
local parties=adventure.parties;local caravan
for i=0,parties.data.Count-1 do local row=parties.data:GetAt(i)
    if parties.definitions:Get(row.DefinitionId).kind=='caravan' then caravan=row;break end
end
assert(caravan,'Generated world has no reachable caravan route')
test('actual world has six party kinds, valid routes, visible model snapshots and game-time movement',function()
    local kinds={};for i=0,parties.data.Count-1 do kinds[parties.data:GetAt(i).DefinitionId]=true end
    for i=1,6 do assert(kinds[i],'Missing party type '..i) end
    assert(caravan.HomeSiteId~=caravan.DestinationSiteId and caravan.Travel.Active)
    local before=caravan.Travel.RemainingMinutes;local minutes=adventure.narrative.data.Minutes
    adventure:Tick(.1);assert(adventure.narrative.data.Minutes>minutes and caravan.Travel.RemainingMinutes<before,'Idle world clock must move other parties')
    adventure.travel.data:SetPaused(true);minutes=adventure.narrative.data.Minutes;before=caravan.Travel.RemainingMinutes
    adventure:Tick(1);assert(adventure.narrative.data.Minutes==minutes and caravan.Travel.RemainingMinutes==before,'Paused world clock moved parties')
    local snapshot=adventure:Snapshot();assert(#snapshot.worldParties.rows==parties.data.Count and snapshot.worldParties.playerModelPath:find('Flag'))
end)
test('contact uses the real caravan inventory and preserves paused travel',function()
    local travel=adventure.travel.data
    travel:Reset(adventure.data.Seed,caravan.Travel.Q,caravan.Travel.R,#adventure.sites+1)
    assert(parties:Pursue(caravan.Id));assert(parties.data.ContactId==caravan.Id and travel.Paused)
    assert(parties:Command('world_trade'));assert(#parties:ContactSnapshot().rows>0)
    assert(not adventure.travel:Command('travel_move',1));assert(not require('Game.Adventure.CharacterSave').Write(adventure))
    assert(parties:Command('world_close'));assert(travel.Paused)
end)
test('native contact Panel binds commands, pauses and releases cached Back interaction',function()
    assert(parties:Pursue(caravan.Id))
    local ui=registry:Get('UI');local demo={MainHudFont=ShopFont,LastError='',BattleHUDRevision=0,SetStoryOpen=function(self,value)self.storyOpen=value end}
    function demo:SendCommand(command,a,b,c)
        local ok,reason=parties:Command(command,a,b,c);self.LastError=ok and '' or reason;self.BattleHUDRevision=self.BattleHUDRevision+1
    end
    ui:Open('WorldParty',{demo=demo});local ctrl=ui.panels.WorldParty.ctrl
    assert(Services.UI.IsWorldPaused and #ctrl.rows==2 and ctrl.rows[1].view.Button.interactable)
    ctrl.rows[1].view.Button.onClick:Invoke();ctrl:Tick();assert(parties.data.Trading and #ctrl.rows>2)
    ui:Back();assert(not parties.data.IsOpen and not demo.storyOpen and not Services.UI.IsWorldPaused)
end)
test('v12 roundtrip retains moving parties and cargo without restoring a transient contact',function()
    local save=require('Game.Adventure.CharacterSave');local q,r,progress=caravan.Travel.Q,caravan.Travel.R,caravan.Travel.Progress
    local count=caravan.CargoCount;local amount=count>0 and caravan:GetCargoAt(0).Count or 0;local id=caravan.Id
    assert(save.Write(adventure));assert(save.Read(adventure))
    caravan=parties.data:Find(id)
    assert(caravan.Travel.Q==q and caravan.Travel.R==r and math.abs(caravan.Travel.Progress-progress)<.00001)
    assert(caravan.CargoCount==count and (count==0 or caravan:GetCargoAt(0).Count==amount))
    assert(not parties.data.IsOpen and adventure.travel.data.Paused)
end)
test('caravan attack enters its configured real battlefield with cargo attached',function()
    adventure.travel.data:Reset(adventure.data.Seed,caravan.Travel.Q,caravan.Travel.R,#adventure.sites+1)
    assert(parties:Pursue(caravan.Id));assert(parties:Attack())
    assert(adventure.data.Phase=='battle' and adventure.data.Battle.EncounterId==401 and caravan.BattleSiteId>0)
    assert(not parties.data.IsOpen and caravan.Cargo)
end)
test('victory transfers exactly the remaining cargo and removes the map party once',function()
    local totals={};for i=0,caravan.Cargo.ItemCount-1 do totals[caravan.Cargo:GetItemIdAt(i)]=caravan.Cargo:GetCountAt(i) end
    for _,actor in ipairs(adventure.battle:Units()) do if actor.Team==2 then actor:Damage(actor.HP) end end
    assert(adventure.battle:CheckWinner());adventure:SettleBattle()
    assert(caravan.Defeated and not caravan.Cargo and adventure.data.Phase=='area')
    local cargo;local area=adventure.data.Areas.Active
    for i=0,area.LootCount-1 do local row=area:GetLootAt(i);if row.Name=='行旅商队的货物' then cargo=row end end
    assert(cargo,'Victory did not produce a cargo container')
    for i=0,cargo.ItemCount-1 do assert(cargo:GetCountAt(i)==totals[cargo:GetItemIdAt(i)],'Cargo amount changed during settlement') end
    for _,row in ipairs(parties:Snapshot().rows) do assert(row.id~=caravan.Id,'Defeated caravan remains on the map') end
    adventure.equipment.worldLoot.session:Close();assert(adventure:AreaCommand('area_leave'))
    local save=require('Game.Adventure.CharacterSave');assert(save.Write(adventure));assert(save.Read(adventure));assert(parties.data:Find(caravan.Id).Defeated)
end)
test('large hostile contact, retreat and re-engagement preserve the same battlefield',function()
    local monster
    for i=0,parties.data.Count-1 do local row=parties.data:GetAt(i);if row.DefinitionId==6 then monster=row;break end end
    adventure.travel.data:Reset(adventure.data.Seed,monster.Travel.Q,monster.Travel.R,#adventure.sites+1)
    assert(parties:Pursue(monster.Id));assert(adventure.data.Phase=='battle' and adventure.data.Battle.EncounterId==406)
    local enemy=adventure.data.Areas.Active:GetEncounterAt(0):GetEnemyAt(0)
    assert(#adventure.battle.stats.animals:Cells(enemy,adventure.battle.board)==4)
    local site=monster.BattleSiteId;enemy:Damage(3);local hp=enemy.HP
    adventure.data.Battle:Finish('draw');adventure:SettleBattle();assert(adventure.data.Phase=='map' and not monster.Defeated)
    assert(parties:Pursue(monster.Id));assert(monster.BattleSiteId==site and adventure.data.Phase=='battle')
    assert(adventure.data.Areas.Active:GetEncounterAt(0):GetEnemyAt(0).HP==hp)
end)
return table.concat(messages,'\n')
