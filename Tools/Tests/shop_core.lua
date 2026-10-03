package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=file:read('*a');file:close();return bytes
end}})
local Rules=require('Game.Shop.ShopRules');local rules=Rules.New(config)
local function signature(entries,items,counts,prices)
    local rows={};for i,id in ipairs(entries) do rows[#rows+1]=table.concat({id,items[i],counts[i],prices[i]},':') end;return table.concat(rows,',')
end
assert(rules:Period(1,1439.99)==0 and rules:Period(1,1440)==1 and rules:Period(1,4320)==3)
local area={configId=2};assert(rules:Resolve(area,{id=1,templateId=3}).templateId==1)
assert(not rules:Resolve(area,{id=2,templateId=2}));assert(not rules:Resolve(area,{id=3,templateId=3,narrativeId=1}))
local variants={}
for npc=1,30 do
    local entries,items,counts,prices=rules:Roll(1,2718,1,2,npc,0)
    assert(items[1]==31 and counts[1]>=12 and counts[1]<=24,'Guaranteed stock must appear')
    local sig=signature(entries,items,counts,prices);variants[sig]=true
    assert(sig==signature(rules:Roll(1,2718,1,2,npc,0)),'Reopen must preserve deterministic roll')
    for i,id in ipairs(entries) do local row=rules.entries:Get(id);assert(counts[i]>=row.minCount and counts[i]<=row.maxCount and prices[i]==row.price) end
end
local count=0;for _ in pairs(variants) do count=count+1 end;assert(count>1,'NPCs sharing a template must roll independently')
local entries={{id=1,templateId=1,itemId=31,chance=100,minCount=2,maxCount=2,price=3},
    {id=2,templateId=1,itemId=40,chance=0,minCount=1,maxCount=1,price=5},
    {id=3,templateId=1,itemId=51,chance=100,minCount=1,maxCount=1,price=7}}
local merchants={{id=1,templateId=1,npcIds={},townNpcTemplateIds={3},areaIds={2}}}
local fixture={GetTable=function(_,name)
    if name=='ShopEntryTable' then return {All=function()return entries end} end
    if name=='ShopMerchantTable' then return {All=function()return merchants end} end
    if name=='ShopTemplateTable' then return {All=function()return {{id=1,refreshDays=3}} end,Get=function()return {id=1,refreshDays=3,seedSalt=123} end} end
    return config:GetTable(name)
end}
local exact=Rules.New(fixture);local ids,items,amounts=exact:Roll(1,123,1,1,1,0)
assert(#ids==2 and items[1]==31 and amounts[1]==2 and items[2]==51)
assert(exact:Period(1,4319.99)==0 and exact:Period(1,4320)==1)
assert(not exact:Resolve({configId=3},{id=1,templateId=3}))
entries[1].chance=0;entries[3].chance=0;assert(#exact:Roll(1,123,1,1,1,0)==0,'Empty stock must be valid')
entries[2].maxCount=0;assert(not pcall(Rules.New,fixture),'Reversed quantity range must fail');entries[2].maxCount=1
merchants[1].npcIds={1};assert(not pcall(Rules.New,fixture),'Ambiguous merchant selector must fail')
print('PASS shop: real exported config, independent 0/100 percent rolls, empty stock, deterministic NPC stock, quantities, area filters, refresh boundaries and invalid configuration')
