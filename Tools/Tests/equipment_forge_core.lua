package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local value=file:read('*a');file:close();return value
end}})
local L=require('Language')
local Rules=require('Game.Equipment.EquipmentForgeRules');local rules=Rules.New(config)
local function legacy(forged)
    return {Forged=forged,PathId=0,Awakened=false,WishState=0,DeedCount=0,Revision=0,deeds={},
        GetDeedAt=function(self,index)return assert(self.deeds[index+1])end,
        RecordDeed=function(self,rule,actor,target,site,minutes)
            if not self.Forged then return false end
            for _,row in ipairs(self.deeds)do if row.RuleId==rule and row.TargetId==target then return false end end
            self.deeds[#self.deeds+1]={RuleId=rule,ActorId=actor,TargetId=target,SiteId=site,Minutes=minutes}
            self.DeedCount=#self.deeds;self.Revision=self.Revision+1;return true
        end,
        ChoosePath=function(self,path,rule)
            assert(self.Forged and self.PathId==0)
            self.PathId=path;self.Revision=self.Revision+1;return true
        end}
end
CS={ProjectY={Data={EquipmentLegacyData={Of=function(weapon)return weapon.legacy end}}}}
assert(rules:Recipe(101) and rules:Recipe(40) and not rules:Recipe(9001))
local first={Id=10,ItemId=101,OwnerActorId=1,legacy=legacy(false)}
local swapped={Id=11,ItemId=40,OwnerActorId=2,legacy=legacy(true)}
local alien={Id=12,ItemId=101,OwnerActorId=99,legacy=legacy(true)}
assert(not rules:CanAdvance(first.legacy,1))
first.legacy.Forged=true;assert(not rules:CanAdvance(first.legacy,1))
first.legacy:RecordDeed(3,1,701,3,100)
assert(not rules:CanAdvance(first.legacy,1),'A peaceful witness must finish its associated mission first')
local equipment={WeaponCount=3,Revision=1,GetWeaponAt=function(_,index)return ({first,swapped,alien})[index+1]end,
    Equipped=function(_,id)return id==1 and first or swapped end,CountItem=function()return 20 end}
local logs={};local camp={IsOpen=true,Revision=4,GetLevel=function()return 1 end,Stored=function()return 0 end}
local story={data={DialogueOpen=true,DialogueNpcId=101,DialogueLocalNpcId=11,DialogueActorId=1,Minutes=200},rules={npcs=config:GetTable('NpcTable')}}
local a={config=config,data={SiteId=3,Phase='map'},player={Coins=99},narrative=story,
    equipment={data=equipment,IsCarriedWeapon=function(_,weapon)return weapon.OwnerActorId==1 or weapon.OwnerActorId==2 end,
        rules={affixes={Name=function(_,weapon)return rules.items:Get(weapon.ItemId).name end},Condition=function()return {Current=50,Maximum=80,BaseMaximum=100}end}},
    camp={data=camp,rules=require('Game.Camp.CampRules').New(config),Session=function(_,revision)return revision==4,L.ForgeStateChanged end},
    growth={chronicle={Record=function(_,kind,actor,title,body)logs[#logs+1]={title,body}end}},
    parties={data={Find=function(_,id)return id==11 and {DefinitionId=11}end},legends={byUnit={[701]={id=11,defeatedFlag='legend_blood_resolved'}}}}}
local model=require('Game.Equipment.EquipmentForgeModel').New(a);a.forge=model
assert(model:Find(10)==first and not model:Find(12))
model:MissionCompleted(702)
assert(first.legacy.DeedCount==1,'An unrelated mission cannot grant a deed')
model:MissionCompleted(701)
assert(first.legacy.DeedCount==2 and swapped.legacy.DeedCount==0,'Mission credit follows the witnessed weapon, not the weapon held on reward claim')
model:MissionCompleted(701);assert(first.legacy.DeedCount==2 and #logs==1,'Mission completion is idempotent')
assert(rules:CanAdvance(first.legacy,1))
local ok=model:Advance(10,3,1);assert(not ok and first.legacy.PathId==0,'Stale camp selection cannot advance')
assert(model:Advance(10,4,2));assert(first.legacy.PathId==2)
assert(not model:Advance(10,4,1),'A chosen path cannot be overwritten by a stale option')
assert(model:Name(first):find(rules.paths:Get(2).name,1,true))
assert(model:DeedText(first.legacy:GetDeedAt(0)):find(rules.units:Get(701).name,1,true))
rules:ValidateSaved(first)
local invalid={ItemId=101,legacy=legacy(true)};invalid.legacy:RecordDeed(1,1,999999,3,200)
assert(not pcall(function()rules:ValidateSaved(invalid)end),'Unknown deed target must reject the save')
first.legacy.Forged=false
assert(not model:WitnessResolution('flag:legend_blood_resolved',1));first.legacy.Forged=true
swapped.legacy.deeds={};swapped.legacy.DeedCount=0
story.data.DialogueActorId=2
model:WitnessResolution('flag:unrelated',1);assert(swapped.legacy.DeedCount==0)
model:WitnessResolution('flag:legend_blood_resolved',1);assert(swapped.legacy.DeedCount==1)
assert(swapped.legacy:GetDeedAt(0).RuleId==3 and swapped.legacy:GetDeedAt(0).ActorId==2)
story.data.Status=function(_,kind,id)return id==701 and 'completed' or 'inactive'end
swapped.OwnerActorId=99;model:ReconcileMissions();assert(swapped.legacy.DeedCount==1)
swapped.OwnerActorId=2;equipment.Revision=equipment.Revision+1
model:ReconcileMissions();assert(swapped.legacy.DeedCount==2,'A recovered original witness reconciles a mission completed while it was away')
model:ReconcileMissions();assert(swapped.legacy.DeedCount==2,'Reconciliation is idempotent')
local rows=model:Rows();local actions={}
for _,row in ipairs(rows)do assert(row.section=='forge');if row.command then actions[row.command]=true end end
assert(actions.forge_forge and actions.forge_path and actions.forge_awaken,'Forge UI exposes the actual state-dependent commands')
assert(select(1,model:CanForge(first)));a.player.Coins=0
assert(not model:CanForge(first),'Forge preview rejects unaffordable payment')
print('equipment_forge_core: PASS (real configuration, provenance, progression, snapshots, localization)')
