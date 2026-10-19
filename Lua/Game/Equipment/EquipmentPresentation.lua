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
    local row=rules.affixes:Of(item);local lines={Text.Heading('品质效果')..'  '..Text.Paint(row.name,rules.affixes:Color(item),12)}
    if row.damageMultiplier~=1 then lines[#lines+1]=Text.Signed('伤害',math.floor((row.damageMultiplier-1)*100+.5),'%') end
    if row.hitBonus~=0 then lines[#lines+1]=Text.Signed('命中',row.hitBonus,' 个百分点') end
    for i,id in ipairs(row.attributeIds) do lines[#lines+1]=Text.Signed(rules.attributes:Get(id).name,row.attributeValues[i]) end
    if #lines==1 then lines[#lines+1]=Text.Note('无额外属性修正') end
    return table.concat(lines,'\n')
end
function Text.Condition(rules,item)
    local condition=rules:Condition(item)
    local color=condition.Broken and Text.colors.negative or condition.Current*2<condition.Maximum and Text.colors.accent or Text.colors.positive
    local lines={Text.Heading('装备状态'),Text.Value('耐久',condition.Current..' / '..condition.Maximum,color)}
    lines[#lines+1]=Text.Note(string.format('效能 %d%%',math.floor(condition.Efficiency*100+.5)))
    if condition.Maximum<condition.BaseMaximum then lines[#lines+1]=Text.Note('原始耐久上限 '..condition.BaseMaximum..' · 已有永久损伤') end
    if condition.Broken then lines[#lines+1]=Text.Paint('已损毁 · 维修后可用',Text.colors.negative,12) end
    return table.concat(lines,'\n')
end
function Text.Requirements(rules,item,actor,stats)
    local lines={Text.Heading('装备要求')}
    if actor then
        local requirement=rules:ItemRequirements(actor,item.ItemId,stats,true)
        for _,entry in ipairs(requirement.entries) do
            lines[#lines+1]=Text.Value(entry.name,entry.current..' / '..entry.required,entry.current>=entry.required and Text.colors.positive or Text.colors.negative)
        end
        if #requirement.entries>0 then lines[#lines+1]=Text.Note('当前值 / 需求 · 不含装备加成') end
        if not requirement.met then lines[#lines+1]=Text.Paint('属性不足，无法装备',Text.colors.negative,12) end
    else
        local definition=rules.items:Get(item.ItemId).kind=='weapon' and rules.weapons:Get(item.ItemId) or rules.wearables:Get(item.ItemId)
        local requirement=rules.requirements:Get(definition.requirementId)
        for i,id in ipairs(requirement.attributeIds) do lines[#lines+1]=Text.Value(rules.attributes:Get(id).name,requirement.values[i]) end
    end
    if #lines==1 then lines[#lines+1]=Text.Note('无属性限制') end
    return table.concat(lines,'\n')
end
function Text.Attributes(rules,item)
    local lines={Text.Heading('装备属性')};local definition=rules.items:Get(item.ItemId)
    if definition.kind=='weapon' then
        local weapon=rules.weapons:Get(item.ItemId)
        if weapon.description~='' then lines[#lines+1]=Text.Paint(weapon.description,Text.colors.label,12) end
        lines[#lines+1]=Text.Value('伤害倍率',string.format('× %.2f',weapon.damageMultiplier*rules.affixes:Of(item).damageMultiplier*rules:Condition(item).Efficiency))
    end
    for _,attribute in ipairs(rules.attributes:All()) do
        local value=rules:ItemAttributeBonus(item,attribute.code)
        if value~=0 then lines[#lines+1]=Text.Signed(attribute.name,value) end
    end
    if #lines==1 then lines[#lines+1]=Text.Note('当前无有效属性加成') end
    lines[#lines+1]=Text.Note('已计入品质与当前耐久')
    return table.concat(lines,'\n')
end
function Text.Details(rules,item,actor,stats)
    local kind=rules.items:Get(item.ItemId).kind;local category
    if kind=='weapon' then
        local weapon=rules.weapons:Get(item.ItemId)
        category=rules.categories:Get(weapon.categoryId).name..' · Lv.'..weapon.level..' · '..(weapon.hands==1 and '单手' or '双手')
    else
        local slots={head='头部护具',body='身体护甲',legs='腿部护具',feet='足部护具',offhand='盾牌',ring='戒指'}
        category=assert(slots[rules.wearables:Get(item.ItemId).slot])
    end
    return table.concat({Text.Note(category),Text.Attributes(rules,item),Text.Affix(rules,item),Text.Condition(rules,item),Text.Requirements(rules,item,actor,stats)},'\n\n')
end
function Text.Attachment(rules,itemId)
    local row=rules.runes:Get(itemId)
    local slots={head='法杖 · 杖头',shaft='法杖 · 杖身',thruster='巨剑 · 剑脊机械组件',catalyst='单手剑 · 奥术触媒',rail='步枪/弓 · 导轨',edge='近战武器 · 刃部组件',
        grip='近战武器 · 握柄组件',pommel='近战武器 · 柄尾配重',bowlimb='弓 · 弓臂组件',bowstring='弓 · 弓弦组件',muzzle='步枪 · 枪口组件',stock='步枪 · 枪托组件'}
    local lines={Text.Note(assert(slots[row.slotKind])),Text.Paint(row.description,Text.colors.label,12),Text.Heading('改装效果')}
    if row.damageMultiplier~=1 then lines[#lines+1]=Text.Signed('技能伤害',math.floor((row.damageMultiplier-1)*100+.5),'%') end
    if row.rangeBonus~=0 then lines[#lines+1]=Text.Signed('射程',row.rangeBonus,' 格') end
    if row.hitBonus~=0 then lines[#lines+1]=Text.Signed('命中',row.hitBonus,' 个百分点') end
    if row.cooldownBonus~=0 then lines[#lines+1]=Text.Value('冷却',string.format('%+d 回合',row.cooldownBonus),row.cooldownBonus<0 and Text.colors.positive or Text.colors.negative) end
    if row.maxTargets>1 then lines[#lines+1]=Text.Value('扩散',row.splashRadius..' 格内 · 目标上限至少 '..row.maxTargets..' 人') end
    if row.transferSelf then
        lines[#lines+1]=Text.Value('转施',row.transferRange..' 格内任意角色')
        lines[#lines+1]=Text.Note('仅影响允许转施的自身法术；可选择自己、队友或敌人，保留原行动消耗。')
    end
    for _,id in ipairs(row.onHitEffectIds)do
        local effect=rules.effects:Get(id)
        local name=effect.kind=='apply_buff' and rules.buffDefinitions:Get(effect.buffId).name or effect.name
        local target=effect.recipient=='source' and '自身：' or ''
        lines[#lines+1]=Text.Value('伤害命中后',effect.chance..'% '..target..name)
        if #effect.requiredTags>0 or #effect.forbiddenTags>0 then lines[#lines+1]=Text.Note(effect.description) end
    end
    if row.requiredTalentId>0 then lines[#lines+1]=Text.Note('需要专精：'..rules.passives:Get(rules.talents:Get(row.requiredTalentId).passiveId).name) end
    lines[#lines+1]=Text.Note('在武器改装界面选择对应挂点安装')
    return table.concat(lines,'\n')
end
return Text
