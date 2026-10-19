-- 便携照明复用背包实物与叙事事实；Lua 不持有第二份可变开关状态。
local Torch={}
local flag='flag:torch_extinguished'
local function switchValue(narrative)
    local value=narrative:GetValue(flag)
    assert(value==0 or value==1,'Invalid saved torch switch')
    return value
end
function Torch.ValidateSaved(prepared)
    if not prepared.LegacyNarrative then switchValue(prepared.Narrative) end
end
function Torch.Snapshot(adventure)
    local definition=adventure.config:GetTable('TorchTable'):Get(1)
    local count=adventure.data.Equipment:CountItem(definition.itemId)
    local extinguished=switchValue(adventure.data.Narrative)
    local available=count>0
    local enabled=available and extinguished==0
    return {available=available,enabled=enabled,count=count,
        label=not available and '火炬 · 背包中没有火炬' or enabled and '火炬 · 已点亮 [T]' or '火炬 · 已熄灭 [T]'}
end
function Torch.Toggle(adventure)
    local phase=adventure.data.Phase
    if phase~='map' and phase~='area' then return false,'只能在探索期间开关火炬' end
    local state=Torch.Snapshot(adventure)
    if not state.available then return false,'背包中需要一支旅行火炬' end
    adventure.data.Narrative:SetValue(flag,state.enabled and 1 or 0)
    return true,''
end
return Torch
