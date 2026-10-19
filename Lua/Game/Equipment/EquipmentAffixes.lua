-- Config-only rules. Physical IDs and generation remain in EquipmentData.
local Affixes={};Affixes.__index=Affixes
Affixes.NormalizeColor=require('Config.Color').Normalize
function Affixes.New(config)
    local self=setmetatable({table=config:GetTable('EquipmentAffixTable'),items=config:GetTable('EquipmentItemTable'),
        weapons=config:GetTable('EquipmentWeaponTable'),wearables=config:GetTable('EquipmentWearableTable'),
        attributes=config:GetTable('EquipmentAttributeTable'),pools={},allowed={},attributeCodes={},colors={}},Affixes)
    for _,attribute in ipairs(self.attributes:All()) do self.attributeCodes[attribute.code]=attribute end
    for _,row in ipairs(self.table:All()) do
        self.colors[row.id]=Affixes.NormalizeColor(row.color)
        assert(#row.targetTypes>0 and #row.attributeIds==#row.attributeValues,'Invalid affix arrays: '..row.id)
        local seen={}
        for _,id in ipairs(row.attributeIds) do self.attributes:Get(id);assert(not seen[id],'Repeated affix attribute');seen[id]=true end
        seen={};for _,kind in ipairs(row.targetTypes) do assert(not seen[kind],'Repeated affix target');seen[kind]=true end
    end
    local ordinary=self.table:Get(1)
    assert(ordinary.damageMultiplier==1 and ordinary.hitBonus==0 and #ordinary.attributeIds==0,'Ordinary affix must have no modifiers')
    for _,item in ipairs(self.items:All()) do
        if item.kind=='weapon' or item.kind=='wearable' then
            local kind=self:Type(item.id);local ids,weights,allowed={},{},{};local total=0
            for _,row in ipairs(self.table:All()) do for _,target in ipairs(row.targetTypes) do if target==kind then
                ids[#ids+1]=row.id;weights[#weights+1]=row.weight;allowed[row.id]=true;total=total+row.weight;break
            end end end
            assert(allowed[1] and total>0,'Equipment needs an ordinary affix and a positive pool: '..item.id)
            self.pools[item.id]={ids=ids,weights=weights};self.allowed[item.id]=allowed
        end
    end
    return self
end
function Affixes:Type(itemId)
    local weapon=self.weapons:Find(itemId)
    if weapon then return weapon.kind end
    local slot=self.wearables:Get(itemId).slot
    return slot=='ring' and 'ring' or slot=='offhand' and 'shield' or 'armor'
end
function Affixes:Define(data)
    for itemId,pool in pairs(self.pools) do CS.ProjectY.Data.EquipmentAffixData.Define(data,itemId,pool.ids,pool.weights) end
end
function Affixes:Of(item)
    local id=CS.ProjectY.Data.EquipmentAffixData.Of(item)
    assert(assert(self.allowed[item.ItemId],'Item cannot have an equipment affix')[id],'Equipment affix is not applicable: '..id)
    return self.table:Get(id)
end
function Affixes:Name(item)
    local row=self:Of(item);local name=self.items:Get(item.ItemId).name
    return row.id==1 and name or row.name..'的'..name
end
function Affixes:Color(item) return self.colors[self:Of(item).id] end
function Affixes:Bonus(item,name)
    local row=self:Of(item)
    for i,id in ipairs(row.attributeIds) do if self.attributes:Get(id).code==name then return row.attributeValues[i] end end
    return 0
end
function Affixes:Text(item)
    local row=self:Of(item);local values={}
    if row.damageMultiplier~=1 then values[#values+1]=string.format('伤害 %+.0f%%',(row.damageMultiplier-1)*100) end
    if row.hitBonus~=0 then values[#values+1]=string.format('命中 %+d 个百分点',row.hitBonus) end
    for i,id in ipairs(row.attributeIds) do values[#values+1]=self.attributes:Get(id).name..string.format(' %+d',row.attributeValues[i]) end
    return '品质：'..row.name..' · '..(#values>0 and table.concat(values,'，') or '无属性修正')
end
return Affixes
