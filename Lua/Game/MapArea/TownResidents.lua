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
            local moved=false
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
                        moved=true
                        break
                    end
                end
            end
            -- 紧凑街巷里的迎面排队不能只等待对方的格子空出来。编号较大的居民
            -- 主动侧让到有出口的邻格；保留巡游游标，下次沿原路线继续，不传送穿人。
            if not moved then
                local current=area.cells[npc.CellIndex];local shouldYield=false
                for _,cell in ipairs(area:Neighbors(current)) do
                    local other=occupied[cell.index]
                    if other and other<npc.Id then shouldYield=true;break end
                end
                local best,bestExits
                if shouldYield then for _,cell in ipairs(area:Neighbors(current)) do if allowed(cell) then
                    local exits=0
                    for _,neighbor in ipairs(area:Neighbors(cell)) do if allowed(neighbor) and neighbor.index~=current.index then exits=exits+1 end end
                    if exits>0 and (not bestExits or exits>bestExits) then best,bestExits=cell,exits end
                end end end
                if best then
                    occupied[npc.CellIndex]=nil;occupied[best.index]=npc.Id
                    state:MoveNpc(npc.Id,best.index,npc.PatrolCursor,0)
                end
            end
        end
    end
end
-- 只在生成时创建不可变的出生位置与巡游路线；运行时计时和占格仍归 C#。
function Residents.Populate(area,row,config,doors)
    local npcTemplates=config:GetTable('MapAreaTownNpcTable')
    local occupied={}
    local function addNpc(templateId,index,route)
        assert(not occupied[index],'NPC spawn overlap');occupied[index]=true
        local template=npcTemplates:Get(templateId)
        area.npcs[#area.npcs+1]={id=#area.npcs+1,templateId=templateId,spawnIndex=index,route=route,stepSeconds=template.stepSeconds,idleSeconds=template.idleSeconds}
    end
    for _,site in ipairs(area.facilities) do
        local door=area.cells[site.entryIndex];local found
        for _,cell in ipairs(area:Neighbors(door)) do
            if not occupied[cell.index] and cell.index~=area.entryIndex and cell.index~=site.approachIndex
                and cell.interiorId==door.interiorId then found=cell;break end
        end
        assert(found,'No service NPC space');addNpc(site.npcTemplateId,found.index,{})
    end
    for i=1,row.residentCount do
        local start=doors[(i-1)%#doors+1];local target=doors[(i+3)%#doors+1]
        local spawn
        for _,cell in ipairs(area:Neighbors(start)) do if not occupied[cell.index] and cell.index~=area.entryIndex then spawn=cell;break end end
        assert(spawn,'No resident spawn space')
        local out=assert(area:FindPath(spawn.index,target.index));local back=assert(area:FindPath(target.index,spawn.index))
        local route={};for _,index in ipairs(out) do route[#route+1]=index end;for _,index in ipairs(back) do route[#route+1]=index end
        addNpc(row.residentTemplateIds[(i-1)%#row.residentTemplateIds+1],spawn.index,route)
    end
end
return Residents
