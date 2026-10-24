package.path='Lua/?.lua;'..package.path
local EmptyGrowth=assert(loadfile('Tools/Tests/growth_empty.lua'))()
local Gear=assert(loadfile('Tools/Tests/equipment_read_fixture.lua'))()
CS.ProjectY.Data.SkillSynergyDiscovery={Has=function()return false end}
assert(loadfile('Tools/Tests/battle_movement_fixture.lua'))()
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local f=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=f:read('*a');f:close();return bytes
end}})
local battle=require('Game.Battle.BattleSystem')()
battle.skills=config:GetTable('CombatSkillTable');battle.effects=config:GetTable('CombatEffectTable')
battle.encounters=config:GetTable('CombatEncounterTable');battle.consumables=config:GetTable('ConsumableTable')
battle.stats=require('Game.Battle.CombatStats')(config)
battle.board=require('Game.Battle.BattleBoard').Create(5,12,0)
local spear=Gear(1,742,1)
battle.stats.equipment.data={WearableCount=0,Equipped=function()return spear end,Offhand=function()end,Worn=function()end,CountItem=function()return 0 end}
battle.gameEffects=require('Game.Battle.GameEffects').New(battle.stats,config:GetTable('CombatEffectTable'))
local function actor(id,side,q)
    return {Id=id,TemplateId=1,Team=side,HP=30,MaxHP=30,AP=4,Guard=0,Q=q,R=0,TraitCount=0,
        AnimalOwnerId=0,AnimalSpeciesId=0,Effects={Count=0},Growth=EmptyGrowth(),MainUsed=false,Moved=false,
        GetCooldown=function()return 0 end,SpendAction=function()error('Invalid target spent an action')end}
end
local source,target=actor(1,1,0),actor(101,2,1);local units={source,target}
battle.data={Phase='combat',Winner='',ActiveId=1,UnitCount=2,Round=1,TurnCount=2,TurnIndex=0,MaxRounds=20,EncounterId=1,LogCount=0,
    GetUnitAt=function(_,i)return units[i+1]end,GetTurnAt=function(_,i)return units[i+1].Id end,
    RollPercent=function()error('Invalid target consumed RNG')end}
local skill=battle:Skill(source,1625)
assert(skill.range==2 and skill.minRange==2 and skill.fixedRange)
local ok,why=battle:TrySkill(1625,target.Id)
assert(not ok and why:find('过近') and source.AP==4 and not source.MainUsed)
target.Q=2;assert(battle:CanUseSkill(1625,target.Id))
target.Q=3;assert(not battle:CanUseSkill(1625,target.Id))
local high,low=battle.board:Find(0,0),battle.board:Find(3,0);high.height=4;low.height=0
assert(battle.stats.heightAdvantage:RangeBonus(high,low,skill)==0)
assert(require('Game.Battle.Construction').RangeBonusAt({},battle.board,source,low,skill)==0)
assert(battle.stats.heightAdvantage:RangeBonus(high,low,battle.skills:Get(2))>0,'Existing ranged elevation bonus changed')
assert(not battle.stats.heightAdvantage:Description(skill):find('远程射程'))
print('PASS spear 1/2/3-cell boundaries, no invalid AP/RNG spending, fixed high-ground reach')

local animal
for _,row in ipairs(config:GetTable('CombatBodyTable'):All())do if #row.footprintQ>1 then animal=row;break end end
assert(animal);target.TemplateId=animal.unitId;target.Q=1
assert(not battle:CanUseSkill(1625,target.Id),'A far part of a touching multi-cell target bypassed the minimum')
target.TemplateId=1;target.Q=2
local hud=require('Game.Battle.BattleHUDModel').Build(battle,{PartyCount=1,GetPartyAt=function()return source end})
local action;for _,row in ipairs(hud.skills)do if row.id==1625 then action=row end end
assert(action and action.available)
local tip=require('Game.Presentation.SkillTipModel').New(config):Build(action)
local minimum=false;for _,stat in ipairs(tip.stats)do if stat.label=='最小距离' then minimum=stat.value=='2 格' end end
assert(minimum,'Tooltip omits the dead zone')
target.Q=1
local cells=battle:ApproachCells(source,target);assert(#cells>0)
local retreat=false
for _,cell in ipairs(cells)do
    assert(require('Game.Map.HexGrid').Distance(cell.q,cell.r,target.Q,target.R)==2,'AI planned an adjacent spear attack')
    if cell.q==-1 and cell.r==0 then retreat=true end
end
assert(retreat and source.Q==0 and source.AP==4,'Spacing search mutated the actor or missed a retreat')
print('PASS multi-cell nearest distance, target HUD, tooltip, AI retreat candidates and query immutability')

local board=battle.board;target.Q=2
local physical={MaxDurability=20,Destroyed=false,Unlocked=true,CellCount=1,GetCellAt=function()return board:Find(target.Q,0).index end}
local state={Revision=1};local container={Id=1}
for i,cell in ipairs(board.cells)do cell.index=i;cell.layer=0 end
board.area={containerState=state,CanSee=function()return true end};board.originLayer=0
for _,cell in ipairs(board.cells)do board.byKey[require('Game.Map.HexGrid').Key(cell.q,cell.r)..':0']=cell end
local areas={data={Active=state},ActiveLayout=function()return board end}
local combat=setmetatable({adventure={data={Areas={ActiveSiteId=1}},areas=areas,battle=battle},
    loot={Find=function()return container end,SyncLock=function()return physical end},visibleState=state,visibleRevision=1,visibleCells={}},
    require('Game.Loot.ContainerCombat'))
board.byIndex={};for _,cell in ipairs(board.cells)do board.byIndex[cell.index]=cell;combat.visibleCells[cell.index]=true end
assert(combat:Target(source,skill,1,battle))
target.Q=1;assert(not combat:Target(source,skill,1,battle))
target.Q=3;assert(not combat:Target(source,skill,1,battle))
local weapon=config:GetTable('EquipmentWeaponTable'):Get(742)
assert(weapon.hands==2 and weapon.offhandSkillId==0 and battle.stats.equipment.motion:Resolve(weapon,nil,nil).code=='spear')
assert(not pcall(function()battle.stats.equipment.motion:Resolve(weapon,nil,{})end))
local stocked=false;for _,row in ipairs(config:GetTable('ShopEntryTable'):All())do if row.itemId==742 then stocked=row.chance==100 end end
assert(stocked and config:GetTable('SkillDescriptionTable'):Get(1625))
print('PASS container dead zone, two-handed motion, shield conflict and shop registration')
