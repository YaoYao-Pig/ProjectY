local Life=require('Game.Battle.ActorLife')
local L=require('Language')
local Spirit={};Spirit.__index=Spirit
local function state()return CS.ProjectY.Data.EquipmentSpiritSession end
local function legacy(weapon)return CS.ProjectY.Data.EquipmentLegacyData.Of(weapon)end
function Spirit.New(adventure)return setmetatable({adventure=adventure},Spirit)end
function Spirit:Active()
    local data=self.adventure.data.Narrative
    return data.DialogueOpen and state().WeaponId(data)>0
end
function Spirit:FindWeapon(id)
    local equipment=self.adventure.equipment
    for i=0,equipment.data.WeaponCount-1 do
        local weapon=equipment.data:GetWeaponAt(i)
        if weapon.Id==id and equipment:IsCarriedWeapon(weapon)then return weapon end
    end
end
function Spirit:Weapon()
    return self:FindWeapon(state().WeaponId(self.adventure.data.Narrative))
end
function Spirit:Path(weapon)
    return self.adventure.forge.rules.paths:Get(legacy(weapon).PathId)
end
function Spirit:CanContinue()
    local adventure=self.adventure
    if adventure.data.Phase~='map' then return false,L.EquipmentSpiritMapOnly end
    local weapon=self:Weapon()
    if not weapon then return false,L.EquipmentSpiritUnavailable end
    if not legacy(weapon).Awakened then return false,L.EquipmentSpiritDormant end
    local actor=adventure.equipment:Actor(adventure.data.Narrative.DialogueActorId)
    if not actor or not Life.Alive(actor) then return false,L.EquipmentSpiritLivingActor end
    return true
end
function Spirit:Open(weaponId)
    local adventure=self.adventure;local data=adventure.data.Narrative
    if data.DialogueOpen then return false,L.EquipmentSpiritBusy end
    if adventure.data.Phase~='map' then return false,L.EquipmentSpiritMapOnly end
    local weapon=self:FindWeapon(weaponId)
    if not weapon then return false,L.EquipmentSpiritUnavailable end
    if not legacy(weapon).Awakened then return false,L.EquipmentSpiritDormant end
    local actor=adventure.equipment:Actor(weapon.OwnerActorId)
    if not actor or not Life.Alive(actor) then actor=adventure.events:LivingParty()[1]end
    if not actor then return false,L.EquipmentSpiritLivingActor end
    local path=self:Path(weapon)
    adventure.travel.data:SetPaused(true)
    state().Begin(data,weapon.Id,actor.Id)
    data:AddDialogueLine(adventure.forge:Name(weapon),path.spiritOpening,false)
    return true
end
function Spirit:Title()
    return self.adventure.forge:Name(assert(self:Weapon(),'Equipment spirit lost its weapon'))
end
function Spirit:Caption()
    return string.format(L.EquipmentSpiritCaption,self:Path(assert(self:Weapon(),'Equipment spirit lost its weapon')).name)
end
function Spirit:Choices()
    local ok,reason=self:CanContinue()
    local result={}
    local function add(id,text,available,why)
        result[#result+1]={id=id,text=text,available=available,reason=why or ''}
    end
    add(-1,L.EquipmentSpiritKnow,ok,reason)
    add(-2,L.EquipmentSpiritMemories,ok,reason)
    add(-3,L.EquipmentSpiritWish,ok,reason)
    if ok and legacy(self:Weapon()).WishState==0 then add(-4,L.EquipmentSpiritAcceptWish,true)end
    add(-5,L.EquipmentSpiritLeave,true)
    return result
end
function Spirit:Choose(id,version)
    local adventure=self.adventure;local data=adventure.data.Narrative
    if not self:Active() or version~=data.DialogueVersion then return false,L.EquipmentSpiritStale end
    local selected
    for _,row in ipairs(self:Choices())do if row.id==id then selected=row;break end end
    if not selected then return false,L.EquipmentSpiritStale end
    if not selected.available then return false,selected.reason end
    if id==-5 then return self:Close()end
    local weapon=assert(self:Weapon());local growth=legacy(weapon);local path=self:Path(weapon)
    local name=adventure.forge:Name(weapon)
    data:AddDialogueLine(adventure.narrative.rules.settings.playerSpeaker,selected.text,true)
    if id==-1 then
        data:AddDialogueLine(name,path.personality,false)
    elseif id==-2 then
        if growth.DeedCount==0 then data:AddDialogueLine(name,L.EquipmentSpiritNoMemory,false)end
        for i=0,growth.DeedCount-1 do
            data:AddDialogueLine(name,adventure.forge:DeedText(growth:GetDeedAt(i)),false)
        end
    elseif id==-3 then
        local text=growth.WishState==0 and path.wish or growth.WishState==1 and path.wishProgress or path.wishCompleted
        data:AddDialogueLine(name,text,false)
    elseif id==-4 then
        assert(growth:AcceptWish(),'Validated equipment spirit wish was not accepted')
        data:AddDialogueLine(name,path.wishAccepted,false)
    end
    state().Touch(data)
    return true
end
function Spirit:Close()
    if self:Active()then self.adventure.data.Narrative:CloseDialogue()end
    return true
end
return Spirit
