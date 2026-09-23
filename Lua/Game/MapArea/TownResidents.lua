-- 城镇巡游规则无持久 Lua 状态；占格、巡游游标和计时全部写入 C# MapAreaStateData。
local Residents={}
function Residents.Tick(area,state,dt)
    if #area.npcs==0 then return end
    local occupied={}
    for i=0,state.NpcCount-1 do local npc=state:GetNpcAt(i);occupied[npc.CellIndex]=npc.Id end
    for _,definition in ipairs(area.npcs) do
        local npc=state:GetNpcAt(definition.id-1)
        if #definition.route>0 and not (state.InteractionKind==2 and state.InteractionId==npc.Id)
            and npc:Due(dt,definition.stepSeconds) then
            local allowed=function(cell)
                return (not occupied[cell.index] or occupied[cell.index]==npc.Id) and not state:IsSquadReserved(cell.index)
            end
            -- 迎面遇人时寻找前方少量路点，从空余侧街绕行；每次仍只走一个相邻格。
            for offset=1,math.min(4,#definition.route) do
                local nextCursor=(npc.PatrolCursor+offset-1)%#definition.route+1
                local target=definition.route[nextCursor]
                if target~=npc.CellIndex and allowed(area.cells[target]) then
                    local path=area:FindPath(npc.CellIndex,target,allowed)
                    if path and #path>0 then
                        local nextIndex=path[1]
                        occupied[npc.CellIndex]=nil;occupied[nextIndex]=npc.Id
                        local arrived=nextIndex==target
                        state:MoveNpc(npc.Id,nextIndex,arrived and nextCursor or npc.PatrolCursor,
                            arrived and nextCursor==#definition.route and definition.idleSeconds or 0)
                        break
                    end
                end
            end
        end
    end
end
return Residents
