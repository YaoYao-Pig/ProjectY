-- GM 查询与传送：读取叙事身份/真实占格，不生成替身，不修改 NPC 日程或任务事实。
local Npcs={};Npcs.__index=Npcs
function Npcs.New(adventure,story) return setmetatable({adventure=adventure,story=story},Npcs) end
local function integer(id) return type(id)=='number' and id%1==0 and id>0 end
function Npcs:Target(id)
    if not integer(id) then return nil,'请输入有效的 NPC 整数 ID' end
    local definition=self.story.rules.npcs:Find(id)
    if not definition then return nil,'不存在 NPC #'..id end
    local actorId=self.story.data:GetValue('recruited:'..id)
    if actorId~=0 then
        for i=0,self.adventure.data.PartyCount-1 do if self.adventure.data:GetPartyAt(i).Id==actorId then
            return nil,definition.name..' 已入队，位于队伍槽位 '..(i+1)
        end end
        error('Recruited NPC is missing from the party: '..id)
    end
    if not self.adventure.sites then return nil,'请先开始远征' end
    local siteId=self.story.npcs.locations[id]
    if not siteId then return nil,'本次地图未生成 '..definition.name..' 的出生城镇' end
    return {definition=definition,site=assert(self.adventure.sites[siteId],'NPC placement references an unknown site')}
end
function Npcs:CanTravel()
    local data=self.adventure.data
    if self.story.data.DialogueOpen then return false,'请先结束当前对话' end
    if data.Phase~='map' and data.Phase~='area' then return false,'只能在大地图或探索阶段传送，不能中断战斗/事件' end
    for i=0,data.PartyCount-1 do if data:GetPartyAt(i).HP>0 then return true end end
    return false,'队伍已全部倒地，请先治疗队员'
end
function Npcs:LocalNpc(layout,id)
    for _,npc in ipairs(layout.npcs) do if npc.narrativeId==id then return npc end end
    error('Assigned narrative NPC is missing from the layout: '..id)
end
function Npcs:Search(query)
    query=(query or ''):match('^%s*(.-)%s*$'):lower()
    local result={}
    for _,definition in ipairs(self.story.rules.npcs:All()) do
        if query=='' or tostring(definition.id):find(query,1,true) or definition.name:lower():find(query,1,true) then
            local target,reason=self:Target(definition.id)
            local row={id=definition.id,name=definition.name,available=false,body=reason or ''}
            if target then
                local schedule=self.story.npcs:Schedule(definition.id)
                row.body=target.site.name..' · '..schedule.activity
                local data=self.adventure.data
                if data.Areas.ActiveSiteId==target.site.id then
                    local layout=self.adventure.areas:ActiveLayout();local npc=self:LocalNpc(layout,definition.id)
                    local live=data.Areas.Active:GetNpcAt(npc.id-1);local cell=layout.cells[live.CellIndex]
                    row.body=row.body..string.format('\n当前位置 (%d, %d) · 层 %d',cell.q,cell.r,cell.layer)
                    if not live.Present then reason='NPC 当前不在场景中' end
                else row.body=row.body..'\n传送时进入该城镇并读取 NPC 实际位置' end
                if not reason then row.available,reason=self:CanTravel() end
                row.body=row.body..'\n'..(row.available and '点击传送到附近 · 关闭 GM 后按 E 交谈' or reason)
            end
            result[#result+1]=row
        end
    end
    return result
end
function Npcs:Deployment(layout,state,targetIndex)
    local ids={}
    for i=0,self.adventure.data.PartyCount-1 do local actor=self.adventure.data:GetPartyAt(i);if actor.HP>0 then ids[#ids+1]=actor.Id end end
    local footprint=self.adventure.areas:SquadFootprint(layout,ids)
    local enemies=self.adventure.areas:EnemyOccupancy(layout,state)
    local radius=self.story.rules.settings.recruitSearchRadius
    local distance,queue,head={[targetIndex]=0},{targetIndex},1
    while head<=#queue do local index=queue[head];head=head+1
        if distance[index]<radius then for _,cell in ipairs(layout:Neighbors(layout.cells[index])) do if distance[cell.index]==nil then
            distance[cell.index]=distance[index]+1;queue[#queue+1]=cell.index
        end end end
    end
    -- 领队必须与 NPC 沿真实导航相邻；整队占地均须合法，骑乘同样检查完整 footprint。
    local used,cells={},{}
    local function place(member)
        if member>#ids then return true end
        for _,index in ipairs(queue) do
            if member~=1 or distance[index]==1 then
                local parts=footprint(index,member);local valid=parts~=nil
                if parts then for _,part in ipairs(parts) do
                    if used[part] or enemies[part] or state:IsNpcOccupied(part) or layout.cells[part].blocked then valid=false;break end
                end end
                if valid then
                    for _,part in ipairs(parts) do used[part]=true end;cells[member]=index
                    if place(member+1) then return true end
                    for _,part in ipairs(parts) do used[part]=nil end;cells[member]=nil
                end
            end
        end
        return false
    end
    if not place(1) then return nil,'NPC 附近没有可容纳整队的合法位置（含坐骑占地）' end
    return {ids=ids,cells=cells}
end
function Npcs:GoTo(id)
    local target,reason=self:Target(id);if not target then return false,reason end
    local ok;ok,reason=self:CanTravel();if not ok then return false,reason end
    local adventure=self.adventure;local areas,data=adventure.areas,adventure.data
    local entered=false
    if data.Areas.ActiveSiteId~=target.site.id then
        if data.Phase=='area' then assert(areas:Stop());assert(areas:Leave()) end
        assert(areas:Enter(target.site,data.Seed));adventure.equipment:InitializeLoot(areas);entered=true
    end
    local layout,state=areas:ActiveLayout(),data.Areas.Active
    local npc=self:LocalNpc(layout,id);local live=state:GetNpcAt(npc.id-1)
    if not live.Present then return false,'NPC 当前不在场景中' end
    local deployment;deployment,reason=self:Deployment(layout,state,live.CellIndex)
    if not deployment then return false,(entered and ('已进入 '..target.site.name..'；') or '')..reason end
    state:SetInteraction(0,0);state:Stop();state:DeployMembers(deployment.ids,deployment.cells)
    areas:RevealSquad(layout,state)
    return true,'已传送到 '..target.definition.name..' 附近'
end
return Npcs
