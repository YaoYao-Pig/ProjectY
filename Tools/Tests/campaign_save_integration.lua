-- Native public-service acceptance. Caller supplies isolated FrameworkServices(null, temporaryPath).
-- Runs in an existing Editor's independent LuaEnv; does not enter Play or touch the player's save.
local registry=require('Core.SystemRegistry')(Services)
local listener
function CloseCampaignSaveIntegrationFixture()
    if listener then Services.Player:RemoveChangedListener(listener);listener=nil end
    registry:Shutdown()
end
for _,spec in ipairs({
    {'Config','Config.ConfigSystem'},{'Condition','Game.Condition.ConditionSystem',{'Config'}},
    {'PlayerModel','Game.PlayerModelSystem',{'Config'}},{'Map','Game.Map.MapSystem',{'Config'}},
    {'MapArea','Game.MapArea.MapAreaSystem',{'Config'}},{'Battle','Game.Battle.BattleSystem',{'Config'}},
    {'Equipment','Game.Equipment.EquipmentSystem',{'Config'}},{'Growth','Game.Progression.GrowthSystem',{'Battle'}},
    {'AdventureEvents','Game.Adventure.EventSystem',{'Battle','PlayerModel','Growth','Equipment'}},
    {'Adventure','Game.Adventure.AdventureSystem',{'Map','MapArea','AdventureEvents','Equipment'}},
    {'Narrative','Game.Narrative.NarrativeSystem',{'Adventure','Condition'}},
})do registry:Register(spec[1],require(spec[2]),spec[3])end
registry:Start()
local adventure=registry:Get('Adventure');local save=require('Game.Adventure.CharacterSave')
local file=adventure.characterSaves.FilePath:gsub('\\','/'):lower()
assert(file:find('project%-y%-') and not file:find('/characters/party%-'),'Campaign save acceptance requires an isolated temporary path')
adventure:Start(20261016,3,10000)
local data,areas,equipment=adventure.data,adventure.areas,adventure.equipment
local site
for _,row in ipairs(adventure.sites)do if row.areaConfigId and areas.generator.definitions:Get(row.areaConfigId).areaType==adventure.config:GetEnum('MapArea','E_MapAreaType').Dungeon then site=row;break end end
assert(site,'The real campaign needs a dungeon fixture')
-- Enter the real area directly: travel behavior has its own check, this fixture isolates persistence.
assert(areas:Enter(site,data.Seed));equipment:InitializeLoot(areas);adventure.obstacles:Initialize()
local state,layout=data.Areas.Active,areas:ActiveLayout()
local moved=false
for _,cell in ipairs(layout:Neighbors(layout.cells[state.CellIndex]))do
    if state:IsKnown(cell.index) and not cell.blocked and not state:IsSquadReserved(cell.index) and not state:IsNpcOccupied(cell.index) then
        local ok=adventure:AreaCommand('area_move_cell',cell.index)
        if ok then moved=true;break end
    end
end
assert(moved,'No adjacent exploration move was available');assert(adventure:AreaCommand('area_stop'))
assert(data.Phase=='area','The entry movement unexpectedly entered combat')

local actors={}
for i=0,state.EncounterCount-1 do local group=state:GetEncounterAt(i)
    for j=0,group.EnemyCount-1 do local enemy=group:GetEnemyAt(j);if enemy.Team==2 then enemy:Damage(enemy.HP);actors[#actors+1]=enemy end end
end
assert(#actors>0)
local loot=equipment.worldLoot;local beforeDrops=state.LootCount
assert(loot:ActorDrops(areas,actors,adventure.battle.stats)>0,'Real defeated enemies did not produce loot')
assert(loot:ActorDrops(areas,actors,adventure.battle.stats)==0,'Enemy loot resolved twice before save')
local drop=state:GetLootAt(beforeDrops);local dropId=drop.Id
local session=loot.session;loot:Prepare(drop)
session:Open(state,{dropId},false,'存档验证战利品','')
local taken
for i=0,session.Count-1 do local entry=session:GetAt(i)
    if entry.Count>0 then
        session:Advance(entry.Key,1,1)
        local ammo,capacity,rounds=0,0,0
        if entry.Kind=='magazine' then local row=equipment.rules.magazines:Get(entry.ItemId);ammo,capacity,rounds=row.ammoItemId,row.capacity,row.initialRounds or row.capacity end
        for y=0,equipment.data.Grid.Height-1 do for x=0,equipment.data.Grid.Width-1 do
            if not taken and session:Take(equipment.data,entry.Key,x,y,false,ammo,capacity,rounds) then taken={key=entry.Key,item=entry.ItemId};break end
        end;if taken then break end end
        if taken then break end
    end
end
assert(taken,'Could not pick up one real enemy drop');session:Close()

-- Store the exact original weapon into an intact generated chest, then verify its identity on disk restore.
local hero=data:GetPartyAt(0);local original=assert(equipment.data:Equipped(hero.Id));local originalId=original.Id
local originalAffix=CS.ProjectY.Data.EquipmentAffixData.Of(original)
assert(equipment.data:Equip(hero.Id,0));hero:SetMaxHP(adventure.battle.stats:MaximumHP(hero))
local stored,box,blockedCell
for i=0,beforeDrops-1 do local container=state:GetLootAt(i);local physical=loot:SyncLock(state,container)
    local definition=loot.rules.containers:Get(container.TableId)
    if physical.CanSearch and physical.Configured and not physical.Destroyed and definition.blocksMovement then
        loot:Prepare(container);session:Open(state,{container.Id},false,'原装备存放验证','')
        for y=0,session.Grid.Height-1 do for x=0,session.Grid.Width-1 do
            if session:Put(equipment.data,'w'..originalId,x,y,false) then stored=true;box=container;blockedCell=physical:GetCellAt(0);break end
        end;if stored then break end end
        session:Close();if stored then break end
    end
end
assert(stored and layout.cells[blockedCell].blocked,'No intact blocking chest accepted the original weapon')
local expected={site=site.id,known=state.KnownCount,anchor=state.CellIndex,lootCount=state.LootCount,boxId=box.Id,
    heroHP=hero.HP,weaponId=originalId,affix=originalAffix,coins=Services.Player.Coins,dropItemCount=drop:GetCountAt(0)}
data.Narrative:SetValue('flag:torch_extinguished',1)
assert(save.Write(adventure));assert(save.Write(adventure))
local prepared=adventure.characterSaves:Prepare(equipment.data);save.Validate(adventure,prepared)
assert(CS.ProjectY.Data.ExpeditionPersistence.HasWorld(prepared) and CS.ProjectY.Data.ExpeditionPersistence.Target(prepared)==10000)
assert(CS.System.IO.File.ReadAllText(adventure.characterSaves.FilePath):find('"version":11',1,true))
assert(CS.System.IO.File.Exists(adventure.characterSaves.FilePath..'.bak'))

hero:Damage(2);Services.Player:AddCoins(17);data.Narrative:SetValue('flag:torch_extinguished',0)
local notification=false
listener=function()
    notification=true
    assert(data.Areas.ActiveSiteId==expected.site and data.Phase=='area')
    assert(areas:ActiveLayout().containerState==data.Areas.Active,'Player notification saw an unbound container state')
    assert(areas:ActiveLayout().cells[blockedCell].blocked,'Player notification lost an intact chest obstacle')
end
Services.Player:AddChangedListener(listener)
local ok,reason=save.Read(adventure);assert(ok,reason)
Services.Player:RemoveChangedListener(listener);listener=nil
assert(notification)
state=data.Areas.Active;layout=areas:ActiveLayout();hero=data:GetPartyAt(0)
assert(state.CellIndex==expected.anchor and state.KnownCount==expected.known and state.LootCount==expected.lootCount)
assert(hero.HP==expected.heroHP and Services.Player.Coins==expected.coins and data.Narrative:GetValue('flag:torch_extinguished')==1)
assert(layout.containerState==state and layout.cells[blockedCell].blocked)
local restoredBox=state:GetLootAt(expected.boxId-1);local found=false
for i=0,CS.ProjectY.Data.ExpeditionPersistence.GroundCount(restoredBox)-1 do
    local weapon=CS.ProjectY.Data.ExpeditionPersistence.GroundWeapon(restoredBox,i)
    if weapon and weapon.Id==expected.weaponId then assert(CS.ProjectY.Data.EquipmentAffixData.Of(weapon)==expected.affix);found=true end
end
assert(found,'The original stored weapon was missing or replaced')
local restoredDrop=state:GetLootAt(dropId-1);loot:Prepare(restoredDrop)
session:Open(state,{dropId},false,'读取后掉落验证','')
local takenEntry=session:Find(taken.key);assert(takenEntry and takenEntry.Count==0,'Already collected drop respawned')
session:Close()
local restoredEnemies={}
for i=0,state.EncounterCount-1 do local group=state:GetEncounterAt(i)
    for j=0,group.EnemyCount-1 do local enemy=group:GetEnemyAt(j);assert(enemy.HP==0 and enemy.DropResolved);restoredEnemies[#restoredEnemies+1]=enemy end
end
assert(loot:ActorDrops(areas,restoredEnemies,adventure.battle.stats)==0 and state.LootCount==expected.lootCount,'Loading reissued enemy drops')

function AssertCampaignSaveCorruptRejected()
    local current=data.Areas.Active;local member=data:GetPartyAt(0);local coins=Services.Player.Coins
    local success=save.Read(adventure)
    assert(not success and data.Areas.Active==current and data:GetPartyAt(0)==member and Services.Player.Coins==coins,'Invalid save replaced the live expedition')
    assert(areas:ActiveLayout().containerState==current and areas:ActiveLayout().cells[blockedCell].blocked)
end
return 'PASS v9 public-service disk save: real area movement, defeated enemies, partial loot, original equipment stored in a blocking chest, atomic notification, active-area restore, no repeated drops, torch choice and backup'
