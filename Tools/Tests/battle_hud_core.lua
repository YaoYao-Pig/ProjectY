-- Targeted, editor-free projection checks against the real config and skill rules.
package.path = 'Lua/?.lua;' .. package.path
local config = require('Config.ConfigSystem')()
config:OnInit({services = {ReadConfig = function(_, name)
    local file = assert(io.open('Assets/GameFramework/Resources/_Gen/Config/' .. name .. '.bytes', 'rb'))
    local bytes = file:read('*a'); file:close(); return bytes
end}})
local battle = require('Game.Battle.BattleSystem')()
battle.skills = config:GetTable('CombatSkillTable'); battle.encounters = config:GetTable('CombatEncounterTable')
battle.stats = require('Game.Battle.CombatStats')(config)
battle.board = require('Game.Battle.BattleBoard').Create(4, 123, 0)
local hero = {Id=1,TemplateId=2,Team=1,HP=32,MaxHP=38,AP=4,Guard=3,Moved=false,MainUsed=false,TraitCount=0,Q=-1,R=0}
local down = {Id=2,TemplateId=3,Team=1,HP=0,MaxHP=34,AP=0,Guard=0,Moved=false,MainUsed=false,TraitCount=0,Q=-2,R=0}
local enemy = {Id=101,TemplateId=4,Team=2,HP=24,MaxHP=34,AP=4,Guard=0,Moved=false,MainUsed=false,TraitCount=0,Q=0,R=0}
local units = {hero,down,enemy}; local order = {1,101,2}
for _,unit in ipairs(units) do function unit:GetCooldown() return 0 end end
battle.data = {Winner='',ActiveId=1,UnitCount=3,TurnCount=3,TurnIndex=0,Round=3,MaxRounds=18,EncounterId=1,LogCount=2,
    GetUnitAt=function(_,i) return units[i+1] end,GetTurnAt=function(_,i) return order[i+1] end,
    GetLogAt=function(_,i) return ({'first','second'})[i+1] end}
local adventure = {PartyCount=2,GetPartyAt=function(_,i) return units[i+1] end}
local build = require('Game.Battle.BattleHUDModel').Build
local view = build(battle,adventure)
assert(view.hp==32 and view.maxHP==38 and view.ap==4 and view.maxAP==4 and view.guard==3 and view.defense==2)
assert(#view.party==2 and view.party[2].hp==0 and #view.turns==2 and view.turns[1].active)
assert(view.moveAvailable and view.skills[1].available and view.skills[2].available and #view.logs==2)
assert(hero.AP==4 and hero.HP==32 and not hero.Moved and not hero.MainUsed)
print('PASS real resources, dead party members, living initiative and read-only projection')
hero.MainUsed=true
view=build(battle,adventure);assert(not view.skills[1].available and view.skills[1].reason:find('主要行动') and view.skills[2].available)
hero.MainUsed=false;hero.AP=0
view=build(battle,adventure);assert(not view.moveAvailable and not view.skills[2].available and view.skills[2].reason:find('行动点'))
hero.AP=4;enemy.Q=4;enemy.R=0
view=build(battle,adventure);assert(not view.skills[1].available and view.skills[1].reason:find('距离'))
battle.data.ActiveId=101;battle.data.TurnIndex=1
view=build(battle,adventure);assert(not view.player and not view.moveAvailable and not view.skills[1].available and view.turns[1].acted)
print('PASS main-action, AP, range and enemy-turn gating through actual battle rules')
local icons=config:GetTable('BattleIconTable')
for _,skill in ipairs(battle.skills:All()) do assert(icons:Get(skill.iconId).spritePath=='') end
local hud=config:GetTable('BattleHUDTable'):Get(1);assert(#hud.itemIconIds==4)
for _,id in ipairs(hud.itemIconIds) do assert(icons:Get(id).spritePath=='') end
print('PASS skill/icon references and four configurable empty item slots')
for _,path in ipairs({'Lua/UI/Panel/BattleHUDCtr.lua','Lua/UI/Widget/BattleAction.lua','Lua/UI/Widget/BattleUnit.lua','Lua/UI/BattleHUDBridge.lua'}) do assert(loadfile(path)) end
