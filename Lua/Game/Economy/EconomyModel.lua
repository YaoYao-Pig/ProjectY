local Life=require('Game.Battle.ActorLife')
local L=require('Language')
local Hex=require('Game.Map.HexGrid')
local Model={};Model.__index=Model
local function failure(reason) return reason=='',reason=='' and '' or assert(L[reason],'Missing economy language key: '..reason) end
function Model.New(adventure)
    local self=setmetatable({adventure=adventure,data=CS.ProjectY.Data.TownEconomyData.For(adventure.data),
        rule=adventure.config:GetTable('EconomyRuleTable'):Get(1),commodities=adventure.config:GetTable('EconomyCommodityTable'),byItem={},profiles={}},Model)
    local native=CS.ProjectY.Data.EconomyRules();local food={}
    for _,key in ipairs({'foodBase','foodLevelStep','wageBase','wagePerLevel','animalFoodBase','termDays','investmentLimit',
        'maximumLossPercent','maximumGainPercent','historyDays','marketTarget','marketCapacity','sellMultiplier','hungerPenalty','debtPenalty','maximumPenalty'}) do native[key]=self.rule[key] end
    for _,good in ipairs(self.commodities:All()) do
        assert(not self.byItem[good.itemId],'Duplicate economic item');self.byItem[good.itemId]=good
        assert(adventure.config:GetTable('EquipmentItemTable'):Get(good.itemId).kind=='material','Economic goods must be stackable materials')
        if good.food then food[#food+1]=good.itemId end
    end
    native.foodItems=food;self.data:Configure(native);return self
end
function Model:Bind(world,newCampaign)
    local a=self.adventure;self.profiles={};local towns={}
    for _,town in ipairs(world.map:GetTowns()) do towns[town.id]=town end
    if not self.data.Initialized then self.data:Initialize(a.narrative.data.Minutes) end
    for _,site in ipairs(world.sites) do
        local town=site.source and site.source.townId and towns[site.source.townId]
        if town and town.role=='settlement' then
            local profile=town.economy or require('Game.Map.TownEconomyProfile').ForTown(world.map,town,a.config)
            self.profiles[site.id]=profile
            if not self.data:FindTown(site.id) then
                local ids,prices,strengths={},{},{}
                for _,good in ipairs(self.commodities:All()) do ids[#ids+1]=good.itemId;prices[#prices+1]=good.basePrice;strengths[#strengths+1]=profile.resources[good.id] end
                self.data:AddTown(site.id,profile.tradeAccess,ids,prices,strengths)
            end
        end
    end
    if newCampaign then
        local foodItem
        for _,good in ipairs(self.commodities:All()) do if good.food then foodItem=good.itemId;break end end
        assert(a.equipment:CanGrant({foodItem},{self.rule.starterFood}),'Initial food does not fit in the shared inventory')
        a.equipment.data:AddStack(foodItem,self.rule.starterFood)
    end
end
function Model:ValidateSaved(prepared,world)
    local data=CS.ProjectY.Data.TownEconomyData.Prepared(prepared)
    if not data.Initialized then return end -- Explicit migration: old saves start upkeep at their current clock.
    local known={};for _,site in ipairs(world.sites) do if site.source and site.source.townId then known[site.id]=true end end
    for i=0,data.TownCount-1 do
        local town=data:GetTownAt(i);assert(known[town.SiteId],'Saved economy town no longer exists')
        assert(town.GoodCount==#self.commodities:All(),'Saved commodity catalog differs')
        for j=0,town.GoodCount-1 do local good=town:GetGoodAt(j);local row=assert(self.byItem[good.ItemId],'Unknown saved commodity')
            assert(good.BasePrice==row.basePrice and good.Stock<=self.rule.marketCapacity,'Invalid saved economic stock')
        end
        assert(town.Principal<=self.rule.investmentLimit,'Saved investment exceeds limit')
        if town.Principal>0 then
            assert(town.DueTick-town.StartTick>=self.rule.termDays*4 and town.DueTick-town.StartTick<=self.rule.termDays*4+1,'Saved investment term differs')
            assert(town.Payout<0 or town.Payout>=math.floor(town.Principal*(1-self.rule.maximumLossPercent/100)) and
                town.Payout<=math.floor(town.Principal*(1+self.rule.maximumGainPercent/100)),'Saved investment payout exceeds contract')
        end
    end
end
function Model:Needs()
    local a=self.adventure;local ids,food,wages,rows,seen={},{},{},{},{}
    local function add(actor,animal,leader)
        if not Life.Alive(actor) or seen[actor.Id] then return end;seen[actor.Id]=true
        local level=actor.Growth.Level;local size=1
        if animal then size=#a.config:GetTable('AnimalSpeciesTable'):Get(actor.AnimalSpeciesId).footprintQ end
        local need=(animal and self.rule.animalFoodBase*size or self.rule.foodBase)+(level-1)//self.rule.foodLevelStep
        local wage=(animal or leader) and 0 or self.rule.wageBase+self.rule.wagePerLevel*level
        ids[#ids+1]=actor.Id;food[#food+1]=need;wages[#wages+1]=wage
        rows[#rows+1]={actor=actor,food=need,wage=wage}
    end
    for i=0,CS.ProjectY.Data.PartyRoster.Count(a.data)-1 do local actor=CS.ProjectY.Data.PartyRoster.At(a.data,i)
        add(actor,actor.AnimalSpeciesId>0,CS.ProjectY.Data.PartyRoster.IsProtagonist(a.data,actor.Id))
        local animal=CS.ProjectY.Data.AnimalCompanionState.Bound(actor);if animal then add(animal,true,false) end
    end
    return ids,food,wages,rows
end
function Model:Advance(minutes)
    if not self.data.Initialized then return end
    local target=math.floor(minutes/360);if target<=self.data.LastTick then return end
    local a=self.adventure;local ids,food,wages=self:Needs();local closed={}
    for i=0,self.data.TownCount-1 do local town=self.data:GetTownAt(i)
        if not a.factions:ServiceAllowed(town.SiteId) then closed[#closed+1]=town.SiteId end
    end
    for tick=self.data.LastTick+1,target do self.data:Step(tick,a.data.Seed,closed,ids,food,wages,a.equipment.data,a.player) end
end
function Model:ApplyAttribute(actor,name,value)
    if name=='strength' or name=='speed' or name=='defense' then return math.max(0,math.floor(value*(1-self.data:Penalty(actor.Id)))) end
    return value
end
function Model:Tags(site)
    local profile=self.profiles[site];if not profile then return '' end
    local tags={}
    for _,tag in ipairs(profile.tags) do local good=self.commodities:Get(tag.commodityId);tags[#tags+1]=tag.rich and good.richTag or good.poorTag end
    tags[#tags+1]=profile.tradeAccess>=.5 and L.EconomyRoadGood or L.EconomyRoadPoor
    return table.concat(tags,L.EconomyTagSeparator)
end
function Model:Summary()
    local _,food,wages,rows=self:Needs();local dailyFood,dailyWages,hungry=0,0,0
    for i=1,#food do dailyFood=dailyFood+food[i];dailyWages=dailyWages+wages[i]
        local account=self.data:FindAccount(rows[i].actor.Id);if account and account.HungryDays>0 then hungry=hungry+1 end
    end
    return {food=self.data:Food(self.adventure.equipment.data),dailyFood=dailyFood,dailyWages=dailyWages,debt=self.data.TotalArrears,hungry=hungry,rows=rows}
end
function Model:BankSession(revision)
    local a=self.adventure;local site=self.data.ActiveBankSite
    if site==0 or a.data.Phase~='area' or a.data.Areas.ActiveSiteId~=site then return false,L.EconomyBankMissing end
    if revision and revision~=self.data.Revision then return false,L.EconomyStale end
    return a.areas:Interact(1,self.data.ActiveBankFacility)
end
function Model:OpenBank(facility)
    local a=self.adventure
    if a.data.Phase~='area' or self.data.ActiveBankSite~=0 or a.shop.data.IsOpen or a.narrative.data.DialogueOpen then return false,L.EconomyBankMissing end
    local site=a.data.Areas.ActiveSiteId;local definition=a.areas:ActiveLayout().facilities[facility]
    if not definition or definition.kind~='bank' or not self.data:FindTown(site) then return false,L.EconomyBankMissing end
    local ok,reason=a.areas:Interact(1,facility);if not ok then return false,reason end
    a.areas:Stop();self.data:OpenBank(site,facility);return true
end
function Model:CloseBank()
    self.data:CloseBank();if self.adventure.data.Phase=='area' then self.adventure.areas:CloseInteraction() end;return true
end
function Model:Command(command,id,revision,count)
    if command=='bank_close' then return self:CloseBank() end
    if command=='economy_pay_wages' then
        if self.adventure.data.Phase~='map' and self.adventure.data.Phase~='area' then return false,L.EconomyUnavailable end
        return failure(self.data:PayArrears(revision,self.adventure.player))
    end
    if command=='economy_buy' or command=='economy_sell' then
        local a=self.adventure;local stock=a.shop.data.Active
        if not stock or a.data.Phase~='area' or stock.SiteId~=a.data.Areas.ActiveSiteId then return false,L.EconomyUnavailable end
        local ok,reason=a.areas:Interact(2,stock.LocalNpcId);if not ok then return false,reason end
        return failure(self.data:Trade(stock.SiteId,id,count,command=='economy_buy',revision,a.equipment.data,a.player))
    end
    local ok,reason=self:BankSession(revision);if not ok then return false,reason end
    if command=='bank_invest' then return failure(self.data:Invest(id,revision,self.adventure.narrative.data.Minutes,self.adventure.player)) end
    if command=='bank_claim' then return failure(self.data:Claim(revision,self.adventure.player)) end
    error('Unknown economy command: '..command)
end
function Model:MarketRows(site,rows,allowed,reason)
    local town=self.data:FindTown(site);if not town then return end
    local a=self.adventure
    for i=0,town.GoodCount-1 do local good=town:GetGoodAt(i);local item=a.equipment.rules.items:Get(good.ItemId)
        for _,action in ipairs({{buy=true,count=1},{buy=true,count=10},{buy=false,count=10}}) do
            local count=action.buy and action.count or math.min(10,a.equipment.data:CountItem(good.ItemId))
            local total=self.data:Quote(site,good.ItemId,math.max(1,count),action.buy)
            local available=allowed and count>0 and (action.buy and good.Stock>=count and a.player.Coins>=total and a.equipment:CanGrant({good.ItemId},{count})
                or not action.buy and good.Stock+count<=self.rule.marketCapacity)
            rows[#rows+1]={id=good.ItemId,name=string.format(action.buy and L.EconomyBuyName or L.EconomySellName,item.name,count),
                body=string.format(L.EconomyTradeBody,total,good.Stock,a.equipment.data:CountItem(good.ItemId)),
                command=action.buy and 'economy_buy' or 'economy_sell',version=self.data.Revision,quantity=count,available=available,
                reason=allowed and '' or reason}
        end
    end
end
function Model:CaravanSite(party)
    local best,distance
    for site in pairs(self.profiles) do local location=self.adventure.sites[site];local d=Hex.Distance(party.Travel.Q,party.Travel.R,location.q,location.r)
        if not distance or d<distance or d==distance and site<best then best,distance=site,d end
    end
    return best
end
function Model:CaravanPrice(party,item,count,buy,default)
    if not self.byItem[item] then return default end
    local site=assert(self:CaravanSite(party),'Caravan has no town market')
    return math.floor(self.data:Quote(site,item,count,buy)/count)
end
return Model
