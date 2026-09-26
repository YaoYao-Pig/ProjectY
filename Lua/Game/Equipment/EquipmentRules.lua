-- Read-only equipment/config queries, shared by combat, the workbench and pawn presentation.
local Rules = {}; Rules.__index = Rules
function Rules.New(config, data)
    local self = setmetatable({data=data},Rules)
    for key,name in pairs({items='EquipmentItemTable',weapons='EquipmentWeaponTable',runes='EquipmentRuneTable',
        magazines='EquipmentMagazineTable',sockets='EquipmentSocketTable',assets='EquipmentAssetTable',
        poses='EquipmentPoseTable',actions='EquipmentActionTable',skills='CombatSkillTable',effects='CombatEffectTable',
        categories='EquipmentCategoryTable',requirements='EquipmentRequirementTable',attributes='EquipmentAttributeTable',wearables='EquipmentWearableTable'}) do self[key]=config:GetTable(name) end
    for _,row in ipairs(self.wearables:All()) do
        assert(self.items:Get(row.id).kind=='wearable' and #row.attributeNames==#row.attributeValues,'Invalid wearable definition')
        for _,name in ipairs(row.attributeNames) do
            local found=false;for _,attribute in ipairs(self.attributes:All()) do if attribute.code==name then found=true end end
            assert(found,'Unknown wearable attribute: '..name)
        end
    end
    for _,weapon in ipairs(self.weapons:All()) do
        assert(self.items:Get(weapon.id).kind=='weapon')
        self.categories:Get(weapon.categoryId)
        local requirement=self.requirements:Get(weapon.requirementId)
        assert(#requirement.attributeIds==#requirement.values,'Weapon requirement arrays differ')
        for _,id in ipairs(weapon.socketIds) do assert(self.sockets:Get(id).weaponItemId==weapon.id,'Weapon/socket mismatch') end
        if weapon.kind=='gun' then self.magazines:Get(weapon.magazineItemId) end
        assert(weapon.hands==1 or weapon.hands==2,'Invalid weapon hand count')
        if weapon.hands==1 then assert(self.skills:Get(weapon.offhandSkillId).action=='secondary','Offhand attack must use a secondary action')
        else assert(weapon.offhandSkillId==0,'Two-handed weapon cannot grant an offhand attack') end
    end
    for _,magazine in ipairs(self.magazines:All()) do assert(magazine.spawnRounds<=magazine.capacity and self.items:Get(magazine.ammoItemId).kind=='ammo') end
    return self
end
-- No inventory is required for static config/attribute queries; battle supplies the expedition's real Data.
function Rules:Weapon(actor) return self.data and actor.Team==1 and self.data:Equipped(actor.Id) or nil end
function Rules:Offhand(actor) return self.data and actor.Team==1 and self.data:Offhand(actor.Id) or nil end
function Rules:AttributeBonus(actor,name)
    if not self.data or actor.Team~=1 then return 0 end
    local bonus=0
    for i=0,self.data.WearableCount-1 do local item=self.data:GetWearableAt(i)
        if item.OwnerActorId==actor.Id then
            local row=self.wearables:Get(item.ItemId)
            for j,attribute in ipairs(row.attributeNames) do if attribute==name then bonus=bonus+row.attributeValues[j] end end
        end
    end
    return bonus
end
function Rules:SkillIds(actor, template)
    local weapon = self:Weapon(actor)
    local definition = weapon and self.weapons:Get(weapon.ItemId) or nil
    local removed,seen,result={},{},{}
    if definition then for _,id in ipairs(definition.replacesSkillIds) do removed[id]=true end end
    for _,id in ipairs(template.skillIds) do if not removed[id] then result[#result+1]=id;seen[id]=true end end
    if definition then for _,id in ipairs(definition.skillIds) do if not seen[id] then result[#result+1]=id;seen[id]=true end end end
    local off=self:Offhand(actor)
    if off then local id=self.weapons:Get(off.ItemId).offhandSkillId;assert(id>0,'Offhand weapon has no attack');if not seen[id] then result[#result+1]=id end end
    return result
end
function Rules:Requirements(actor,weapon,stats)
    local definition=self.weapons:Get(weapon.ItemId)
    local rule=self.requirements:Get(definition.requirementId)
    local result={missing=0,entries={}}
    for i,id in ipairs(rule.attributeIds) do
        local attribute=self.attributes:Get(id);local current=stats:Get(actor,attribute.code);local required=rule.values[i]
        result.missing=result.missing+math.max(0,required-current)
        result.entries[#result.entries+1]={name=attribute.name,current=current,required=required}
    end
    result.met=result.missing==0
    result.damageScale=math.max(rule.minimumDamageScale,1-result.missing*rule.damageLossPerPoint)
    result.hitLoss=math.min(rule.maximumHitLoss,result.missing*rule.hitLossPerPoint)
    return result
end
function Rules:Skill(actor, id, stats)
    local base=self.skills:Get(id);local result={}
    for _,key in ipairs({'id','name','description','iconId','action','cost','range','target','proficiency','effectIds',
        'skillGroup','cooldownTurns','hitChance','shots','ammoPerShot','damageScale','actionTemplate'}) do result[key]=base[key] end
    result.maxTargets=1;result.splashRadius=0
    local weapon=self:Weapon(actor)
    local off=self:Offhand(actor);local offAttack=off and self.weapons:Get(off.ItemId).offhandSkillId==id
    if offAttack then weapon=off end
    if weapon then
        local definition=self.weapons:Get(weapon.ItemId)
        local granted=offAttack and {definition.offhandSkillId} or definition.skillIds
        for _,skillId in ipairs(granted) do if skillId==id then
            local requirement=self:Requirements(actor,weapon,assert(stats,'Equipment skill resolution needs CombatStats'))
            result.damageScale=result.damageScale*definition.damageMultiplier*requirement.damageScale
            result.hitChance=math.max(0,result.hitChance-requirement.hitLoss)
        end end
        for _,socketId in ipairs(definition.socketIds) do
            local runeId=weapon:GetRune(socketId)
            if runeId~=0 then
                local rune=self.runes:Get(runeId)
                if rune.skillGroup==result.skillGroup then
                    result.damageScale=result.damageScale*rune.damageMultiplier
                    result.range=result.range+rune.rangeBonus
                    result.hitChance=math.min(100,result.hitChance+rune.hitBonus)
                    result.cooldownTurns=result.cooldownTurns+rune.cooldownBonus
                    if result.target=='enemy' then
                        result.maxTargets=math.max(result.maxTargets,rune.maxTargets)
                        result.splashRadius=math.max(result.splashRadius,rune.splashRadius)
                    end
                end
            end
        end
    end
    return result
end
function Rules:IsReload(skill)
    for _,id in ipairs(skill.effectIds) do if self.effects:Get(id).kind=='reload' then
        assert(#skill.effectIds==1 and skill.shots==1 and skill.ammoPerShot==0 and skill.target=='self','Reload must be a standalone self action')
        return true
    end end
    return false
end
function Rules:Loaded(weapon)
    return weapon and weapon.MagazineId~=0 and self.data:GetMagazine(weapon.MagazineId) or nil
end
function Rules:NextMagazine(weapon)
    local definition=self.weapons:Get(weapon.ItemId)
    if definition.kind~='gun' then return nil end
    local loaded=self:Loaded(weapon);local rounds=loaded and loaded.Rounds or 0
    local selected
    for i=0,self.data.MagazineCount-1 do
        local magazine=self.data:GetMagazineAt(i)
        if magazine.ItemId==definition.magazineItemId and self.data:MagazineWeapon(magazine.Id)==0 and magazine.Rounds>rounds and self.data:CanAttachMagazine(weapon.Id,magazine.Id) then
            if not selected or magazine.Rounds>selected.Rounds then selected=magazine end
        end
    end
    return selected
end
function Rules:CheckAmmo(actor,skill)
    local weapon=self:Weapon(actor)
    if self:IsReload(skill) then
        if not weapon or self.weapons:Get(weapon.ItemId).kind~='gun' then return false,'需要装备枪械' end
        local loaded=self:Loaded(weapon)
        if loaded and loaded.Rounds==loaded.Capacity then return false,'弹匣已满' end
        if not self:NextMagazine(weapon) then return false,'没有弹药更多的备用弹匣；战斗外可用散弹药装填' end
    elseif skill.ammoPerShot>0 then
        local loaded=self:Loaded(weapon)
        if not loaded then return false,'尚未装入弹匣' end
        if loaded.Rounds<skill.shots*skill.ammoPerShot then return false,'弹匣内子弹不足，请先换弹' end
    end
    return true
end
function Rules:Consume(actor,skill)
    local weapon=self:Weapon(actor)
    if self:IsReload(skill) then assert(self.data:AttachMagazine(weapon.Id,assert(self:NextMagazine(weapon)).Id),'Reload placement changed after validation')
    elseif skill.ammoPerShot>0 then self.data:SpendAmmo(weapon.Id,skill.shots*skill.ammoPerShot) end
end
local function vector(row) assert(#row==3,'Expected xyz');return {row[1],row[2],row[3]} end
function Rules:Asset(id)
    local asset=self.assets:Get(id);return {id=id,path=asset.prefabPath}
end
function Rules:WeaponVisual(weapon)
    local item,definition=self.items:Get(weapon.ItemId),self.weapons:Get(weapon.ItemId)
    local view={id=weapon.Id,asset=self:Asset(item.assetId),sockets={},previewRotation=vector(definition.previewRotation),previewZoom=definition.previewZoom}
    for _,id in ipairs(definition.socketIds) do
        local socket=self.sockets:Get(id);local attachment
        if socket.kind=='magazine' then
            local magazine=self:Loaded(weapon)
            if magazine then attachment=self:Asset(self.items:Get(magazine.ItemId).assetId) end
        else
            local runeId=weapon:GetRune(id)
            if runeId~=0 then attachment=self:Asset(self.items:Get(runeId).assetId) end
        end
        view.sockets[#view.sockets+1]={id=id,name=socket.name,kind=socket.kind,calloutSide=socket.calloutSide,position=vector(socket.position),rotation=vector(socket.rotation),asset=attachment}
    end
    return view
end
function Rules:ActorVisual(actor)
    if not self.data or actor.Team~=1 then return nil end
    local weapon=self:Weapon(actor)
    local offhand=self:Offhand(actor)
    local pose=self.poses:Get(weapon and self.weapons:Get(weapon.ItemId).poseId or 3)
    local result={weapon=weapon and self:WeaponVisual(weapon),offhand=offhand and self:WeaponVisual(offhand),wearables={},pose={id=pose.id,corePartId=pose.corePartId,offHandFollowsWeapon=weapon~=nil and pose.offHandFollowsWeapon,
        upper=self:Asset(pose.upperAssetId),forearm=self:Asset(pose.forearmAssetId),hand=self:Asset(pose.handAssetId)}}
    for i=0,self.data.WearableCount-1 do local worn=self.data:GetWearableAt(i)
        if worn.OwnerActorId==actor.Id then
            local definition=self.wearables:Get(worn.ItemId)
            result.wearables[#result.wearables+1]={slot=worn.Slot,mount=definition.mount,
                asset=self:Asset(self.items:Get(worn.ItemId).assetId),position=vector(definition.position),rotation=vector(definition.rotation)}
        end
    end
    for _,key in ipairs({'mainShoulder','mainElbow','mainHand','offShoulder','offElbow','offHand','weaponRotation'}) do result.pose[key]=vector(pose[key]) end
    local offPose=offhand and self.poses:Get(self.weapons:Get(offhand.ItemId).poseId) or pose
    result.pose.offWeaponRotation=vector(offPose.weaponRotation);result.pose.offWeaponRotation[3]=-result.pose.offWeaponRotation[3]
    local action=self.actions:Get(actor.ActionTemplateId)
    result.action={sequence=actor.ActionSequence,kind=action.kind,duration=action.duration,recoil=action.recoil,
        pitch=action.pitch,yaw=action.yaw,roll=action.roll,handLift=action.handLift,magazineDrop=action.magazineDrop,shots=actor.ActionShots,
        targetQ=actor.ActionTargetQ,targetR=actor.ActionTargetR}
    return result
end
return Rules
