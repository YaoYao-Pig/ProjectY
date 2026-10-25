local LuaLanguage = require('Language')
-- Inventory commands and read-only presentation. All item/placement state belongs to EquipmentData.
local Model={};Model.__index=Model
local Text=require('Game.Equipment.EquipmentPresentation')
Model.slots={'head','body','leftRing','rightRing','legs','feet','weapon','offhand'}
Model.slotNames=require('Config.LanguageProxy').Map(LuaLanguage,{head='UIInventoryHead',body='UIInventoryBody',leftRing='UIInventoryLeftRing',rightRing='UIInventoryRightRing',legs='UIInventoryLegs',feet='UIInventoryFeet',weapon='UIInventoryWeapon',offhand='UIInventoryOffhand'})
function Model.New(system,stats) return setmetatable({system=system,data=system.data,rules=system.rules,stats=stats},Model) end
function Model:Rows(actorId)
    local rows={};local actor=assert(self.system:Actor(actorId),'Unknown inventory actor')
    local function add(key,instance,itemId,owner,slot,count,extra)
        local item=self.rules.items:Get(itemId);local place=self.data.Grid:Find(key);local name=item.name;local displayName=Text.Escape(item.name)
        if not place and owner~=actorId then return end
        local compatible=item.kind=='weapon' and 'weapon' or item.kind=='wearable' and self.rules.wearables:Get(itemId).slot or ''
        local mask=0
        for i,target in ipairs(Model.slots) do
            local kind=(target=='leftRing' or target=='rightRing') and 'ring' or target
            local allowed=false
            if item.kind=='weapon' and (target=='weapon' or target=='offhand') then
                allowed=self.rules:CanEquip(actor,itemId,self.stats) and self.system:HandAllowed(actorId,self.data:GetWeapon(instance),target) and (target=='weapon' and self.data:CanEquip(actorId,instance) or target=='offhand' and self.data:CanEquipOffhand(actorId,instance))
            elseif item.kind=='wearable' and compatible==kind then
                allowed=self.rules:CanEquip(actor,itemId,self.stats) and (target~='offhand' or self.system:HandAllowed(actorId,nil,'offhand')) and self.data:CanWear(actorId,target,instance)
            end
            if allowed then mask=mask+2^(i-1) end
        end
        if item.kind=='weapon' or item.kind=='wearable' then
            local instanceData=item.kind=='weapon' and self.data:GetWeapon(instance) or self.data:GetWearable(instance)
            name=self.rules.affixes:Name(instanceData);displayName=Text.Name(self.rules,instanceData)
            extra=Text.Details(self.rules,instanceData,actor,self.stats)
        elseif item.kind=='rune' or item.kind=='module' then
            extra=Text.Attachment(self.rules,itemId)
        elseif item.kind=='ammo' then
            extra=Text.Ammunition(self.rules,itemId)
        end
        local legendary=self.rules.affixes:Legendary(itemId)
        rows[#rows+1]={key=key,id=instance,itemId=itemId,kind=item.kind,name=name,displayName=displayName,count=count,
            legendary=legendary~=nil,rarityColor=legendary and legendary.color or '',
            detail=extra,iconPath=item.iconPath,slot=slot,compatible=compatible,equipMask=mask,width=item.width,height=item.height,
            x=place and place.X or -1,y=place and place.Y or -1,rotated=place~=nil and place.Rotated or false}
    end
    for i=0,self.data.WeaponCount-1 do local row=self.data:GetWeaponAt(i)
        add('w'..row.Id,row.Id,row.ItemId,row.OwnerActorId,row.Hand,1,self.rules.weapons:Get(row.ItemId).hands==1 and LuaLanguage.UIInventoryText4 or LuaLanguage.UIInventoryText3)
    end
    for i=0,self.data.MagazineCount-1 do local row=self.data:GetMagazineAt(i)
        add('m'..row.Id,row.Id,row.ItemId,0,'',1,Text.Magazine(self.rules,row))
    end
    local torch=self.rules.torch
    for i=0,self.data.StackCount-1 do local row=self.data:GetStackAt(i)
        if row.Count>0 then
            local detail=row.ItemId==torch.itemId and torch.description or LuaLanguage.UIInventoryText
            for _,disease in ipairs(self.stats.diseases.definitions:All())do if disease.itemId==row.ItemId then
                local buff=self.stats.diseases.buffs:Get(disease.buffId);detail=string.format(LuaLanguage.BodyMedicineDescription,buff.name,buff.description)
            end end
            add(CS.ProjectY.Data.InventoryStacks.Key(row),row.ItemId,row.ItemId,0,'',row.Count,detail)
        end
    end
    for i=0,self.data.WearableCount-1 do local row=self.data:GetWearableAt(i)
        add('g'..row.Id,row.Id,row.ItemId,row.OwnerActorId,row.Slot,1,'')
    end
    return rows
end
function Model:Command(command,actorId,key,x,y,rotated)
    if self.system.adventure.Phase~='map' and self.system.adventure.Phase~='area' then return false,LuaLanguage.UIInventoryText13 end
    local actor=self.system:Actor(actorId);if not actor then return false,LuaLanguage.UIInventoryText12 end
    local selected
    for _,row in ipairs(self:Rows(actorId)) do if row.key==key then selected=row;break end end
    if not selected then return false,LuaLanguage.UIInventoryText11 end
    if command=='repair' then return self.system:Repair(actorId,key) end
    if command=='move' then
        if selected.slot~='' then
            if not self.data:ReturnToBag(key,actorId,x,y,rotated) then return false,LuaLanguage.UIInventoryText10 end
            actor:SetMaxHP(self.stats:MaximumHP(actor));return true
        end
        return self.data:Move(key,x,y,rotated),LuaLanguage.UIInventoryText10
    end
    if command=='unequip' then
        if selected.slot=='' then return false,LuaLanguage.UIInventoryText9 end
        if selected.kind=='weapon' then return self.system:Command(selected.slot=='offhand' and 'unequip_offhand' or 'unequip',actorId,0,0,0) end
        if not self.data:Wear(actorId,selected.slot,0) then return false,LuaLanguage.UIInventoryText8 end
    elseif command:sub(1,6)=='equip:' then
        local slot=command:sub(7)
        if not Model.slotNames[slot] then return false,LuaLanguage.UIInventoryText7 end
        if (slot=='weapon' or slot=='offhand') and selected.kind=='weapon' then
            local ok,reason=self.system:Command(slot=='offhand' and 'equip_offhand' or 'equip',actorId,selected.id,0,0)
            if ok then actor:SetMaxHP(self.stats:MaximumHP(actor)) end
            return ok,reason
        end
        local compatible=(slot=='leftRing' or slot=='rightRing') and 'ring' or slot
        if selected.kind~='wearable' or selected.compatible~=compatible then return false,LuaLanguage.UIInventoryText6 end
        local allowed,reason=self.rules:CanEquip(actor,selected.itemId,self.stats);if not allowed then return false,reason end
        if slot=='offhand' then local allowed,reason=self.system:HandAllowed(actorId,nil,'offhand');if not allowed then return false,reason end end
        if not self.data:Wear(actorId,slot,selected.id) then return false,LuaLanguage.UIInventoryText5 end
    else error('Unknown inventory command: '..tostring(command)) end
    actor:SetMaxHP(self.stats:MaximumHP(actor)) -- Reuse the actor contract: preserve damage when the maximum changes.
    return true
end
return Model
