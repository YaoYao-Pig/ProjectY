local LuaLanguage = require('Language')
local Model={};Model.__index=Model
local function failure(key)
    return assert(LuaLanguage[key],'Unknown camp failure key: '..key)
end
-- 配置数组是只读代理；xLua 数组转换需要带有原始整数键的普通表。
local function arrays(ids,counts)
    local items,amounts={},{};for i,id in ipairs(ids) do items[i]=id;amounts[i]=counts[i] end
    return items,amounts
end
function Model.New(adventure)
    return setmetatable({adventure=adventure,rules=require('Game.Camp.CampRules').New(adventure.config),
        data=CS.ProjectY.Data.CampData.For(adventure.data)},Model)
end
function Model:Available()
    local adventure=self.adventure
    if adventure.data.Phase~='map' then return false,LuaLanguage.UICampText3 end
    if adventure.parties.data.IsOpen then return false,LuaLanguage.UICampText2 end
    if adventure.shop.data.IsOpen or adventure.narrative.data.DialogueOpen then return false,LuaLanguage.UICampText end
    return true,''
end
function Model:Open()
    local ok,reason=self:Available();if not ok then return false,reason end
    if self.data.IsOpen then return false,LuaLanguage.UICampText4 end
    self.data:Open();return true
end
function Model:Close() self.data:Close();return true end
function Model:Session(revision)
    local ok,reason=self:Available();if not ok then return false,reason end
    if not self.data.IsOpen then return false,LuaLanguage.UICampText6 end
    if self.data.Revision~=revision then return false,LuaLanguage.UICampText5 end
    return true,''
end
function Model:Record(title,body)
    self.adventure.growth.chronicle:Record('loot',nil,title,body,LuaLanguage.UICampTitleText,true)
end
function Model:Upgrade(facilityId,revision)
    local ok,reason=self:Session(revision);if not ok then return false,reason end
    local adventure=self.adventure
    local upgrade;ok,reason,upgrade=self.rules:CanUpgrade(self.data,adventure.equipment.data,adventure.player.Coins,facilityId)
    if not ok then return false,reason end
    local items,counts=arrays(upgrade.itemIds,upgrade.itemCounts)
    reason=self.data:Upgrade(facilityId,upgrade.level-1,revision,upgrade.coins,items,counts,adventure.equipment.data,adventure.player)
    if reason~='' then return false,failure(reason) end
    self:Record(LuaLanguage.UICampText8,string.format(LuaLanguage.UICampText7, (self.rules.facilities:Get(facilityId).name), (upgrade.level)));return true
end
function Model:Produce(recipeId,revision)
    local ok,reason=self:Session(revision);if not ok then return false,reason end
    local adventure=self.adventure;local minutes=adventure.narrative.data.Minutes
    ok,reason=self.rules:CanProduce(self.data,adventure.equipment.data,adventure.player.Coins,recipeId,minutes)
    if not ok then return false,reason end
    local row=self.rules.recipes:Get(recipeId)
    local items,counts=arrays(row.itemIds,row.itemCounts)
    reason=self.data:Enqueue(row.facilityId,row.id,row.requiredLevel,minutes,row.minutes,revision,row.coins,items,counts,adventure.equipment.data,adventure.player)
    if reason~='' then return false,failure(reason) end
    self:Record(LuaLanguage.UICampText10,string.format(LuaLanguage.UICampText9, (row.name), (row.minutes)));return true
end
function Model:Claim(facilityId,revision)
    local ok,reason=self:Session(revision);if not ok then return false,reason end
    local job=self.data:JobFor(facilityId);if not job then return false,LuaLanguage.UICampText12 end
    local row=self.rules.recipes:Get(job.RecipeId);local kinds={}
    for i,id in ipairs(row.outputIds) do kinds[i]=self.rules.items:Get(id).kind end
    local items,counts=arrays(row.outputIds,row.outputCounts)
    reason=self.data:Claim(facilityId,revision,self.adventure.narrative.data.Minutes,items,counts,kinds,self.adventure.equipment.data)
    if reason~='' then return false,failure(reason) end
    self:Record(LuaLanguage.UICampText11,self.rules:ItemsText(row.outputIds,row.outputCounts));return true
end
function Model:Deposit(itemId,revision,count)
    local ok,reason=self:Session(revision);if not ok then return false,reason end
    if not self.rules:IsStack(itemId) then return false,LuaLanguage.UICampText13 end
    reason=self.data:Deposit(itemId,count,self.rules:Capacity(self.data),revision,self.adventure.equipment.data)
    return reason=='',reason=='' and '' or failure(reason)
end
function Model:Withdraw(itemId,revision,count)
    local ok,reason=self:Session(revision);if not ok then return false,reason end
    if not self.rules:IsStack(itemId) then return false,LuaLanguage.UICampText14 end
    reason=self.data:Withdraw(itemId,count,revision,self.rules.items:Get(itemId).kind,self.adventure.equipment.data)
    return reason=='',reason=='' and '' or failure(reason)
end
function Model:Wait(minutes,revision)
    local ok,reason=self:Session(revision);if not ok then return false,reason end
    reason=self.data:Wait(minutes,revision,self.adventure.narrative.data)
    if reason~='' then return false,failure(reason) end
    self.adventure.narrative:TickBuffs()
    self.adventure.narrative:Refresh();return true
end
function Model:Snapshot()
    assert(self.data.IsOpen,'Camp snapshot requires an open session')
    local adventure=self.adventure;local data,rules=self.data,self.rules;local equipment=adventure.equipment.data
    local minutes=adventure.narrative.data.Minutes;local rows={};local coins=adventure.player.Coins
    local function add(section,title,body,command,id,available,count)
        rows[#rows+1]={section=section,title=title,body=body,command=command,id=id,available=available~=false,count=count or 0}
    end
    for _,facility in ipairs(rules.facilities:All()) do
        local level=data:GetLevel(facility.id);local ok,reason,upgrade=rules:CanUpgrade(data,equipment,coins,facility.id)
        local detail=facility.description..'\n'..(upgrade and (string.format(LuaLanguage.UICampDetail2, (upgrade.level), (rules:CostText(upgrade)))) or reason)
        if upgrade then detail=detail..'\n'..(ok and LuaLanguage.UICampDetail or reason) end
        add('build',string.format(LuaLanguage.UICampText35, (facility.name), (level)),detail,upgrade and 'camp_upgrade' or nil,facility.id,ok)
        local job=data:JobFor(facility.id)
        if job then
            local row=rules.recipes:Get(job.RecipeId);local ready=minutes>=job.ReadyAt
            local fits=ready and adventure.equipment:CanGrant(row.outputIds,row.outputCounts)
            add('production',(ready and LuaLanguage.UICampText34 or LuaLanguage.UICampText33)..row.name,rules:ItemsText(row.outputIds,row.outputCounts)..'\n'..
                (ready and (fits and LuaLanguage.UICampText32 or LuaLanguage.UICampText31) or (string.format(LuaLanguage.UICampText30, (math.ceil(job.ReadyAt-minutes))))),
                'camp_claim',facility.id,ready and fits)
        end
        for _,recipe in ipairs(rules.byFacility[facility.id]) do
            ok,reason=rules:CanProduce(data,equipment,coins,recipe.id,minutes)
            add('production',string.format(LuaLanguage.UICampText29, (recipe.name), (facility.name), (recipe.requiredLevel)),
                string.format(LuaLanguage.UICampText28, (rules:ItemsText(recipe.outputIds,recipe.outputCounts)), (recipe.minutes), (rules:CostText(recipe)), (ok and LuaLanguage.UICampText27 or reason)),'camp_produce',recipe.id,ok)
        end
    end
    local capacity=rules:Capacity(data);local free=capacity-data.StoredTotal
    add('storage',string.format(LuaLanguage.UICampText26, (data.StoredTotal), (capacity)),LuaLanguage.UICampText25)
    local deposited,withdrawn=0,0
    for _,item in ipairs(rules.items:All()) do if rules:IsStack(item.id) then
        local batch=(item.kind=='material' or item.kind=='ammo') and 10 or 1
        local bag=equipment:CountItem(item.id);local stored=data:Stored(item.id)
        if bag>0 then
            local amount=math.min(bag,batch,math.max(1,free))
            add('storage',string.format(LuaLanguage.UICampText24, (item.name), (amount)),string.format(LuaLanguage.UICampText23, (bag), (stored), (free==0 and LuaLanguage.UICampText22 or '')),'camp_deposit',item.id,free>0,amount);deposited=deposited+1
        end
        if stored>0 then
            local amount=math.min(stored,batch);local fits=adventure.equipment:CanGrant({item.id},{amount})
            add('storage',string.format(LuaLanguage.UICampText21, (item.name), (amount)),string.format(LuaLanguage.UICampText20, (stored), (bag), (not fits and LuaLanguage.UICampText19 or '')),'camp_withdraw',item.id,fits,amount);withdrawn=withdrawn+1
        end
    end end
    if deposited+withdrawn==0 then add('storage',LuaLanguage.UICampText18,LuaLanguage.UICampText17) end
    for _,duration in ipairs({60,360,1440}) do
        add('wait',string.format(LuaLanguage.UICampText16, (duration//60)),LuaLanguage.UICampText15,'camp_wait',duration,minutes+duration<=1000000000)
    end
    return {version=data.Revision,coins=coins,minutes=minutes,capacity=capacity,stored=data.StoredTotal,jobs=data.JobCount,rows=rows}
end
return Model
