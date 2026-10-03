local Model={};Model.__index=Model
function Model.New(adventure)
    return setmetatable({adventure=adventure,rules=require('Game.Shop.ShopRules').New(adventure.config),data=CS.ProjectY.Data.ShopData.For(adventure.data)},Model)
end
function Model:Open(localId,dialogueVersion)
    local adventure=self.adventure
    if adventure.data.Phase~='area' or self.data.IsOpen then return false,'当前不能开启商店' end
    local area=adventure.areas:ActiveLayout();local npc=area.npcs[localId]
    if not npc then return false,'商人不存在' end
    local merchant=self.rules:Resolve(area,npc)
    if not merchant then return false,'这位居民不出售商品' end
    local narrative=adventure.narrative
    if narrative.data.DialogueOpen and (narrative.data.DialogueLocalNpcId~=localId or narrative.data.DialogueVersion~=dialogueVersion) then return false,'对话已变化，请重新选择' end
    local ok,reason=adventure.areas:Interact(2,localId)
    if not ok then return false,reason end
    if narrative.data.DialogueOpen then narrative.dialogue:Close();assert(adventure.areas:Interact(2,localId)) end
    local siteId=adventure.data.Areas.ActiveSiteId;local period=self.rules:Period(merchant.templateId,narrative.data.Minutes)
    local stock=self.data:Find(merchant.id,siteId,localId)
    if not stock or stock.Period~=period then
        local entries,items,counts,prices=self.rules:Roll(merchant.templateId,adventure.data.Seed,merchant.id,siteId,localId,period)
        stock=self.data:Refresh(merchant.id,siteId,localId,merchant.templateId,period,entries,items,counts,prices)
    end
    adventure.data.Areas.Active:Stop();self.data:Open(stock);return true
end
function Model:Close()
    self.data:Close()
    if self.adventure.data.Phase=='area' then self.adventure.areas:CloseInteraction() end
    return true
end
function Model:Buy(entryId,version,count)
    local adventure=self.adventure;local stock=self.data.Active
    if not stock or adventure.data.Phase~='area' or adventure.data.Areas.ActiveSiteId~=stock.SiteId then return false,'商店已关闭' end
    if version~=self.data.Revision then return false,'商品列表已变化，请重新选择' end
    local ok,reason=adventure.areas:Interact(2,stock.LocalNpcId)
    if not ok then return false,reason end
    if self.rules:Period(stock.TemplateId,adventure.narrative.data.Minutes)~=stock.Period then
        self:Close();return false,'商店已到补货时间，请重新打开'
    end
    local entry=stock:Find(entryId)
    if not entry then return false,'商品不在当前商店中' end
    local item=self.rules.items:Get(entry.ItemId);local ammo,capacity,rounds=0,0,0
    if item.kind=='magazine' then local mag=adventure.equipment.rules.magazines:Get(item.id);ammo,capacity,rounds=mag.ammoItemId,mag.capacity,mag.spawnRounds end
    reason=self.data:Buy(entryId,count,version,adventure.equipment.data,adventure.player,item.kind,ammo,capacity,rounds)
    if reason~='' then return false,reason end
    adventure.growth.chronicle:Record('loot',nil,'购买商品',item.name..' ×'..count..'（花费 '..entry.Price*count..' 金币）',adventure.areas:ActiveLayout().name,true)
    return true
end
function Model:Snapshot()
    local stock=assert(self.data.Active,'No shop session');local adventure=self.adventure
    local area=adventure.areas:ActiveLayout();local npc=area.npcs[stock.LocalNpcId]
    local name=npc.narrativeId and adventure.narrative.rules.npcs:Get(npc.narrativeId).name or adventure.config:GetTable('MapAreaTownNpcTable'):Get(npc.templateId).name
    local template=self.rules.templates:Get(stock.TemplateId);local rows={}
    for i=0,stock.Count-1 do
        local entry=stock:GetAt(i);local item=self.rules.items:Get(entry.ItemId)
        local reason=entry.Count==0 and '已售罄' or adventure.player.Coins<entry.Price and '金币不足' or ''
        if reason=='' and not adventure.equipment:CanGrant({entry.ItemId},{1}) then reason='背包空间不足' end
        rows[#rows+1]={id=entry.EntryId,name=item.name,width=item.width,height=item.height,price=entry.Price,count=entry.Count,reason=reason,available=reason==''}
    end
    return {name=name,template=template.name,coins=adventure.player.Coins,refreshDay=(stock.Period+1)*template.refreshDays+1,rows=rows,version=self.data.Revision}
end
return Model
