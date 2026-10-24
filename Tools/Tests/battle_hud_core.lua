local EmptyGrowth=assert(loadfile('Tools/Tests/growth_empty.lua'))()
local Gear=assert(loadfile('Tools/Tests/equipment_read_fixture.lua'))()
assert(loadfile('Tools/Tests/battle_movement_fixture.lua'))()
-- Targeted, editor-free projection checks against the real config and skill rules.
package.path = 'Lua/?.lua;' .. package.path
local config = require('Config.ConfigSystem')()
config:OnInit({services = {ReadConfig = function(_, name)
    local file = assert(io.open('Assets/GameFramework/Resources/_Gen/Config/' .. name .. '.bytes', 'rb'))
    local bytes = file:read('*a'); file:close(); return bytes
end}})
local battle = require('Game.Battle.BattleSystem')()
battle.skills = config:GetTable('CombatSkillTable'); battle.encounters = config:GetTable('CombatEncounterTable')
battle.consumables=config:GetTable('ConsumableTable');battle.effects=config:GetTable('CombatEffectTable')
battle.stats = require('Game.Battle.CombatStats')(config)
local bow=Gear(1,46,1)
battle.stats.equipment.data={WearableCount=0,Equipped=function(_,id)return id==1 and bow or nil end,Offhand=function()return nil end,Worn=function()return nil end,CountItem=function()return 0 end}
battle.gameEffects=require('Game.Battle.GameEffects').New(battle.stats,config:GetTable('CombatEffectTable'))
battle.board = require('Game.Battle.BattleBoard').Create(4, 123, 0)
local hero = {Id=1,Growth=EmptyGrowth(),TemplateId=2,Team=1,HP=32,MaxHP=38,AP=4,Guard=3,Moved=false,MainUsed=false,TraitCount=0,Q=-1,R=0}
local down = {Id=2,Growth=EmptyGrowth(),TemplateId=3,Team=1,HP=0,MaxHP=34,AP=0,Guard=0,Moved=false,MainUsed=false,TraitCount=0,Q=-2,R=0}
local enemy = {Id=101,Growth=EmptyGrowth(),TemplateId=4,Team=2,HP=24,MaxHP=34,AP=4,Guard=0,Moved=false,MainUsed=false,TraitCount=0,Q=0,R=0}
local units = {hero,down,enemy}; local order = {1,101,2}
for _,unit in ipairs(units) do unit.AnimalOwnerId=0;unit.Effects={Count=0};function unit:GetCooldown() return 0 end end
battle.data = {Phase='combat',Winner='',ActiveId=1,UnitCount=3,TurnCount=3,TurnIndex=0,Round=3,MaxRounds=18,EncounterId=1,LogCount=2,
    GetUnitAt=function(_,i) return units[i+1] end,GetTurnAt=function(_,i) return order[i+1] end,
    GetLogAt=function(_,i) return ({'first','second'})[i+1] end}
local adventure = {PartyCount=2,GetPartyAt=function(_,i) return units[i+1] end}
local build = require('Game.Battle.BattleHUDModel').Build
local function action(view,id)for _,row in ipairs(view.skills)do if row.id==id then return row end end;error('Missing HUD action '..id)end
local view = build(battle,adventure)
assert(view.hp==32 and view.maxHP==38 and view.ap==4 and view.maxAP==4 and view.guard==3 and view.defense==2)
assert(#view.party==2 and view.party[2].hp==0 and #view.turns==2 and view.turns[1].active)
assert(view.moveAvailable and view.skills[1].available and view.skills[2].available and #view.logs==2)
assert(hero.AP==4 and hero.HP==32 and not hero.Moved and not hero.MainUsed)
print('PASS real resources, dead party members, living initiative and read-only projection')
hero.MainUsed=true
view=build(battle,adventure);assert(not action(view,2).available and action(view,2).reason:find('主要行动') and action(view,4).available)
hero.MainUsed=false;hero.AP=0
view=build(battle,adventure);assert(not view.moveAvailable and not action(view,4).available and action(view,4).reason:find('行动点'))
hero.AP=4;enemy.Q=4;enemy.R=0
view=build(battle,adventure);assert(not action(view,2).available and action(view,2).reason:find('距离'))
battle.data.ActiveId=101;battle.data.TurnIndex=1
view=build(battle,adventure);assert(not view.player and not view.moveAvailable and not view.skills[1].available and view.turns[1].active)
print('PASS main-action, AP, range and enemy-turn gating through actual battle rules')
local icons=config:GetTable('BattleIconTable')
local checkedIcons={}
local function checkIcon(icon)
    if checkedIcons[icon.id] then return end
    checkedIcons[icon.id]=true
    local path=icon.spritePath
    assert(type(path)=='string','Battle icon path must be a string: '..icon.id)
    if path=='' then return end
    assert(path:sub(1,7)=='Assets/' and not path:find('\\',1,true),'Battle icon must be under Assets/: '..path)
    for segment in path:gmatch('[^/]+') do assert(segment~='.' and segment~='..','Invalid battle icon path: '..path) end
    local file=assert(io.open(path,'rb'),'Missing battle icon PNG: '..path)
    local signature=file:read(8);file:close()
    assert(signature=='\137PNG\r\n\26\n','Battle icon must be a PNG: '..path)
end
for _,skill in ipairs(battle.skills:All()) do checkIcon(icons:Get(skill.iconId)) end
local recipes=config:GetTable('SkillIconRecipeTable')
for _,recipe in ipairs(recipes:All()) do
    local skill=battle.skills:Get(recipe.skillId)
    local published=icons:Find(recipe.id)
    if published then
        assert(skill.iconId==recipe.id,'Published skill icon mapping differs from recipe: '..recipe.id)
        assert(published.spritePath~='','Published skill icon has no PNG: '..recipe.id)
        checkIcon(published)
    end
end
local hud=config:GetTable('BattleHUDTable'):Get(1);assert(#hud.itemIconIds==4)
for _,id in ipairs(hud.itemIconIds) do assert(icons:Get(id).spritePath=='') end
print('PASS skill/icon references, published recipe PNGs and four configurable empty item slots')
for _,path in ipairs({'Lua/UI/Panel/BattleHUDCtr.lua','Lua/UI/Widget/BattleAction.lua','Lua/UI/Widget/BattleUnit.lua','Lua/UI/BattleHUDBridge.lua'}) do assert(loadfile(path)) end
