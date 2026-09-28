-- Two-hand loadout chooses a motion module; each weapon supplies independent local grip markers.
local Motion={};Motion.__index=Motion
local ZERO_ROTATION={0,0,0}
local function adjustmentKey(weaponId,moduleId,hand) return weaponId..':'..moduleId..':'..hand end
function Motion.New(config)
    local self=setmetatable({modules=config:GetTable('EquipmentMotionModuleTable'),matches=config:GetTable('EquipmentMotionMatchTable'),grips=config:GetTable('EquipmentGripTable')},Motion)
    local seen={}
    for _,row in ipairs(self.matches:All()) do
        local key=table.concat({row.mainKind,row.mainHands,row.offKind,row.gunClass},':')
        assert(not seen[key],'Duplicate equipment motion match: '..key);seen[key]=true
    end
    for _,row in ipairs(self.grips:All()) do for _,key in ipairs({'mainPosition','mainRotation','offPosition','offRotation'}) do assert(#row[key]==3,'Grip must be Vector3: '..row.id..'/'..key) end end
    self.adjustments={}
    for _,row in ipairs(config:GetTable('EquipmentHoldAdjustmentTable'):All()) do
        local key=adjustmentKey(row.weaponId,row.moduleId,row.hand)
        assert(not self.adjustments[key],'Duplicate equipment hold adjustment: '..key)
        assert(#row.rotationOffset==3,'Hold adjustment must be Vector3: '..row.id)
        self.adjustments[key]=row.rotationOffset
    end
    return self
end
function Motion:Resolve(main,off,shield)
    local mainKind=main and main.kind or 'none';local hands=main and main.hands or 0
    local offKind=off and 'weapon' or shield and 'shield' or 'none'
    local gunClass=main and main.gunClass or ''
    local found
    for _,rule in ipairs(self.matches:All()) do
        if rule.mainKind==mainKind and rule.mainHands==hands and rule.offKind==offKind and rule.gunClass==gunClass then
            assert(not found,'Ambiguous weapon motion match');found=self.modules:Get(rule.moduleId)
        end
    end
    return assert(found,'No motion module for '..mainKind..'/'..hands..'/'..offKind..'/'..gunClass)
end
function Motion:Grip(weapon)
    return self.grips:Get(weapon.gripId)
end
function Motion:RotationOffset(weaponId,moduleId,hand)
    assert(hand=='main' or hand=='off','Invalid weapon hand: '..tostring(hand))
    -- A missing optional override explicitly inherits the motion module without any added rotation.
    return self.adjustments[adjustmentKey(weaponId,moduleId,hand)] or ZERO_ROTATION
end
return Motion
