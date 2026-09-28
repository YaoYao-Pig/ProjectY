-- 各物品独立掷骰；结果交给 C# 容器保存，领取与重进不再抽取。
local Random=require('Game.Map.SeededRandom')
local Rules={};Rules.__index=Rules
function Rules.New(config)
    local self=setmetatable({entries={},pools=config:GetTable('LootPoolTable'),containers=config:GetTable('EquipmentLootTable'),enemies={}},Rules)
    local items=config:GetTable('EquipmentItemTable')
    for _,pool in ipairs(self.pools:All()) do self.entries[pool.id]={} end
    for _,entry in ipairs(config:GetTable('LootEntryTable'):All()) do
        assert(entry.minCount<=entry.maxCount,'Loot count range is reversed')
        items:Get(entry.itemId);local list=assert(self.entries[entry.poolId],'Unknown loot pool')
        list[#list+1]=entry
    end
    for _,container in ipairs(self.containers:All()) do
        assert(#container.itemIds==#container.counts,'Fixed loot arrays differ')
        if container.poolId>0 then self.pools:Get(container.poolId);assert(#container.itemIds==0,'Random loot must not also have fixed contents') end
    end
    for _,row in ipairs(config:GetTable('EnemyDropTable'):All()) do
        assert(not self.enemies[row.unitId],'Duplicate enemy drop definition')
        assert(self.containers:Get(row.lootTableId).kind=='ground','Enemy drops need a ground presentation')
        self.enemies[row.unitId]=row
    end
    return self
end
function Rules:Roll(containerId,seed)
    local row=self.containers:Get(containerId);local ids,counts,indices={},{},{}
    local function add(id,count)
        local index=indices[id]
        if not index then index=#ids+1;indices[id]=index;ids[index]=id;counts[index]=0 end
        counts[index]=counts[index]+count
    end
    if row.poolId==0 then for i,id in ipairs(row.itemIds) do add(id,row.counts[i]) end
    else
        local pool=self.pools:Get(row.poolId);local random=Random((seed ~ pool.seedSalt) & 0xffffffff)
        for _,entry in ipairs(self.entries[row.poolId]) do
            if random:Integer(1,10000)<=entry.chance*100 then add(entry.itemId,random:Integer(entry.minCount,entry.maxCount)) end
        end
    end
    return ids,counts
end
return Rules
