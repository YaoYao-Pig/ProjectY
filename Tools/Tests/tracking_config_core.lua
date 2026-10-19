-- Tracking/transfer source configuration and real Lua rules; no Unity host is used.
package.path='Lua/?.lua;'..package.path
local Gear=assert(loadfile('Tools/Tests/equipment_read_fixture.lua'))()
local EmptyGrowth=assert(loadfile('Tools/Tests/growth_empty.lua'))()
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local function effects()
    local rows={Count=0,nextId=1,list={}}
    function rows:GetAt(index)return assert(self.list[index+1])end
    function rows:Find(id)for _,row in ipairs(self.list)do if row.EffectId==id then return row end end end
    function rows:Add(id,source,name,amount,duration)
        local row={Id=self.nextId,EffectId=id,SourceId=source,SourceName=name,Amount=amount,Remaining=duration,Elapsed=0,Stacks=1}
        self.nextId=self.nextId+1;self.list[#self.list+1]=row;self.Count=#self.list;return row
    end
    function rows:Refresh(id,source,name,amount,duration,maxStacks,stack)
        for _,row in ipairs(self.list)do if row.Id==id then
            row.SourceId=source;row.SourceName=name;row.Amount=amount;row.Remaining=duration;row.Elapsed=0
            if stack then row.Stacks=math.min(maxStacks,row.Stacks+1)end;return
        end end;error('Unknown effect instance')
    end
    function rows:Remove(id)
        for index,row in ipairs(self.list)do if row.Id==id then table.remove(self.list,index);self.Count=#self.list;return end end
        error('Unknown effect instance')
    end
    function rows:Advance(id,period)
        for _,row in ipairs(self.list)do if row.Id==id then
            if row.Remaining>0 then row.Remaining=row.Remaining-1 end
            row.Elapsed=period>0 and (row.Elapsed+1)%period or 0;return
        end end;error('Unknown effect instance')
    end
    return rows
end
CS.ProjectY.Data.GameBuffState={Configure=function(row,ids,amounts,expires,nextTick)
    row.ids={};row.amounts={};for i,id in ipairs(ids)do row.ids[i]=id;row.amounts[id]=amounts[i]end
    row.expires=expires;row.nextTick=nextTick
end,Count=function(row)return #row.ids end,EffectAt=function(row,index)return row.ids[index+1]end,
    Amount=function(row,id)return assert(row.amounts[id])end,ExpiresAt=function(row)return row.expires end,
    NextTickAt=function(row)return row.nextTick end}
local runes={[1]=11,[2]=0}
local staff=Gear(1,1,1);function staff:GetRune(id)return runes[id] or 0 end
local bow=Gear(2,46,2)
local equipment={WearableCount=0,Equipped=function(_,id)return id==1 and staff or id==2 and bow or nil end,
    Offhand=function()return nil end,Worn=function()return nil end}
local stats=require('Game.Battle.CombatStats')(config,equipment)
local rules=stats.equipment
local function actor(id,team,template)
    local row={Id=id,Team=team,TemplateId=template,TraitCount=0,Guard=0,Growth=EmptyGrowth(),Effects=effects(),HP=40,MaxHP=40}
    function row:SetMaxHP(value)self.HP=math.max(0,math.min(value,self.HP+value-self.MaxHP));self.MaxHP=value end
    row:SetMaxHP(stats:MaximumHP(row));return row
end
local caster,ally,enemy=actor(1,1,3),actor(2,1,2),actor(3,2,4)
local gameEffects=require('Game.Battle.GameEffects').New(stats,config:GetTable('CombatEffectTable'),function()end)
gameEffects:Validate()
local function resolve(owner,id)
    return stats.buffs:ApplySkillModifiers(owner,rules:Skill(owner,id,stats))
end
local base=config:GetTable('CombatSkillTable'):Get(6)
local normal=resolve(caster,6)
assert(normal.maxTargets==3 and normal.splashRadius==2 and normal.trajectory=='direct')
assert(not normal.guided and not normal.manualTargets)
assert(gameEffects:Apply(1361,caster,caster))
local tracking=resolve(caster,6)
assert(tracking.guided and tracking.manualTargets and tracking.maxTargets==3)
assert(base.maxTargets==1 and base.range==3 and base.target=='enemy','Buff/attachment resolution mutated the shared skill definition')
assert(not resolve(caster,10).guided and not resolve(caster,10).manualTargets,'Melee range must not acquire projectile capabilities')
assert(not resolve(caster,508).guided and not resolve(caster,508).manualTargets,'Self spells are not projectile attacks')
local sightSpell=resolve(caster,505)
assert(sightSpell.trajectory=='sight' and not sightSpell.guided and sightSpell.manualTargets,'Non-projectile sight spells retain their line of sight while manual scatter remains independent')
local unsupported={target='enemy',range=5,skillGroup='animal',maxTargets=3}
assert(stats.buffs:ApplySkillModifiers(caster,unsupported)==unsupported and not unsupported.guided and not unsupported.manualTargets)
print('PASS tracking adds ranged enemy capabilities through configured groups without mutating shared skill rows')

gameEffects:TickActor(caster,'turn_start');assert(caster.Effects:Find(10105).Remaining==3)
gameEffects:TickActor(caster,'turn_end');assert(caster.Effects:Find(10105).Remaining==2)
assert(gameEffects:Apply(1361,caster,caster));assert(caster.Effects.Count==1 and caster.Effects:Find(10105).Remaining==3)
for turn=1,3 do gameEffects:TickActor(caster,'turn_end')end
assert(not caster.Effects:Find(10105) and not resolve(caster,6).guided)
print('PASS tracking refreshes one canonical instance, counts owner turn ends and expires after three')

local selfSpell=rules:Skill(caster,1624,stats)
assert(selfSpell.target=='self' and selfSpell.cost==1 and selfSpell.action=='secondary' and selfSpell.cooldownTurns==0)
runes[1]=508;runes[2]=721 -- The head adds range; transfer must still be exactly four.
for _,id in ipairs({1624,508,403})do
    local skill=rules:Skill(caster,id,stats);local original=config:GetTable('CombatSkillTable'):Get(id)
    assert(skill.target=='any' and skill.range==4 and skill.allowTransfer)
    assert(skill.cost==original.cost and skill.action==original.action and skill.cooldownTurns==original.cooldownTurns)
    assert(original.target=='self' and original.range==0)
end
for _,id in ipairs({4,9,503,701,702})do assert(rules:Skill(caster,id,stats).target=='self','Unsafe/unconfigured self action became transferable')end
assert(rules:Skill(caster,1603,stats).target=='ally','An existing targeted spell must retain its target kind')
assert(rules:Skill(caster,6,stats).target=='enemy' and rules:Skill(caster,6,stats).range==5)
local transferred=rules:Skill(caster,1624,stats)
for _,recipient in ipairs({caster,ally,enemy})do
    assert(gameEffects:ApplyPrepared(gameEffects:Prepare(transferred.effectIds[1],caster,recipient,transferred,0)))
    assert(recipient.Effects:Find(10105).SourceId==caster.Id and recipient.Effects:Find(10105).Remaining==3)
end
gameEffects:TickActor(ally,'turn_end')
assert(ally.Effects:Find(10105).Remaining==2 and caster.Effects:Find(10105).Remaining==3 and enemy.Effects:Find(10105).Remaining==3)
assert(resolve(ally,2).guided and not resolve(ally,2).manualTargets,'A recipient without scatter still gains guided single-target attacks')
gameEffects:Clear(caster,'battle_end');gameEffects:Clear(ally,'battle_end');gameEffects:Clear(enemy,'battle_end')
runes[2]=0;assert(rules:Skill(caster,1624,stats).target=='self','Removing the rune must restore the base target immediately')
print('PASS transfer covers self/allies/enemies via target recipients, preserves action costs and fixed range, and excludes unsafe actions')

-- Exercise the real battle command boundary: tracking is a secondary action,
-- so spending its 1 AP must leave the main attack available in the same turn.
runes[1]=11;runes[2]=0
local battle=require('Game.Battle.BattleSystem')()
battle.stats=stats;battle.skills=config:GetTable('CombatSkillTable');battle.effects=config:GetTable('CombatEffectTable')
battle.gameEffects=gameEffects;battle.board=require('Game.Battle.BattleBoard').Create(4,171,0)
local units={caster,ally,enemy}
for i,unit in ipairs(units)do
    unit.Q=i==1 and 0 or 2;unit.R=i==2 and -1 or 0
    unit.AnimalOwnerId=0;unit.AP=4;unit.MainUsed=false;unit.Moved=false
    function unit:GetCooldown()return 0 end
    function unit:SetCooldown(id,value)self.lastCooldown={id,value}end
    function unit:RecordAction()end
    function unit:SpendAction(kind,cost)
        assert(self.AP>=cost and (kind~='main' or not self.MainUsed))
        self.AP=self.AP-cost;self.Moved=true;if kind=='main' then self.MainUsed=true end
    end
end
battle.data={Phase='combat',Winner='',ActiveId=caster.Id,UnitCount=#units,
    GetUnitAt=function(_,i)return units[i+1]end,AddLog=function()end}
battle.Changed={Emit=function()end}
assert(battle:TrySkill(1624,caster.Id))
assert(caster.AP==3 and not caster.MainUsed and caster.Effects:Find(10105).Remaining==3)
assert(battle:CanUseSkill(6,enemy.Id),'Tracking must not spend the main action needed for its following attack')
assert(battle:Skill(caster,6).guided and battle:Skill(caster,6).manualTargets)
print('PASS real battle casting spends 1 AP as a secondary action and leaves the same-turn main attack available')

local function changedConfig(name,id,changes)
    local original=config:GetTable(name);local replacement={}
    for key,value in pairs(original:Get(id))do replacement[key]=value end
    for key,value in pairs(changes)do replacement[key]=value end
    local tableView={Get=function(_,value)return value==id and replacement or original:Get(value)end,
        Find=function(_,value)return value==id and replacement or original:Find(value)end,
        All=function()local rows={};for _,row in ipairs(original:All())do rows[#rows+1]=row.id==id and replacement or row end;return rows end}
    return {GetTable=function(_,value)return value==name and tableView or config:GetTable(value)end}
end
assert(not pcall(require('Game.Equipment.EquipmentRules').New,changedConfig('EquipmentRuneTable',721,{transferRange=0}),equipment))
assert(not pcall(require('Game.Equipment.EquipmentRules').New,changedConfig('CombatSkillTable',9,{allowTransfer=true}),equipment))
assert(not pcall(require('Game.Equipment.EquipmentRules').New,changedConfig('CombatEffectTable',1361,{recipient='source'}),equipment))
assert(not pcall(require('Game.Battle.BuffRules').New,changedConfig('BuffTable',10105,{skillGroups={}})))
print('PASS invalid transfer ranges, unsafe actions, source-directed transfer effects and empty tracking groups fail validation')

local item=config:GetTable('EquipmentItemTable'):Get(721);local rune=config:GetTable('EquipmentRuneTable'):Get(721)
assert(item.assetId==3 and item.iconPath==config:GetTable('EquipmentItemTable'):Get(12).iconPath and rune.slotKind=='shaft')
for _,path in ipairs({item.iconPath,config:GetTable('EquipmentAssetTable'):Get(item.assetId).modelPath})do
    local file=assert(io.open(path,'rb'),'Reused rune resource is missing: '..path);file:close()
end
for _,id in ipairs({1,601,602,603})do
    local found=false;for _,skill in ipairs(config:GetTable('EquipmentWeaponTable'):Get(id).skillIds)do if skill==1624 then found=true end end
    assert(found,'Tracking skill lacks its configured weapon acquisition path')
end
assert(config:GetTable('SkillAtlasTable'):Get(1624).glyphCode=='staff')
assert(config:GetTable('ProfessionSkillTable'):Get(3624).skillId==1624)
assert(config:GetTable('ShopEntryTable'):Get(721).itemId==721)
assert(config:GetTable('LootEntryTable'):Get(704).itemId==721 and config:GetTable('LootPoolTable'):Get(5).mode=='weighted')
local cover=config:GetTable('ProjectileCoverTable'):Get(1)
assert(cover.actorChance==35 and cover.objectChance==50)
assert(require('Game.Equipment.EquipmentPresentation').Attachment(rules,721):find('4 格内任意角色',1,true))
print('PASS tracking/transfer acquisition, shared art references, display metadata and 35/50 cover configuration resolve')
config:OnShutdown()
