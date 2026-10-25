-- Actual exported configuration plus production placement rules. No Editor, gameplay session or user save files.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local acquisition=require('Game.Equipment.LegendaryAcquisition').New(config,{})
local affixes=require('Game.Equipment.EquipmentAffixes').New(config)
local counts={reserved=0,actor=0,dungeon=0}
for _,row in ipairs(acquisition.definitions:All())do
    counts[row.acquisitionKind]=counts[row.acquisitionKind]+1
    assert(#affixes.pools[row.id].ids==1 and affixes.pools[row.id].ids[1]==row.fixedAffixId)
    assert(affixes:Legendary(row.id)==row)
end
assert(counts.reserved==5 and counts.actor==1 and counts.dungeon==9)
local loadout
for _,row in ipairs(config:GetTable('CharacterLoadoutTable'):All())do if row.unitId==705 then loadout=row end end
assert(loadout and loadout.weaponId==9001 and loadout.offhandWeaponId==0)
for _,row in ipairs(config:GetTable('NarrativeActionTable'):All())do
    assert(row.kind~='grant_item' or not acquisition.definitions:Find(row.targetId),'Reserved quests must not auto-award a named legendary')
end
print('PASS actual 15 definitions, 5 reserved/1 existing enemy/9 dungeon sources, fixed quality and no placeholder quest grants')

local generator=require('Game.MapArea.MapAreaGenerator')(config)
local entries={{1,1,'Dungeon',1},{20,3,'Forest',5},{40,5,'Shipwreck',1},{50,6,'Mine',3},
    {70,9,'HighMountain',12},{71,10,'Canyon',13},{72,11,'GiantTree',12}}
for _,entry in ipairs(entries)do
    generator:Register(entry[2],require('Game.MapArea.'..entry[3]..'Generator'),'MapArea'..entry[3]..'Table',
        entry[1]==1 and 'MapAreaThemeTable' or 'MapArea'..entry[3]..'ThemeTable')
end
local Chest=require('Game.Loot.ChestGenerator')
local checked=0
for _,entry in ipairs(entries)do
    local region=entry[4]
    local area=generator:Generate(entry[1],20261025,1700+entry[1],{regionId=region,regionConfigId=region,regionType=region,
        q=0,r=0,height=1,biomeWeights={{regionType=region,weight=1}}})
    local _,distance=Chest.Distances(area)
    local sources={}
    for _,plan in ipairs(area.containerPlans)do
        local row=acquisition.byContainer[plan.lootTableId]
        if row then
            assert(not sources[row.id] and distance[plan.cellIndex] and not area.cells[plan.cellIndex].blocked)
            assert(acquisition.areas[row.id][area.configId])
            sources[row.id]=true;checked=checked+1
        end
    end
    for _,row in ipairs(acquisition.definitions:All())do
        if acquisition.areas[row.id][area.configId]then assert(sources[row.id],'Missing actual legendary placement plan')end
    end
end
assert(checked>9)
print('PASS '..checked..' guaranteed primary/fallback container plans across all 7 actual area generators')
config:OnShutdown()
