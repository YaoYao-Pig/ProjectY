-- Run after the unified config export. Exercises real config, growth, appearance and
-- starter-equipment rules offline; no Editor, game save or runtime scene is involved.
package.path='Lua/?.lua;'..package.path
local Gear=assert(loadfile('Tools/Tests/equipment_read_fixture.lua'))()
-- Starting characters are healthy; substitute only the new C# injury scalar reads.
CS.ProjectY.Data.BodyHealth={Revision=function()return 0 end,Damage=function(_,index)
    assert(index>=0 and index<6,'Invalid body-part index');return 0
end}
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local starts=config:GetTable('CampaignStartTable')
local adventures=config:GetTable('AdventureDemoTable')
local packs=config:GetTable('EquipmentDemoTable')
local units=config:GetTable('CombatUnitTable')
local items=config:GetTable('EquipmentItemTable')
local pawnAppearance=require('Game.Adventure.PawnAppearance').New(config)
local growthRules=require('Game.Progression.GrowthRules').New(config)
local Starter=require('Game.Equipment.StarterWeapons')
local base=adventures:Get(5)
local expectedCoins={60,35,20,45,90,15,120,25,30,45,8,45}
local expectedLeaders={1,2,3,1101,1,1,1,2,3,1,1,3}
local starterWeapons={[101]=true,[102]=true,[103]=true,[104]=true}
local ordinaryTools={[72]=true,[73]=true,[74]=true}
local seenNames,seenDescriptions,seenRecipes,seenPacks,seenSupplies={},{},{},{},{}
local function sameArray(left,right,message)
    assert(#left==#right,message)
    for i,value in ipairs(left)do assert(value==right[i],message)end
end
local function exists(path)
    local file=assert(io.open(path,'rb'),'Missing opening resource: '..path);file:close()
end
local function actor(id,unitId)
    local profile=assert(growthRules.profileByUnit[unitId],'Starting unit lacks a growth profile')
    return {Id=id,TemplateId=unitId,Team=1,AnimalSpeciesId=0,TraitCount=#profile.traitIds,
        GetTraitAt=function(_,index)return profile.traitIds[index+1]end,Effects={Count=0},
        Growth={Level=1,SkillCount=0,TalentCount=0,GetAttribute=function()return 0 end,GetRank=function()return 0 end}}
end
assert(starts.Count==12,'Expected twelve selectable backgrounds')
for id=1,12 do
    local start=starts:Get(id)
    assert(start.name~='' and not seenNames[start.name],'Duplicate/empty background name');seenNames[start.name]=true
    assert(start.description~='' and not seenDescriptions[start.description],'Duplicate/empty background story');seenDescriptions[start.description]=true
    assert(start.coins==expectedCoins[id] and start.adventureRecipeId==100+id)
    assert(not seenRecipes[start.adventureRecipeId]);seenRecipes[start.adventureRecipeId]=true
    local adventure=adventures:Get(start.adventureRecipeId)
    assert(#adventure.partyIds==3 and adventure.maxPartySize==4 and adventure.partyIds[1]==expectedLeaders[id])
    assert(adventure.startAreaId==2 and adventure.seededRegions==base.seededRegions and adventure.seed==base.seed)
    assert(adventure.campEventId==base.campEventId)
    for _,key in ipairs({'regionIds','wildEventIds','buildingIds','buildingEventIds'})do
        sameArray(adventure[key],base[key],'A background must preserve the current world-generation rules')
    end
    assert(adventure.equipmentRecipeId==100+id and not seenPacks[adventure.equipmentRecipeId])
    seenPacks[adventure.equipmentRecipeId]=true
    local pack=packs:Get(adventure.equipmentRecipeId)
    sameArray(pack.equipUnitIds,adventure.partyIds,'Starter mapping must follow the selected party')
    assert(#pack.equipWeaponIds==3 and #pack.starterItemIds==#pack.starterCounts)
    local actors,seenUnits={},{}
    for index,unitId in ipairs(adventure.partyIds)do
        assert(not seenUnits[unitId] and (unitId==1 or unitId==2 or unitId==3 or unitId==1101),'Starting party reused a unique NPC')
        seenUnits[unitId]=true;units:Get(unitId);actors[index]=actor(index,unitId)
        local profile=growthRules.profileByUnit[unitId]
        config:GetTable('ProfessionTable'):Get(profile.initialProfessionId)
        for _,treeId in ipairs(profile.treeIds)do config:GetTable('TalentTreeTable'):Get(treeId)end
        for _,traitId in ipairs(profile.traitIds)do config:GetTable('CombatTraitTable'):Get(traitId)end
        local pawn=assert(pawnAppearance.templates[unitId]);config:GetTable('CharacterAppearancePoolTable'):Get(pawn.appearancePoolId)
        for _,part in ipairs(pawnAppearance:Template(unitId).parts)do exists(part.path)end
    end
    local gear,onGrid,equipped={},{},{}
    local data={WearableCount=0,WeaponCount=0,Grid={Find=function(_,key)return onGrid[key]end},
        GetWeaponAt=function(_,index)return gear[index+1]end,Equipped=function(_,actorId)return equipped[actorId]end,
        Offhand=function()end,Worn=function()end,Equip=function(_,actorId,weaponId)
            local weapon=assert(gear[weaponId]);assert(onGrid['w'..weaponId])
            weapon.OwnerActorId=actorId;onGrid['w'..weaponId]=nil;equipped[actorId]=weapon;return true
        end}
    local stats=require('Game.Battle.CombatStats')(config,data)
    local rules=stats.equipment
    local loadouts=require('Game.Equipment.InitialLoadout').New(config,rules,function()return stats end)
    local carried,signature,cells={},{},0
    for index,itemId in ipairs(pack.starterItemIds)do
        local count=pack.starterCounts[index];local item=items:Get(itemId)
        assert(not carried[itemId] and count>0,'Opening pack contains duplicated IDs or invalid counts')
        carried[itemId]=count;signature[#signature+1]=itemId..'x'..count
        assert(item.width<=pack.bagWidth and item.height<=pack.bagHeight)
        local isEntity=item.kind=='weapon' or item.kind=='wearable' or item.kind=='magazine'
        cells=cells+item.width*item.height*(isEntity and count or 1)
        assert(item.iconPath~='','Opening supplies need visible item icons');exists(item.iconPath)
        local asset=rules.assets:Get(item.assetId);exists(asset.modelPath);exists(asset.prefabPath)
        if item.kind=='weapon' then
            assert(starterWeapons[itemId] or ordinaryTools[itemId],'Opening pack includes an advanced weapon')
            assert(rules.weapons:Get(itemId).level==1)
            for _=1,count do
                local instance=Gear(#gear+1,itemId,0);gear[#gear+1]=instance;onGrid['w'..instance.Id]=true
            end
        end
        if item.kind=='weapon' or item.kind=='wearable' then
            local usable=false
            for _,member in ipairs(actors)do if rules:CanEquip(member,itemId,stats)then usable=true end end
            assert(usable,'Nobody in the opening party can use a supplied piece of equipment')
        end
    end
    assert(carried[91]>=2 and carried[94]>=1,'Opening lacks first-aid or light')
    assert(cells<pack.bagWidth*pack.bagHeight/2,'Opening supplies leave too little looting space')
    table.sort(signature);signature=table.concat(signature,',')
    assert(not seenSupplies[signature],'Two backgrounds have identical opening supplies');seenSupplies[signature]=true
    data.WeaponCount=#gear
    local party={PartyCount=#actors,GetPartyAt=function(_,index)return actors[index+1]end}
    local plan=Starter.Plan(pack,data,party,rules,stats,loadouts)
    assert(#plan==3 and next(equipped)==nil,'Starter planning changed equipment before the whole party was validated')
    Starter.Apply(data,plan)
    assert(data.WeaponCount==#gear,'Starter equipment must reuse the original inventory instances')
    for index,member in ipairs(actors)do
        local weapon=assert(equipped[member.Id]);assert(weapon.ItemId==pack.equipWeaponIds[index] and starterWeapons[weapon.ItemId])
        assert(not onGrid['w'..weapon.Id] and weapon.OwnerActorId==member.Id)
        local skill=rules:Skill(member,rules.weapons:Get(weapon.ItemId).skillIds[1],stats)
        assert(rules:CheckSkillEquipment(member,skill,stats),'Opening grants an unusable basic attack')
    end
end
print('PASS twelve unique backgrounds: coins, parties, growth/appearance, world rules, distinct supplies, capacity and original-instance starter equipment')

local artisan=units:Get(1101)
assert(growthRules.profileByUnit[1101].initialProfessionId==4)
local craftsmanship=0
for index,name in ipairs(artisan.attributeNames)do if name=='crafting'then craftsmanship=artisan.attributeValues[index]end end
assert(craftsmanship>=4,'Travelling repairer needs a usable crafting proficiency')
for _,npc in ipairs(config:GetTable('NpcTable'):All())do assert(npc.actorTemplateId~=1101,'Opening repairer borrowed an existing unique NPC identity')end
for _,loadout in ipairs(config:GetTable('CharacterLoadoutTable'):All())do assert(loadout.unitId~=1101,'Opening repairer would receive equipment twice')end
for id=1,5 do adventures:Get(id)end
packs:Get(1);packs:Get(2)
print('PASS independent repairer unit/profession/appearance and no overlapping NPC identity or default equipment grants')
