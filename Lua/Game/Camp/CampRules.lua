local Language=require('Language')
local Rules={};Rules.__index=Rules
local stackKinds={material=true,ammo=true,consumable=true,rune=true,module=true}
local function positive(value) return type(value)=='number' and value>0 and value%1==0 end
function Rules.New(config)
    local self=setmetatable({facilities=config:GetTable('CampFacilityTable'),upgrades=config:GetTable('CampUpgradeTable'),
        recipes=config:GetTable('CampRecipeTable'),items=config:GetTable('EquipmentItemTable'),byFacility={},byLevel={}},Rules)
    for _,row in ipairs(self.facilities:All()) do
        assert(row.baseCapacity>=0,'Invalid camp base capacity')
        self.byFacility[row.id]={};self.byLevel[row.id]={}
        if row.baseCapacity>0 then assert(not self.warehouse,'Only one camp warehouse is supported');self.warehouse=row end
    end
    assert(self.warehouse,'Camp requires a warehouse')
    for _,row in ipairs(self.upgrades:All()) do
        local facility=self.facilities:Get(row.facilityId)
        local levels=self.byLevel[facility.id]
        assert(positive(row.level) and not levels[row.level] and row.coins>=0,'Invalid or duplicate camp upgrade')
        self:ValidateItems(row.itemIds,row.itemCounts,false);levels[row.level]=row
        assert((facility.baseCapacity>0)==(row.storageCapacity>0),'Camp warehouse upgrade capacity mismatch')
    end
    for _,facility in ipairs(self.facilities:All()) do
        local levels=self.byLevel[facility.id];local count=0;for _ in pairs(levels) do count=count+1 end
        assert(count>0,'Camp facility has no upgrades')
        local capacity=facility.baseCapacity
        for level=1,count do local upgrade=assert(levels[level],'Camp upgrade levels must be consecutive')
            if capacity>0 then assert(upgrade.storageCapacity>capacity,'Warehouse upgrades must increase capacity');capacity=upgrade.storageCapacity end
        end
    end
    for _,row in ipairs(self.recipes:All()) do
        local facility=self.facilities:Get(row.facilityId)
        assert(facility.baseCapacity==0 and self.byLevel[facility.id][row.requiredLevel] and positive(row.minutes) and row.coins>=0,'Invalid camp recipe')
        self:ValidateItems(row.itemIds,row.itemCounts,false);self:ValidateItems(row.outputIds,row.outputCounts,true)
        self.byFacility[facility.id][#self.byFacility[facility.id]+1]=row
    end
    return self
end
function Rules:IsStack(itemId) return stackKinds[self.items:Get(itemId).kind]==true end
function Rules:ValidateItems(ids,counts,output)
    assert(#ids==#counts and (not output or #ids>0),'Camp item quantities differ')
    local seen={}
    for i,id in ipairs(ids) do
        local kind=self.items:Get(id).kind
        local allowed=stackKinds[kind] or output and (kind=='weapon' or kind=='wearable')
        assert(not seen[id] and positive(counts[i]) and allowed,'Camp items require unique supported kinds with positive counts');seen[id]=true
    end
end
function Rules:Capacity(data)
    local level=data:GetLevel(self.warehouse.id)
    return level==0 and self.warehouse.baseCapacity or assert(self.byLevel[self.warehouse.id][level],'Unknown warehouse level').storageCapacity
end
function Rules:Cost(data,equipment,coins,row)
    if coins<row.coins then return false,Language.CampInsufficientCoins end
    for i,id in ipairs(row.itemIds) do
        if data:Stored(id)+equipment:CountItem(id)<row.itemCounts[i] then return false,string.format(Language.CampMissingMaterial,self.items:Get(id).name) end
    end
    return true,''
end
function Rules:CanUpgrade(data,equipment,coins,facilityId)
    self.facilities:Get(facilityId)
    local row=self.byLevel[facilityId][data:GetLevel(facilityId)+1]
    if not row then return false,Language.CampMaxLevel end
    local ok,reason=self:Cost(data,equipment,coins,row);return ok,reason,row
end
function Rules:CanProduce(data,equipment,coins,recipeId,minutes)
    local row=self.recipes:Get(recipeId)
    if data:GetLevel(row.facilityId)<row.requiredLevel then return false,string.format(Language.CampRequiredFacilityLevel,self.facilities:Get(row.facilityId).name,row.requiredLevel) end
    if data:JobFor(row.facilityId) then return false,Language.CampFacilityBusy end
    if minutes+row.minutes>1000000000 then return false,Language.CampTimeLimit end
    return self:Cost(data,equipment,coins,row)
end
function Rules:ItemsText(ids,counts)
    local parts={};for i,id in ipairs(ids) do parts[#parts+1]=string.format(Language.CampItemQuantity,self.items:Get(id).name,counts[i]) end
    return table.concat(parts,Language.CampItemSeparator)
end
function Rules:CostText(row)
    if #row.itemIds==0 then return string.format(Language.CampCostCoins,row.coins) end
    return string.format(Language.CampCostMaterialsCoins,self:ItemsText(row.itemIds,row.itemCounts),row.coins)
end
function Rules:ValidateSaved(data,minutes)
    for i=0,data.LevelCount-1 do local row=data:GetLevelAt(i)
        self.facilities:Get(row.FacilityId);assert(self.byLevel[row.FacilityId][row.Level],'存档营地等级不在配置中')
    end
    assert(data.StoredTotal<=self:Capacity(data),'存档营地仓库超过容量')
    for i=0,data.StorageCount-1 do assert(self:IsStack(data:GetStorageAt(i).ItemId),'存档仓库物品不能堆叠') end
    for i=0,data.JobCount-1 do local job=data:GetJobAt(i);local recipe=self.recipes:Get(job.RecipeId)
        assert(recipe.facilityId==job.FacilityId and data:GetLevel(job.FacilityId)>=recipe.requiredLevel,'存档生产订单与设施不一致')
        assert(job.StartedAt<=minutes and math.abs(job.ReadyAt-job.StartedAt-recipe.minutes)<0.001,'存档生产时长与配置不一致')
    end
end
return Rules
