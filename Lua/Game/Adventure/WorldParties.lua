local Hex=require('Game.Map.HexGrid')
local Parties={};Parties.__index=Parties
function Parties.New(adventure)
    local self=setmetatable({adventure=adventure,data=CS.ProjectY.Data.WorldPartiesData.For(adventure.data),
        definitions=adventure.config:GetTable('WorldPartyTable'),rule=adventure.config:GetTable('WorldPartyRuleTable'):Get(1),prices={}},Parties)
    for _,row in ipairs(adventure.config:GetTable('WorldTradePriceTable'):All()) do
        assert(not self.prices[row.itemId],'Duplicate world trade price');self.prices[row.itemId]=row.price
    end
    for _,row in ipairs(self.definitions:All()) do
        assert(row.kind=='caravan' or row.kind=='hostile','Unknown world party kind')
        adventure.config:GetTable('CombatEncounterTable'):Get(row.encounterId)
        if row.kind=='caravan' then adventure.shop.rules.templates:Get(row.shopTemplateId) end
    end
    self.inventory=require('Game.Equipment.InventoryModel').New(adventure.equipment,adventure.battle.stats)
    return self
end
function Parties:Bind(map,sites)
    self.map=map;self.sites=sites;self.towns={};self.townRoutes={};self.paths=self.adventure.travel.paths
    for _,site in ipairs(sites) do
        if site.areaConfigId and self.adventure.areas.generator.definitions:Get(site.areaConfigId).areaType==self.adventure.areas.townType then
            self.towns[#self.towns+1]=site
        end
    end
end
function Parties:Path(a,b)
    return self.paths:FindPath(a,b,function(x,y)return self.adventure.travel:Cost(x,y)end)
end
function Parties:Plan(party,target)
    local path=self:Path(self.map:GetCell(party.Travel.AnchorQ,party.Travel.AnchorR),target)
    if not path then return false end
    local qs,rs,costs={},{},{};local speed=self.definitions:Get(party.DefinitionId).speed
    for i=2,#path do qs[#qs+1]=path[i].q;rs[#rs+1]=path[i].r;costs[#costs+1]=self.adventure.travel:Cost(path[i-1],path[i])/speed end
    party.Travel:Plan(qs,rs,costs,0);return true
end
function Parties:TownRoute(site)
    if self.townRoutes[site.id] then return self.townRoutes[site.id] end
    local destinations={}
    local ordered={};for _,other in ipairs(self.towns) do if other.id~=site.id then ordered[#ordered+1]=other end end
    table.sort(ordered,function(a,b)return Hex.Distance(site.q,site.r,a.q,a.r)<Hex.Distance(site.q,site.r,b.q,b.r) end)
    for _,other in ipairs(ordered) do
        if self:Path(self.map:GetCell(site.q,site.r),self.map:GetCell(other.q,other.r)) then destinations[#destinations+1]=other;break end
    end
    self.townRoutes[site.id]=destinations;return destinations
end
function Parties:Restock(party)
    local rule=self.definitions:Get(party.DefinitionId)
    local _,items,counts=self.adventure.shop.rules:Roll(rule.shopTemplateId,self.adventure.data.Seed,party.Id,
        party.DestinationSiteId>0 and party.DestinationSiteId or party.HomeSiteId,party.Id,party.Travel:Roll(2147483647))
    local kinds,widths,heights={},{},{}
    for i,id in ipairs(items) do local item=self.adventure.equipment.rules.items:Get(id)
        assert(self.prices[id],'Caravan item has no price');kinds[i]=item.kind;widths[i]=item.width;heights[i]=item.height
    end
    party:SetCargo(rule.name..'的货物',items,counts,kinds,widths,heights)
end
function Parties:Initialize()
    if self.data.Initialized then return end
    local camp=assert(self.sites[1]);local used={};local candidates={}
    for _,cell in ipairs(self.map:GetCells()) do
        if not cell.waterLevel and not cell.buildingId and Hex.Distance(camp.q,camp.r,cell.q,cell.r)>=self.rule.spawnSafeRadius then
            candidates[#candidates+1]=cell
        end
    end
    table.sort(candidates,function(a,b)
        local da,db=Hex.Distance(camp.q,camp.r,a.q,a.r),Hex.Distance(camp.q,camp.r,b.q,b.r)
        return da<db or da==db and (a.q<b.q or a.q==b.q and a.r<b.r)
    end)
    for _,row in ipairs(self.definitions:All()) do
        for n=1,row.count do
            if row.kind=='caravan' then
                if #self.towns>1 and n<=#self.towns then
                    local home=self.towns[n];local destinations=self:TownRoute(home)
                    if #destinations>0 then
                        local party=self.data:Add(row.id,home.q,home.r,home.id,(self.adventure.data.Seed ~ (row.id*7919+n*104729)) & 0xffffffff)
                        party:SetDestination(destinations[1].id);self:Restock(party);assert(self:Plan(party,self.map:GetCell(destinations[1].q,destinations[1].r)))
                    end
                end
            else
                local selected
                -- Spread the first parties around the starting area and later parties across the land.
                local first=math.min(#candidates,1+math.floor((n-1)*#candidates/math.max(1,row.count)))
                for offset=0,#candidates-1 do
                    local cell=candidates[(first+offset-1)%#candidates+1];local clear=true
                    for _,other in ipairs(used) do if Hex.Distance(cell.q,cell.r,other.q,other.r)<4 then clear=false;break end end
                    if clear then
                        for direction=1,6 do local q,r=Hex.Neighbor(cell.q,cell.r,direction);local nextCell=self.map:FindCell(q,r)
                            if nextCell and self.adventure.travel:Cost(cell,nextCell) then selected=cell;break end
                        end
                    end
                    if selected then break end
                end
                if selected then
                    used[#used+1]=selected
                    local party=self.data:Add(row.id,selected.q,selected.r,0,(self.adventure.data.Seed ~ (row.id*7919+n*104729)) & 0xffffffff)
                    self:Roam(party)
                end
            end
        end
    end
    self.data:Complete(self.adventure.narrative.data.Minutes)
end
function Parties:Roam(party)
    local travel=party.Travel;local row=self.definitions:Get(party.DefinitionId)
    -- Local destinations bound path-search cost even on a hundred-thousand-cell world.
    for _=1,16 do
        local q=travel.Q+travel:Roll(row.roamRadius*2+1)-row.roamRadius-1
        local r=travel.R+travel:Roll(row.roamRadius*2+1)-row.roamRadius-1
        local cell=self.map:FindCell(q,r)
        if cell and not cell.waterLevel and not cell.buildingId and Hex.Distance(travel.Q,travel.R,q,r)>0 and self:Plan(party,cell) then return end
    end
    local first=travel:Roll(6)
    for offset=0,5 do local q,r=Hex.Neighbor(travel.Q,travel.R,(first+offset-1)%6+1);local cell=self.map:FindCell(q,r)
        if cell and self.adventure.travel:Cost(self.map:GetCell(travel.Q,travel.R),cell) then assert(self:Plan(party,cell));return end
    end
end
function Parties:TickParty(party,minute)
    if party.Defeated or party.BattleSiteId>0 then return end
    local row=self.definitions:Get(party.DefinitionId);local travel=party.Travel;local player=self.adventure.travel.data
    local budget=1
    while budget>0 do
    local chasing=row.kind=='hostile' and self.adventure.data.Phase=='map' and minute>=party.SafeUntil and
        #self.adventure.events:LivingParty()>0 and Hex.Distance(travel.Q,travel.R,player.Q,player.R)<=row.detectRadius
    if travel.Progress==0 then
        party:SetChasing(chasing)
        if chasing then self:Plan(party,self.map:GetCell(player.Q,player.R))
        elseif not travel.Active then
            if row.kind=='caravan' then
                local arrived=self.sites[party.DestinationSiteId];local destinations=self:TownRoute(arrived)
                assert(#destinations>0,'Caravan route lost its return connection')
                self:Restock(party);party:SetDestination(destinations[1].id)
                assert(self:Plan(party,self.map:GetCell(destinations[1].q,destinations[1].r)))
            else self:Roam(party) end
        end
    end
    if not travel.Active then break end
    local spent=travel:Step(budget);assert(spent>0,'World party failed to advance');budget=math.max(0,budget-spent)
    end
end
function Parties:SyncClock()
    if not self.data.Initialized then return end
    local ticks=self.data:ElapsedTicks(self.adventure.narrative.data.Minutes)
    for tick=1,ticks do
        local minute=self.data.Clock-self.data.Remainder-ticks+tick
        for i=0,self.data.Count-1 do self:TickParty(self.data:GetAt(i),minute) end
    end
end
function Parties:Near(party)
    local player=self.adventure.travel.data;local travel=party.Travel
    if player.Progress~=0 then return false end
    local q,r=travel.Q,travel.R
    if travel.Active and travel.Progress>=.5 then local nextCell=travel:GetStepAt(0);q,r=nextCell.Q,nextCell.R end
    local distance=Hex.Distance(player.Q,player.R,q,r)
    if distance>self.rule.contactRadius then return false end
    local path=self:Path(self.map:GetCell(player.Q,player.R),self.map:GetCell(q,r))
    return path~=nil and #path-1<=self.rule.contactRadius
end
function Parties:CheckContact()
    if self.adventure.data.Phase~='map' or self.data.IsOpen or #self.adventure.events:LivingParty()==0 then return false end
    for i=0,self.data.Count-1 do local party=self.data:GetAt(i);local row=self.definitions:Get(party.DefinitionId)
        if not party.Defeated and (self.data.TargetId==party.Id or row.kind=='hostile' and self.data.Clock>=party.SafeUntil) and self:Near(party) then
            self.adventure.travel.data:SetPaused(true);self.data:Open(party.Id)
            if row.kind=='hostile' then assert(self:Attack()) end
            return true
        end
    end
    return false
end
function Parties:Pursue(id)
    local ok,reason=self.adventure.travel:Allowed();if not ok then return false,reason end
    local party=self.data:Find(id);if not party or party.Defeated then return false,'队伍已经离开' end
    if #self.adventure.events:LivingParty()==0 then return false,'没有能够行动的队员' end
    ok,reason=self.adventure.travel:Plan(self.map:GetCell(party.Travel.AnchorQ,party.Travel.AnchorR),0)
    if not ok then return false,reason end
    self.data:Target(id);self:CheckContact();return true
end
function Parties:ReplanPursuit()
    if self.data.TargetId==0 then return end
    local party=assert(self.data:Find(self.data.TargetId));local player=self.adventure.travel.data
    if not party.Defeated and player.Progress==0 then
        local ok,reason=self.adventure.travel:Plan(self.map:GetCell(party.Travel.AnchorQ,party.Travel.AnchorR),0)
        if not ok then self.data:Target(0);player:SetPaused(true);player:Report(reason) end
    end
end
function Parties:Attack()
    if not self.data.IsOpen or self.adventure.data.Phase~='map' then return false,'请先追上这支队伍' end
    local party=assert(self.data:Find(self.data.ContactId));if not self:Near(party) then return false,'队伍已经不在附近' end
    local row=self.definitions:Get(party.DefinitionId)
    if party.BattleSiteId==0 then
        local site=self.adventure.travel:CreateStop({eventId=0,encounterId=row.encounterId})
        self.data:BeginBattle(party.Id,site.id)
    else self.data:BeginBattle(party.Id,party.BattleSiteId) end
    return self.adventure.travel:EnterBattle(self.sites[party.BattleSiteId],row.encounterId)
end
function Parties:Command(command,id,revision,inventoryRevision)
    if command=='world_pursue' then return self:Pursue(id) end
    if command=='world_close' then self.data:Close();return true end
    if not self.data.IsOpen or self.adventure.data.Phase~='map' then return false,'当前没有接触中的队伍' end
    local party=assert(self.data:Find(self.data.ContactId))
    if not self:Near(party) then return false,'请先追上商队' end
    if command=='world_attack' then return self:Attack() end
    if command=='world_trade' then
        if self.definitions:Get(party.DefinitionId).kind~='caravan' then return false,'这支队伍不进行交易' end
        self.data:Trade();return true
    end
    local equipment=self.adventure.equipment.data;local reason
    if command=='world_buy' then
        if id<1 or id>party.CargoCount then return false,'无效商品' end
        local item=party:GetCargoAt(id-1);local definition=self.adventure.equipment.rules.items:Get(item.ItemId);local ammo,capacity,rounds=0,0,0
        if definition.kind=='magazine' then local mag=self.adventure.equipment.rules.magazines:Get(item.ItemId);ammo,capacity,rounds=mag.ammoItemId,mag.capacity,mag.spawnRounds end
        reason=self.data:Buy(id-1,revision,assert(self.prices[item.ItemId]),equipment,self.adventure.player,ammo,capacity,rounds)
    elseif command=='world_sell' then
        if inventoryRevision~=equipment.Revision or id<1 or id>equipment.Grid.Count then return false,'背包已变化，请重新选择' end
        local place=equipment.Grid:GetAt(id-1);local price=math.floor(assert(self.prices[place.ItemId])*self.rule.sellMultiplier)
        reason=self.data:Sell(id-1,revision,inventoryRevision,price,equipment,self.adventure.player)
    else error('Unknown world party command: '..command) end
    return reason=='',reason
end
function Parties:Settle(result)
    local adventure=self.adventure;local dropped=0
    if result=='victory' then dropped=self.data:DropCargo(adventure.data.SiteId,adventure.data.Areas.Active,adventure.data.Areas.Active.CellIndex) end
    self.data:Settle(adventure.data.SiteId,result=='victory',adventure.narrative.data.Minutes+self.rule.retreatSafeMinutes)
    return dropped
end
function Parties:Snapshot()
    local rows={}
    for i=0,self.data.Count-1 do local party=self.data:GetAt(i)
        if not party.Defeated then
            local row=self.definitions:Get(party.DefinitionId);local travel=party.Travel
            local x,y,z=self.map:GetCellWorldPosition(travel.Q,travel.R)
            if travel.Active then local nextCell=travel:GetStepAt(0);local nx,ny,nz=self.map:GetCellWorldPosition(nextCell.Q,nextCell.R);local t=travel.Progress
                x=x+(nx-x)*t;y=y+(ny-y)*t;z=z+(nz-z)*t
            end
            local target=party.DestinationSiteId>0 and self.sites[party.DestinationSiteId]
            rows[#rows+1]={id=party.Id,definitionId=row.id,name=row.name,kind=row.kind,x=x,y=y,z=z,
                status=party.Chasing and '正在追击' or target and ('前往 '..target.name) or '游荡中',modelPath=row.modelPath}
        end
    end
    return {playerModelPath=self.rule.playerModelPath,rows=rows,targetId=self.data.TargetId}
end
function Parties:ContactSnapshot()
    local party=assert(self.data:Find(self.data.ContactId));local row=self.definitions:Get(party.DefinitionId);local rows={}
    if not self.data.Trading then
        if row.kind=='caravan' then rows[#rows+1]={name='与商队交易',body='购买随行货物，或出售共享背包中的物品。',command='world_trade',id=0,available=true} end
        rows[#rows+1]={name='攻击这支队伍',body='进入战斗；胜利后可搜刮剩余货物。',command='world_attack',id=0,available=true}
    else
        for i=0,party.CargoCount-1 do local item=party:GetCargoAt(i)
            if item.Count>0 then local definition=self.adventure.equipment.rules.items:Get(item.ItemId);local price=assert(self.prices[item.ItemId])
                rows[#rows+1]={name='购买 · '..definition.name,body=price..' 金币 / 件  |  剩余 '..item.Count,
                    command='world_buy',id=i+1,available=self.adventure.player.Coins>=price}
            end
        end
        local equipment=self.adventure.equipment
        local inventory=self.inventory:Rows(self.adventure.data:GetPartyAt(0).Id);local byKey={}
        for _,item in ipairs(inventory) do byKey[item.key]=item end
        for i=0,equipment.data.Grid.Count-1 do local place=equipment.data.Grid:GetAt(i);local item=assert(byKey[place.Key]);local price=math.floor(assert(self.prices[item.itemId])*self.rule.sellMultiplier)
            rows[#rows+1]={name='出售 · '..item.name..' ×'..item.count,body='出售这一堆 / 件，获得 '..price*item.count..' 金币',command='world_sell',id=i+1,available=true}
        end
    end
    return {name=row.name,rows=rows,version=self.data.Revision,coins=self.adventure.player.Coins,inventoryRevision=self.adventure.equipment.data.Revision,
        caption=self.data.Trading and '随行货物 · 抵达城镇后补货 · 出售保留装备状态' or '已追上队伍 · 请选择行动'}
end
return Parties
