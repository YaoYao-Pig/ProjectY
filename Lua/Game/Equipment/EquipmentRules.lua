-- Read-only equipment/config queries, shared by combat, the workbench and pawn presentation.
local Rules = {}; Rules.__index = Rules
function Rules.New(config, data)
    local self = setmetatable({data=data},Rules)
    for key,name in pairs({items='EquipmentItemTable',weapons='EquipmentWeaponTable',runes='EquipmentRuneTable',
        magazines='EquipmentMagazineTable',sockets='EquipmentSocketTable',assets='EquipmentAssetTable',
        poses='EquipmentPoseTable',actions='EquipmentActionTable',skills='CombatSkillTable',effects='CombatEffectTable'}) do self[key]=config:GetTable(name) end
    for _,weapon in ipairs(self.weapons:All()) do
        assert(self.items:Get(weapon.id).kind=='weapon')
        for _,id in ipairs(weapon.socketIds) do assert(self.sockets:Get(id).weaponItemId==weapon.id,'Weapon/socket mismatch') end
        if weapon.kind=='gun' then self.magazines:Get(weapon.magazineItemId) end
    end
    for _,magazine in ipairs(self.magazines:All()) do assert(magazine.spawnRounds<=magazine.capacity and self.items:Get(magazine.ammoItemId).kind=='ammo') end
    return self
end
-- No inventory is required for static config/attribute queries; battle supplies the expedition's real Data.
function Rules:Weapon(actor) return self.data and actor.Team==1 and self.data:Equipped(actor.Id) or nil end
function Rules:SkillIds(actor, template)
    local weapon = self:Weapon(actor)
    if not weapon then return template.skillIds end
    local definition = self.weapons:Get(weapon.ItemId)
    local removed,seen,result={},{},{}
    for _,id in ipairs(definition.replacesSkillIds) do removed[id]=true end
    for _,id in ipairs(template.skillIds) do if not removed[id] then result[#result+1]=id;seen[id]=true end end
    for _,id in ipairs(definition.skillIds) do if not seen[id] then result[#result+1]=id;seen[id]=true end end
    return result
end
function Rules:Skill(actor, id)
    local base=self.skills:Get(id);local result={}
    for _,key in ipairs({'id','name','description','iconId','action','cost','range','target','proficiency','effectIds',
        'skillGroup','cooldownTurns','hitChance','shots','ammoPerShot','damageScale','actionTemplate'}) do result[key]=base[key] end
    result.maxTargets=1;result.splashRadius=0
    local weapon=self:Weapon(actor)
    if weapon then
        for _,socketId in ipairs(self.weapons:Get(weapon.ItemId).socketIds) do
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
        if magazine.ItemId==definition.magazineItemId and self.data:MagazineWeapon(magazine.Id)==0 and magazine.Rounds>rounds then
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
    if self:IsReload(skill) then self.data:AttachMagazine(weapon.Id,assert(self:NextMagazine(weapon)).Id)
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
        view.sockets[#view.sockets+1]={id=id,name=socket.name,kind=socket.kind,position=vector(socket.position),rotation=vector(socket.rotation),asset=attachment}
    end
    return view
end
function Rules:ActorVisual(actor)
    local weapon=self:Weapon(actor)
    if not weapon then return nil end
    local pose=self.poses:Get(self.weapons:Get(weapon.ItemId).poseId)
    local result={weapon=self:WeaponVisual(weapon),pose={id=pose.id,corePartId=pose.corePartId,
        upper=self:Asset(pose.upperAssetId),forearm=self:Asset(pose.forearmAssetId),hand=self:Asset(pose.handAssetId)}}
    for _,key in ipairs({'mainShoulder','mainElbow','mainHand','offShoulder','offElbow','offHand','weaponRotation'}) do result.pose[key]=vector(pose[key]) end
    local action=self.actions:Get(actor.ActionTemplateId)
    result.action={sequence=actor.ActionSequence,kind=action.kind,duration=action.duration,recoil=action.recoil,
        pitch=action.pitch,handLift=action.handLift,magazineDrop=action.magazineDrop,shots=actor.ActionShots,
        targetQ=actor.ActionTargetQ,targetR=actor.ActionTargetR}
    return result
end
return Rules
