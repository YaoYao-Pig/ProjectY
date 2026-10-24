-- Shared content contract for world effects and equipment previews. No gameplay state.
local Catalog={}
function Catalog.Item(config,itemId)
    local item=config:GetTable('EquipmentItemTable'):Get(itemId)
    local id=item.visualEffectId
    if id==0 then id=config:GetTable('VisualEffectItemCategoryTable'):Get(item.kind).visualEffectId end
    return config:GetTable('VisualEffectTable'):Get(id)
end
function Catalog.Snapshot(config)
    local profiles=config:GetTable('VisualEffectTable')
    -- xLua LuaTable.Length reads the raw array length; keep the bridge list concrete.
    local result={profiles={},skills={},items={}}
    for _,profile in ipairs(profiles:All()) do result.profiles[#result.profiles+1]=profile end
    local used={}
    for _,skill in ipairs(config:GetTable('CombatSkillTable'):All()) do
        profiles:Get(skill.visualEffectId)
        assert(not used[skill.visualEffectId],'Each skill requires its own visual effect: '..skill.id)
        used[skill.visualEffectId]=true
        result.skills[#result.skills+1]={id=skill.id,profileId=skill.visualEffectId,trajectory=skill.trajectory}
    end
    for _,item in ipairs(config:GetTable('EquipmentItemTable'):All()) do
        result.items[#result.items+1]={id=item.id,profileId=Catalog.Item(config,item.id).id}
    end
    return result
end
return Catalog
