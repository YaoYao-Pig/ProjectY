local Life=require('Game.Battle.ActorLife')
-- Configuration and event routing only. Physical weapon history and battle evidence belong to C# Data.
local Combat={};Combat.__index=Combat
local function finite(value)return type(value)=='number' and value==value and value>=0 and value<math.huge end
function Combat.New(adventure)
    local config=adventure.config
    local self=setmetatable({adventure=adventure,battle=adventure.battle,equipment=adventure.battle.stats.equipment,
        data=CS.ProjectY.Data.EquipmentLegacyBattleData.For(adventure.data),forgeByWeapon={},deedsByTarget={},legendByTemplate={},
        paths=config:GetTable('EquipmentLegacyPathTable')},Combat)
    for _,row in ipairs(config:GetTable('EquipmentForgeTable'):All())do
        assert(finite(row.damageBonus),'Invalid forge damage bonus')
        for _,id in ipairs(row.weaponIds)do
            assert(not self.forgeByWeapon[id],'Weapon has multiple forge rules')
            self.forgeByWeapon[id]=row
        end
    end
    for _,row in ipairs(config:GetTable('EquipmentDeedTable'):All())do
        if row.kind=='legendary_kill' then
            for _,id in ipairs(row.targetIds)do
                local rules=self.deedsByTarget[id] or {};self.deedsByTarget[id]=rules;rules[#rules+1]=row
            end
        end
    end
    for _,row in ipairs(config:GetTable('LegendaryEncounterTable'):All())do
        local npc=config:GetTable('NpcTable'):Get(row.npcId)
        assert(not self.legendByTemplate[npc.actorTemplateId],'Legendary actor template reused')
        self.legendByTemplate[npc.actorTemplateId]=row.id
    end
    for _,row in ipairs(self.paths:All())do
        assert(finite(row.damageBonus) and finite(row.guardValue) and row.guardValue%1==0 and finite(row.wishDamageBonus),'Invalid legacy combat bonuses')
    end
    return self
end
function Combat:Start()
    assert(not self.unsubscribe and not self.battle.legacyCombat and not self.battle.gameEffects.legacyCombat,'Equipment legacy already attached')
    self.battle.legacyCombat=self;self.battle.gameEffects.legacyCombat=self
    self.unsubscribe=self.battle.Changed:Subscribe(function(event)if event.kind=='battle_started' then self:Begin()end end)
end
function Combat:Reset()self.data:Reset()end
function Combat:Dispose()
    if self.unsubscribe then self.unsubscribe();self.unsubscribe=nil end
    if self.battle.legacyCombat==self then self.battle.legacyCombat=nil end
    if self.battle.gameEffects.legacyCombat==self then self.battle.gameEffects.legacyCombat=nil end
    self:Reset()
end
function Combat:IsParticipant(actor)
    if not actor or actor.Team~=1 or self.battle:FindUnit(actor.Id)~=actor then return false end
    local data=self.adventure.data
    for i=0,data.PartyCount-1 do if data:GetPartyAt(i)==actor then return true end end
    return false
end
function Combat:IsHeld(actor,weapon)
    return self.equipment:Weapon(actor)==weapon or self.equipment:Offhand(actor)==weapon
end
function Combat:Begin()
    self.data:Begin()
    -- Admission records when the wish was accepted; later genuine use still has to earn its contribution.
    for i=0,self.equipment.data.WeaponCount-1 do
        local weapon=self.equipment.data:GetWeaponAt(i)
        if CS.ProjectY.Data.EquipmentLegacyData.Of(weapon).WishState==1 then self.data:AdmitWish(weapon)end
    end
end
function Combat:LegendaryTarget(target)
    if not target or target.AnimalOwnerId~=0 then return 0 end
    local definition=self.legendByTemplate[target.TemplateId]
    if not definition then return 0 end
    local parties=self.adventure.parties.data
    for i=0,parties.Count-1 do
        local party=parties:GetAt(i)
        if party.DefinitionId==definition then
            for j=0,party.MemberCount-1 do if party:GetMemberAt(j)==target then return target.TemplateId end end
        end
    end
    return 0
end
function Combat:Legacy(skill)
    local weapon=skill and skill.weaponInstance
    if not weapon then return end
    local legacy=CS.ProjectY.Data.EquipmentLegacyData.Of(weapon)
    if not legacy.Forged then return end
    return legacy,weapon,assert(self.forgeByWeapon[weapon.ItemId],'Forged weapon has no forge rule')
end
function Combat:Damage(source,target,row,amount,skill,periodic,attackHit)
    if row.kind~='damage' or row.duration~='instant' or periodic or not attackHit or amount<=0 or source==target then return amount end
    local legacy=self:Legacy(skill)
    if not legacy then return amount end
    local bonus=0
    if legacy.PathId>0 and self.battle:IsHostile(source,target) and self:LegendaryTarget(target)>0 then bonus=self.paths:Get(legacy.PathId).damageBonus end
    local value=math.floor(amount*(1+bonus)+0.000000001)
    assert(value<=1000000,'Legacy damage exceeds effect bounds')
    return value
end
function Combat:Resolved(source,target,row,amount,impact,skill,periodic,sourceId,attackHit)
    local battle=self.battle
    if not self.data.Active or battle.data.Phase~='combat' or row.kind~='damage' or not impact
        or not impact.hpBefore or impact.hpBefore<=0 or not impact.hpAfter then return end
    local armorDamage=impact.armor and impact.armor.damage or 0
    if not (amount>0 and impact.hpAfter<impact.hpBefore or armorDamage>0) then return end
    local attacker=source or (sourceId and battle:FindUnit(sourceId))
    if not attacker or battle:FindUnit(attacker.Id)~=attacker or battle:FindUnit(target.Id)~=target or not battle:IsHostile(attacker,target)
        or not battle:IsHostile(1,target) or target.AnimalOwnerId~=0 then return end
    -- This observes actual effect execution; GM's synthetic Notify events never authorize a death.
    if not Life.Alive(target) and attacker.Team==1 then self.data:MarkDefeated(target)end
    if periodic or not attackHit or row.duration~='instant' or not self:IsParticipant(source) then return end
    local legacy,weapon=self:Legacy(skill)
    if not legacy then return end
    self.data:Record(weapon,source,target,self:LegendaryTarget(target),self.data:IsWishEligible(weapon))
end
function Combat:BeginTurn(actor)
    if self.battle.data.Phase~='combat' or self.battle.data.Round~=1 or not self:IsParticipant(actor) or not Life.Alive(actor) then return end
    for _,hand in ipairs({'Weapon','Offhand'})do
        local weapon=self.equipment[hand](self.equipment,actor)
        if self.equipment:Usable(weapon) then
            local legacy=CS.ProjectY.Data.EquipmentLegacyData.Of(weapon)
            if legacy.Forged and legacy.PathId>0 then actor:SetGuard(self.paths:Get(legacy.PathId).guardValue)end
        end
    end
end
function Combat:Settle(result,location)
    assert(result=='victory' or result=='defeat' or result=='draw','Unknown battle result')
    if not self.data:Finish() then return false end
    if result~='victory' then return true end
    for i=0,self.data.Count-1 do
        local entry=self.data:GetAt(i);local legacy=CS.ProjectY.Data.EquipmentLegacyData.Of(entry.Weapon)
        if entry.LegendaryTargetId>0 and not Life.Alive(entry.Target) and entry.Target.AnimalOwnerId==0
            and self.data:WasDefeated(entry.Target) and self.battle:IsHostile(1,entry.Target) then
            for _,rule in ipairs(self.deedsByTarget[entry.LegendaryTargetId] or {})do
                legacy:RecordDeed(rule.id,entry.Actor.Id,entry.LegendaryTargetId,self.adventure.data.SiteId,self.adventure.narrative.data.Minutes)
            end
        end
        if entry.WishEligible and Life.Alive(entry.Actor) and self:IsHeld(entry.Actor,entry.Weapon) then legacy:FulfillWish()end
    end
    return true
end
return Combat
