-- Edit Mode 独立 LuaEnv：真实 C# 状态与现有命令贯通探索、原地战斗、结算和重进。
local Registry=require('Core.SystemRegistry')
local registry=Registry(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('PlayerModel',require('Game.PlayerModelSystem'),{'Config'})
registry:Register('Map',require('Game.Map.MapSystem'),{'Config'})
registry:Register('MapArea',require('Game.MapArea.MapAreaSystem'),{'Config'})
registry:Register('Battle',require('Game.Battle.BattleSystem'),{'Config'})
registry:Register('Equipment',require('Game.Equipment.EquipmentSystem'),{'Config'})
registry:Register('AdventureEvents',require('Game.Adventure.EventSystem'),{'Battle','PlayerModel'})
registry:Register('Adventure',require('Game.Adventure.AdventureSystem'),{'Map','MapArea','AdventureEvents','Equipment'})
local messages={}
local function test(name,run) run();messages[#messages+1]='PASS '..name end
local ok,err=xpcall(function()
    registry:Start()
    local adventure,areas,battle=registry:Get('Adventure'),registry:Get('MapArea'),registry:Get('Battle')
    local data,player=Services.Adventure,Services.Player
    adventure:Start()
    local site
    for _,candidate in ipairs(adventure.sites) do if candidate.areaConfigId==1 then site=candidate;break end end
    assert(site and adventure:Visit(site.id))
    local area,state=areas:ActiveLayout(),data.Areas.Active
    local function view()
        local snapshot=adventure:Snapshot();snapshot.error=''
        return CS.ProjectY.Samples.AdventureViewData.Read(snapshot)
    end
    test('enemy groups are persistent real actors, hidden by fog and separate from the safe entrance',function()
        assert(state.EncounterCount==3 and state.EncountersInitialized and state.MemberCount==4)
        local occupied={}
        for i=0,state.EncounterCount-1 do
            local group=state:GetEncounterAt(i);assert(group.EnemyCount==3 and not group.Defeated)
            for j=0,group.EnemyCount-1 do
                local actor=group:GetEnemyAt(j);local cell=assert(area:Find(actor.Q,actor.R))
                assert(actor.HP==actor.MaxHP and not cell.blocked and not occupied[cell.index]);occupied[cell.index]=true
            end
        end
        assert(view().Area.Enemies.Length==0 and not areas:FindEncounter())
    end)
    test('exploration movement triggers combat without relocating either side or rebuilding terrain',function()
        local enemy=state:GetEncounterAt(0):GetEnemyAt(0)
        local goal=area:Find(enemy.Q,enemy.R)
        local original={}
        for _=1,600 do
            if data.Phase=='battle' then break end
            if state.RemainingSteps==0 then
                local path=assert(area:FindPath(state.CellIndex,goal.index))
                local destination
                for i=1,math.min(3,#path) do
                    if state:IsKnown(path[i]) then destination=path[i] else break end
                end
                assert(destination,'No visible progress toward test encounter')
                local moved,why=areas:MoveToIndex(destination);assert(moved,why)
            end
            areas:Tick(area.moveStepSeconds+.01)
            original={};for i=0,state.MemberCount-1 do original[state:GetMemberIdAt(i)]=state:GetMemberCellAt(i) end
            adventure:Tick()
        end
        assert(data.Phase=='battle' and state.RemainingSteps==0 and data.AreaEncounterId>0)
        assert(battle.board.area==area and areas:ActiveLayout()==area)
        for id,index in pairs(original) do
            local actor=battle:FindUnit(id);assert(actor.Q==area.cells[index].q and actor.R==area.cells[index].r)
        end
        assert(not areas:MoveToIndex(area.entryIndex))
        local snapshot=view();assert(snapshot.Area~=nil and snapshot.Units.Length==7 and snapshot.Reachable.Length>0)
        for i=0,snapshot.Units.Length-1 do assert(snapshot.Units[i].CellIndex>=0 and snapshot.Units[i].Appearance.Parts.Length>=2) end
    end)
    local group=state:GetEncounterAt(data.AreaEncounterId-1)
    local initialCoins=player.Coins
    test('same combat commands win in the dungeon and settlement continues exploration exactly once',function()
        local Hex=require('Game.Map.HexGrid')
        local function attack()
            local actor=battle:Active()
            for _,skillId in ipairs(battle.stats:Template(actor).skillIds) do
                if battle.skills:Get(skillId).target=='enemy' then for _,target in ipairs(battle:Units()) do
                    if battle:CanUseSkill(skillId,target.Id) then return adventure:BattleCommand('skill',skillId,target.Id) end
                end end
            end
            return false
        end
        for _=1,240 do
            if data.Phase~='battle' then break end
            local actor=battle:Active()
            if actor.Team==2 then assert(adventure:BattleCommand('ai'))
            else
                if not attack() then
                    local best,score
                    for _,cell in ipairs(battle:Reachable()) do for _,target in ipairs(battle:Units()) do
                        if target.Team==2 and target.HP>0 then
                            local value=Hex.Distance(cell.q,cell.r,target.Q,target.R)
                            if not score or value<score then best,score=cell,value end
                        end
                    end end
                    if best then assert(adventure:BattleCommand('move_cell',best.index)) end
                    attack()
                end
                if data.Phase=='battle' then
                    if battle:CanUseSkill(4,actor.Id) then assert(adventure:BattleCommand('skill',4,actor.Id)) end
                    assert(adventure:BattleCommand('end_turn'))
                end
            end
        end
        assert(data.Phase=='area' and group.Defeated,'Dungeon strategy did not win: '..data.Phase)
        assert(player.Coins==initialCoins+35 and data.Battle.UnitCount==0 and battle.board==nil)
        assert(view().Area.ClearedEncounters==1)
        assert(not adventure:BattleCommand('end_turn') and player.Coins==initialCoins+35)
        local positions={};for i=0,state.MemberCount-1 do positions[i+1]=state:GetMemberCellAt(i) end
        assert(areas:Leave() and adventure:Visit(site.id))
        assert(areas:ActiveLayout()==area and group.Defeated and state.EncounterCount==3)
        for i=0,state.MemberCount-1 do assert(state:GetMemberCellAt(i)==positions[i+1]) end
    end)
    local function prepareNext()
        local nextGroup
        for i=0,state.EncounterCount-1 do if not state:GetEncounterAt(i).Defeated then nextGroup=state:GetEncounterAt(i);break end end
        local enemy=nextGroup:GetEnemyAt(0);local cell=area:Find(enemy.Q,enemy.R)
        local occupied=areas:EnemyOccupancy(area,state)
        local ids={};for i=0,data.PartyCount-1 do local actor=data:GetPartyAt(i);if actor.HP>0 then ids[#ids+1]=actor.Id end end
        local positions=require('Game.MapArea.SquadMovement').Deploy(area,cell.index,#ids,function(next) return not occupied[next.index] end)
        state:DeployMembers(ids,positions);areas:RevealSquad(area,state);adventure:Tick()
        assert(data.Phase=='battle');return state:GetEncounterAt(data.AreaEncounterId-1)
    end
    test('round limit retreats to map, preserves enemy wounds and redeploys at entrance on re-entry',function()
        local nextGroup=prepareNext();local actor=nextGroup:GetEnemyAt(0);actor:Damage(2);local hp=actor.HP
        data.Battle:Finish('draw');adventure:SettleBattle()
        assert(data.Phase=='map' and data.Areas.ActiveSiteId==0 and data.AreaEncounterId==0 and player.Coins==initialCoins+35)
        assert(view().Area==nil and adventure:Visit(site.id))
        assert(actor.HP==hp and not nextGroup.Defeated and state.CellIndex==area.entryIndex)
    end)
    test('party wipe retreats without rewards; a new expedition resets enemy groups',function()
        prepareNext()
        for i=0,data.PartyCount-1 do data:GetPartyAt(i):Damage(1000000) end
        assert(battle:CheckWinner());adventure:SettleBattle()
        assert(data.Phase=='map' and data.Areas.ActiveSiteId==0 and player.Coins==initialCoins+35)
        assert(not adventure:Visit(site.id) and view().Area==nil)
        adventure:Start();assert(adventure:Visit(site.id))
        local fresh=data.Areas.Active;assert(fresh.EncounterCount==3)
        for i=0,fresh.EncounterCount-1 do
            local encounter=fresh:GetEncounterAt(i);assert(not encounter.Defeated)
            for j=0,encounter.EnemyCount-1 do local enemy=encounter:GetEnemyAt(j);assert(enemy.HP==enemy.MaxHP) end
        end
    end)
end,debug.traceback)
registry:Shutdown()
if not ok then error(err,0) end
return 'Area battle integration: '..#messages..' checks passed\n'..table.concat(messages,'\n')
