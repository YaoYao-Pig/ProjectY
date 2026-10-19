local Model={};Model.__index=Model
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
    if adventure.data.Phase~='map' then return false,'请先返回地图营地' end
    if adventure.parties.data.IsOpen then return false,'请先结束队伍交互' end
    if adventure.shop.data.IsOpen or adventure.narrative.data.DialogueOpen then return false,'请先结束当前交互' end
    return true,''
end
function Model:Open()
    local ok,reason=self:Available();if not ok then return false,reason end
    if self.data.IsOpen then return false,'营地已经打开' end
    self.data:Open();return true
end
function Model:Close() self.data:Close();return true end
function Model:Session(revision)
    local ok,reason=self:Available();if not ok then return false,reason end
    if not self.data.IsOpen then return false,'请先打开营地' end
    if self.data.Revision~=revision then return false,'营地状态已变化，请重新选择' end
    return true,''
end
function Model:Record(title,body)
    self.adventure.growth.chronicle:Record('loot',nil,title,body,'远征营地',true)
end
function Model:Upgrade(facilityId,revision)
    local ok,reason=self:Session(revision);if not ok then return false,reason end
    local adventure=self.adventure
    local upgrade;ok,reason,upgrade=self.rules:CanUpgrade(self.data,adventure.equipment.data,adventure.player.Coins,facilityId)
    if not ok then return false,reason end
    local items,counts=arrays(upgrade.itemIds,upgrade.itemCounts)
    reason=self.data:Upgrade(facilityId,upgrade.level-1,revision,upgrade.coins,items,counts,adventure.equipment.data,adventure.player)
    if reason~='' then return false,reason end
    self:Record('营地建设',self.rules.facilities:Get(facilityId).name..' 升至 '..upgrade.level..' 级');return true
end
function Model:Produce(recipeId,revision)
    local ok,reason=self:Session(revision);if not ok then return false,reason end
    local adventure=self.adventure;local minutes=adventure.narrative.data.Minutes
    ok,reason=self.rules:CanProduce(self.data,adventure.equipment.data,adventure.player.Coins,recipeId,minutes)
    if not ok then return false,reason end
    local row=self.rules.recipes:Get(recipeId)
    local items,counts=arrays(row.itemIds,row.itemCounts)
    reason=self.data:Enqueue(row.facilityId,row.id,row.requiredLevel,minutes,row.minutes,revision,row.coins,items,counts,adventure.equipment.data,adventure.player)
    if reason~='' then return false,reason end
    self:Record('开始生产',row.name..' · '..row.minutes..' 分钟后可领取');return true
end
function Model:Claim(facilityId,revision)
    local ok,reason=self:Session(revision);if not ok then return false,reason end
    local job=self.data:JobFor(facilityId);if not job then return false,'该设施没有待领取订单' end
    local row=self.rules.recipes:Get(job.RecipeId);local kinds={}
    for i,id in ipairs(row.outputIds) do kinds[i]=self.rules.items:Get(id).kind end
    local items,counts=arrays(row.outputIds,row.outputCounts)
    reason=self.data:Claim(facilityId,revision,self.adventure.narrative.data.Minutes,items,counts,kinds,self.adventure.equipment.data)
    if reason~='' then return false,reason end
    self:Record('领取营地产物',self.rules:ItemsText(row.outputIds,row.outputCounts));return true
end
function Model:Deposit(itemId,revision,count)
    local ok,reason=self:Session(revision);if not ok then return false,reason end
    if not self.rules:IsStack(itemId) then return false,'营地仓库只接收材料、弹药、药品与组件' end
    reason=self.data:Deposit(itemId,count,self.rules:Capacity(self.data),revision,self.adventure.equipment.data)
    return reason=='',reason
end
function Model:Withdraw(itemId,revision,count)
    local ok,reason=self:Session(revision);if not ok then return false,reason end
    if not self.rules:IsStack(itemId) then return false,'营地仓库只保存堆叠物品' end
    reason=self.data:Withdraw(itemId,count,revision,self.rules.items:Get(itemId).kind,self.adventure.equipment.data)
    return reason=='',reason
end
function Model:Wait(minutes,revision)
    local ok,reason=self:Session(revision);if not ok then return false,reason end
    reason=self.data:Wait(minutes,revision,self.adventure.narrative.data)
    if reason~='' then return false,reason end
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
        local detail=facility.description..'\n'..(upgrade and ('建设至 '..upgrade.level..' 级：'..rules:CostText(upgrade)) or reason)
        if upgrade then detail=detail..'\n'..(ok and '点击建设，费用一次性扣除' or reason) end
        add('build',facility.name..' · '..level..' 级',detail,upgrade and 'camp_upgrade' or nil,facility.id,ok)
        local job=data:JobFor(facility.id)
        if job then
            local row=rules.recipes:Get(job.RecipeId);local ready=minutes>=job.ReadyAt
            local fits=ready and adventure.equipment:CanGrant(row.outputIds,row.outputCounts)
            add('production',(ready and '领取 · ' or '生产中 · ')..row.name,rules:ItemsText(row.outputIds,row.outputCounts)..'\n'..
                (ready and (fits and '生产已完成，点击收入背包' or '背包空间不足，产物保留在设施中') or ('剩余 '..math.ceil(job.ReadyAt-minutes)..' 分钟')),
                'camp_claim',facility.id,ready and fits)
        end
        for _,recipe in ipairs(rules.byFacility[facility.id]) do
            ok,reason=rules:CanProduce(data,equipment,coins,recipe.id,minutes)
            add('production',recipe.name..' · '..facility.name..' '..recipe.requiredLevel..' 级',
                '产出 '..rules:ItemsText(recipe.outputIds,recipe.outputCounts)..'  |  '..recipe.minutes..' 分钟\n投入 '..rules:CostText(recipe)..'\n'..
                (ok and '点击安排生产 · 每个设施保留一个订单' or reason),'camp_produce',recipe.id,ok)
        end
    end
    local capacity=rules:Capacity(data);local free=capacity-data.StoredTotal
    add('storage','营地仓库 · '..data.StoredTotal..' / '..capacity,'材料先从仓库扣除，再从背包补足。每次转移最多 10 件，药品和组件每次 1 件。')
    local deposited,withdrawn=0,0
    for _,item in ipairs(rules.items:All()) do if rules:IsStack(item.id) then
        local batch=(item.kind=='material' or item.kind=='ammo') and 10 or 1
        local bag=equipment:CountItem(item.id);local stored=data:Stored(item.id)
        if bag>0 then
            local amount=math.min(bag,batch,math.max(1,free))
            add('storage','存入 '..item.name..' ×'..amount,'背包 '..bag..'  |  仓库 '..stored..(free==0 and '\n仓库已满，请先升级或取出' or ''),'camp_deposit',item.id,free>0,amount);deposited=deposited+1
        end
        if stored>0 then
            local amount=math.min(stored,batch);local fits=adventure.equipment:CanGrant({item.id},{amount})
            add('storage','取出 '..item.name..' ×'..amount,'仓库 '..stored..'  |  背包 '..bag..(not fits and '\n背包空间不足，物品留在仓库' or ''),'camp_withdraw',item.id,fits,amount);withdrawn=withdrawn+1
        end
    end end
    if deposited+withdrawn==0 then add('storage','尚无可转移物资','探索、搜刮或向商人购买材料后，可在这里安全存放。') end
    for _,duration in ipairs({60,360,1440}) do
        add('wait','等待 '..(duration//60)..' 小时','推进营地生产、世界时钟与商人补货周期。等待不直接恢复伤势或发放物品。','camp_wait',duration,minutes+duration<=1000000000)
    end
    return {version=data.Revision,coins=coins,minutes=minutes,capacity=capacity,stored=data.StoredTotal,jobs=data.JobCount,rows=rows}
end
return Model
