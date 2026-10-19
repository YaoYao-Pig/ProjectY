package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local f=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local result=f:read('*a');f:close();return result
end}})
local shapes=require('Game.Animals.AnimalRules').New(config)
assert(not shapes.byUnit[401] and not shapes.byUnit[402],'Monsters must not gain taming or riding identity')
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(config:GetEnum('MapArea','E_MapAreaType').Battlefield,require('Game.MapArea.BattlefieldGenerator'),'MapAreaBattlefieldTable','MapAreaBattlefieldThemeTable')
local definition=config:GetConstant('Loot','EventBattlefieldAreaId')
for _,encounter in ipairs({405,406}) do
    for _,seed in ipairs({431,721}) do
        local area=generator:Generate(definition,seed,70,{regionId=1,regionConfigId=1,regionType=1,q=0,r=0,height=0,biomeWeights={{regionType=1,weight=1}},encounterId=encounter})
        local used={};local rule=config:GetTable('CombatEncounterTable'):Get(encounter)
        for i,cell in ipairs(area.encounterPlans[1].cells) do
            local actor={TemplateId=rule.enemyIds[i],Q=cell.q,R=cell.r}
            assert(shapes:CanPlace(actor,area,cell.q,cell.r,used),'Large enemies overlap or spawn across blocked cells')
            local cells=assert(shapes:Cells(actor,area));assert(#cells==(encounter==405 and 2 or 4))
            for _,part in ipairs(cells) do assert(area:FindPath(area.entryIndex,part.index),'Footprint is disconnected from the party') end
            shapes:Occupy(actor,area,used)
        end
    end
end
local prices={};for _,row in ipairs(config:GetTable('WorldTradePriceTable'):All()) do prices[row.itemId]=row.price end
for _,row in ipairs(config:GetTable('EquipmentItemTable'):All()) do assert(prices[row.id],'Backpack item has no sell price') end
for _,row in ipairs(config:GetTable('ShopEntryTable'):All()) do if row.templateId==1 then assert(prices[row.itemId]==row.price,'Existing shop prices changed') end end
for _,file in ipairs({'Lua/Game/Adventure/WorldParties.lua','Lua/Game/Adventure/WorldTravel.lua','Lua/UI/Panel/WorldPartyCtr.lua','Lua/Game/Adventure/ExpeditionSave.lua'}) do assert(loadfile(file)) end
print('PASS two/four-cell deployment, non-overlap, reachability, non-tameable monsters, complete trade prices, Lua syntax')
config:OnShutdown()
