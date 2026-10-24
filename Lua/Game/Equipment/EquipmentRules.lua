-- Read-only equipment/config queries, shared by combat, the workbench and pawn presentation.
local Rules = {}; Rules.__index = Rules
function Rules.New(config, data)
    local self = setmetatable({data=data,visualEffectConfig=config},Rules)
    self.motion=require('Game.Equipment.EquipmentMotion').New(config)
    self.affixes=require('Game.Equipment.EquipmentAffixes').New(config)
    self.torch=config:GetTable('TorchTable'):Get(1)
    for key,name in pairs({items='EquipmentItemTable',weapons='EquipmentWeaponTable',runes='EquipmentRuneTable',
        magazines='EquipmentMagazineTable',sockets='EquipmentSocketTable',assets='EquipmentAssetTable',
        poses='EquipmentPoseTable',actions='EquipmentActionTable',skills='CombatSkillTable',effects='CombatEffectTable',buffDefinitions='BuffTable',
        categories='EquipmentCategoryTable',tags='EquipmentWeaponTagTable',requirements='EquipmentRequirementTable',attributes='EquipmentAttributeTable',wearables='EquipmentWearableTable',
        talents='TalentNodeTable',passives='PassiveSkillTable',traits='CombatTraitTable',units='CombatUnitTable'}) do self[key]=config:GetTable(name) end
    for _,trait in ipairs(self.traits:All()) do
        assert(trait.attribute~='' or trait.amount==0,'A trait without an attribute cannot grant an attribute bonus')
        assert(trait.attribute~='' or #trait.onHitEffectIds>0,'Trait needs an attribute or on-hit effect')
        for _,id in ipairs(trait.onHitEffectIds) do
            local effect=self.effects:Get(id)
            assert(effect.kind=='apply_buff' or effect.kind=='damage' or effect.kind=='heal' or effect.kind=='guard' or effect.kind=='remove_buffs','Unsupported trait on-hit instruction')
        end
    end
    for _,unit in ipairs(self.units:All()) do
        local seen={}
        for _,id in ipairs(unit.traitIds) do self.traits:Get(id);assert(not seen[id],'Duplicate innate trait');seen[id]=true end
    end
    self.pawnParts=config:GetTable('PawnPartTable');self.pawnTemplates={}
    for _,row in ipairs(config:GetTable('PawnTemplateTable'):All()) do self.pawnTemplates[row.unitId]=row end
    for _,row in ipairs(self.wearables:All()) do
        assert(self.items:Get(row.id).kind=='wearable' and #row.attributeNames==#row.attributeValues,'Invalid wearable definition')
        self.requirements:Get(row.requirementId)
        for _,name in ipairs(row.attributeNames) do
            local found=false;for _,attribute in ipairs(self.attributes:All()) do if attribute.code==name then found=true end end
            assert(found,'Unknown wearable attribute: '..name)
        end
    end
    for _,row in ipairs(self.requirements:All()) do
        assert(#row.attributeIds==#row.values,'Equipment requirement arrays differ')
        for _,id in ipairs(row.attributeIds) do self.attributes:Get(id) end
    end
    for _,row in ipairs(self.runes:All()) do
        for _,id in ipairs(row.onHitEffectIds)do
            local effect=self.effects:Get(id)
            assert(effect.kind=='apply_buff' or effect.kind=='damage' or effect.kind=='heal' or effect.kind=='guard' or effect.kind=='remove_buffs','Unsupported attachment on-hit instruction')
        end
        if row.requiredTalentId>0 then self.talents:Get(row.requiredTalentId) end
        assert(row.catalystKind~='none' or row.requiredTalentId==0,'A catalyst specialization requires a catalyst component')
        assert(row.transferSelf and row.transferRange>0 or not row.transferSelf and row.transferRange==0,'Transfer rune needs an explicit positive range')
        assert(not row.transferSelf or row.skillGroup=='spell','Transfer runes only retarget spells')
    end
    for _,skill in ipairs(self.skills:All())do
        if skill.allowTransfer then
            assert(skill.target=='self' and skill.skillGroup=='spell' and skill.skillKind~='item' and #skill.effectIds>0,'Only configured self spells may transfer')
            for _,id in ipairs(skill.effectIds)do
                local effect=self.effects:Get(id)
                assert(effect.recipient=='target' and (effect.kind=='apply_buff' or effect.kind=='modifier' or effect.kind=='heal' or effect.kind=='guard' or effect.kind=='remove_buffs'),'Transfer spell effects must apply supported actions to the selected recipient')
            end
        end
    end
    for _,weapon in ipairs(self.weapons:All()) do
        for _,id in ipairs(weapon.onHitEffectIds)do self.effects:Get(id)end
        assert(self.items:Get(weapon.id).kind=='weapon')
        self.categories:Get(weapon.categoryId)
        local seenTags={}
        for _,id in ipairs(weapon.tagIds) do
            self.tags:Get(id)
            assert(not seenTags[id],'Duplicate weapon tag: '..weapon.id..'/'..id);seenTags[id]=true
        end
        local requirement=self.requirements:Get(weapon.requirementId)
        assert(#requirement.attributeIds==#requirement.values,'Weapon requirement arrays differ')
        for _,id in ipairs(weapon.socketIds) do assert(self.sockets:Get(id).weaponItemId==weapon.id,'Weapon/socket mismatch') end
        if weapon.kind=='gun' then self.magazines:Get(weapon.magazineItemId) end
        assert(weapon.hands==1 or weapon.hands==2,'Invalid weapon hand count')
        self.motion:Grip(weapon)
        if weapon.hands==1 then assert(self.skills:Get(weapon.offhandSkillId).action=='secondary','Offhand attack must use a secondary action')
        else assert(weapon.offhandSkillId==0,'Two-handed weapon cannot grant an offhand attack') end
    end
    for _,magazine in ipairs(self.magazines:All()) do assert(magazine.spawnRounds<=magazine.capacity and self.items:Get(magazine.ammoItemId).kind=='ammo') end
    return self
end
function Rules:WeaponTags(itemId)
    local result={}
    for _,id in ipairs(self.weapons:Get(itemId).tagIds) do result[#result+1]=self.tags:Get(id) end
    return result
end
function Rules:HasWeaponTag(itemId,tagId)
    self.tags:Get(tagId)
    for _,id in ipairs(self.weapons:Get(itemId).tagIds) do if id==tagId then return true end end
    return false
end
function Rules:IsUtilityWeapon(itemId)
    for _,id in ipairs(self.weapons:Get(itemId).tagIds) do if self.tags:Get(id).tool then return true end end
    return false
end
-- No inventory is required for static config/attribute queries; battle supplies the expedition's real Data.
function Rules:Weapon(actor) return self.data and self.data:Equipped(actor.Id) or nil end
function Rules:Offhand(actor) return self.data and self.data:Offhand(actor.Id) or nil end
function Rules:Condition(item) return CS.ProjectY.Data.EquipmentConditionData.Of(item) end
function Rules:Usable(item) return item~=nil and not self:Condition(item).Broken end
function Rules:ConditionText(item)
    local condition=self:Condition(item)
    return string.format('耐久 %d / %d · 原始上限 %d · 效能 %d%%%s',condition.Current,condition.Maximum,condition.BaseMaximum,
        math.floor(condition.Efficiency*100+.5),condition.Broken and ' · 已损毁，维修后可用' or '')
end
-- The workbench inspects one weapon, not a hypothetical mixed loadout. Keep real inventory untouched.
function Rules:PreviewWeapon(weapon)
    local module=self.motion:Resolve(self.weapons:Get(weapon.ItemId),nil,nil)
    return setmetatable({
        Weapon=function() return weapon end,
        Offhand=function() return nil end,
        MotionModule=function() return module end,
    },{__index=self})
end
function Rules:MotionModule(actor)
    local main,off=self:Weapon(actor),self:Offhand(actor)
    if not self.data then
        local mainId,offId=self:TemplateLoadout(actor.TemplateId)
        local offItem=offId~=0 and self.items:Get(offId)
        return self.motion:Resolve(mainId~=0 and self.weapons:Get(mainId),offItem and offItem.kind=='weapon' and self.weapons:Get(offId),offItem and offItem.kind=='wearable')
    end
    return self.motion:Resolve(main and self.weapons:Get(main.ItemId),off and self.weapons:Get(off.ItemId),self.data and self.data:Worn(actor.Id,'offhand'))
end
function Rules:TemplateLoadout(unitId)
    local main,off=0,0;local row=assert(self.pawnTemplates[unitId],'Missing pawn template loadout')
    for _,id in ipairs(row.partIds) do local part=self.pawnParts:Get(id)
        if part.slot=='mainHand' or part.slot=='offHand' then
            assert(part.equipmentItemId>0,'Hand part lacks its configured equipment item: '..id)
            local item=self.items:Get(part.equipmentItemId)
            if part.slot=='mainHand' then assert(item.kind=='weapon','Main-hand part must reference a weapon');main=part.equipmentItemId
            else assert(item.kind=='weapon' or (item.kind=='wearable' and self.wearables:Get(item.id).slot=='offhand'),'Off-hand part must reference a weapon or shield');off=part.equipmentItemId end
        end
    end
    return main,off
end
local function rounded(value) return value<0 and math.ceil(value-.5) or math.floor(value+.5) end
function Rules:ItemAttributeBonus(item,name)
    local value=self.affixes:Bonus(item,name)
    local definition=self.items:Get(item.ItemId).kind=='wearable' and self.wearables:Get(item.ItemId)
    if definition then for i,attribute in ipairs(definition.attributeNames) do if attribute==name then value=value+definition.attributeValues[i] end end end
    return rounded(value*self:Condition(item).Efficiency)
end
function Rules:AttributeBonus(actor,name)
    if not self.data then return 0 end
    local bonus=0
    for i=0,self.data.WearableCount-1 do local item=self.data:GetWearableAt(i)
        if item.OwnerActorId==actor.Id then
            bonus=bonus+self:ItemAttributeBonus(item,name)
        end
    end
    local main,off=self:Weapon(actor),self:Offhand(actor)
    if main then bonus=bonus+self:ItemAttributeBonus(main,name) end
    if off then bonus=bonus+self:ItemAttributeBonus(off,name) end
    return bonus
end
function Rules:SkillIds(actor, template)
    local weapon = self:Weapon(actor)
    local definition = self:Usable(weapon) and self.weapons:Get(weapon.ItemId) or nil
    local removed,seen,result={},{},{}
    if definition then for _,id in ipairs(definition.replacesSkillIds) do removed[id]=true end end
    for _,id in ipairs(template.skillIds) do
        local base=self.skills:Get(id)
        if (not removed[id] or base.catalystKind~='none') and (definition or (base.skillGroup~='weapon' and base.skillGroup~='slash') or not self.data) then result[#result+1]=id;seen[id]=true end
    end
    for i=0,actor.Growth.SkillCount-1 do local id=actor.Growth:GetSkillAt(i); if not seen[id] then result[#result+1]=id;seen[id]=true end end
    if definition then for _,id in ipairs(definition.skillIds) do if not seen[id] then result[#result+1]=id;seen[id]=true end end end
    local off=self:Offhand(actor)
    if self:Usable(off) then local id=self.weapons:Get(off.ItemId).offhandSkillId;assert(id>0,'Offhand weapon has no attack');if not seen[id] then result[#result+1]=id;seen[id]=true end end
    if self.data and actor.AnimalSpeciesId==0 then
        if not definition and not seen[504] then result[#result+1]=504 end
        if not seen[503] then result[#result+1]=503 end
    end
    return result
end
function Rules:ItemRequirements(actor,itemId,stats,excludeEquipment)
    local item=self.items:Get(itemId)
    assert(item.kind=='weapon' or item.kind=='wearable','Only wearable equipment has attribute requirements')
    local definition=item.kind=='weapon' and self.weapons:Get(itemId) or self.wearables:Get(itemId)
    local rule=self.requirements:Get(definition.requirementId)
    local result={missing=0,entries={}}
    for i,id in ipairs(rule.attributeIds) do
        local attribute=self.attributes:Get(id);local current=stats:Get(actor,attribute.code,excludeEquipment);local required=rule.values[i]
        result.missing=result.missing+math.max(0,required-current)
        result.entries[#result.entries+1]={name=attribute.name,current=current,required=required}
    end
    result.met=result.missing==0
    result.damageScale=math.max(rule.minimumDamageScale,1-result.missing*rule.damageLossPerPoint)
    result.hitLoss=math.min(rule.maximumHitLoss,result.missing*rule.hitLossPerPoint)
    return result
end
function Rules:Requirements(actor,weapon,stats) return self:ItemRequirements(actor,weapon.ItemId,stats,false) end
function Rules:CanEquip(actor,itemId,stats)
    local requirement=self:ItemRequirements(actor,itemId,stats,true)
    if requirement.met then return true end
    local missing={}
    for _,entry in ipairs(requirement.entries) do
        if entry.current<entry.required then missing[#missing+1]=entry.name..' '..entry.current..' / '..entry.required end
    end
    return false,'属性不足，无法装备：'..table.concat(missing,'，')..'（不计装备加成）'
end
local function catalystWeapon(self,actor,weapon,kind)
    if not self:Usable(weapon) then return nil end
    local definition=self.weapons:Get(weapon.ItemId)
    if definition.catalystKind==kind then return weapon end
    local blockedTalent
    for _,socketId in ipairs(definition.socketIds) do
        local runeId=weapon:GetRune(socketId)
        if runeId~=0 then
            local rune=self.runes:Get(runeId)
            if rune.catalystKind==kind then
                if rune.requiredTalentId==0 or actor.Growth:GetRank(rune.requiredTalentId)>0 then return weapon end
                blockedTalent=blockedTalent or rune.requiredTalentId
            end
        end
    end
    return nil,blockedTalent
end
-- Select one catalyst deterministically; equipment changes never erase a learned skill.
function Rules:Catalyst(actor,kind)
    assert(kind=='arcane','Unknown catalyst kind: '..tostring(kind))
    if not self.data then
        local mainId,offId=self:TemplateLoadout(actor.TemplateId)
        if mainId~=0 and self.weapons:Get(mainId).catalystKind==kind then return {ItemId=mainId} end
        if offId~=0 and self.items:Get(offId).kind=='weapon' and self.weapons:Get(offId).catalystKind==kind then return {ItemId=offId} end
        return nil,'需要奥术触媒（主手或副手）'
    end
    local selected,blockedTalent=catalystWeapon(self,actor,self:Weapon(actor),kind)
    if selected then return selected end
    local offTalent;selected,offTalent=catalystWeapon(self,actor,self:Offhand(actor),kind)
    if selected then return selected end
    blockedTalent=blockedTalent or offTalent
    if blockedTalent then return nil,'触媒配件需要专精：'..self.passives:Get(self.talents:Get(blockedTalent).passiveId).name end
    return nil,'需要奥术触媒（主手或副手）'
end
function Rules:CheckSkillEquipment(actor,skill,stats)
    if skill.skillGroup=='weapon' or skill.skillGroup=='slash' then
        local main,off=self:Weapon(actor),self:Offhand(actor)
        if not self:Usable(main) and not (self:Usable(off) and self.weapons:Get(off.ItemId).offhandSkillId==skill.id) then return false,'需要一把耐久大于零的已装备武器' end
    end
    if skill.catalystKind=='none' then return true end
    local weapon,reason=self:Catalyst(actor,skill.catalystKind)
    return weapon~=nil,reason,weapon
end
function Rules:Skill(actor, id, stats)
    local base=self.skills:Get(id);local result={}
    result.appliedRuneIds={}
    result.baseHitChance=base.hitChance
    for _,key in ipairs({'id','name','description','iconId','action','cost','range','minRange','fixedRange','target','proficiency','effectIds',
        'skillGroup','cooldownTurns','hitChance','shots','ammoPerShot','damageScale','actionTemplate','contexts','affectsContainers','opportunityAttack','trajectory','catalystKind','skillKind','weaponWear','allowTransfer'}) do result[key]=base[key] end
    result.maxTargets=base.maxTargets;result.splashRadius=base.splashRadius
    result.criticalChance=base.criticalChance;result.criticalMultiplier=base.criticalMultiplier
    local damageSkill=false
    for _,effectId in ipairs(base.effectIds)do if self.effects:Get(effectId).kind=='damage' then damageSkill=true end end
    local function appendEffects(ids)
        if #ids==0 then return end
        if result.effectIds==base.effectIds then local copy={};for _,effectId in ipairs(base.effectIds)do copy[#copy+1]=effectId end;result.effectIds=copy end
        for _,effectId in ipairs(ids)do result.effectIds[#result.effectIds+1]=effectId end
    end
    if damageSkill and base.target=='enemy' then
        for i=0,actor.TraitCount-1 do appendEffects(self.traits:Get(actor:GetTraitAt(i)).onHitEffectIds) end
    end
    local weapon=self:Weapon(actor)
    local off=self:Offhand(actor);local offAttack=off and self.weapons:Get(off.ItemId).offhandSkillId==id
    if offAttack then weapon=off end
    local weaponAttack=false
    if weapon then
        local definition=self.weapons:Get(weapon.ItemId)
        local granted=offAttack and {definition.offhandSkillId} or definition.skillIds
        for _,skillId in ipairs(granted) do if skillId==id then
            if not self:IsReload(base) and base.target=='enemy' then weaponAttack=true end
            if base.actionTemplate~=0 and not self:IsReload(base) then
                local module=self:MotionModule(actor);local grip=self.motion:Grip(definition)
                result.actionTemplate=offAttack and module.offActionId or grip.attackActionId~=0 and grip.attackActionId or module.attackActionId
                assert(result.actionTemplate>0,'Weapon motion module has no action')
            end
            local requirement=self:Requirements(actor,weapon,assert(stats,'Equipment skill resolution needs CombatStats'))
            result.damageScale=result.damageScale*definition.damageMultiplier*requirement.damageScale*self:Condition(weapon).Efficiency
            result.hitChance=math.max(0,result.hitChance-requirement.hitLoss)
        end end
    end
    local modifierWeapon=weapon
    if weapon and base.target=='enemy' and base.catalystKind=='none' and (base.skillGroup=='weapon' or base.skillGroup=='slash') then
        local onHit=self.weapons:Get(weapon.ItemId).onHitEffectIds
        appendEffects(onHit)
    end
    if base.catalystKind~='none' then modifierWeapon=self:Catalyst(actor,base.catalystKind) end
    if modifierWeapon and (weaponAttack or base.catalystKind~='none') then
        local affix=self.affixes:Of(modifierWeapon)
        result.damageScale=result.damageScale*affix.damageMultiplier
        result.hitChance=result.hitChance+affix.hitBonus
    end
    local transferRange=0
    if modifierWeapon then
        local definition=self.weapons:Get(modifierWeapon.ItemId)
        for _,socketId in ipairs(definition.socketIds) do
            local runeId=modifierWeapon:GetRune(socketId)
            if runeId~=0 then
                local rune=self.runes:Get(runeId)
                if rune.skillGroup==result.skillGroup or rune.skillGroup=='physical' and (result.skillGroup=='weapon' or result.skillGroup=='slash') then
                    result.appliedRuneIds[#result.appliedRuneIds+1]=runeId
                    result.damageScale=result.damageScale*rune.damageMultiplier
                    if not result.fixedRange then result.range=result.range+rune.rangeBonus end
                    result.hitChance=result.hitChance+rune.hitBonus
                    result.criticalChance=result.criticalChance+rune.criticalBonus
                    result.cooldownTurns=result.cooldownTurns+rune.cooldownBonus
                    if rune.transferSelf and base.allowTransfer and base.target=='self' then
                        transferRange=math.max(transferRange,rune.transferRange)
                    end
                    if result.target=='enemy' then
                        result.maxTargets=math.max(result.maxTargets,rune.maxTargets)
                        result.splashRadius=math.max(result.splashRadius,rune.splashRadius)
                        if damageSkill then appendEffects(rune.onHitEffectIds) end
                    end
                end
            end
        end
    end
    if not self.data and self.pawnTemplates[actor.TemplateId] and base.skillGroup=='weapon' and base.target=='enemy' then
        local mainId,offId=self:TemplateLoadout(actor.TemplateId)
        -- Creature/empty-hand templates retain their own skill presentation.
        if mainId~=0 or offId~=0 then
            result.actionTemplate=self:MotionModule(actor).attackActionId
            assert(result.actionTemplate>0,'Enemy weapon module has no attack')
        end
    end
    result.hitChance=math.max(0,math.min(100,result.hitChance))
    result.criticalChance=math.max(0,math.min(100,result.criticalChance))
    result.range=math.max(result.target=='enemy' and 1 or 0,result.range)
    result.cooldownTurns=math.max(0,result.cooldownTurns)
    if transferRange>0 then result.target='any';result.range=transferRange end
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
function Rules:NextMagazine(actor,weapon)
    -- The shared backpack belongs to the player's party, even when enemies hold real weapons.
    if actor.Team~=1 then return nil end
    local definition=self.weapons:Get(weapon.ItemId)
    if definition.kind~='gun' then return nil end
    local loaded=self:Loaded(weapon);local rounds=loaded and loaded.Rounds or 0
    local selected
    for i=0,self.data.MagazineCount-1 do
        local magazine=self.data:GetMagazineAt(i)
        if magazine.ItemId==definition.magazineItemId and self.data:MagazineWeapon(magazine.Id)==0 and self.data.Grid:Find('m'..magazine.Id) and magazine.Rounds>rounds and self.data:CanAttachMagazine(weapon.Id,magazine.Id) then
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
        if not self:NextMagazine(actor,weapon) then return false,'没有可用的备用弹匣；队员可在战斗外用散装弹药装填' end
    elseif skill.ammoPerShot>0 then
        local loaded=self:Loaded(weapon)
        if not loaded then return false,'尚未装入弹匣' end
        if loaded.Rounds<skill.shots*skill.ammoPerShot then return false,'弹匣内子弹不足，请先换弹' end
    end
    return true
end
function Rules:Consume(actor,skill)
    local weapon=self:Weapon(actor)
    if self:IsReload(skill) then assert(self.data:AttachMagazine(weapon.Id,assert(self:NextMagazine(actor,weapon)).Id),'Reload placement changed after validation')
    elseif skill.ammoPerShot>0 then self.data:SpendAmmo(weapon.Id,skill.shots*skill.ammoPerShot) end
    local off=self:Offhand(actor)
    if off and self.weapons:Get(off.ItemId).offhandSkillId==skill.id then weapon=off end
    if weapon and skill.weaponWear>0 then CS.ProjectY.Data.EquipmentCombatState.DamageWeapon(self.data,weapon.Id,skill.weaponWear*skill.shots) end
end
local function vector(row) assert(#row==3,'Expected xyz');return {row[1],row[2],row[3]} end
function Rules:Asset(id)
    local asset=self.assets:Get(id);return {id=id,path=asset.prefabPath}
end
function Rules:WeaponVisual(weapon)
    local item,definition=self.items:Get(weapon.ItemId),self.weapons:Get(weapon.ItemId)
    local effectCatalog=require('Game.Presentation.VisualEffectCatalog')
    local view={id=weapon.Id,effect=effectCatalog.Item(self.visualEffectConfig,item.id),asset=self:Asset(item.assetId),sockets={},previewRotation=vector(definition.previewRotation),previewZoom=definition.previewZoom}
    local grip=self.motion:Grip(definition)
    view.primaryGrip={position=vector(grip.mainPosition),rotation=vector(grip.mainRotation)}
    view.secondaryGrip={position=vector(grip.offPosition),rotation=vector(grip.offRotation)}
    for _,id in ipairs(definition.socketIds) do
        local socket=self.sockets:Get(id);local attachment,effect
        if socket.kind=='magazine' then
            local magazine=self:Loaded(weapon)
            if magazine then attachment=self:Asset(self.items:Get(magazine.ItemId).assetId);effect=effectCatalog.Item(self.visualEffectConfig,magazine.ItemId) end
        else
            local runeId=weapon:GetRune(id)
            if runeId~=0 then attachment=self:Asset(self.items:Get(runeId).assetId);effect=effectCatalog.Item(self.visualEffectConfig,runeId) end
        end
        view.sockets[#view.sockets+1]={id=id,name=socket.name,kind=socket.kind,calloutSide=socket.calloutSide,position=vector(socket.position),rotation=vector(socket.rotation),asset=attachment,effect=effect}
    end
    return view
end
function Rules:ActorVisual(actor)
    if not self.data or actor.AnimalSpeciesId~=0 then return nil end
    local weapon=self:Weapon(actor)
    local offhand=self:Offhand(actor)
    local wearables={}
    for i=0,self.data.WearableCount-1 do local worn=self.data:GetWearableAt(i)
        if worn.OwnerActorId==actor.Id then local definition=self.wearables:Get(worn.ItemId)
            wearables[#wearables+1]={slot=worn.Slot,mount=definition.mount,effect=require('Game.Presentation.VisualEffectCatalog').Item(self.visualEffectConfig,worn.ItemId),asset=self:Asset(self.items:Get(worn.ItemId).assetId),position=vector(definition.position),rotation=vector(definition.rotation)}
        end
    end
    return self:AssembleVisual(weapon,offhand,wearables,actor)
end
function Rules:ConfiguredVisual(unitId)
    local mainId,offId=self:TemplateLoadout(unitId)
    local function weapon(id) return id~=0 and {Id=id,ItemId=id,MagazineId=0,GetRune=function() return 0 end} or nil end
    local main=weapon(mainId);local offItem=offId~=0 and self.items:Get(offId);local off=offItem and offItem.kind=='weapon' and weapon(offId) or nil
    local wearables={}
    if offItem and offItem.kind=='wearable' then local definition=self.wearables:Get(offId)
        wearables[1]={slot='offhand',mount=definition.mount,effect=require('Game.Presentation.VisualEffectCatalog').Item(self.visualEffectConfig,offItem.id),asset=self:Asset(offItem.assetId),position=vector(definition.position),rotation=vector(definition.rotation)}
    end
    local result=self:AssembleVisual(main,off,wearables,nil);result.templateEquipment=true;return result
end
function Rules:AssembleVisual(weapon,offhand,wearables,actor)
    local shield=false;for _,worn in ipairs(wearables) do if worn.slot=='offhand' then shield=true end end
    local module=self.motion:Resolve(weapon and self.weapons:Get(weapon.ItemId),offhand and self.weapons:Get(offhand.ItemId),shield)
    local definition=weapon and self.weapons:Get(weapon.ItemId)
    local grip=definition and self.motion:Grip(definition)
    local pose=self.poses:Get(grip and module.offHandMode=='shared' and grip.poseId or module.poseId)
    local result={weapon=weapon and self:WeaponVisual(weapon),offhand=offhand and self:WeaponVisual(offhand),wearables=wearables,pose={id=pose.id,corePartId=pose.corePartId,offHandFollowsWeapon=weapon~=nil and pose.offHandFollowsWeapon,
        upper=self:Asset(pose.upperAssetId),forearm=self:Asset(pose.forearmAssetId),hand=self:Asset(pose.handAssetId)}}
    result.pose.moduleId=module.id;result.pose.moduleName=module.name;result.pose.holdId=module.holdId
    result.pose.offHandMode=module.offHandMode
    result.pose.lockWeaponOrientation=module.lockWeaponOrientation
    result.pose.offHandFollowsWeapon=weapon~=nil and module.offHandMode=='shared'
    result.pose.hasMainWeapon=weapon~=nil;result.pose.hasOffWeapon=offhand~=nil
    result.pose.attackActionId=grip and grip.attackActionId~=0 and grip.attackActionId or module.attackActionId
    result.pose.primaryGrip=result.weapon and result.weapon.primaryGrip or {position={0,0,0},rotation={0,0,0}}
    result.pose.secondaryGrip=result.pose.offHandFollowsWeapon and result.weapon.secondaryGrip or result.offhand and result.offhand.primaryGrip or {position={0,0,0},rotation={0,0,0}}
    result.pose.weaponRotationOffset=weapon and vector(self.motion:RotationOffset(weapon.ItemId,module.id,'main')) or {0,0,0}
    result.pose.offWeaponRotationOffset=offhand and vector(self.motion:RotationOffset(offhand.ItemId,module.id,'off')) or {0,0,0}
    for _,key in ipairs({'mainShoulder','mainElbow','mainHand','offShoulder','offElbow','offHand','weaponRotation'}) do result.pose[key]=vector(pose[key]) end
    local offPose=offhand and self.poses:Get(self.motion:Grip(self.weapons:Get(offhand.ItemId)).poseId) or pose
    result.pose.offWeaponRotation=vector(offPose.weaponRotation);result.pose.offWeaponRotation[3]=-result.pose.offWeaponRotation[3]
    local action=self.actions:Get(actor and actor.ActionTemplateId or 0)
    result.action={sequence=actor and actor.ActionSequence or 0,kind=action.kind,duration=action.duration,recoil=action.recoil,
        pitch=action.pitch,yaw=action.yaw,roll=action.roll,handLift=action.handLift,magazineDrop=action.magazineDrop,shots=actor and actor.ActionShots or 1,
        targetQ=actor and actor.ActionTargetQ or 0,targetR=actor and actor.ActionTargetR or 0}
    return result
end
return Rules
