local Hex=require('Game.Map.HexGrid')
local Body={}
function Body.New(config)
    local result={}
    for _,row in ipairs(config:GetTable('CombatBodyTable'):All()) do
        assert(not result[row.unitId],'Duplicate combat body')
        assert(#row.footprintQ>0 and #row.footprintQ==#row.footprintR,'Combat body footprint arrays differ')
        local cells={};local reached={['0:0']=true}
        for i,q in ipairs(row.footprintQ) do local key=Hex.Key(q,row.footprintR[i]);assert(not cells[key],'Duplicate combat body cell');cells[key]=true end
        assert(cells['0:0'],'Combat body must contain its anchor')
        for _=1,#row.footprintQ do for i,q in ipairs(row.footprintQ) do
            local r=row.footprintR[i]
            for d=1,6 do local nq,nr=Hex.Neighbor(q,r,d);if reached[Hex.Key(nq,nr)] then reached[Hex.Key(q,r)]=true end end
        end end
        for key in pairs(cells) do assert(reached[key],'Combat body must be connected') end
        result[row.unitId]=row
    end
    return result
end
-- The original preferred deployment remains first; larger bodies find the nearest valid anchor.
function Body.Deploy(area,encounter,shapes)
    local occupied,enemies={},{}
    for i,unitId in ipairs(encounter.enemyIds) do
        local wantedQ,wantedR=encounter.radius,1-i;local candidates={}
        for _,cell in ipairs(area.cells) do if not cell.blocked and cell.q>0 then candidates[#candidates+1]=cell end end
        table.sort(candidates,function(a,b)
            local da,db=Hex.Distance(a.q,a.r,wantedQ,wantedR),Hex.Distance(b.q,b.r,wantedQ,wantedR)
            return da<db or da==db and a.index<b.index
        end)
        for _,cell in ipairs(candidates) do
            local actor={TemplateId=unitId,Q=cell.q,R=cell.r}
            if shapes:CanPlace(actor,area,cell.q,cell.r,occupied) then
                shapes:Occupy(actor,area,occupied);enemies[i]=cell;break
            end
        end
        assert(enemies[i],'Battlefield cannot fit configured enemy footprint: '..unitId)
    end
    return enemies
end
return Body
