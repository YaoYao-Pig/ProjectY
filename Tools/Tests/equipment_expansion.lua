-- All 30 authored attachments resolve through the real equipment rules and existing socket contract.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=file:read('*a');file:close();return bytes
end}})
CS={ProjectY={Data={EquipmentConditionData={Of=function(item)return item.condition end},EquipmentAffixData={Of=function()return 1 end}}}}
local actor={Id=1,TemplateId=3,Team=1,TraitCount=0,Effects={Count=0},Growth={TalentCount=0,SkillCount=0,GetAttribute=function()return 30 end,GetRank=function()return 1 end}}
local data={WearableCount=0,main=nil}
function data:Equipped()return self.main end
function data:Offhand()return nil end
function data:Worn()return nil end
local stats=require('Game.Battle.CombatStats')(config,data);local rules=stats.equipment
local sockets={head={1,1},shaft={1,2},thruster={44,4},catalyst={40,6}}
local counts={head=0,shaft=0,thruster=0,catalyst=0}
local function count(values,id)local n=0;for _,value in ipairs(values)do if value==id then n=n+1 end end;return n end
for id=501,530 do
    local rune=rules.runes:Get(id);local pair=sockets[rune.slotKind]
    data.main={Id=1,ItemId=pair[1],MagazineId=0,condition={Broken=false,Efficiency=1},GetRune=function(_,socket)return socket==pair[2] and id or 0 end}
    local skillId=rune.skillGroup=='spell' and 103 or rules.weapons:Get(pair[1]).skillIds[1]
    local base=rules.skills:Get(skillId);local shared=table.concat(base.effectIds,',')
    local result=rules:Skill(actor,skillId,stats)
    assert(rules:CheckSkillEquipment(actor,result,stats),'Authored attachment must have a usable host weapon')
    assert(result.range==math.max(1,base.range+rune.rangeBonus) and result.cooldownTurns==math.max(0,base.cooldownTurns+rune.cooldownBonus))
    for _,effectId in ipairs(rune.onHitEffectIds)do assert(count(result.effectIds,effectId)==count(base.effectIds,effectId)+1,'Matching damage action lost its on-hit component')end
    assert(table.concat(base.effectIds,',')==shared,'Attachment mutated the shared skill definition')
    local statusOnly=rules:Skill(actor,505,stats)
    for _,effectId in ipairs(rune.onHitEffectIds)do assert(count(statusOnly.effectIds,effectId)==0,'Pure status spells must not trigger damage-on-hit components')end
    assert(#require('Game.Equipment.EquipmentPresentation').Attachment(rules,id)>20,'New inventory attachment lacks readable rules')
    local item=rules.items:Get(id);assert(item.assetId==id and item.iconMode=='model')
    local obtainable=false;for _,entry in ipairs(config:GetTable('ShopEntryTable'):All())do if entry.itemId==id and entry.chance>0 then obtainable=true end end
    assert(obtainable,'Attachment cannot be obtained in the game')
    counts[rune.slotKind]=counts[rune.slotKind]+1
end
assert(counts.head==10 and counts.shaft==8 and counts.thruster==8 and counts.catalyst==4)
-- Two cooldown reducers never underflow; both mounted components remain independent.
data.main={Id=1,ItemId=1,MagazineId=0,condition={Broken=false,Efficiency=1},GetRune=function(_,socket)return socket==1 and 510 or socket==2 and 512 or 0 end}
assert(rules:Skill(actor,103,stats).cooldownTurns==0)
-- Incompatible skill groups never acquire the equipped component's status trigger.
data.main={Id=1,ItemId=44,MagazineId=0,condition={Broken=false,Efficiency=1},GetRune=function()return 522 end}
assert(count(rules:Skill(actor,103,stats).effectIds,1202)==0)
print('PASS 30 attachments: host/socket compatibility, effect composition, signed tradeoffs, no shared mutation, descriptions and obtainable shop entries')
