local Hex=require('Game.Map.HexGrid')
local Construction={};Construction.__index=Construction
local function contains(values,value) for _,item in ipairs(values) do if item==value then return true end end return false end
function Construction.New(config,adventure,data)
    local self=setmetatable({adventure=adventure,definitions=config:GetTable('ConstructionTable'),skills=config:GetTable('CombatSkillTable'),
        items=config:GetTable('EquipmentItemTable'),data=data or CS.ProjectY.Data.ConstructionData(),cacheRevision=-1,cache={}},Construction)
    for _,row in ipairs(self.definitions:All()) do
        local skill=self.skills:Get(row.id)
        assert(skill.target=='cell' and #skill.effectIds==0 and skill.skillGroup=='construction','Invalid construction skill')
        assert(#row.itemIds==#row.itemCounts,'Construction material arrays differ')
        if row.kind=='pit' or row.kind=='trench' then
            assert(row.maxHP==0 and row.height<0 and #row.diggableSurfaces>0 and row.toolTag~='','Invalid excavation definition')
        elseif row.kind~='demolish' then assert(row.maxHP>0 and row.height>0,'Invalid structure definition') end
        local seen={}
        for i,id in ipairs(row.itemIds) do assert(not seen[id] and self.items:Get(id).kind=='material' and row.itemCounts[i]>0,'Invalid construction material');seen[id]=true end
        if row.kind=='demolish' then assert(not self.demolitionId,'Duplicate demolition action');self.demolitionId=row.id end
    end
    assert(self.demolitionId,'Construction requires a demolition action')
    return self
end
function Construction:Records(site)
    local revision=self.data.Revision
    if self.cacheRevision~=revision then
        self.cache={}
        for i=0,self.data.Count-1 do local row=self.data:GetAt(i)
            if not row.Removed then
                local cells=self.cache[row.SiteId];if not cells then cells={};self.cache[row.SiteId]=cells end
                cells[row.CellIndex]=row
            end
        end
        self.cacheRevision=revision
    end
    return self.cache[site]
end
function Construction:Record(site,index)
    local records=self:Records(site);return records and records[index]
end
function Construction:Layout(base,site)
    return require('Game.MapArea.ConstructionTerrain').Wrap(base,self,site)
end
function Construction:Budget(actor,skillId)
    local row=self.definitions:Get(skillId)
    if row.kind=='demolish' then return true end
    if actor.Team~=1 then return false,'没有可使用的施工材料' end
    local inventory=self.adventure.equipment.data
    for i,id in ipairs(row.itemIds) do if inventory:CountItem(id)<row.itemCounts[i] then return false,'材料不足：'..self.items:Get(id).name..' ×'..row.itemCounts[i] end end
    if row.toolTag~='' then
        local found=false
        for _,hand in ipairs({'Equipped','Offhand'}) do
            local weapon=inventory[hand](inventory,actor.Id)
            if weapon and self.adventure.equipment.rules:HasWeaponTag(weapon.ItemId,row.toolTag) then found=true end
        end
        if not found then return false,'需要施术者装备铲子' end
    end
    return true
end
function Construction:CanUse(battle,skill,cell)
    local board=battle.board;local source=battle:Active();local row=self.definitions:Get(skill.id)
    if not board.area or not board.area.constructionSite then return false,'施工需要当前探索区域的真实地形' end
    if source.Team==1 and board.allowed and not board.allowed(cell) then return false,'目标地格尚未探索' end
    if Hex.Distance(source.Q,source.R,cell.q,cell.r)>skill.range then return false,'目标超出施工距离' end
    if not board.area:CanSee(board:Find(source.Q,source.R),cell) then return false,'地形遮挡了目标' end
    local existing=self:Record(board.area.constructionSite,cell.index)
    if row.kind=='demolish' then return existing~=nil and existing.MaxHP>0,'请选择可破坏的工事' end
    if existing then return false,'此处已有工事或挖掘地形' end
    if cell.blocked or cell.layer~=0 or cell.index==board.area.entryIndex or cell.index==board.area.goalIndex then return false,'入口、出口、墙体或上层地面不能施工' end
    if cell.kind~='floor' and cell.kind~='grass' and cell.kind~='dirt' then return false,'此地形不适合施工' end
    if battle:Occupied()[Hex.Key(cell.q,cell.r)] then return false,'不能在单位或障碍物占格上施工' end
    local areaState=self.adventure.data.Areas.Active
    if areaState:IsNpcOccupied(cell.index) or (cell.obstacleId or 0)>0 then return false,'此处已有居民或陈设' end
    for _,loot in ipairs(self.adventure.equipment:LootSnapshot(self.adventure.areas)) do if loot.cellIndex==cell.index and not loot.looted then return false,'此处仍有待搜刮物品' end end
    if (row.kind=='pit' or row.kind=='trench') and not contains(row.diggableSurfaces,cell.surfaceId) then return false,'只能挖掘未铺装的泥土或草地' end
    return self:Budget(source,skill.id)
end
function Construction:Apply(battle,skill,cell)
    local actor=battle:Active();local row=self.definitions:Get(skill.id);local site=battle.board.area.constructionSite
    if row.kind=='demolish' then
        local record=assert(self:Record(site,cell.index));local name=self.skills:Get(record.SkillId).name
        local amount=math.max(1,math.floor(row.demolitionBase+battle.stats:Get(actor,'strength')*row.demolitionStrength))
        local damage=self.data:Damage(site,cell.index,amount)
        battle:Emit('construction',name..' 受到 '..damage..' 点结构伤害'..(record.Removed and '，已被拆毁' or '（剩余 '..record.HP..'）'),actor.Id)
    else
        local hp=row.maxHP>0 and math.floor(row.maxHP+battle.stats:Get(actor,'crafting')*row.hpPerCrafting) or 0
        -- 配置数组是只读代理；跨 xLua 边界前投影为实体数组，避免 raw length 为 0。
        local ids,counts={},{}
        for i,id in ipairs(row.itemIds) do ids[i]=id;counts[i]=row.itemCounts[i] end
        self.data:Place(site,cell.index,row.id,hp,self.adventure.equipment.data,ids,counts)
        battle:Emit('construction',battle.stats:Template(actor).name..' · '..skill.name,actor.Id)
    end
end
function Construction:RangeBonus(board,source,target,skill)
    return self:RangeBonusAt(board,source,board:Find(target.Q,target.R),skill)
end
function Construction:RangeBonusAt(board,source,targetCell,skill)
    if skill.target~='enemy' or skill.range<=1 or not board.area or not board.area.constructionSite then return 0 end
    local origin=board:Find(source.Q,source.R);local record=self:Record(board.area.constructionSite,origin.index)
    if record and origin.height>targetCell.height+.1 then return self.definitions:Get(record.SkillId).rangeBonus end
    return 0
end
function Construction:AreaTargets()
    local result={};local state=self.adventure.data.Areas.Active
    for i=0,state.VisibleCount-1 do
        local index=state:GetVisibleAt(i);local record=self:Record(state.SiteId,index)
        if record and record.MaxHP>0 then result[#result+1]=index end
    end
    return result
end
function Construction:CanDismantle(actor,index)
    local areas=self.adventure.areas;local area,state=areas:ActiveLayout(),areas.data.Active
    local cell=area.cells[index];local record=cell and self:Record(state.SiteId,index)
    if not record or record.MaxHP==0 then return false,'请选择可破坏的工事' end
    local origin
    for i=0,state.MemberCount-1 do if state:GetMemberIdAt(i)==actor.Id then origin=area.cells[state:GetMemberCellAt(i)];break end end
    if not origin then return false,'此角色没有参与探索' end
    if Hex.Distance(origin.q,origin.r,cell.q,cell.r)>self.skills:Get(self.demolitionId).range then return false,'请先靠近工事' end
    if not area:CanSee(origin,cell) then return false,'地形遮挡了工事' end
    return true
end
function Construction:Dismantle(actor,index)
    local ok,reason=self:CanDismantle(actor,index);if not ok then return false,reason end
    local areas=self.adventure.areas;local row=self.definitions:Get(self.demolitionId)
    local amount=math.max(1,math.floor(row.demolitionBase+self.adventure.battle.stats:Get(actor,'strength')*row.demolitionStrength))
    areas:Stop();self.data:Damage(areas.data.ActiveSiteId,index,amount)
    areas:SpendWorkRounds(row.workRounds)
    if areas:RefreshLivingSquad() then areas:RevealSquad(areas:ActiveLayout(),areas.data.Active) end
    return true
end
function Construction:Snapshot()
    local site=self.adventure.data.Areas.ActiveSiteId;local state=self.adventure.data.Areas.Active
    local rows={}
    for i=0,self.data.Count-1 do local record=self.data:GetAt(i)
        if record.SiteId==site and not record.Removed and state:IsKnown(record.CellIndex) then
            local row=self.definitions:Get(record.SkillId)
            rows[#rows+1]={id=record.Id,cellIndex=record.CellIndex,skillId=row.id,kind=row.kind,height=row.height,moveExtra=row.moveExtra,hp=record.HP,maxHP=record.MaxHP,
                blocksMovement=row.blocksMovement,blocksSight=row.blocksSight,name=self.skills:Get(row.id).name}
        end
    end
    return rows
end
return Construction
