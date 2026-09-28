local Random=require('Game.Map.SeededRandom')
local Encounters={}
function Encounters.Plan(area,rule,config)
    local random=Random((area.seed ~ rule.seedSalt) & 0xffffffff)
    local rooms={};for _,room in ipairs(area.rooms) do rooms[#rooms+1]=room end
    local plans,occupied={},{}
    local animals=require('Game.Animals.AnimalRules').New(config)
    for _,spawn in ipairs(config:GetTable('MapAreaForestSpawnTable'):All()) do if spawn.areaId==area.configId then
        assert(spawn.minCount<=spawn.maxCount,'Invalid forest spawn count')
        if random:Integer(1,100)<=spawn.chance then
            local encounter=config:GetTable('CombatEncounterTable'):Get(spawn.encounterId)
            for _=1,random:Integer(spawn.minCount,spawn.maxCount) do
                assert(#rooms>0,'Forest spawn budget exceeds clearing count')
                local room=table.remove(rooms,random:Integer(1,#rooms));local center=area.cells[room.center]
                local cells,queue,seen,head={},{center},{[center.index]=true},1
                while head<=#queue and #cells<#encounter.enemyIds do
                    local cell=queue[head];head=head+1
                    local actor={TemplateId=encounter.enemyIds[#cells+1],Q=cell.q,R=cell.r}
                    if animals:CanPlace(actor,area,cell.q,cell.r,occupied) then
                        cells[#cells+1]=cell;animals:Occupy(actor,area,occupied)
                    end
                    for _,other in ipairs(area:Neighbors(cell)) do
                        if other.roomId==room.id and not seen[other.index] then seen[other.index]=true;queue[#queue+1]=other end
                    end
                end
                assert(#cells==#encounter.enemyIds,'Forest clearing cannot fit encounter')
                plans[#plans+1]={id=#plans+1,encounterId=encounter.id,cells=cells,
                    team=random:Integer(1,100)<=spawn.neutralChance and 0 or 2}
            end
        end
    end end
    return plans
end
return Encounters
