-- Display-only formatting of settled facts. Never parses prose or rolls gameplay randomness.
local Log={}
local color={muted='#95A3B6',action='#E9C580',value='#EDF2F7',good='#76D6AE',bad='#F19A96',check='#BDA8E8',ally='#80CFE0',enemy='#F09283',neutral='#E5CD80'}
local function escape(value)return tostring(value):gsub('<','＜'):gsub('>','＞')end
local function paint(value,tint,size)return '<color='..tint..'><size='..(size or 14)..'>'..escape(value)..'</size></color>'end
local function actor(row)return paint(row.name,(row.team==1 or row.team==4) and color.ally or row.team==2 and color.enemy or color.neutral)end
local function number(value)return string.format('%g',value)end
local function value(text,tint)return paint(text,tint or color.value,15)end
local function action(text)return paint(text,color.action)end
local function note(text)return paint(text,color.muted,12)end
function Log.Format(kind,message,source,target,amount,details)
    local d=details or {}
    local who=source and actor(source) or nil
    local whom=target and actor(target) or d.targetName and paint(d.targetName,color.neutral)
    local prefix=(who and who..' ' or '')..(d.actionName and action(d.actionName)..' ' or '')..(whom and '→ '..whom..'  ' or '')
    if kind=='check' then
        local chance=assert(d.chance,'Check log needs its actual threshold')
        local text=prefix..paint(d.checkName or '判定',color.check)..' '..value(number(chance)..'/100',color.check)..note(' ('..number(chance)..'%)')
        if d.baseChance and d.baseChance~=chance then text=text..note(' · 基础 '..number(d.baseChance)..'/100')end
        if d.roll~=nil then text=text..note(' · 掷值 ')..value(number(d.roll)..'/100') end
        if d.comparison then for _,entry in ipairs(d.comparison)do text=text..note(' · '..entry.name..' ')..value(entry.value)end end
        return text..'  '..paint(d.passed and (d.successLabel or '通过') or (d.failureLabel or '未通过'),d.passed and color.good or color.bad)
    end
    if kind=='damage' or kind=='heal' or kind=='guard' then
        local verb=kind=='damage' and (d.periodic and '持续伤害' or '伤害') or kind=='heal' and '治疗' or '护卫'
        local tint=kind=='damage' and (d.damageColor and d.damageColor~='' and d.damageColor or color.bad) or color.good
        local text=prefix..action(verb)..' '..value(assert(amount),tint)
        if kind=='guard' and d.guardAfter~=nil then return prefix..action(verb)..' '..value(d.guardAfter,color.good)..note('（原 '..number(d.guardBefore)..'）')end
        if d.hpAfter~=nil and d.maxHP then
            text=text..note(' · 生命 ')..value(number(d.hpAfter)..'/'..number(d.maxHP))
            if d.hpBefore~=nil then text=text..note('（原 '..number(d.hpBefore)..'）')end
        end
        if kind=='damage' and d.defense~=nil then text=text..note(' · 防御 ')..value(d.defense)..note(' / 护卫 ')..value(d.guard or 0)end
        if d.shot and d.shot>1 then text=text..note(' · 第'..d.shot..'发')end
        return text
    end
    if kind=='effect_added' then
        local text=prefix..action('获得状态')..' '..paint(assert(d.statusName),d.color or color.check)
        if d.stacks and d.stacks>1 then text=text..' '..value('×'..d.stacks)end
        if d.durationTurns then text=text..note(' · ')..value(d.durationTurns)..note(' 回合')end
        if d.durationMinutes then text=text..note(' · ')..value(d.durationMinutes)..note(' 分钟')end
        return text
    end
    if kind=='effect_blocked' or kind=='immune' then
        return prefix..paint(d.statusName or '效果',color.check)..' '..paint('未生效',color.bad)..note(' · '..assert(d.reason))
    end
    if kind=='effect_removed' and d.statusName then return prefix..action('状态结束')..' '..paint(d.statusName,d.color or color.check)end
    if kind=='miss' then return prefix..paint('未命中',color.bad)end
    if kind=='opportunity_attack' then return prefix..note('移动前反应')end
    if kind=='reload' then return prefix..action('装入弹药')..' '..value(amount)..note(' 发')end
    if kind=='disarmed' then return prefix..paint('缴械成功',color.good)..note(' · 武器落在脚下')end
    if kind=='intercepted' then return prefix..paint('弹体被拦截',color.bad)end
    if kind=='defeated' or kind=='mount_defeated' then return (whom or who or '')..' '..paint('倒地',color.bad)end
    if kind=='skill_used' then return prefix..action('施放')..note(d.cost and (' · AP -'..d.cost) or '')end
    if kind=='container_damage' and d.targetName then
        return prefix..action('结构伤害')..' '..value(amount,color.bad)..note(' · 耐久 ')..value(number(d.remaining)..'/'..number(d.maximum))
    end
    return paint(message,color.muted)
end
return Log
