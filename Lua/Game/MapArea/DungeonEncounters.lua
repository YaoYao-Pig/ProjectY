-- 只生成静态部署计划；敌人 HP/位置归 MapAreaEncounterData 中的 CombatActorData。
local Hex=require('Game.Map.HexGrid')
local Random=require('Game.Map.SeededRandom')
local Encounters={}
function Encounters.Plan(area, rule, encounter)
    assert(area.areaType==1, 'Only dungeon areas support encounters')
    assert(#encounter.enemyIds>0 and #encounter.enemyIds<=4, 'Dungeon encounter needs 1..4 enemies')
    local entry=area.cells[area.entryIndex];local candidates={}
    for _,room in ipairs(area.rooms) do
        local center=area.cells[room.center]
        if room.id~=entry.roomId and Hex.Distance(entry.q,entry.r,center.q,center.r)>area.visionRadius+rule.alertRange then
            candidates[#candidates+1]=room
        end
    end
    assert(#candidates>=rule.groupCount, 'Not enough safe rooms for configured dungeon encounters')
    local random=Random((area.seed ~ rule.seedSalt) & 0xffffffff)
    local plans,occupied={},{}
    for id=1,rule.groupCount do
        local room=table.remove(candidates,random:Integer(1,#candidates))
        local center=area.cells[room.center]
        local queue,seen,head={center},{[center.index]=true},1
        local cells={}
        while head<=#queue and #cells<#encounter.enemyIds do
            local cell=queue[head];head=head+1
            if not cell.blocked and not occupied[cell.index] then cells[#cells+1]=cell;occupied[cell.index]=true end
            for _,other in ipairs(area:Neighbors(cell)) do
                if other.roomId==room.id and not seen[other.index] then seen[other.index]=true;queue[#queue+1]=other end
            end
        end
        assert(#cells==#encounter.enemyIds, 'Dungeon enemy group does not fit in its room')
        plans[#plans+1]={id=id,encounterId=encounter.id,cells=cells}
    end
    return plans
end
return Encounters
