package.path='Lua/?.lua;'..package.path
local Loadout=require('Game.Equipment.InitialLoadout')
local function tableOf(rows)return {All=function()return rows end,Get=function(_,id)for _,r in ipairs(rows)do if r.id==id then return r end end;error('missing row')end}end
local rows={{id=1,unitId=8,weaponId=40,offhandWeaponId=41,wearableIds={51},appearanceJson=''}}
local tables={CharacterLoadoutTable=tableOf(rows),EquipmentWeaponTable=tableOf({{id=40,hands=1},{id=41,hands=1},{id=44,hands=2}}),EquipmentWearableTable=tableOf({{id=51,slot='head'},{id=57,slot='offhand'}})}
local config={GetTable=function(_,name)return assert(tables[name])end}
local loadout=Loadout.New(config)
local ids,counts=loadout:Items(8);assert(#ids==3 and ids[1]==40 and ids[2]==41 and ids[3]==51 and counts[3]==1)
assert(#loadout:Items(9)==0)
local calls={};local data={AddWeapon=function(_,id)calls[#calls+1]='weapon:'..id;return {Id=id+100}end,AddWearable=function(_,id)calls[#calls+1]='wearable:'..id;return {Id=id+100}end,
Equip=function(_,actor,id)assert(actor==10008 and id==140);return true end,EquipOffhand=function(_,actor,id)assert(actor==10008 and id==141);return true end,Wear=function(_,actor,slot,id)assert(actor==10008 and slot=='head' and id==151);return true end}
loadout:Apply(data,{Id=10008,TemplateId=8});assert(#calls==3)
rows[1].weaponId=44;assert(not pcall(Loadout.New,config));rows[1].weaponId=40
rows[1].wearableIds={51,51};assert(not pcall(Loadout.New,config));rows[1].wearableIds={51}
local Actions=require('Game.Narrative.NarrativeActions')
local state,mutations={PartyCount=1,GetValue=function()return 0 end},0
local actor={Id=10008,TemplateId=8}
local equipment={initialLoadouts=loadout,CanGrant=function(_,items,amounts)assert(#items==4 and items[1]==40 and items[4]==31 and amounts[4]==2);return false end}
local story={adventure={player={Coins=0},data=state,recipe={maxPartySize=4},equipment=equipment},data=state,rules={actions=tableOf({{id=1,kind='recruit_npc',targetId=8},{id=2,kind='grant_item',targetId=31,value=2}})},npcs={PrepareRecruit=function()return {npcId=8,actorId=actor.Id,actor=actor}end,Recruit=function()mutations=mutations+1 end}}
local plan,reason=Actions.Prepare(story,{1,2});assert(plan==nil and reason:find('背包') and mutations==0,'Capacity must preflight recruits and rewards together')
equipment.CanGrant=function()return true end;story.npcs.PrepareDeployment=function()return {}end
plan=assert(Actions.Prepare(story,{1,2}));assert(#plan.recruits==1 and #plan.items==4 and mutations==0)
local duplicate,why=Actions.Prepare(story,{1,1});assert(not duplicate and why:find('入队'))
print('PASS initial loadout references/slots/hand rules, equipment application, combined reward capacity, preparation without grants, duplicate recruit gate')
