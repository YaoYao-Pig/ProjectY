local L=require('Language')
local Loadout={};Loadout.__index=Loadout
local function native() return CS.ProjectY.Data.CampLoadoutData end
function Loadout.New(model)
    local a=model.adventure
    local rule=a.config:GetTable('CampLoadoutTable'):Get(1)
    assert(rule.speedMultiplier>=1 and math.tointeger(rule.visionBonus) and rule.visionBonus>=0,'Invalid camp loadout bonuses')
    assert(rule.nightStart>rule.nightEnd,'Camp torch night interval must cross midnight')
    return setmetatable({model=model,adventure=a,data=native().For(model.data),rule=rule,
        species=a.config:GetTable('AnimalSpeciesTable'),torch=a.config:GetTable('TorchTable'):Get(1)},Loadout)
end
function Loadout:Animal(ownerId,animalId,prepared)
    local source=prepared or self.adventure.data
    local count=prepared and CS.ProjectY.Data.PartyRoster.PreparedActiveCount(prepared) or source.PartyCount
    for i=0,count-1 do
        local owner=prepared and source:GetActorAt(i) or source:GetPartyAt(i)
        if owner.Id==ownerId then
            local animal=CS.ProjectY.Data.AnimalCompanionState.Bound(owner)
            if animal and animal.Id==animalId and animal.AnimalOwnerId==owner.Id and animal.HP>0 then return animal,owner end
        end
    end
end
function Loadout:Selected(slot,prepared)
    local data=prepared and native().For(CS.ProjectY.Data.CampData.Prepared(prepared)) or self.data
    if slot==1 then return self:Animal(data.MountOwnerId,data.MountAnimalId,prepared) end
    assert(slot==2,'Animal slot must be mount or pet')
    return self:Animal(data.PetOwnerId,data.PetAnimalId,prepared)
end
function Loadout:SpeedMultiplier()
    if self.adventure.water and self.adventure.water.data.Mode~='walk' then return 1 end
    return self:Selected(1) and self.rule.speedMultiplier or 1
end
function Loadout:VisionBonus(prepared) return self:Selected(2,prepared) and self.rule.visionBonus or 0 end
function Loadout:Night(minutes)
    local hour=minutes/60%24
    return hour>=self.rule.nightStart or hour<self.rule.nightEnd
end
function Loadout:ValidateSaved(prepared)
    local data=native().For(CS.ProjectY.Data.CampData.Prepared(prepared))
    assert(data.TorchItemId==0 or data.TorchItemId==self.torch.itemId,'Invalid saved camp torch')
    for slot=1,2 do
        local id=slot==1 and data.MountAnimalId or data.PetAnimalId
        if id~=0 then
            local animal=assert(self:Selected(slot,prepared),'Saved camp animal is no longer in the party')
            assert(slot~=1 or self.species:Get(animal.AnimalSpeciesId).rideable,'Saved camp mount cannot be ridden')
        end
    end
end
function Loadout:Equip(slot,ownerId,animalId,revision)
    local ok,reason=self.model:Session(revision);if not ok then return false,reason end
    if slot~=1 and slot~=2 then return false,L.CampLoadoutInvalid end
    if animalId~=0 then
        local animal=self:Animal(ownerId,animalId)
        if not animal then return false,L.CampLoadoutAnimalMissing end
        if slot==1 and not self.species:Get(animal.AnimalSpeciesId).rideable then return false,L.CampLoadoutNotRideable end
    end
    reason=native().EquipAnimal(self.model.data,self.adventure.data,slot,ownerId,animalId,revision)
    if reason~='' then return false,assert(L[reason]) end
    self.adventure.fog:Update();return true
end
function Loadout:EquipTorch(equip,revision)
    local ok,reason=self.model:Session(revision);if not ok then return false,reason end
    if equip~=0 and equip~=1 then return false,L.CampLoadoutInvalid end
    reason=native().EquipTorch(self.model.data,self.adventure.equipment.data,self.torch.itemId,equip==1,revision)
    return reason=='',reason=='' and '' or assert(L[reason])
end
function Loadout:Name(slot)
    if slot==3 then return self.data.TorchItemId==0 and L.CampLoadoutEmpty or self.model.rules.items:Get(self.data.TorchItemId).name end
    local animal=self:Selected(slot)
    return animal and self.adventure.battle.stats:Template(animal).name or L.CampLoadoutEmpty
end
function Loadout:Build(s,state)
    local slot=state.loadoutSlot or 1;state.loadoutSlot=slot
    local names={L.CampLoadoutMount,L.CampLoadoutPet,L.CampLoadoutTorch}
    local effect=slot==1 and string.format(L.CampLoadoutMountEffect,(self.rule.speedMultiplier-1)*100) or
        slot==2 and string.format(L.CampLoadoutPetEffect,self.rule.visionBonus) or
        string.format(L.CampLoadoutTorchEffect,self.rule.nightStart,self.rule.nightEnd,self.torch.range)
    s.panelTitle=L.CampLoadoutTitle;s.panelSubtitle=string.format(L.CampLoadoutSummary,self:Name(1),self:Name(2),self:Name(3))
    for i=1,3 do s.secondary[i]={title=string.format(i==slot and L.CampLoadoutTabSelected or L.CampLoadoutTab,names[i]),available=true} end
    local current=slot==3 and self.data.TorchItemId or slot==1 and self.data.MountAnimalId or self.data.PetAnimalId
    s.rows={{key='0',title=L.CampLoadoutEmpty,subtitle=L.CampLoadoutRemoveHint,itemId=0,iconPath=''}}
    if slot==3 then
        local item=self.model.rules.items:Get(self.torch.itemId)
        s.rows[#s.rows+1]={key=tostring(item.id),title=item.name,subtitle=string.format(L.CampLoadoutTorchStock,
            self.adventure.equipment.data:CountItem(item.id),self.model.data:Stored(item.id)),itemId=item.id,iconPath=item.iconPath}
    else
        for i=0,self.adventure.data.PartyCount-1 do
            local owner=self.adventure.data:GetPartyAt(i);local animal=CS.ProjectY.Data.AnimalCompanionState.Bound(owner)
            if animal and animal.HP>0 and (slot==2 or self.species:Get(animal.AnimalSpeciesId).rideable) then
                s.rows[#s.rows+1]={key=tostring(animal.Id),title=self.adventure.battle.stats:Template(animal).name,
                    subtitle=string.format(L.CampLoadoutAnimalOwner,self.adventure.battle.stats:Template(owner).name),
                    itemId=0,iconPath='',animal=animal,owner=owner}
            end
        end
    end
    local selected
    for _,row in ipairs(s.rows) do if row.key==state.selected then selected=row end end
    if not selected then
        for _,row in ipairs(s.rows) do if row.key==tostring(current) then selected=row end end
        if current==0 then selected=s.rows[2] or s.rows[1] end
    end
    selected=assert(selected);state.selected=selected.key
    for _,row in ipairs(s.rows) do row.selected=row==selected end
    local id=assert(tonumber(selected.key));s.detailTitle=selected.title;s.detailText=effect..'\n\n'..(slot==3 and L.CampLoadoutTorchHelp or L.CampLoadoutAnimalHelp)
    s.cost=string.format(L.CampLoadoutCurrent,self:Name(slot));s.actionLabel=id==0 and L.CampLoadoutUnequip or L.CampLoadoutEquip
    s.actionEnabled=id~=current;s.reason=id==current and L.CampLoadoutAlreadySelected or ''
    if slot==3 then
        s.previewAsset=self.adventure.equipment.rules:Asset(self.model.rules.items:Get(self.torch.itemId).assetId)
        s.operation={command='camp_loadout_torch',id=id==0 and 0 or 1,count=0}
        if id~=0 and current==0 and self.adventure.equipment.data:CountItem(id)+self.model.data:Stored(id)==0 then s.actionEnabled=false;s.reason=L.CampLoadoutTorchMissing end
        if id==0 and current~=0 and not self.adventure.equipment:CanGrant({current},{1}) then s.actionEnabled=false;s.reason=L.UICampText31 end
    else
        local animal=selected.animal or self:Selected(slot)
        if animal then
            s.previewPawn=self.adventure.appearances:Template(animal.TemplateId)
            s.detailText=s.detailText..'\n\n'..string.format(L.CampLoadoutAnimalStatus,animal.HP,animal.MaxHP,animal.AnimalBond)
        end
        s.operation={command=slot==1 and 'camp_loadout_mount' or 'camp_loadout_pet',id=selected.owner and selected.owner.Id or 0,count=id}
        if id~=0 and id==(slot==1 and self.data.PetAnimalId or self.data.MountAnimalId) then s.actionEnabled=false;s.reason=L.CampLoadoutAnimalBusy end
        if #s.rows==1 then s.reason=L.CampLoadoutNoAnimals end
    end
    return s
end
return Loadout
