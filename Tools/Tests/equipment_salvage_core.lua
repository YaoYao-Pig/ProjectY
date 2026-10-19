package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local value=file:read('*a');file:close();return value
end}})
for name,rows in pairs(SalvageSourceRows) do
    local index={}
    for _,row in ipairs(rows) do
        if name=='CombatEffectTable' then
            local expression=row.amount
            row.amount={Evaluate=function(_,values)
                local env={};for key,value in pairs(values) do env[key]=value end
                for _,key in ipairs({'floor','ceil','min','max','abs'}) do env[key]=math[key] end
                return assert(load('return '..expression,'@source_effect','t',env))()
            end}
        end
        assert(not index[row.id]);index[row.id]=row
    end
    config.tables[name]={All=function()return rows end,Get=function(_,id)return assert(index[id],name..' missing '..tostring(id))end,Find=function(_,id)return index[id]end}
end
local full={Current=100,Maximum=100,BaseMaximum=100,ThresholdArmed=true,Broken=false,Efficiency=1}
CS={ProjectY={Data={EquipmentConditionData={Of=function(item)return assert(item.condition)end},EquipmentCombatState={}}}}
local function weapon(id,item,owner,condition)
    return {Id=id,ItemId=item,OwnerActorId=owner,Hand='weapon',MagazineId=0,condition=condition or full,GetRune=function()return 0 end}
end
local growth={SkillCount=0,GetSkillAt=function()error('No learned skills')end,GetRank=function()return 0 end}
local enemy={Id=101,TemplateId=4,Team=2,AnimalSpeciesId=0,Growth=growth,ActionTemplateId=0,ActionSequence=0,ActionShots=1,ActionTargetQ=0,ActionTargetR=0}
local actor={Id=1,TemplateId=1,Team=1,AnimalSpeciesId=0,Growth=growth}
local sword,staff=weapon(10,40,101),weapon(11,1,1)
local armor={Id=12,ItemId=52,OwnerActorId=101,Slot='body',condition=full}
local data={owners={[101]=sword,[1]=staff},WearableCount=1,GetWearableAt=function()return armor end,Worn=function()return nil end,Offhand=function()return nil end}
function data:Equipped(id)return self.owners[id]end
local rules=require('Game.Equipment.EquipmentRules').New(config,data)
local stats={equipment=rules,Get=function(_,_,name)return name=='intellect' and 8 or 10 end}
local template={skillIds={1,4}}
local function has(ids,id)for _,value in ipairs(ids)do if value==id then return true end end;return false end
assert(rules:Weapon(enemy)==sword and rules:AttributeBonus(enemy,'defense')==3)
assert(has(rules:SkillIds(enemy,template),501) and has(rules:SkillIds(enemy,template),502))
assert(not has(rules:SkillIds(enemy,template),1))
assert(rules:ActorVisual(enemy).weapon.id==sword.Id)
data.owners[101]=nil
local unarmed=rules:SkillIds(enemy,template)
assert(not has(unarmed,1) and not has(unarmed,10) and not has(unarmed,501) and has(unarmed,504) and has(unarmed,503))
assert(rules:ActorVisual(enemy).weapon==nil,'Disarmed enemies must not restore a template weapon')
assert(not rules:CheckSkillEquipment(enemy,rules:Skill(enemy,501,stats),stats))
assert(rules:Catalyst(actor,'arcane')==staff)
staff.condition={Current=0,Maximum=95,BaseMaximum=100,Broken=true,Efficiency=0}
assert(not rules:Catalyst(actor,'arcane'),'A broken staff is not a catalyst')
armor.condition={Current=0,Maximum=95,BaseMaximum=100,Broken=true,Efficiency=0}
assert(rules:AttributeBonus(enemy,'defense')==0)
data.owners[101]=sword;sword.condition={Current=95,Maximum=95,BaseMaximum=100,Broken=false,Efficiency=.95}
local skill=rules:Skill(enemy,10,stats)
assert(math.abs(skill.damageScale-.95*config:GetTable('EquipmentWeaponTable'):Get(40).damageMultiplier)<.00001)
print('PASS real enemy ownership, disarm skill/visual removal, broken catalyst/armor and permanent loss scaling')

-- Recovered enemy firearms retain their loaded rounds, but cannot draw replacements from the player's backpack.
local gun=weapon(20,2,101);gun.MagazineId=21
local loaded={Id=21,ItemId=21,Rounds=1,Capacity=12};local spare={Id=22,ItemId=21,Rounds=12,Capacity=12}
data.owners[101]=gun;data.owners[1]=nil;data.MagazineCount=2
data.GetMagazine=function(_,id)assert(id==21);return loaded end
data.GetMagazineAt=function(_,i)assert(i==0 or i==1);return i==0 and loaded or spare end
data.MagazineWeapon=function(_,id)return id==21 and gun.Id or 0 end
data.Grid={Find=function(_,key)return key=='m22' and {Key=key} or nil end}
data.CanAttachMagazine=function()return true end
local reload=rules:Skill(enemy,9,stats)
assert(rules:CheckAmmo(enemy,rules:Skill(enemy,7,stats)),'A recovered gun retains and can fire its actual loaded ammo')
assert(not rules:NextMagazine(enemy,gun) and not rules:CheckAmmo(enemy,reload),'Enemy must not reload from the player backpack')
data.owners[101]=nil;data.owners[1]=gun;gun.OwnerActorId=1
assert(rules:NextMagazine(actor,gun)==spare and rules:CheckAmmo(actor,reload),'Allied reloading must still use backpack magazines')
assert(loaded.Rounds==1 and spare.Rounds==12,'Availability queries must not spend any rounds')
data.owners[101]=sword;data.owners[1]=staff
print('PASS captured firearms retain loaded ammunition without exposing player backpack magazines to enemies')

local effects=config:GetTable('CombatEffectTable')
local precise,fire,heavy=effects:Get(502),effects:Get(3),effects:Get(11)
assert(precise.equipmentDamage==0 and precise.killEquipmentDamage==0 and fire.equipmentDamage>effects:Get(9).equipmentDamage and heavy.killEquipmentDamage>0)
for _,entry in ipairs(config:GetTable('LootEntryTable'):All()) do
    if entry.poolId==3 or entry.poolId==4 then local kind=rules.items:Get(entry.itemId).kind;assert(kind~='weapon' and kind~='wearable','Enemy pool must not duplicate actual equipment') end
end
local wear=0
CS.ProjectY.Data.EquipmentCombatState.DamageArmor=function(_,id,amount)assert(id==101);wear=wear+amount;return amount end
CS.ProjectY.Data.EquipmentCombatState.RefreshMaximum=function(target,maximum)target.MaxHP=maximum end
local target={Id=101,HP=20,MaxHP=20,Effects={Count=0}}
function target:Damage(amount)local applied=math.min(self.HP,amount);self.HP=self.HP-applied;return applied end
function target:Heal(amount)local applied=math.min(self.MaxHP-self.HP,amount);self.HP=self.HP+applied;return applied end
local emitted={}
stats.Template=function()return {name='fixture'}end
stats.MaximumHP=function()return 20 end
local runtime=require('Game.Battle.GameEffects').New(stats,effects,function(kind,_,_,_,_,_,_,impact)emitted[kind]=impact end)
runtime:Execute(precise,target,10,1,'source','precise',actor,true)
assert(target.HP==10 and wear==0)
runtime:Execute(effects:Get(5),target,4,1,'source','heal',actor,false)
assert(emitted.heal.hpBefore==10 and emitted.heal.hpAfter==14 and emitted.heal.periodic==false)
runtime:Execute(effects:Get(5),target,1,1,'source','periodic',nil,false,nil,true)
assert(emitted.heal.hpBefore==14 and emitted.heal.hpAfter==15 and emitted.heal.periodic==true)
runtime:Execute(fire,target,30,1,'source','fire',actor,true,{shot=2})
assert(wear==fire.equipmentDamage+fire.killEquipmentDamage and emitted.damage.hpBefore==15 and emitted.damage.hpAfter==0 and emitted.damage.shot==2)
print('PASS source profiles distinguish armor preservation/fire/heavy blows, real HP metadata and periodic healing')

for _,path in ipairs({'Lua/Game/Equipment/EquipmentSystem.lua','Lua/Game/Equipment/InitialLoadout.lua','Lua/Game/Equipment/InventoryModel.lua',
    'Lua/Game/Loot/MapLoot.lua','Lua/Game/Loot/LootModel.lua','Lua/Game/Battle/BattleSystem.lua','Lua/Game/MapArea/MapAreaSystem.lua',
    'Lua/UI/Panel/InventoryCtr.lua','Lua/UI/Panel/EquipmentWorkbenchCtr.lua','Lua/Game/Loot/LootRules.lua','Tools/Tests/equipment_salvage_integration.lua'}) do assert(loadfile(path)) end
print('PASS changed Lua syntax; physical transactions require equipment_salvage_integration.lua in the existing Unity host')
