local Random=require('Game.Map.SeededRandom')
local Rules={};Rules.__index=Rules
local function contains(values,value) for _,v in ipairs(values) do if v==value then return true end end;return false end
function Rules.New(config)
    local self=setmetatable({config=config,templates=config:GetTable('ShopTemplateTable'),merchants=config:GetTable('ShopMerchantTable'),
        items=config:GetTable('EquipmentItemTable'),entries=config:GetTable('ShopEntryTable'),byTemplate={}},Rules)
    for _,template in ipairs(self.templates:All()) do
        assert(template.refreshDays>=1 and template.refreshDays%1==0,'Invalid shop refresh interval')
        self.byTemplate[template.id]={}
    end
    for _,entry in ipairs(self.entries:All()) do
        self.items:Get(entry.itemId)
        local rows=assert(self.byTemplate[entry.templateId],'Unknown shop template')
        assert(entry.chance>=0 and entry.chance<=100 and entry.minCount>=1 and entry.minCount<=entry.maxCount and entry.price>=0,'Invalid shop entry')
        for _,other in ipairs(rows) do assert(other.itemId~=entry.itemId,'Duplicate item in shop template') end
        rows[#rows+1]=entry
    end
    for _,merchant in ipairs(self.merchants:All()) do
        self.templates:Get(merchant.templateId)
        assert((#merchant.npcIds>0)~=(#merchant.townNpcTemplateIds>0),'Merchant must select named NPCs or town NPC templates')
    end
    return self
end
function Rules:Resolve(area,npc)
    local found
    for _,row in ipairs(self.merchants:All()) do
        local matches=npc.narrativeId and contains(row.npcIds,npc.narrativeId) or not npc.narrativeId and contains(row.townNpcTemplateIds,npc.templateId)
        if matches and (#row.areaIds==0 or contains(row.areaIds,area.configId)) then
            assert(not found,'Overlapping merchant bindings for NPC '..npc.id);found=row
        end
    end
    return found
end
function Rules:Period(templateId,minutes)
    return math.floor(minutes/(self.templates:Get(templateId).refreshDays*1440))
end
function Rules:Roll(templateId,seed,merchantId,siteId,npcId,period)
    local template=self.templates:Get(templateId)
    local random=Random((seed ~ template.seedSalt ~ (merchantId*73856093) ~ (siteId*19349663) ~ (npcId*83492791) ~ (period*2654435761)) & 0xffffffff)
    local entries,items,counts,prices={},{},{},{}
    for _,row in ipairs(self.byTemplate[templateId]) do
        if random:Integer(1,10000)<=row.chance*100 then
            entries[#entries+1]=row.id;items[#items+1]=row.itemId;counts[#counts+1]=random:Integer(row.minCount,row.maxCount);prices[#prices+1]=row.price
        end
    end
    return entries,items,counts,prices
end
function Rules:ValidateSaved(data,minutes)
    for i=0,data.Count-1 do
        local stock=data:GetAt(i);local merchant=self.merchants:Get(stock.MerchantId)
        assert(merchant.templateId==stock.TemplateId and stock.Period<=self:Period(stock.TemplateId,minutes),'Saved merchant template or refresh period is invalid')
        for j=0,stock.Count-1 do
            local entry=stock:GetAt(j);local row=self.entries:Get(entry.EntryId)
            assert(row.templateId==stock.TemplateId and row.itemId==entry.ItemId and row.price==entry.Price and entry.Count<=row.maxCount,'Saved shop entry differs from current configuration')
        end
    end
end
return Rules
