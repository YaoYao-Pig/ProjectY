-- 棋子外观只解析配置，不持有装备状态；未来由角色装备数据提供部件 ID。
local Appearance={}
Appearance.__index=Appearance
function Appearance.New(config)
    local self=setmetatable({parts=config:GetTable('PawnPartTable'),templates={}},Appearance)
    for _,row in ipairs(config:GetTable('PawnTemplateTable'):All()) do
        assert(not self.templates[row.unitId],'Duplicate pawn template for unit: '..row.unitId)
        self.templates[row.unitId]=row
        self:Resolve(row.partIds) -- 启动时检查插槽冲突和必需部件。
    end
    return self
end
-- 所有部件都显式给出插槽与资源路径，不从角色名猜模型，也不在显示层补默认装备。
function Appearance:Resolve(partIds)
    local result,slots={},{}
    for _,id in ipairs(partIds) do
        local part=self.parts:Get(id)
        assert(not slots[part.slot],'Pawn parts overlap at slot: '..part.slot)
        slots[part.slot]=true
        result[#result+1]={id=id,slot=part.slot,path=part.prefabPath}
    end
    assert(slots.body and slots.base,'Pawn appearance requires body and base')
    return result
end
function Appearance:Template(unitId,equipment)
    local row=assert(self.templates[unitId],'Missing pawn template for unit: '..unitId)
    if equipment then
        local ids={equipment.pose.corePartId}
        for _,id in ipairs(row.partIds) do
            local slot=self.parts:Get(id).slot
            if slot~='body' and slot~='mainHand' and slot~='offHand' and slot~='head' and slot~='chest' then ids[#ids+1]=id end
        end
        return {templateId=row.id,parts=self:Resolve(ids),equipment=equipment}
    end
    return {templateId=row.id,parts=self:Resolve(row.partIds)}
end
return Appearance
