-- Real exported configs and presentation/rule code; only native discovery and view I/O are substituted.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local known={};local writes=0
CS={ProjectY={Data={SkillSynergyDiscovery={
    Has=function(_,id)return known[id]==true end,
    Discover=function(_,id) if known[id] then return false end;known[id]=true;writes=writes+1;return true end
}},UI={}}}
local catalog=require('Game.Presentation.SkillTipCatalog').New(config)
for _,skill in ipairs(config:GetTable('CombatSkillTable'):All()) do
    local description=catalog:Description(skill.id)
    assert(#description.tags>0 and description.body~='','Missing configured skill presentation '..skill.id)
end
assert(catalog:Rich('<link="term:hit">命中</link>'):find('<u>',1,true))
assert(not pcall(function()catalog:Rich('<link="term:missing_term">broken</link>')end),'Missing term links must fail')
assert(catalog:Term('tracking').body:find('<link=',1,true),'Term drill-down must retain nested links')
local base=config:GetTable('CombatSkillTable'):Get(6)
local skill={};for key,value in pairs(base) do skill[key]=value end
skill.damageScale=.7;skill.maxTargets=3;skill.appliedRuneIds={11}
local row={skill=skill,cooldown=1,name=skill.name,available=true}
local model=require('Game.Presentation.SkillTipModel').New(config)
local data={}
local page=model:Build(row,data)
assert(writes==0 and #page.synergies>0,'Browsing cannot discover synergies')
for _,entry in ipairs(page.synergies) do assert(not entry.known and entry.name=='' and entry.body=='' and not entry.active,'Locked text leaked') end
local multiplier
for _,stat in ipairs(page.stats) do
    assert(stat.color:match('^#%x%x%x%x%x%x$'),'Every stat must have a valid presentation color')
    if stat.label=='伤害倍率' then multiplier=stat.value end
end
assert(multiplier=='× 0.70','Tooltip must use resolved equipment multiplier')
local synergies=model.synergies
local weaponConfig
for _,weapon in ipairs(config:GetTable('EquipmentWeaponTable'):All()) do
    for _,socket in ipairs(weapon.socketIds) do if config:GetTable('EquipmentSocketTable'):Get(socket).kind=='head' then weaponConfig=weapon;break end end
    if weaponConfig then break end
end
assert(weaponConfig)
local weapon={ItemId=weaponConfig.id,GetRune=function(_,socket)
    return config:GetTable('EquipmentSocketTable'):Get(socket).kind=='head' and 11 or 0
end}
synergies:Discover(data,weapon);assert(known[11] and writes==1)
synergies:Discover(data,weapon);assert(writes==1,'Repeated installation must be idempotent')
page=model:Build(row,data);assert(page.synergies[1].id==11 and page.synergies[1].known and page.synergies[1].active)
skill.appliedRuneIds={};page=model:Build(row,data);assert(page.synergies[1].known and not page.synergies[1].active,'Removal must retain discovery')
assert(not synergies:Applies(config:GetTable('SkillSynergyTable'):Get(721),base),'Transfer must not be offered on hostile spells')
assert(synergies:Applies(config:GetTable('SkillSynergyTable'):Get(93),base),'Pure catalyst support must remain discoverable')
local tracking=config:GetTable('CombatSkillTable'):Get(1624)
assert(not synergies:Applies(config:GetTable('SkillSynergyTable'):Get(501),tracking),'Non-damaging self spell ignores damage/hit modifiers')
assert(not synergies:Applies(config:GetTable('SkillSynergyTable'):Get(512),tracking),'Zero cooldown reduction is not an effect')
local combination={runeIds={11,12}};assert(not synergies:Assembled(combination,weapon),'Partial combinations must stay locked')

-- Exercise explicit command success/failure boundaries, with the actual command method.
local Equipment=require('Game.Equipment.EquipmentSystem')
local socket=weaponConfig.socketIds[1]
for _,id in ipairs(weaponConfig.socketIds) do if config:GetTable('EquipmentSocketTable'):Get(id).kind=='head' then socket=id end end
weapon.Id=1;weapon.OwnerActorId=1
local installed=false
local state={WeaponCount=1,GetWeaponAt=function()return weapon end,CountItem=function()return 1 end,
    SetRune=function()return installed end}
local controller=setmetatable({adventure={Phase='map'},data=state,synergies=synergies,
    rules={weapons=config:GetTable('EquipmentWeaponTable'),sockets=config:GetTable('EquipmentSocketTable'),runes=config:GetTable('EquipmentRuneTable')},
    Actor=function()return{}end,IsCarriedWeapon=function()return true end},{__index=Equipment})
known={};writes=0
assert(not controller:Command('attach',1,1,socket,11));assert(writes==0,'Rejected install discovered knowledge')
installed=true;assert(controller:Command('attach',1,1,socket,11));assert(known[11] and writes==1)

local bridge={};local queued='';local rendered;local visible=false
function bridge.Begin(_,title,body)rendered={title=title,body=body};queued='' end
function bridge.AddTag()end;function bridge.AddStat()end;function bridge.AddSynergy()end
function bridge.SetNavigation(_,back,breadcrumb)rendered.back=back end
function bridge.Show()visible=true end;function bridge.Hide()visible=false end
function bridge.KeepOpen()return visible end
function bridge.TakeLink()local id=queued;queued='';return id end
CS.ProjectY.UI.SkillTooltipPresentation=bridge
local presenter=require('UI.SkillTipPresenter').New({},config)
presenter:Show(row,data,{});assert(not rendered.back)
queued='term:tracking';presenter:Tick();assert(#presenter.stack==2 and rendered.back)
queued='term:hit';presenter:Tick();assert(#presenter.stack==3)
queued='term:tracking';presenter:Tick();assert(#presenter.stack==2,'Repeated nested link should return without an unbounded cycle')
queued='__back';presenter:Tick();assert(#presenter.stack==1 and rendered.title==skill.name)
presenter:Hide();assert(not visible and not presenter:KeepOpen() and #presenter.stack==0)
print('PASS tooltip real config coverage, colored links, resolved stat rows, hidden knowledge, installed-only discovery, combinations and nested navigation lifecycle')
