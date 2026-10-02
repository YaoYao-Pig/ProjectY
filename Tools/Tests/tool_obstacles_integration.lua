-- Real C# state and production rules in an isolated Edit Mode LuaEnv.
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
registry:Register('UI',require('UI.UISystem'),{'Config'})
local messages={}
local ok,err=xpcall(function()
    registry:Start()
    local adventure=registry:Get('Adventure');adventure:Start()
    local areaSystem,equipment=adventure.areas,adventure.equipment
    local site;for _,candidate in ipairs(adventure.sites)do if candidate.areaConfigId==1 then site=candidate;break end end
    assert(site and adventure:Visit(site.id))
    if adventure.data.Phase=='event' then assert(adventure:Choose(103));assert(adventure:ReturnToMap()) end
    local obstacles=adventure.obstacles;local state=areaSystem.data.Active;local layout=areaSystem:ActiveLayout()
    assert(obstacles.data:Count(site.id)==2)
    local all={};for i=1,#layout.cells do all[i]=i end;state:Reveal(all)
    local actor=adventure.data:GetPartyAt(0)
    local function approach(row)
        local blocked=obstacles:BlockedCells();local occupied=areaSystem:EnemyOccupancy(layout,state)
        for j=0,row.CellCount-1 do for _,cell in ipairs(layout:Neighbors(layout.cells[row:GetCellAt(j)]))do
            if not blocked[cell.index] and not occupied[cell.index] then state:DeployMembers({actor.Id},{cell.index});return end
        end end
        error('No adjacent fixture cell')
    end
    local stone,dirt
    for i=1,obstacles.data:Count(site.id) do local row=obstacles.data:Get(site.id,i);local tag=obstacles.rules:Get(row.RuleId).toolTag
        if tag=='pickaxe' then stone=row elseif tag=='shovel' then dirt=row end
    end
    -- Clicking a visible blocker walks to its border and starts the existing event flow.
    local moved,reason=obstacles:MoveTo(stone:GetCellAt(0));assert(moved,reason)
    for _=1,500 do
        if adventure.data.Phase=='event' then break end
        areaSystem:Tick(layout.moveStepSeconds);obstacles:TryRequested()
    end
    assert(adventure.data.Phase=='event' and obstacles.data.CurrentId==stone.Id)
    local adapter={BattleHUDRevision=1,LastError=''}
    function adapter:SetStoryOpen(value)self.open=value end
    local ui=registry:Get('UI');local panel=ui:Open('StoryEvent',{demo=adapter})
    assert(panel.view.Title.text=='坍塌的石块' and panel.view.Description.text:find('镐子'))
    ui:Close('StoryEvent');assert(not adapter.open and not Services.UI.IsWorldPaused)
    local snapshot=adventure:Snapshot();local display=CS.ProjectY.Samples.MapAreaViewData.ReadState(snapshot)
    assert(display.Obstacles.Length==#snapshot.area.obstacles and display.Obstacles.Length>0)
    for i,row in ipairs(snapshot.area.obstacles)do
        assert(display.Obstacles[i-1].Id==row.id and display.Obstacles[i-1].Cells.Length==#row.cells)
        for j,index in ipairs(row.cells)do assert(display.Obstacles[i-1].Cells[j-1]==index-1)end
    end
    assert(adventure:Choose(103));assert(adventure:ReturnToMap());assert(not stone.Cleared)
    local board=areaSystem:BattleWindow(stone:GetCellAt(0),8)
    local cell=layout.cells[stone:GetCellAt(0)];assert(board.externalOccupied[require('Game.Map.HexGrid').Key(cell.q,cell.r)])
    messages[#messages+1]='PASS click-to-approach StoryEvent UI, C# display snapshot and shared battle obstacle occupancy'
    approach(stone);assert(obstacles:Begin(stone.Id));assert(not adventure.events:CanChoose(101))
    local before=state.WorldRound;assert(adventure:Choose(102));assert(stone.Cleared and stone.Attempts==1)
    assert(state.WorldRound==before+3 and not adventure:Choose(102));assert(adventure:ReturnToMap())
    assert(not obstacles.data:IsBlocked(site.id,stone:GetCellAt(0)))
    messages[#messages+1]='PASS manual clearing, exploration time, duplicate choice rejection and navigation unblocking'
    -- Shovel remains an obstacle tool; wooden containers now use ContainerCombat.
    assert(equipment:Grant(73,1));local shovel
    for i=0,equipment.data.WeaponCount-1 do local w=equipment.data:GetWeaponAt(i);if w.ItemId==73 then shovel=w end end
    approach(dirt);assert(obstacles:Begin(dirt.Id));assert(not adventure.events:CanChoose(101));assert(adventure:Choose(103))
    assert(adventure:ReturnToMap())
    assert(equipment:Command('equip',actor.Id,shovel.Id,0,0))
    assert(obstacles:Worker('shovel'))
    messages[#messages+1]='PASS carried versus equipped two-handed shovel qualification'
    approach(dirt);local count=state.LootCount;local reward={}
    for i=0,dirt.ItemCount-1 do reward[#reward+1]=dirt:GetItemAt(i)..':'..dirt:GetCountAt(i) end
    assert(obstacles:Begin(dirt.Id));assert(adventure:Choose(102));assert(adventure:ReturnToMap())
    assert(dirt.Cleared and state.LootCount==count+1)
    assert(not obstacles:Begin(dirt.Id),'Resolved dirt must not produce another reward')
    local stored=state:GetLootAt(count);assert(stored.ItemCount==dirt.ItemCount)
    for i=0,stored.ItemCount-1 do assert(stored:GetItemIdAt(i)==dirt:GetItemAt(i) and stored:GetCountAt(i)==dirt:GetCountAt(i))end
    messages[#messages+1]='PASS pre-rolled buried contents materialize once and remain in a real loot container'
    actor:Damage(actor.HP);assert(not obstacles:Worker('shovel'),'A fallen equipped worker must not qualify');actor:Restore()
    local rule=obstacles.rules:Get(dirt.RuleId)
    local retry=CS.ProjectY.Data.MapObstacleData();retry:Add(1,rule.id,false,{1},{40},{1});retry:CompleteInitialization(1)
    retry:Begin(1,1);retry:Resolve(false);assert(not retry:Get(1,1).Cleared and retry:Get(1,1).Attempts==1)
    local hp=actor.HP;assert(retry:Exert(actor,hp+99)==hp-1 and actor.HP==1);actor:Restore()
    local lootCount=state.LootCount
    messages[#messages+1]='PASS fallen-worker exclusion, nonlethal exertion and failed-attempt persistence'
    assert(areaSystem:Leave());assert(adventure:Visit(site.id));assert(obstacles.data:Count(site.id)==2)
    assert(stone.Cleared and dirt.Cleared)
    assert(areaSystem.data.Active.LootCount==lootCount)
    adventure:Start();assert(obstacles.data:Count(site.id)==0)
    messages[#messages+1]='PASS retry state, revisit persistence and new-expedition reset'
end,debug.traceback)
registry:Shutdown();if not ok then error(err,0) end
return table.concat(messages,'\n')
