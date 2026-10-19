package.path='Lua/?.lua;'..package.path
local config
if CampSourceRows then
    local function readonly(value)
        if type(value)~='table' then return value end
        local copy={};for key,item in pairs(value) do copy[key]=readonly(item) end
        return setmetatable({},{__index=copy,__len=function()return #copy end,__pairs=function()return next,copy,nil end,__newindex=function()error('Read-only source fixture')end})
    end
    local tables={}
    for name,source in pairs(CampSourceRows) do
        local rows=readonly(source)
        local lookup={};for _,row in ipairs(rows) do lookup[row.id]=row end
        tables[name]={All=function()return rows end,Get=function(_,id)return assert(lookup[id],name..': '..tostring(id))end}
    end
    config={GetTable=function(_,name)return assert(tables[name],name)end}
else
    config=require('Config.ConfigSystem')()
    config:OnInit({services={ReadConfig=function(_,name)
        local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=file:read('*a');file:close();return bytes
    end}})
end
local Rules=require('Game.Camp.CampRules');local rules=Rules.New(config)
local levels,stored,items,jobs={},{},{},{}
local data={StoredTotal=0,LevelCount=0,StorageCount=0,JobCount=0,
    GetLevel=function(_,id)return levels[id] or 0 end,Stored=function(_,id)return stored[id] or 0 end,JobFor=function(_,id)return jobs[id]end}
local equipment={CountItem=function(_,id)return items[id] or 0 end}
assert(rules:Capacity(data)==80)
levels[3]=1;assert(rules:Capacity(data)==160);levels[3]=2;assert(rules:Capacity(data)==320);levels[3]=nil
local ok,reason=rules:CanUpgrade(data,equipment,0,1);assert(not ok and reason=='金币不足')
ok,reason=rules:CanUpgrade(data,equipment,100,1);assert(not ok and reason:find('缺少'))
local upgrade=rules.byLevel[1][1]
for i,id in ipairs(upgrade.itemIds) do stored[id]=1;items[id]=upgrade.itemCounts[i]-1 end
assert(rules:CanUpgrade(data,equipment,upgrade.coins,1),'Warehouse plus backpack must satisfy a cost together')
local wood,bag=stored[81],items[81];rules:CanUpgrade(data,equipment,100,1);assert(stored[81]==wood and items[81]==bag,'Preview must not consume resources')
levels[1]=2;ok,reason=rules:CanUpgrade(data,equipment,100,1);assert(not ok and reason=='已达到最高等级')
levels[1]=nil;assert(not rules:CanProduce(data,equipment,100,1,0))
levels[1]=1;items[81]=20;items[83]=20;assert(rules:CanProduce(data,equipment,100,1,0))
jobs[1]={};assert(not rules:CanProduce(data,equipment,100,1,0));jobs[1]=nil
assert(not rules:CanProduce(data,equipment,100,1,1000000000))
assert(not rules:CanProduce(data,equipment,100,2,0),'Advanced recipe requires level two')
assert(rules:IsStack(91) and rules:IsStack(92) and not rules:IsStack(40))
assert(not pcall(function()rules:ValidateItems({81,81},{1,1},true)end))
assert(not pcall(function()rules:ValidateItems({40},{1},true)end))
assert(not pcall(function()rules:ValidateItems({81},{0},true)end))
rules:ValidateSaved(data,10)
data.StoredTotal=81;assert(not pcall(function()rules:ValidateSaved(data,10)end));data.StoredTotal=0
data.JobCount=1;local job={FacilityId=1,RecipeId=1,StartedAt=10,ReadyAt=70};data.GetJobAt=function()return job end
assert(not pcall(function()rules:ValidateSaved(data,9)end),'Future production start must be rejected')
rules:ValidateSaved(data,10);job.ReadyAt=71;assert(not pcall(function()rules:ValidateSaved(data,10)end),'Changed recipe duration must be rejected')
local modelData={Revision=7,IsOpen=true,GetLevel=function()return 1 end,Stored=function()return 100 end,JobFor=function()return nil end}
local crossed=0
local function rawArrays(ids,counts,expected)
    assert(rawlen(ids)==expected and rawlen(counts)==expected,'Readonly config proxies must be copied before xLua conversion');crossed=crossed+1;return ''
end
modelData.Upgrade=function(_,facility,level,revision,coins,ids,counts)return rawArrays(ids,counts,3)end
modelData.Enqueue=function(_,facility,recipe,level,now,duration,revision,coins,ids,counts)return rawArrays(ids,counts,2)end
modelData.Claim=function(_,facility,revision,now,ids,counts)return rawArrays(ids,counts,1)end
CS={ProjectY={Data={CampData={For=function()return modelData end}}}}
local adventure={config=config,data={Phase='map'},shop={data={IsOpen=false}},narrative={data={DialogueOpen=false,Minutes=0}},
    player={Coins=1000},equipment={data=equipment},growth={chronicle={Record=function()end}}}
local model=require('Game.Camp.CampModel').New(adventure)
assert(model:Upgrade(1,7));assert(model:Produce(1,7));modelData.JobFor=function()return {RecipeId=1}end;assert(model:Claim(1,7));assert(crossed==3)
for _,file in ipairs({'Lua/Game/Camp/CampModel.lua','Lua/UI/Panel/CampCtr.lua','Tools/Tests/camp_integration.lua','Tools/Tests/camp_ui_integration.lua'}) do
    assert(loadfile(file),'Lua syntax error: '..file)
end
print('PASS camp core: real source tables, 80/160/320 storage, combined materials, balances, levels, queue limits, clock bounds, save validation and Lua syntax')
