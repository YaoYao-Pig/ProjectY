-- Test-only manual search/drop driver. Every attempted placement uses the production transaction.
local Helpers={}
function Helpers.TakeAll(equipment,areas,take)
    local session=equipment.worldLoot.session
    for i=0,session.Count-1 do
        local entry=session:GetAt(i)
        if entry.Count>0 then
            session:Advance(entry.Key,2,1)
            local function drop(x,y,rotated)
                if take then return take(entry.Key,x,y,rotated) end
                return equipment.worldLoot:Take(areas,entry.Key,x,y,rotated)
            end
            local stack=equipment.data.Grid:Find('s'..entry.ItemId);local done=false
            if stack then done=drop(stack.X,stack.Y,false) end
            for rotation=0,1 do if not done then
                for y=0,equipment.data.Grid.Height-1 do if not done then
                    for x=0,equipment.data.Grid.Width-1 do if drop(x,y,rotation==1) then done=true;break end end
                end end
            end end
            assert(done,'Test inventory has no room for loot '..entry.ItemId)
        end
    end
end
return Helpers
