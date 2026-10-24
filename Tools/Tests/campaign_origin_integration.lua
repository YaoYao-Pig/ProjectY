-- Actual C# inventory, growth, config, world preparation and isolated disk saves.
local registry=require('Main');local adventure=registry:Get('Adventure');local config=registry:Get('Config')
local Starts=require('Game.Adventure.CampaignStarts');local bridge=require('Game.Adventure.DemoBridge')
local save=require('Game.Adventure.CharacterSave');local slots=CS.ProjectY.Data.CampaignSaves
assert(Services.CharacterSaves.FilePath:gsub('\\','/'):find('project%-y%-start%-origins%-'),'Temporary save service required')
local function verify(profile)
    local recipe=config:GetTable('AdventureDemoTable'):Get(profile.adventureRecipeId)
    local kit=config:GetTable('EquipmentDemoTable'):Get(recipe.equipmentRecipeId)
    assert(adventure.recipe.id==recipe.id and adventure.data.PartyCount==3)
    for i,unitId in ipairs(recipe.partyIds) do
        local actor=adventure.data:GetPartyAt(i-1)
        assert(actor.TemplateId==unitId and actor.Growth.Initialized and actor.CustomizationJson~='')
        assert(actor.HP>0 and actor.MaxHP>0)
        local equipped=assert(adventure.equipment.data:Equipped(actor.Id))
        assert(equipped.ItemId==kit.equipWeaponIds[i] and equipped.OwnerActorId==actor.Id)
        assert(not adventure.equipment.data.Grid:Find('w'..equipped.Id),'Equipped starter weapon was left in the bag')
    end
    for _,row in ipairs(Starts.Preview(config,profile.id).equipmentRows) do
        local count=0;local data=adventure.equipment.data
        if row.kind=='weapon' then
            for i=0,data.WeaponCount-1 do local weapon=data:GetWeaponAt(i)
                if weapon.ItemId==row.itemId and adventure.equipment:IsCarriedWeapon(weapon) then count=count+1 end
            end
        elseif row.kind=='wearable' then
            for i=0,data.WearableCount-1 do local item=data:GetWearableAt(i)
                if item.ItemId==row.itemId and (adventure.equipment:Actor(item.OwnerActorId) or data.Grid:Find('g'..item.Id)) then count=count+1 end
            end
        else count=data:CountItem(row.itemId) end
        assert(count==row.count,'Opening preview/grant differs: '..profile.id..'/'..row.itemId..'/'..count..'/'..row.count)
    end
end
-- All opening maps use the same geography rules; one prepared map can check all distinct roster/loadout paths.
local world=adventure:BuildWorld(42,101,2500)
for _,profile in ipairs(Starts.List(config)) do
    local prepared={map=world.map,sites=world.sites,recipe=config:GetTable('AdventureDemoTable'):Get(profile.adventureRecipeId),seed=42,targetCells=2500}
    adventure:Start(42,profile.adventureRecipeId,2500,prepared);verify(profile)
end
local map,state=bridge('menu_start',2500,'42',4);assert(map and not state.error and not state.warning)
verify(Starts.Get(config,4));assert(adventure.player.Coins==45 and adventure.narrative.data:GetValue('flag:campaign_start')==4)
assert(adventure.data:GetPartyAt(0).Growth.CurrentProfessionId==4,'Repairer must actually start as an artisan')
local first=slots.CurrentId(adventure.characterSaves);local weapon=adventure.equipment.data:Equipped(1).Id
local aid=adventure.equipment.data:CountItem(91);local seed=adventure.data.Seed
local rejected,why=bridge('menu_start',2500,'123',99999)
assert(not rejected and why.error~='' and adventure.data.Seed==seed and slots.CurrentId(adventure.characterSaves)==first)
-- Change actual inventory before saving; restore must not re-issue the full starting kit.
adventure.equipment.data:ConsumeStack(91,1);adventure.player:AddCoins(7);assert(save.Write(adventure))
map,state=bridge('menu_start',2500,'43',12);assert(map and not state.error and not state.warning)
assert(adventure.narrative.data:GetValue('flag:campaign_start')==12 and slots.CurrentId(adventure.characterSaves)~=first)
for _=1,2 do
    map,state=bridge('menu_load',0,first);assert(map and not state.error)
    assert(adventure.narrative.data:GetValue('flag:campaign_start')==4 and adventure.recipe.id==104)
    assert(adventure.player.Coins==52 and adventure.equipment.data:CountItem(91)==aid-1)
    assert(adventure.equipment.data:Equipped(1).Id==weapon and slots.CurrentId(adventure.characterSaves)==first)
end
assert(slots.List(adventure.characterSaves).Length==2)
return 'PASS 12 real opening loadouts/growth/appearance, preview versus inventory, selected origin and coins, invalid selection retention, independent saves and repeated reload without starter regrants'
