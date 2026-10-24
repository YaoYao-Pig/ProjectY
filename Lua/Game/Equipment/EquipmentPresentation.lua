local LuaLanguage = require('Language')
-- Read-only equipment typography shared by inventory, loot and workbench projections.
local Text={colors={label='#A7B7C9',value='#EDF2F7',muted='#7F91A7',positive='#76D6AE',negative='#F19A96',accent='#E9C580'}}
function Text.Escape(value) return tostring(value):gsub('<','＜'):gsub('>','＞') end
function Text.Paint(value,color,size)
    local text='<color='..color..'>'..Text.Escape(value)..'</color>'
    return size and '<size='..size..'>'..text..'</size>' or text
end
function Text.Heading(value) return Text.Paint(value,Text.colors.accent,12) end
function Text.Note(value) return Text.Paint(value,Text.colors.muted,11) end
function Text.Value(label,value,color)
    return Text.Paint(label,Text.colors.label,13)..'  '..Text.Paint(value,color or Text.colors.value,16)
end
function Text.Signed(label,value,suffix)
    return Text.Value(label,string.format('%+g',value)..(suffix or ''),value<0 and Text.colors.negative or Text.colors.positive)
end
function Text.Name(rules,item)
    return Text.Paint('● '..rules.affixes:Name(item),rules.affixes:Color(item))
end
function Text.Affix(rules,item)
    local row=rules.affixes:Of(item);local lines={Text.Heading(LuaLanguage.UIEquipmentPresentationLines)..'  '..Text.Paint(row.name,rules.affixes:Color(item),12)}
    if row.damageMultiplier~=1 then lines[#lines+1]=Text.Signed(LuaLanguage.UIEquipmentPresentationLinesLines14,math.floor((row.damageMultiplier-1)*100+.5),'%') end
    if row.hitBonus~=0 then lines[#lines+1]=Text.Signed(LuaLanguage.UIEquipmentPresentationLinesLines13,row.hitBonus,LuaLanguage.UIEquipmentPresentationLinesLines12) end
    for i,id in ipairs(row.attributeIds) do lines[#lines+1]=Text.Signed(rules.attributes:Get(id).name,row.attributeValues[i]) end
    if #lines==1 then lines[#lines+1]=Text.Note(LuaLanguage.UIEquipmentPresentationLinesLines1) end
    return table.concat(lines,'\n')
end
function Text.Condition(rules,item)
    local condition=rules:Condition(item)
    local color=condition.Broken and Text.colors.negative or condition.Current*2<condition.Maximum and Text.colors.accent or Text.colors.positive
    local lines={Text.Heading(LuaLanguage.UIEquipmentPresentationLines3),Text.Value(LuaLanguage.UIEquipmentPresentationLines2,condition.Current..' / '..condition.Maximum,color)}
    lines[#lines+1]=Text.Note(string.format(LuaLanguage.UIEquipmentPresentationLinesLines17,math.floor(condition.Efficiency*100+.5)))
    if condition.Maximum<condition.BaseMaximum then lines[#lines+1]=Text.Note(string.format(LuaLanguage.UIEquipmentPresentationLinesLines16, (condition.BaseMaximum))) end
    if condition.Broken then lines[#lines+1]=Text.Paint(LuaLanguage.UIEquipmentPresentationLinesLines15,Text.colors.negative,12) end
    return table.concat(lines,'\n')
end
function Text.Requirements(rules,item,actor,stats)
    local lines={Text.Heading(LuaLanguage.UIEquipmentWorkbenchRequirementsText5)}
    if actor then
        local requirement=rules:ItemRequirements(actor,item.ItemId,stats,true)
        for _,entry in ipairs(requirement.entries) do
            lines[#lines+1]=Text.Value(entry.name,entry.current..' / '..entry.required,entry.current>=entry.required and Text.colors.positive or Text.colors.negative)
        end
        if #requirement.entries>0 then lines[#lines+1]=Text.Note(LuaLanguage.UIEquipmentPresentationLinesLines18) end
        if not requirement.met then lines[#lines+1]=Text.Paint(LuaLanguage.UIEquipmentWorkbenchRequirementsText2,Text.colors.negative,12) end
    else
        local definition=rules.items:Get(item.ItemId).kind=='weapon' and rules.weapons:Get(item.ItemId) or rules.wearables:Get(item.ItemId)
        local requirement=rules.requirements:Get(definition.requirementId)
        for i,id in ipairs(requirement.attributeIds) do lines[#lines+1]=Text.Value(rules.attributes:Get(id).name,requirement.values[i]) end
    end
    if #lines==1 then lines[#lines+1]=Text.Note(LuaLanguage.UIEquipmentWorkbenchRequirementsText4) end
    return table.concat(lines,'\n')
end
function Text.Attributes(rules,item)
    local lines={Text.Heading(LuaLanguage.UIEquipmentPresentationLines4)};local definition=rules.items:Get(item.ItemId)
    if definition.kind=='weapon' then
        local weapon=rules.weapons:Get(item.ItemId)
        if weapon.description~='' then lines[#lines+1]=Text.Paint(weapon.description,Text.colors.label,12) end
        lines[#lines+1]=Text.Value(LuaLanguage.UISkillTipText12,string.format('× %.2f',weapon.damageMultiplier*rules.affixes:Of(item).damageMultiplier*rules:Condition(item).Efficiency))
        lines[#lines+1]=Text.Note(string.format(LuaLanguage.EquipmentWeaponArmor,weapon.armorPenetration,weapon.armorDamageMultiplier))
        lines[#lines+1]=Text.Note(LuaLanguage.EquipmentArmorRule)
    end
    for _,attribute in ipairs(rules.attributes:All()) do
        local value=rules:ItemAttributeBonus(item,attribute.code)
        if value~=0 then lines[#lines+1]=Text.Signed(attribute.name,value) end
    end
    if #lines==1 then lines[#lines+1]=Text.Note(LuaLanguage.UIEquipmentPresentationLinesLines110) end
    lines[#lines+1]=Text.Note(LuaLanguage.UIEquipmentPresentationLinesLines19)
    return table.concat(lines,'\n')
end
function Text.AmmoStats(rules,itemId)
    local ammo=rules.ammunition:Get(itemId)
    return string.format(LuaLanguage.EquipmentAmmoStats,ammo.fleshDamageMultiplier,ammo.armorDamageMultiplier,ammo.armorPenetrationBonus)
end
function Text.Ammunition(rules,itemId)
    local ammo=rules.ammunition:Get(itemId)
    return Text.Paint(ammo.description,Text.colors.label,12)..'\n'..Text.Note(Text.AmmoStats(rules,itemId))
end
function Text.MagazineSummary(rules,magazine)
    return string.format(LuaLanguage.EquipmentMagazineSummary,rules.ammunition:Get(magazine.AmmoItemId).name,magazine.Rounds,magazine.Capacity)
end
function Text.Magazine(rules,magazine)
    return Text.Paint(Text.MagazineSummary(rules,magazine),Text.colors.value,13)..'\n'..Text.Ammunition(rules,magazine.AmmoItemId)
end
function Text.Details(rules,item,actor,stats)
    local kind=rules.items:Get(item.ItemId).kind;local category
    if kind=='weapon' then
        local weapon=rules.weapons:Get(item.ItemId)
        category=rules.categories:Get(weapon.categoryId).name..' · Lv.'..weapon.level..' · '..(weapon.hands==1 and LuaLanguage.UIEquipmentPresentationCategory2 or LuaLanguage.UIEquipmentPresentationCategory)
    else
        local slots={head=LuaLanguage.UIEquipmentPresentationHead,body=LuaLanguage.UIEquipmentPresentationBody,legs=LuaLanguage.UIEquipmentPresentationLegs,feet=LuaLanguage.UIEquipmentPresentationFeet,offhand=LuaLanguage.UIEquipmentPresentationOffhand,ring=LuaLanguage.UIEquipmentPresentationRing}
        category=assert(slots[rules.wearables:Get(item.ItemId).slot])
    end
    return table.concat({Text.Note(category),Text.Attributes(rules,item),Text.Affix(rules,item),Text.Condition(rules,item),Text.Requirements(rules,item,actor,stats)},'\n\n')
end
function Text.Attachment(rules,itemId)
    local row=rules.runes:Get(itemId)
    local slots={head=LuaLanguage.UIEquipmentPresentationHead2,shaft=LuaLanguage.UIEquipmentPresentationShaft,thruster=LuaLanguage.UIEquipmentPresentationThruster,catalyst=LuaLanguage.UIEquipmentPresentationCatalyst,rail=LuaLanguage.UIEquipmentPresentationRail,edge=LuaLanguage.UIEquipmentPresentationEdge,
        grip=LuaLanguage.UIEquipmentPresentationGrip,pommel=LuaLanguage.UIEquipmentPresentationPommel,bowlimb=LuaLanguage.UIEquipmentPresentationBowlimb,bowstring=LuaLanguage.UIEquipmentPresentationBowstring,muzzle=LuaLanguage.UIEquipmentPresentationMuzzle,stock=LuaLanguage.UIEquipmentPresentationStock}
    local lines={Text.Note(assert(slots[row.slotKind])),Text.Paint(row.description,Text.colors.label,12),Text.Heading(LuaLanguage.UIEquipmentPresentationLines5)}
    if row.damageMultiplier~=1 then lines[#lines+1]=Text.Signed(LuaLanguage.UIEquipmentPresentationLinesLines120,math.floor((row.damageMultiplier-1)*100+.5),'%') end
    if row.rangeBonus~=0 then lines[#lines+1]=Text.Signed(LuaLanguage.UISkillTipText17,row.rangeBonus,LuaLanguage.UIEquipmentPresentationLinesLines119) end
    if row.hitBonus~=0 then lines[#lines+1]=Text.Signed(LuaLanguage.UIEquipmentPresentationLinesLines13,row.hitBonus,LuaLanguage.UIEquipmentPresentationLinesLines12) end
    if row.cooldownBonus~=0 then lines[#lines+1]=Text.Value(LuaLanguage.UISkillTipText10,string.format(LuaLanguage.UIEquipmentPresentationLinesLines118,row.cooldownBonus),row.cooldownBonus<0 and Text.colors.positive or Text.colors.negative) end
    if row.maxTargets>1 then lines[#lines+1]=Text.Value(LuaLanguage.UIEquipmentPresentationLinesLines117,string.format(LuaLanguage.UIEquipmentPresentationLinesLines116, (row.splashRadius), (row.maxTargets))) end
    if row.transferSelf then
        lines[#lines+1]=Text.Value(LuaLanguage.UISkillTipMechanicsMechanics1,string.format(LuaLanguage.UIEquipmentPresentationLinesLines115, (row.transferRange)))
        lines[#lines+1]=Text.Note(LuaLanguage.UIEquipmentPresentationLinesLines114)
    end
    for _,id in ipairs(row.onHitEffectIds)do
        local effect=rules.effects:Get(id)
        local name=effect.kind=='apply_buff' and rules.buffDefinitions:Get(effect.buffId).name or effect.name
        local target=effect.recipient=='source' and LuaLanguage.UIEquipmentPresentationTarget or ''
        lines[#lines+1]=Text.Value(LuaLanguage.UIEquipmentPresentationLinesLines113,effect.chance..'% '..target..name)
        if #effect.requiredTags>0 or #effect.forbiddenTags>0 then lines[#lines+1]=Text.Note(effect.description) end
    end
    if row.requiredTalentId>0 then lines[#lines+1]=Text.Note(string.format(LuaLanguage.UIEquipmentPresentationLinesLines112, (rules.passives:Get(rules.talents:Get(row.requiredTalentId).passiveId).name))) end
    lines[#lines+1]=Text.Note(LuaLanguage.UIEquipmentPresentationLinesLines111)
    return table.concat(lines,'\n')
end
return Text
