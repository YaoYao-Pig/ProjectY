-- One shared UI shader clock; modal inventory pauses the world, not its decorative sweep.
local Rarity={}
function Rarity.Tick()
    CS.UnityEngine.Shader.SetGlobalFloat('_EquipmentRarityTime',CS.UnityEngine.Time.unscaledTime)
end
return Rarity
