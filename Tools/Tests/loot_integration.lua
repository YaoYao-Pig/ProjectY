local registry=require('Core.SystemRegistry')(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('PlayerModel',require('Game.PlayerModelSystem'),{'Config'})
registry:Register('Map',require('Game.Map.MapSystem'),{'Config'})
registry:Register('MapArea',require('Game.MapArea.MapAreaSystem'),{'Config'})
registry:Register('Battle',require('Game.Battle.BattleSystem'),{'Config'})
registry:Register('Equipment',require('Game.Equipment.EquipmentSystem'),{'Config'})
registry:Register('Growth',require('Game.Progression.GrowthSystem'),{'Battle'})
registry:Register('AdventureEvents',require('Game.Adventure.EventSystem'),{'Battle','PlayerModel','Growth','Equipment'})
registry:Register('Adventure',require('Game.Adventure.AdventureSystem'),{'Map','MapArea','AdventureEvents','Equipment'})
local messages={}
local helpers=assert(loadfile('Tools/Tests/loot_helpers.lua'))()
local function test(name,body)body();messages[#messages+1]='PASS '..name end
local function contents(row)
    local result={};for i=0,row.ItemCount-1 do result[#result+1]=row:GetItemIdAt(i)..':'..row:GetCountAt(i) end
    return table.concat(result,',')
end
local ok,err=xpcall(function()
    registry:Start()
    local adventure=registry:Get('Adventure');adventure:Start(412)
    local areas,eq,battle,data=adventure.areas,adventure.equipment,adventure.battle,adventure.data
    local forest;for _,site in ipairs(adventure.sites) do if site.areaConfigId==20 then forest=site;break end end
    assert(forest and adventure:Visit(forest.id))
    local area,state=areas:ActiveLayout(),data.Areas.Active
    test('forest chest placement is persistent and contents never reroll on reentry',function()
        assert(state.LootCount==#area.containerPlans and state.LootInitialized)
        local snapshot={}
        for i=0,state.LootCount-1 do local row=state:GetLootAt(i)
            assert(row.ContentsReady and not row.Looted)
            local reachable=false;local physical=eq.worldLoot:Physical(row)
            for j=0,physical.CellCount-1 do for _,side in ipairs(area:Neighbors(area.cells[physical:GetCellAt(j)])) do
                if area:FindPath(area.entryIndex,side.index) then reachable=true end
            end end
            assert(reachable,'Container needs a reachable interaction side')
            snapshot[i+1]={cell=row.CellIndex,contents=contents(row)}
        end
        assert(areas:Leave());assert(adventure:Visit(forest.id));assert(data.Areas.Active==state and state.LootCount==#snapshot)
        for i,row in ipairs(snapshot) do assert(state:GetLootAt(i-1).CellIndex==row.cell and contents(state:GetLootAt(i-1))==row.contents) end
    end)
    test('full inventory can search; hidden or unfittable items never grant; each drop commits once',function()
        local cell=state.CellIndex
        state:AddLoot(cell,100,'容量检查战利品',{40,31},{1,4},true)
        local row=state:GetLootAt(state.LootCount-1);local beforeContents=contents(row)
        while eq:CanGrant({53},{1}) do assert(eq:Grant(53,1)) end
        local revision,ammo=eq.data.Revision,eq.data:CountItem(31)
        assert(eq:Loot(areas,row.Id));local session=eq.worldLoot.session;local item=session:GetAt(0)
        assert(not eq.worldLoot:Take(areas,item.Key,0,0,false))
        session:Advance(item.Key,2,1);assert(item.Revealed)
        assert(not eq.worldLoot:Take(areas,item.Key,0,0,false))
        assert(not row.Looted and eq.data.Revision==revision and eq.data:CountItem(31)==ammo and contents(row)==beforeContents)
        eq.data:Clear();eq.data.Grid:Configure(12,10)
        assert(adventure:TakeLoot(item.Key,3,2,true))
        local place=eq.data.Grid:GetAt(0);assert(place.X==3 and place.Y==2 and place.Rotated)
        assert(not row.Looted and row:GetCountAt(0)==0 and row:GetCountAt(1)==4)
        revision=eq.data.Revision;assert(not adventure:TakeLoot(item.Key,0,0,false));assert(eq.data.Revision==revision)
        adventure:CloseLoot();assert(adventure:AreaCommand('area_loot',row.Id))
        helpers.TakeAll(eq,areas,function(...) return adventure:TakeLoot(...) end)
        assert(row.Looted and eq.data:CountItem(31)==4 and eq.data.WeaponCount==1)
        adventure:CloseLoot()
        revision=eq.data.Revision;assert(not adventure:AreaCommand('area_loot',row.Id));assert(eq.data.Revision==revision)
    end)
    test('physical duplicates search separately and interrupted searches survive closing and reentry',function()
        state:AddLoot(state.CellIndex,100,'独立装备',{40},{2},true)
        local container=state:GetLootAt(state.LootCount-1)
        assert(eq:Loot(areas,container.Id));local session=eq.worldLoot.session
        assert(session.Count==2);local first,second=session:GetAt(0),session:GetAt(1)
        assert(first.Key~=second.Key and first.Count==1 and second.Count==1)
        session:Advance(first.Key,.4,1);assert(not first.Revealed and first.Progress>.39)
        adventure:CloseLoot();assert(areas:Leave());assert(adventure:Visit(forest.id))
        assert(eq:Loot(areas,container.Id));assert(session:GetAt(0).Progress>.39 and not session:GetAt(1).Revealed)
        session:Advance(first.Key,.61,1);assert(first.Revealed and not second.Revealed)
        assert(adventure:TakeLoot(first.Key,8,0,false));assert(container:GetCountAt(0)==1 and not container.Looted)
        adventure:CloseLoot()
    end)
    test('same-item stacks merge at their existing position even with a full backpack',function()
        state:AddLoot(state.CellIndex,100,'堆叠补给',{31},{7},true)
        local container=state:GetLootAt(state.LootCount-1);assert(eq:Loot(areas,container.Id))
        local session=eq.worldLoot.session;local item=session:GetAt(0);session:Advance(item.Key,2,1)
        while eq:CanGrant({53},{1}) do assert(eq:Grant(53,1)) end
        local stack=eq.data.Grid:Find('s31');local count,placements=eq.data:CountItem(31),eq.data.Grid.Count
        assert(adventure:TakeLoot(item.Key,stack.X,stack.Y,false))
        assert(eq.data:CountItem(31)==count+7 and eq.data.Grid.Count==placements and container.Looted)
        adventure:CloseLoot()
    end)
    test('empty chests open successfully without mutating the backpack',function()
        local fixture=CS.ProjectY.Data.MapAreaStateData(77,#area.cells,area.entryIndex)
        fixture:AddLoot(area.entryIndex,10,'空箱检查',{},{},false);fixture:CompleteLootInitialization()
        fixture:DeployMembers({data:GetPartyAt(0).Id},{area.entryIndex})
        local isolated={data={Active=fixture},ActiveLayout=function()return area end}
        local revision=eq.data.Revision;assert(eq:Loot(isolated,1))
        assert(fixture:GetLootAt(0).Looted and eq.data.Revision==revision)
        eq.worldLoot.session:Close()
    end)
    adventure:Start(412)
    local site;for _,row in ipairs(adventure.sites) do if row.eventId==1 then site=row;break end end
    assert(site and adventure:Visit(site.id));assert(adventure:Choose(1))
    area,state=areas:ActiveLayout(),data.Areas.Active
    test('old event battles now own a traversable persistent battlefield',function()
        assert(data.Phase=='battle' and data.AreaEncounterId==1 and area.areaType==areas.battlefieldType)
        assert(battle.board.area==area and state.MemberCount==data.PartyCount and state.LootCount==0)
    end)
    state:AddLoot(area.entryIndex,100,'旧战利品',{31},{1},true)
    local dead,expected={},{}
    for _,actor in ipairs(battle:Units()) do if actor.Team==2 then
        dead[#dead+1]=actor
        local rule=eq.worldLoot.rules.enemies[actor.TemplateId]
        local ids,counts=eq.worldLoot.rules:Roll(rule.lootTableId,(area.seed ~ actor.Id*104729 ~ rule.seedSalt) & 0xffffffff)
        if #ids>0 then
            local result={};for i,id in ipairs(ids) do result[#result+1]=id..':'..counts[i] end
            expected[area:Find(actor.Q,actor.R).index]=table.concat(result,',')
        end
        actor:Damage(1000000)
    end end
    test('settlement rolls each dead enemy once at its exact cell and leaves the party exploring',function()
        local coins=Services.Player.Coins;assert(battle:CheckWinner());adventure:SettleBattle()
        assert(data.Phase=='area' and data.Battle.UnitCount==0 and state.EncounterCount==1 and state:GetEncounterAt(0).Defeated)
        assert(Services.Player.Coins>coins and state.LootCount>0)
        local count=1;for _ in pairs(expected) do count=count+1 end;assert(state.LootCount==count)
        for i=1,state.LootCount-1 do local row=state:GetLootAt(i);assert(contents(row)==expected[row.CellIndex]) end
        assert(eq.worldLoot.session.Active and eq.worldLoot.session.Pending and eq.worldLoot.session.Battle)
        assert(not eq.worldLoot.session:Contains(1))
        for i=1,state.LootCount-1 do assert(eq.worldLoot.session:Contains(state:GetLootAt(i).Id)) end
        for _,actor in ipairs(dead) do assert(actor.DropResolved) end
        assert(eq:GenerateEnemyDrops(areas,{Units=function()return dead end,stats=battle.stats})==0 and state.LootCount==count)
        adventure:CloseLoot()
    end)
    test('post-battle movement, nearby pickup and returning to the event site do not repeat combat or rewards',function()
        local row=state:GetLootAt(0);local coins,count=Services.Player.Coins,state.LootCount
        eq.data:Clear();eq.data.Grid:Configure(12,10)
        local moved,reason=areas:MoveToIndex(row.CellIndex);assert(moved,reason)
        for _=1,150 do if state.RemainingSteps==0 then break end;areas:Tick(area.moveStepSeconds+.001) end
        assert(state.CellIndex==row.CellIndex and state.RemainingSteps==0)
        assert(adventure:AreaCommand('area_loot',row.Id));helpers.TakeAll(eq,areas,function(...) return adventure:TakeLoot(...) end);adventure:CloseLoot();assert(row.Looted)
        assert(areas:Leave());assert(adventure:Visit(site.id));assert(data.Areas.Active==state and state.LootCount==count)
        assert(not areas:FindEncounter() and Services.Player.Coins==coins and state:GetLootAt(0).Looted)
    end)
    test('living and tamed enemies never generate kill drops',function()
        local live=CS.ProjectY.Data.CombatActorData(99001,4);live:Deploy(2,0,0)
        local rider=data:GetPartyAt(1);local animal=CS.ProjectY.Data.CombatActorData(99002,201);animal:InitializeAnimal(1,1);animal:Deploy(2,0,0);rider:TameAndRide(animal,0)
        assert(eq:GenerateEnemyDrops(areas,{Units=function()return {live,animal} end,stats=battle.stats})==0)
        assert(not live.DropResolved and not animal.DropResolved)
    end)
end,debug.traceback)
registry:Shutdown();if not ok then error(err,0) end
return 'Loot integration: '..#messages..' checks passed\n'..table.concat(messages,'\n')
