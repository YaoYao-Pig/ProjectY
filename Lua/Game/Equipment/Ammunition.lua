local Ammo={};Ammo.__index=Ammo
function Ammo.New(config)
    local self=setmetatable({profiles=config:GetTable('EquipmentAmmoTable'),items=config:GetTable('EquipmentItemTable'),
        magazines=config:GetTable('EquipmentMagazineTable'),byCaliber={}},Ammo)
    local types={balanced=true,armor_piercing=true,flesh=true}
    for _,row in ipairs(self.profiles:All())do
        assert(self.items:Get(row.id).kind=='ammo' and row.caliberId>0 and types[row.ammoType],'Invalid ammunition profile')
        assert(row.armorDamageMultiplier>=0 and row.fleshDamageMultiplier>=0 and math.abs(row.armorPenetrationBonus)<=100,'Invalid ammunition multipliers')
        local rows=self.byCaliber[row.caliberId]
        if not rows then rows={};self.byCaliber[row.caliberId]=rows end
        for _,other in ipairs(rows)do assert(other.ammoType~=row.ammoType,'Duplicate ammunition type for caliber')end
        rows[#rows+1]=row
    end
    for _,item in ipairs(self.items:All())do if item.kind=='ammo' then self:Get(item.id)end end
    for _,magazine in ipairs(self.magazines:All())do self:Get(magazine.ammoItemId)end
    return self
end
function Ammo:Get(itemId)return self.profiles:Get(itemId)end
function Ammo:ForMagazine(itemId)
    return self.byCaliber[self:Get(self.magazines:Get(itemId).ammoItemId).caliberId]
end
function Ammo:Compatible(magazineItemId,ammoItemId)
    local ammo=self.profiles:Find(ammoItemId)
    return ammo~=nil and ammo.caliberId==self:Get(self.magazines:Get(magazineItemId).ammoItemId).caliberId
end
function Ammo:Define(data)
    for _,row in ipairs(self.profiles:All())do CS.ProjectY.Data.EquipmentAmmunition.Define(data,row.id,row.caliberId)end
end
return Ammo
