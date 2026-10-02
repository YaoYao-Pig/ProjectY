-- 独立 Edit Mode 数据：真实地点、逐格移动、搜刮、改装、区域故事和设施交易。
-- 此数据检查不创建 UI；只替换暂停查询，所有角色/库存/地点仍使用真实 Services。
local services={Adventure=Services.Adventure,Player=Services.Player,UI={IsWorldPaused=false},
    ReadConfig=function(_,name) return Services:ReadConfig(name) end,LogError=function(_,message) Services:LogError(message) end}
local registry=require('Core.SystemRegistry')(services)
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
local function test(name,fn) fn();messages[#messages+1]='PASS '..name end
local ok,err=xpcall(function()
    registry:Start()
    local adventure,areas,equipment=registry:Get('Adventure'),registry:Get('MapArea'),registry:Get('Equipment')
    local data=Services.Adventure;adventure:Start();Services.Player:AddCoins(100)
    local dungeon,town
    for _,s in ipairs(adventure.sites) do
        if s.areaConfigId==1 and not dungeon then dungeon=s end
        if s.areaConfigId==2 and not town then town=s end
    end
    test('generated world exposes usable dungeon and town entrances',function()
        assert(dungeon and town and adventure:Visit(dungeon.id));assert(data.Phase=='area')
        assert(data.Areas.Active.LootCount==3 and data.JournalCount>data.PartyCount)
        assert(adventure:Snapshot().sites[dungeon.id].kind=='dungeon')
    end)
    local layout,state=areas:ActiveLayout(),data.Areas.Active
    local function walk(goal,allowStory,radius)
        local blocked=0
        for _=1,400 do
            if state.CellIndex==goal then return end
            if radius then
                local remaining=layout:FindPath(state.CellIndex,goal)
                if remaining and #remaining<=radius then return end
            end
            if data.Phase=='event' then assert(allowStory);return end
            assert(data.Phase=='area','Unexpected phase while walking: '..data.Phase)
            if state.RemainingSteps==0 then
                local occupied=areas:EnemyOccupancy(layout,state)
                for i=0,state.NpcCount-1 do occupied[state:GetNpcAt(i).CellIndex]=true end
                local allowed=function(cell) return not occupied[cell.index] end
                local path=layout:FindPath(state.CellIndex,goal,allowed)
                if radius then
                    for _,cell in ipairs(layout:Neighbors(layout.cells[goal])) do
                        local candidate=layout:FindPath(state.CellIndex,cell.index,allowed)
                        if candidate and (not path or #candidate<#path) then path=candidate end
                    end
                end
                if path then
                    blocked=0
                    local nextCell
                    for i=1,math.min(2,#path) do if state:IsKnown(path[i]) then nextCell=path[i] else break end end
                    assert(nextCell,'Route has no visible next step')
                    local moved,reason=areas:MoveToIndex(nextCell);assert(moved,reason)
                else
                    blocked=blocked+1
                    local raw=layout:FindPath(state.CellIndex,goal)
                    assert(blocked<=24,'NPCs still block route after waiting: start='..state.CellIndex..' goal='..goal..' static='..tostring(raw and #raw))
                end
            end
            areas:Tick(layout.moveStepSeconds+.01);adventure:Tick()
        end
        error('Exploration route did not finish')
    end
    test('walking to supply chest grants actual components and permits a real installation',function()
        local chest=state:GetLootAt(0);walk(chest.CellIndex,false)
        assert(adventure:AreaCommand('area_loot',chest.Id))
        assert(loadfile('Tools/Tests/loot_helpers.lua'))().TakeAll(equipment,areas,function(...) return adventure:TakeLoot(...) end)
        adventure:CloseLoot();assert(chest.Looted and equipment.data:CountItem(13)==1)
        assert(adventure:AreaCommand('area_loot',chest.Id));assert(equipment.worldLoot.session.Remaining==0);adventure:CloseLoot()
        assert(equipment.data:CountItem(13)==1)
        local weapon,socket
        for i=0,equipment.data.WeaponCount-1 do
            local candidate=equipment.data:GetWeaponAt(i);local def=equipment.rules.weapons:Get(candidate.ItemId)
            for _,id in ipairs(def.socketIds) do if equipment.rules.sockets:Get(id).kind=='thruster' then weapon,socket=candidate,id end end
        end
        assert(weapon and equipment:Command('attach',1,weapon.Id,socket,13));assert(weapon:GetRune(socket)==13)
        assert(equipment.data:CountItem(13)==0)
        local found=false;for _,row in ipairs(adventure.growth.chronicle:Rows()) do if row.label=='获得' and row.body:find(equipment.rules.items:Get(13).name,1,true) then found=true end end;assert(found)
    end)
    test('normal exploration triggers a story and resumes the exact same map and positions',function()
        local Hex=require('Game.Map.HexGrid');local entry=layout.cells[layout.entryIndex];local goal
        for _,cell in ipairs(layout.cells) do
            if not cell.blocked and Hex.Distance(cell.q,cell.r,entry.q,entry.r)>=7 then
                local path=layout:FindPath(state.CellIndex,cell.index)
                if path and #path<18 then goal=cell.index;break end
            end
        end
        assert(goal);walk(goal,true);assert(data.Phase=='event' and data.EventId==6 and data.EventReturnPhase=='area')
        local position=state.CellIndex;local key=data.StoryTriggerKey
        assert(adventure:Snapshot().area and state.RemainingSteps==0)
        assert(adventure:Choose(7));assert(data:HasStoryTrigger(key));assert(not adventure:Choose(7))
        assert(adventure:ReturnToMap());assert(data.Phase=='area' and state.CellIndex==position and areas:ActiveLayout()==layout)
        adventure:Tick();assert(data.Phase=='area')
        assert(areas:Leave() and adventure:Visit(dungeon.id));assert(areas:ActiveLayout()==layout and state:GetLootAt(0).Looted)
    end)
    test('smithy interaction opens trade, guards insufficient coins and grants the chosen rune once',function()
        assert(areas:Leave() and adventure:Visit(town.id));layout,state=areas:ActiveLayout(),data.Areas.Active
        local smithy;for _,f in ipairs(layout.facilities) do if f.configId==2 then smithy=f;break end end;assert(smithy)
        walk(smithy.entryIndex,false,smithy.interactionRadius);local position=state.CellIndex
        assert(adventure:AreaCommand('area_interact',1,smithy.id))
        assert(data.Phase=='event' and data.EventId==8)
        local before=Services.Player.Coins;assert(Services.Player:TrySpendCoins(before))
        local amount=equipment.data:CountItem(12);assert(not adventure:Choose(12));assert(equipment.data:CountItem(12)==amount and data.Phase=='event')
        Services.Player:AddCoins(before);assert(adventure:Choose(12));assert(not adventure:Choose(12))
        assert(equipment.data:CountItem(12)==amount+1 and Services.Player.Coins==before-20)
        assert(adventure:ReturnToMap());assert(data.Phase=='area' and state.CellIndex==position)
        assert(adventure:AreaCommand('area_interact',1,smithy.id));assert(data.EventId==8)
        assert(adventure:Choose(3) and adventure:ReturnToMap())
    end)
end,debug.traceback)
registry:Shutdown();if not ok then error(err,0) end
return 'Exploration story integration: '..#messages..' checks passed\n'..table.concat(messages,'\n')
