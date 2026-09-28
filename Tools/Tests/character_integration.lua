local registry=require('Core.SystemRegistry')(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('PlayerModel',require('Game.PlayerModelSystem'),{'Config'})
registry:Register('Map',require('Game.Map.MapSystem'),{'Config'})
registry:Register('MapArea',require('Game.MapArea.MapAreaSystem'),{'Config'})
registry:Register('Battle',require('Game.Battle.BattleSystem'),{'Config'})
registry:Register('Equipment',require('Game.Equipment.EquipmentSystem'),{'Config'})
registry:Register('Growth',require('Game.Progression.GrowthSystem'),{'Battle'})
registry:Register('AdventureEvents',require('Game.Adventure.EventSystem'),{'Battle','PlayerModel','Growth','Equipment'})
registry:Register('Adventure',require('Game.Adventure.AdventureSystem'),{'Map','MapArea','AdventureEvents','Equipment'})
registry:Start()
local adventure=registry:Get('Adventure');adventure:Start(412)
local actor=adventure.data:GetPartyAt(0);local equipment=adventure.equipment
Services.Appearances:Apply(actor,AppearanceFixtureJson)
adventure.growth:AddExperience(actor,700,'存档检查')
assert(adventure.growth:InvestAttribute(actor.Id,1));assert(adventure.growth:InvestTalent(actor.Id,1))
assert(actor.Growth.OfferCount>0);assert(adventure.growth:Learn(actor.Id,actor.Growth:GetOfferAt(0)))
actor:Damage(3)
assert(equipment:Command('equip',actor.Id,equipment.data:GetWeaponAt(2).Id,0,0))
for i=0,equipment.data.WearableCount-1 do local row=equipment.data:GetWearableAt(i)
    local slot=({[51]='head',[52]='body',[53]='rightRing',[54]='leftRing',[55]='legs',[56]='feet'})[row.ItemId]
    if slot then assert(equipment.data:Wear(actor.Id,slot,row.Id)) end
end
actor:SetMaxHP(adventure.battle.stats:MaximumHP(actor));Services.Player:AddCoins(77)
local function skills(g) local ids={};for i=0,g.SkillCount-1 do ids[#ids+1]=g:GetSkillAt(i) end;return table.concat(ids,',') end
local function offers(g) local ids={};for i=0,g.OfferCount-1 do ids[#ids+1]=g:GetOfferAt(i) end;return table.concat(ids,',') end
local attributeCode=adventure.config:GetTable('GrowthAttributeTable'):Get(1).code
local saved={appearance=actor.CustomizationJson,hp=actor.HP,coins=Services.Player.Coins,weapon=equipment.data:Equipped(actor.Id).Id,grid=equipment.data.Grid.Count,
    level=actor.Growth.Level,experience=actor.Growth.Experience,attribute=actor.Growth:GetAttribute(attributeCode),rank=actor.Growth:GetRank(1),skills=skills(actor.Growth),offers=offers(actor.Growth),pending=actor.Growth.PendingCount}
local save=require('Game.Adventure.CharacterSave');assert(save.Write(adventure));assert(save.Write(adventure))
local expectedRandom=actor.Growth:NextRandom()
actor:Damage(2);actor.Growth:AddExperience(9);Services.Player:AddCoins(5)
assert(equipment:Command('unequip',actor.Id,0,0,0))
assert(save.Read(adventure))
local restored=adventure.data:GetPartyAt(0)
assert(restored~=actor and restored.CustomizationJson==saved.appearance and restored.HP==saved.hp and restored.Growth.Experience==saved.experience)
assert(restored.Growth.Level==saved.level and restored.Growth:GetAttribute(attributeCode)==saved.attribute and restored.Growth:GetRank(1)==saved.rank)
assert(skills(restored.Growth)==saved.skills and offers(restored.Growth)==saved.offers and restored.Growth.PendingCount==saved.pending and restored.Growth:NextRandom()==expectedRandom)
assert(Services.Player.Coins==saved.coins and equipment.data:Equipped(restored.Id).Id==saved.weapon and equipment.data.Grid.Count==saved.grid)
assert(adventure.data.Phase=='map' and adventure.data.Areas.ActiveSiteId==0)
for i=0,adventure.data.PartyCount-1 do assert(adventure.data:GetPartyAt(i).CustomizationJson~='') end
-- Enter and leave the same real dungeon: appearance identity lives with its enemy, not its view.
local site
for _,row in ipairs(adventure.sites) do if row.areaConfigId and adventure.areas.generator.definitions:Get(row.areaConfigId).areaType~=adventure.areas.townType then site=row;break end end
assert(site,'Fixture map has no dungeon');assert(adventure:Visit(site.id))
local state=adventure.data.Areas.Active;assert(state.EncounterCount>0)
local group=state:GetEncounterAt(0);local enemy=group:GetEnemyAt(0);local before=enemy.CustomizationJson;assert(before~='')
local pool=adventure.config:GetTable('CharacterAppearancePoolTable'):Get(adventure.config:GetTable('CombatEncounterTable'):Get(group.EncounterId).appearancePoolId)
if pool.sameRace then for i=1,group.EnemyCount-1 do assert(Services.Appearances:Race(group:GetEnemyAt(i))==Services.Appearances:Race(enemy)) end end
assert(adventure.areas:Leave());assert(adventure:Visit(site.id));assert(adventure.data.Areas.Active:GetEncounterAt(0):GetEnemyAt(0).CustomizationJson==before)
assert(adventure.areas:Leave())
local hud=require('Game.Adventure.MainHudModel').Build(adventure);local saveButton,loadButton=false,false
for _,row in ipairs(hud.rows) do if row.command=='save_characters' then saveButton=row.available elseif row.command=='load_characters' then loadButton=row.available end end
assert(saveButton and loadButton,'Character save/load is not reachable from the HUD')
function AssertCorruptCharacterSaveRejected()
    local current=adventure.data:GetPartyAt(0);local ok=save.Read(adventure)
    assert(not ok and adventure.data:GetPartyAt(0)==current and current.CustomizationJson==saved.appearance,'Corrupt file replaced active party')
end
function CloseCharacterIntegrationFixture() registry:Shutdown() end
return {partyCount=adventure.data.PartyCount,enemyGroups=state.EncounterCount,stableEnemy=true,saveRoundTrip=true,backpackRoundTrip=true,healthPreserved=true}
