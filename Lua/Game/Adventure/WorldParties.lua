local Hex=require('Game.Map.HexGrid')
local Parties={};Parties.__index=Parties
function Parties.New(adventure)
    local self=setmetatable({adventure=adventure,data=CS.ProjectY.Data.WorldPartiesData.For(adventure.data),
        definitions=adventure.config:GetTable('WorldPartyTable'),rule=adventure.config:GetTable('WorldPartyRuleTable'):Get(1),prices={}},Parties)
    for _,row in ipairs(adventure.config:GetTable('WorldTradePriceTable'):All()) do
        assert(not self.prices[row.itemId],'Duplicate world trade price: itemId='..row.itemId);self.prices[row.itemId]=row.price
    end
    -- Every backpack item can be sold; validate coverage before any randomized cargo is generated.
    for _,item in ipairs(adventure.equipment.rules.items:All()) do
        assert(self.prices[item.id],'WorldTradePriceTable missing price: itemId='..item.id..' ('..item.name..')')
    end
    for _,row in ipairs(self.definitions:All()) do
        assert(row.kind=='caravan' or row.kind=='hostile','Unknown world party kind')
        adventure.config:GetTable('CombatEncounterTable'):Get(row.encounterId)
        if row.kind=='caravan' then adventure.shop.rules.templates:Get(row.shopTemplateId) end
    end
    self.inventory=require('Game.Equipment.InventoryModel').New(adventure.equipment,adventure.battle.stats)
    self.legends=require('Game.Adventure.LegendaryEncounters').New(self)
    return self
end
function Parties:Bind(map,sites)
    self.map=map;self.sites=sites;self.towns={};self.townRoutes={};self.paths=self.adventure.travel.paths
    self.adventure.factions:Bind(map,sites)
    self.lod=require('Game.Adventure.WorldLOD').New(self)
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
    return self:ApplyRoute(party,path)
end
function Parties:ApplyRoute(party,path)
    local qs,rs,costs={},{},{};local speed=self.definitions:Get(party.DefinitionId).speed
    for i=2,#path do qs[#qs+1]=path[i].q;rs[#rs+1]=path[i].r;costs[#costs+1]=self.adventure.travel:Cost(path[i-1],path[i])/speed end
    party.Travel:Plan(qs,rs,costs,0);return true
end
function Parties:TownRoute(site)
    local destinations={}
    local routes=self.townRoutes[site.id]
    if not routes then routes={};self.townRoutes[site.id]=routes end
    local ordered={};for _,other in ipairs(self.towns) do if other.id~=site.id and self.adventure.factions:ServiceAllowed(other.id) then ordered[#ordered+1]=other end end
    table.sort(ordered,function(a,b)return Hex.Distance(site.q,site.r,a.q,a.r)<Hex.Distance(site.q,site.r,b.q,b.r) end)
    for _,other in ipairs(ordered) do
        local path=routes[other.id]
        if path==nil then path=self:Path(self.map:GetCell(site.q,site.r),self.map:GetCell(other.q,other.r)) or false;routes[other.id]=path end
        if path then destinations[1]=other;return destinations,path end
    end
    return destinations
end
function Parties:Restock(party)
    local rule=self.definitions:Get(party.DefinitionId)
    local _,items,counts=self.adventure.shop.rules:Roll(rule.shopTemplateId,self.adventure.data.Seed,party.Id,
        party.DestinationSiteId>0 and party.DestinationSiteId or party.HomeSiteId,party.Id,party.Travel:Roll(2147483647))
    local kinds,widths,heights={},{},{}
    for i,id in ipairs(items) do local item=self.adventure.equipment.rules.items:Get(id)
        assert(self.prices[id],'Caravan item has no price: itemId='..id..' ('..item.name..'), shopTemplateId='..rule.shopTemplateId)
        kinds[i]=item.kind;widths[i]=item.width;heights[i]=item.height
    end
    party:SetCargo(rule.name..'的货物',items,counts,kinds,widths,heights)
end
function Parties:Initialize()
    local factions=self.adventure.factions
    factions:Initialize()
    if self.data.Initialized then
        for i=0,self.data.Count-1 do local party=self.data:GetAt(i)
            if party.FactionId==0 then
                local row=self.definitions:Get(party.DefinitionId);local policy=factions.rules.policies:Get(row.factionId)
                local home=party.HomeSiteId>0 and self.sites[party.HomeSiteId]
                if not home and policy.role~='wildlife' then
                    local candidate=factions:Home(row.factionId,party.Travel.Q,party.Travel.R)
                    local point=candidate and self.sites[candidate.SiteId]
                    if point and self:Path(self.map:GetCell(party.Travel.Q,party.Travel.R),self.map:GetCell(point.q,point.r)) then home=point;party:SetHomeSite(home.id) end
                end
                party:ConfigureFaction(row.factionId,home and home.q or party.Travel.Q,home and home.r or party.Travel.R,row.kind=='caravan' and 'caravan' or policy.role=='wildlife' and 'wildlife' or 'raider')
                if party.BattleSiteId>0 then
                    local area=CS.ProjectY.Data.FactionPersistence.Find(self.adventure.data.Areas,party.BattleSiteId)
                    if area and area.EncounterCount>0 then CS.ProjectY.Data.FactionPersistence.AdoptLegacyParty(area:GetEncounterAt(0),party) end
                end
                self.adventure.factions:PrepareRoster(party,row.encounterId)
                if party.Defeated then for j=0,party.MemberCount-1 do local actor=party:GetMemberAt(j);actor:Damage(actor.HP) end end
            elseif party.MemberCount>0 then
                -- Animal species were added after faction migration; update the saved roster in place.
                factions:PrepareRoster(party,self.definitions:Get(party.DefinitionId).encounterId)
            end
        end
        self:Spawn(true)
        self.data:CompleteFactionMigration();self.lod:Initialize();return
    end
    self:Spawn(false)
    self.data:Complete(self.adventure.narrative.data.Minutes);self.data:CompleteFactionMigration();self.lod:Initialize()
end
function Parties:Spawn(onlyMissingLegends)
    local factions=self.adventure.factions;local existing,used,wanted={},{},{}
    for i=0,self.data.Count-1 do local party=self.data:GetAt(i)
        existing[party.DefinitionId]=true;used[#used+1]={q=party.Travel.Q,r=party.Travel.R}
    end
    for _,row in ipairs(self.definitions:All()) do
        if row.count>0 and (not onlyMissingLegends or self.legends:Find(row.id) and not existing[row.id]) then wanted[#wanted+1]=row end
    end
    if #wanted==0 then return end
    local camp=assert(self.sites[1]);local candidates={}
    for _,cell in ipairs(self.map:GetCells()) do
        if not cell.waterLevel and not cell.buildingId and Hex.Distance(camp.q,camp.r,cell.q,cell.r)>=self.rule.spawnSafeRadius then candidates[#candidates+1]=cell end
    end
    table.sort(candidates,function(a,b)return a.q<b.q or a.q==b.q and a.r<b.r end)
    for _,row in ipairs(wanted) do
        local policy=factions.rules.policies:Get(row.factionId)
        local homes={}
        for i=0,factions.data.SiteCount-1 do local home=factions.data:GetSiteAt(i);if home.FactionId==row.factionId then homes[#homes+1]=home end end
        for n=1,row.count do
            if row.kind=='caravan' then
                if #self.towns>1 and n<=#self.towns then
                    local home=self.towns[n];local destinations,route=self:TownRoute(home)
                    if #destinations>0 then
                        local party=self.data:Add(row.id,home.q,home.r,home.id,(self.adventure.data.Seed ~ (row.id*7919+n*104729)) & 0xffffffff)
                        party:ConfigureFaction(row.factionId,home.q,home.r,'caravan');factions:PrepareRoster(party,row.encounterId)
                        party:SetDestination(destinations[1].id);self:Restock(party);assert(self:ApplyRoute(party,route))
                    end
                end
            elseif #homes>0 or policy.role=='wildlife' then
                local home=#homes>0 and self.sites[homes[(n-1)%#homes+1].SiteId]
                local selected
                local first=math.min(#candidates,1+math.floor((n-1)*#candidates/math.max(1,row.count)))
                if self.legends:Find(row.id) and #candidates>0 then first=1+((self.adventure.data.Seed ~ row.id*7919)%#candidates) end
                for offset=0,#candidates-1 do
                    local cell=candidates[(first+offset-1)%#candidates+1]
                    local clear=factions.rules:Suitable(row.factionId,self.map:GetRegion(cell.regionId).regionType) and
                        (not home or Hex.Distance(home.q,home.r,cell.q,cell.r)<=factions.rules.settings.roamRadius)
                    for _,other in ipairs(used) do if Hex.Distance(cell.q,cell.r,other.q,other.r)<2 then clear=false;break end end
                    if clear then
                        if home then clear=self:Path(self.map:GetCell(home.q,home.r),cell)~=nil end
                        for direction=1,6 do local q,r=Hex.Neighbor(cell.q,cell.r,direction);local nextCell=self.map:FindCell(q,r)
                            if clear and nextCell and self.adventure.travel:Cost(cell,nextCell) then selected=cell;break end
                        end
                    end
                    if selected then break end
                end
                if selected then
                    used[#used+1]=selected
                    local party=self.data:Add(row.id,selected.q,selected.r,home and home.id or 0,(self.adventure.data.Seed ~ (row.id*7919+n*104729)) & 0xffffffff)
                    party:ConfigureFaction(row.factionId,home and home.q or selected.q,home and home.r or selected.r,policy.role=='wildlife' and 'wildlife' or policy.role=='raider' and 'raider' or 'patrol')
                    factions:PrepareRoster(party,row.encounterId);self:Roam(party)
                end
            end
        end
    end
end
function Parties:Roam(party)
    local travel=party.Travel;local row=self.definitions:Get(party.DefinitionId)
    -- Local destinations bound path-search cost even on a hundred-thousand-cell world.
    for _=1,16 do
        local q=party.HomeQ+travel:Roll(row.roamRadius*2+1)-row.roamRadius-1
        local r=party.HomeR+travel:Roll(row.roamRadius*2+1)-row.roamRadius-1
        local cell=self.map:FindCell(q,r)
        if cell and not cell.waterLevel and not cell.buildingId and self.adventure.factions:CanRoam(party,cell) and Hex.Distance(travel.Q,travel.R,q,r)>0 and self:Plan(party,cell) then return end
    end
    local first=travel:Roll(6)
    for offset=0,5 do local q,r=Hex.Neighbor(travel.Q,travel.R,(first+offset-1)%6+1);local cell=self.map:FindCell(q,r)
        if cell and self.adventure.factions:CanRoam(party,cell) and self.adventure.travel:Cost(self.map:GetCell(travel.Q,travel.R),cell) then assert(self:Plan(party,cell));return end
    end
end
function Parties:TickParty(party,minute,minutes)
    if party.Defeated or party.BattleSiteId>0 or party.Role=='garrison' or party.Mission=='occupy' then return end
    if party.Mission=='escort_wait' then
        if self.adventure.data.Phase~='map' then return end
        party:SetMission('escort',0,party.DestinationSiteId,minute);party.Travel:SetPaused(false)
    end
    if party.Mission=='escort' then
        local destination=assert(self.sites[party.DestinationSiteId]);local travel=party.Travel
        if not travel.Active and (travel.Q~=destination.q or travel.R~=destination.r) then
            assert(self:Plan(party,self.map:GetCell(destination.q,destination.r)),'Escort destination lost its route')
        end
        if travel.Active then travel:AdvanceRoute(minutes or 1) end
        return
    end
    local row=self.definitions:Get(party.DefinitionId);local travel=party.Travel;local player=self.adventure.travel.data
    local budget=minutes or 1
    while budget>0 do
    local factions=self.adventure.factions
    if travel.Progress==0 then factions:Think(party,minute) end
    local chasing=party.Role~='caravan' and party.Mission~='raid' and self.adventure.data.Phase=='map' and minute>=party.SafeUntil and
        Hex.Distance(travel.Q,travel.R,player.Q,player.R)<=row.detectRadius and factions:Relation(0,party.FactionId)=='hostile' and
        #self.adventure.events:LivingParty()>0 and factions:Power(party)>=factions:PlayerPower()*factions.rules.settings.raidAdvantage and
        factions:CanRoam(party,self.map:GetCell(player.Q,player.R))
    if travel.Progress==0 then
        party:SetChasing(chasing)
        if chasing then self:Plan(party,self.map:GetCell(player.Q,player.R))
        elseif not travel.Active then
            if row.kind=='caravan' then
                local arrived=self.sites[party.DestinationSiteId];local destinations,route=self:TownRoute(arrived)
                if #destinations>0 then
                    if self.adventure.factions:ServiceAllowed(arrived.id) then self:Restock(party) end
                    party:SetDestination(destinations[1].id)
                    assert(self:ApplyRoute(party,route))
                end
            elseif party.Mission=='patrol' or party.Mission=='' then self:Roam(party) end
        end
    end
    if not travel.Active then break end
    local spent=travel:Step(budget);assert(spent>0,'World party failed to advance');budget=math.max(0,budget-spent)
    end
end
function Parties:AdvanceAnimalRetries(ticks,moving)
    if not moving or ticks<=0 then return end
    for i=0,self.data.Count-1 do local party=self.data:GetAt(i)
        if not party.Defeated and party.BattleSiteId==0 then
            for j=0,party.MemberCount-1 do local actor=party:GetMemberAt(j)
                if actor.HP>0 and actor.AnimalSpeciesId>0 and actor.AnimalOwnerId==0 then
                    for _=1,math.min(ticks,actor.TameRetryTurns) do actor:AdvanceTamingRound() end
                end
            end
        end
    end
end
function Parties:SyncClock(moving)
    if not self.data.Initialized then return end
    local narrative=self.adventure.narrative;local escort=narrative.townMissions and narrative.townMissions.escort
    local now=narrative.data.Minutes
    if escort and escort:HasActive() then
        -- Even camp waits must allow real contacts along a protected convoy's route.
        while self.data.Remainder+now-self.data.Clock>=1-1e-8 do
            local boundary=math.min(now,self.data.Clock+1-self.data.Remainder)
            local ticks=self.data:ElapsedTicks(boundary)
            self:AdvanceAnimalRetries(ticks,moving)
            if ticks>0 then self.lod:Advance(self.data.Clock-self.data.Remainder) end
            escort:Refresh()
        end
        self:AdvanceAnimalRetries(self.data:ElapsedTicks(now),moving);escort:Refresh();return
    end
    local ticks=self.data:ElapsedTicks(now)
    self:AdvanceAnimalRetries(ticks,moving)
    if ticks>0 then self.lod:Advance(self.data.Clock-self.data.Remainder) end
end
function Parties:Near(party)
    if self.adventure.water and self.adventure.water.data.Mode~='walk' then return false end
    local player=self.adventure.travel.data;local travel=party.Travel
    if player.Progress~=0 then return false end
    local q,r=travel.Q,travel.R
    if travel.Active and travel.Progress>=.5 then local nextCell=travel:GetStepAt(0);q,r=nextCell.Q,nextCell.R end
    local distance=Hex.Distance(player.Q,player.R,q,r)
    if distance>self.rule.contactRadius then return false end
    local first,last=self.map:GetCell(player.Q,player.R),self.map:GetCell(q,r)
    if self.rule.contactRadius==1 and distance==1 and not self.adventure.travel:Cost(first,last) then return false end
    local path=self:Path(first,last)
    return path~=nil and #path-1<=self.rule.contactRadius
end
function Parties:CheckContact()
    if self.adventure.data.Phase~='map' or self.data.IsOpen or self.adventure.narrative.data.DialogueOpen or #self.adventure.events:LivingParty()==0 then return false end
    for i=0,self.data.Count-1 do local party=self.data:GetAt(i);local row=self.definitions:Get(party.DefinitionId)
        if not party.Defeated and party.Role~='garrison' and party.Mission~='occupy' and (self.data.TargetId==party.Id or party.BattleSiteId==0 and self.adventure.factions:Relation(0,party.FactionId)=='hostile' and self.data.Clock>=party.SafeUntil) and self:Near(party) then
            self.adventure.travel.data:SetPaused(true);self.data:Open(party.Id)
            if self.legends:Find(party.DefinitionId) and party.BattleSiteId==0 then
                assert(self.adventure.narrative.dialogue:OpenWorld(party));self.data:Close()
            elseif self.adventure.factions:Relation(0,party.FactionId)=='hostile' then assert(self:Attack()) end
            return true
        end
    end
    return false
end
function Parties:Pursue(id)
    if self.adventure.narrative.data.DialogueOpen then return false,'请先结束当前对话' end
    if id>=1000000 then return self.adventure.travel:Visit(id-1000000) end
    local ok,reason=self.adventure.travel:Allowed();if not ok then return false,reason end
    local party=self.data:Find(id);if not party or party.Defeated then return false,'队伍已经离开' end
    if #self.adventure.events:LivingParty()==0 then return false,'没有能够行动的队员' end
    local previousTarget=self.data.TargetId
    self.data:Target(id);self.lod:Advance(self.adventure.narrative.data.Minutes)
    ok,reason=self.adventure.travel:Plan(self.map:GetCell(party.Travel.AnchorQ,party.Travel.AnchorR),0)
    if not ok then
        local previous=previousTarget>0 and self.data:Find(previousTarget)
        self.data:Target(previous and not previous.Defeated and previous.Id or 0)
        return false,reason
    end
    self:CheckContact();return true
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
    if self.adventure.narrative.data.DialogueOpen then return false,'请先在对话中选择行动' end
    if not self.data.IsOpen or self.adventure.data.Phase~='map' then return false,'请先追上这支队伍' end
    local party=assert(self.data:Find(self.data.ContactId));if not self:Near(party) then return false,'队伍已经不在附近' end
    local row=self.definitions:Get(party.DefinitionId)
    if party.BattleSiteId>0 and not self.adventure.factions.data:FindConflict(party.BattleSiteId) then
        self.adventure.factions:Aggress(party.FactionId)
        self.data:BeginBattle(party.Id,party.BattleSiteId)
        return self.adventure.travel:EnterBattle(self.sites[party.BattleSiteId],row.encounterId)
    end
    return self.adventure.factions.conflicts:Attack(party)
end
function Parties:Command(command,id,revision,inventoryRevision)
    if command=='world_pursue' then return self:Pursue(id) end
    if command=='world_close' then self.data:Close();return true end
    if not self.data.IsOpen or self.adventure.data.Phase~='map' then return false,'当前没有接触中的队伍' end
    local party=assert(self.data:Find(self.data.ContactId))
    if not self:Near(party) then return false,'请先追上商队' end
    if command=='world_attack' then return self:Attack() end
    if command=='world_join' then
        local conflict=self.adventure.factions.data:FindConflict(party.BattleSiteId)
        if not conflict or conflict.Phase~='active' then return false,'这里的战斗已经结束' end
        self.data:Close();return self.adventure.factions.conflicts:Enter(conflict)
    end
    if command=='world_trade' then
        if self.definitions:Get(party.DefinitionId).kind~='caravan' then return false,'这支队伍不进行交易' end
        if party.BattleSiteId>0 or self.adventure.factions:Relation(0,party.FactionId)=='hostile' then return false,'交战中的敌对队伍不能交易' end
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
    local handled,dropped=self.adventure.factions.conflicts:Settle(result)
    if handled then return dropped end
    local adventure=self.adventure;local dropped=0
    if result=='victory' then dropped=self.data:DropCargo(adventure.data.SiteId,adventure.data.Areas.Active,adventure.data.Areas.Active.CellIndex) end
    self.data:Settle(adventure.data.SiteId,result=='victory',adventure.narrative.data.Minutes+self.rule.retreatSafeMinutes)
    return dropped
end
function Parties:Snapshot()
    local rows={}
    for i=0,self.data.Count-1 do local party=self.data:GetAt(i)
        if not party.Defeated and party.Role~='garrison' and party.Mission~='occupy' and self.adventure.fog:Visible(party.Travel.Q,party.Travel.R) then
            local row=self.definitions:Get(party.DefinitionId);local travel=party.Travel
            local x,y,z=self.map:GetCellWorldPosition(travel.Q,travel.R)
            if travel.Active then local nextCell=travel:GetStepAt(0);local nx,ny,nz=self.map:GetCellWorldPosition(nextCell.Q,nextCell.R);local t=travel.Progress
                x=x+(nx-x)*t;y=y+(ny-y)*t;z=z+(nz-z)*t
            end
            local target=party.DestinationSiteId>0 and self.sites[party.DestinationSiteId]
            local faction=self.adventure.config:GetTable('FactionTable'):Get(party.FactionId)
            local relation=self.adventure.factions:Relation(0,party.FactionId)
            local escorting=party.Mission=='escort' or party.Mission=='escort_wait'
            rows[#rows+1]={id=party.Id,definitionId=row.id,name=(escorting and '护送委托 · ' or '')..row.name..' · '..faction.name..'（'..({allied='合作',hostile='敌对',neutral='中立'})[relation]..'）',kind=row.kind,x=x,y=y,z=z,
                status=party.BattleSiteId>0 and '交战中 · 点击加入' or party.Mission=='escort_wait' and '等待护卫出城' or party.Chasing and '正在追击' or party.Mission=='raid' and '进攻据点' or party.Mission=='intercept' and '截击敌队' or party.Mission=='return' and '返回据点休整' or target and ('前往 '..target.name) or '领地巡逻',modelPath=row.modelPath}
        end
    end
    for i=0,self.adventure.factions.data.SiteCount-1 do local state=self.adventure.factions.data:GetSiteAt(i)
        if not state.IsTown and self.adventure.fog:Known(self.sites[state.SiteId].q,self.sites[state.SiteId].r) then local site=self.sites[state.SiteId];local policy=self.adventure.factions.rules.policies:Get(state.FactionId)
            rows[#rows+1]={id=1000000+site.id,definitionId=0,name=site.name,kind='stronghold',x=site.x,y=site.y,z=site.z,status=self.adventure.factions:Describe(site.id),modelPath=policy.modelPath}
        end
    end
    return {playerModelPath=self.rule.playerModelPath,rows=rows,targetId=self.data.TargetId}
end
function Parties:ContactSnapshot()
    local party=assert(self.data:Find(self.data.ContactId));local row=self.definitions:Get(party.DefinitionId);local rows={}
    if not self.data.Trading then
        local escort=self.adventure.narrative.townMissions.escort
        local mission=escort:ForParty(party.Id)
        if party.BattleSiteId>0 and self.adventure.factions.data:FindConflict(party.BattleSiteId) then
            rows[#rows+1]={name=mission and '加入战斗，保护商队' or '参与这场战斗',body=mission and '帮助正在护送的商队抵御袭击。' or '根据各方关系自动判定盟军和敌人，独立第三方显示黄色。',command=mission and 'town_mission_join' or 'world_join',id=mission and mission.Id or 0,available=true}
        elseif row.kind=='caravan' then
            if mission then rows[#rows+1]={name='随商队同行',body='小队随商队一起移动，遇敌时自动进入护送战斗。',command='town_mission_attach',id=mission.Id,available=true} end
            rows[#rows+1]={name='与商队交易',body='购买随行货物，或出售共享背包中的物品。',command='world_trade',id=0,available=true}
        end
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
