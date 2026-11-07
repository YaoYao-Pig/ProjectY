local Life=require('Game.Battle.ActorLife')
local L=require('Language')
local Model={};Model.__index=Model
local function state(weapon) return CS.ProjectY.Data.EquipmentLegacyData.Of(weapon) end
function Model.New(adventure)
    return setmetatable({adventure=adventure,rules=require('Game.Equipment.EquipmentForgeRules').New(adventure.config)},Model)
end
function Model:Start()
    self.unsubscribe=self.adventure.narrative.RewardSettled:Subscribe(function(receipt)
        if receipt.kind=='mission' then self:MissionCompleted(receipt.id) end
    end)
end
function Model:Dispose() if self.unsubscribe then self.unsubscribe();self.unsubscribe=nil end end
function Model:Accessible(weapon)
    return self.adventure.equipment:IsCarriedWeapon(weapon)
end
function Model:Find(id)
    local equipment=self.adventure.equipment.data
    for i=0,equipment.WeaponCount-1 do
        local weapon=equipment:GetWeaponAt(i)
        if weapon.Id==id and self:Accessible(weapon) then return weapon end
    end
end
function Model:Name(weapon)
    local name=self.adventure.equipment.rules.affixes:Name(weapon);local legacy=state(weapon)
    if legacy.PathId>0 then return string.format(L.ForgeNamedWeapon,self.rules.paths:Get(legacy.PathId).name,name) end
    return name
end
function Model:DeedText(deed)
    local rule=self.rules.deeds:Get(deed.RuleId)
    local subject=rule.kind=='mission' and self.rules.missions:Get(deed.TargetId).name or self.rules.units:Get(deed.TargetId).name
    local minute=math.floor(deed.Minutes%1440)
    return string.format(L.ForgeDeedMemory,math.floor(deed.Minutes/1440)+1,minute//60,minute%60,rule.name,subject)
end
function Model:Record(weapon,title,body)
    self.adventure.growth.chronicle:Record('loot',nil,title,string.format(L.ForgeChronicleBody,self:Name(weapon),body),L.UICampTitleText,true)
end
function Model:Session(id,revision)
    local ok,reason=self.adventure.camp:Session(revision);if not ok then return nil,reason end
    local weapon=self:Find(id)
    if not weapon then return nil,L.ForgeWeaponUnavailable end
    if not self.rules:Recipe(weapon.ItemId) then return nil,L.ForgeUnsupported end
    return weapon,''
end
function Model:CanForge(weapon)
    local row=self.rules:Recipe(weapon.ItemId);if not row then return false,L.ForgeUnsupported end
    local camp=self.adventure.camp.data;local legacy=state(weapon)
    if camp:GetLevel(row.facilityId)<row.requiredLevel then return false,L.ForgeFacilityRequired end
    local condition=self.adventure.equipment.rules:Condition(weapon)
    if legacy.Forged and condition.Current==condition.BaseMaximum and condition.Maximum==condition.BaseMaximum then return false,L.ForgeAlreadyWhole end
    if self.adventure.player.Coins<row.coins then return false,L.ForgeInsufficientCoins end
    for i,id in ipairs(row.itemIds) do
        if camp:Stored(id)+self.adventure.equipment.data:CountItem(id)<row.itemCounts[i] then return false,L.ForgeInsufficientMaterials end
    end
    return true,''
end
function Model:Forge(id,revision)
    local weapon,reason=self:Session(id,revision);if not weapon then return false,reason end
    local ok;ok,reason=self:CanForge(weapon);if not ok then return false,reason end
    local row=self.rules:Recipe(weapon.ItemId);local items,counts={},{}
    for i,item in ipairs(row.itemIds) do items[i]=item;counts[i]=row.itemCounts[i] end
    local a=self.adventure
    reason=CS.ProjectY.Data.EquipmentForgeState.Forge(a.data,a.player,id,revision,a.equipment.data.Revision,
        row.facilityId,row.requiredLevel,row.coins,items,counts)
    if reason~='' then return false,assert(L[reason],'Unknown forge failure: '..reason) end
    local owner=a.equipment:Actor(weapon.OwnerActorId)
    if owner then a.equipment:RefreshEquipmentHP(owner,a.battle.stats) end
    self:Record(weapon,L.ForgeCompleted,row.description);return true
end
function Model:Advance(id,revision,pathId)
    local weapon,reason=self:Session(id,revision);if not weapon then return false,reason end
    local legacy=state(weapon);local ok,required;ok,reason,required=self.rules:CanAdvance(legacy,pathId)
    if not ok then return false,reason end
    assert(legacy:ChoosePath(pathId,required),'Validated weapon advancement failed')
    self:Record(weapon,L.ForgeAdvanceCompleted,self.rules.paths:Get(pathId).description);return true
end
function Model:Talk(id,revision,awaken)
    local weapon,reason=self:Session(id,revision);if not weapon then return false,reason end
    local legacy=state(weapon)
    if awaken then
        if legacy.PathId==0 then return false,L.ForgeNeedsPath end
        if legacy.Awakened then return false,L.ForgeAlreadyAwake end
    elseif not legacy.Awakened then return false,L.EquipmentSpiritDormant end
    local alive=false
    for i=0,self.adventure.data.PartyCount-1 do if Life.Alive(self.adventure.data:GetPartyAt(i)) then alive=true;break end end
    if not alive then return false,L.EquipmentSpiritLivingActor end
    if awaken then assert(legacy:Awaken(),'Validated awakening failed');self:Record(weapon,L.ForgeAwakenCompleted,self.rules.paths:Get(legacy.PathId).spiritOpening) end
    self.adventure.camp:Close()
    local ok;ok,reason=self.adventure.spiritDialogue:Open(id)
    assert(ok,reason)
    return ok,reason
end
function Model:WitnessResolution(flag,value)
    local a=self.adventure;local story=a.narrative
    if value~=1 or not story.data.DialogueOpen or story.data.DialogueNpcId<=0 then return end
    local npc=story.rules.npcs:Get(story.data.DialogueNpcId)
    if npc.locationKind~='world_party' then return end
    local legend=a.parties.legends.byUnit[npc.actorTemplateId]
    if not legend or flag~='flag:'..legend.defeatedFlag then return end
    local party=a.parties.data:Find(story.data.DialogueLocalNpcId)
    if not party or party.DefinitionId~=legend.id then return end
    local weapon=a.equipment.data:Equipped(story.data.DialogueActorId)
    if not weapon or not self:Accessible(weapon) or not state(weapon).Forged then return end
    local deed=self.rules.byKind.legendary_resolution
    if state(weapon):RecordDeed(deed.id,story.data.DialogueActorId,npc.actorTemplateId,a.data.SiteId,story.data.Minutes) then
        self:Record(weapon,L.ForgeDeedRecorded,self:DeedText(state(weapon):GetDeedAt(state(weapon).DeedCount-1)))
    end
end
function Model:MissionCompleted(id)
    local rule=self.rules.byKind.mission;local sourceTarget
    for i,target in ipairs(rule.targetIds) do if target==id then sourceTarget=rule.sourceTargetIds[i];break end end
    if not sourceTarget then return end
    local a=self.adventure
    for i=0,a.equipment.data.WeaponCount-1 do
        local weapon=a.equipment.data:GetWeaponAt(i);local legacy=state(weapon)
        if self:Accessible(weapon) and legacy.Forged then
            for j=0,legacy.DeedCount-1 do
                local deed=legacy:GetDeedAt(j);local kind=self.rules.deeds:Get(deed.RuleId).kind
                if deed.TargetId==sourceTarget and (kind=='legendary_kill' or kind=='legendary_resolution') then
                    if legacy:RecordDeed(rule.id,deed.ActorId,id,deed.SiteId,a.narrative.data.Minutes) then
                        self:Record(weapon,L.ForgeDeedRecorded,self:DeedText(legacy:GetDeedAt(legacy.DeedCount-1)))
                    end
                    break
                end
            end
        end
    end
end
function Model:ReconcileMissions()
    local a=self.adventure
    if a.data.Phase~='map' and a.data.Phase~='area' then return end
    if self.equipmentRevision==a.equipment.data.Revision then return end
    self.equipmentRevision=a.equipment.data.Revision
    -- Recover the original witness after it returns from a container. The remembered source,
    -- not its current owner or the weapon equipped on the reward screen, authorizes the deed.
    for _,id in ipairs(self.rules.byKind.mission.targetIds) do
        if a.narrative.data:Status('mission',id)=='completed' then self:MissionCompleted(id) end
    end
end
function Model:Rows()
    local rows={};local a=self.adventure
    local function add(title,body,command,id,available,count)
        rows[#rows+1]={section='forge',title=title,body=body,command=command,id=id,available=available~=false,count=count or 0}
    end
    add(L.ForgePageTitle,L.ForgePageDescription)
    local found=false
    for i=0,a.equipment.data.WeaponCount-1 do
        local weapon=a.equipment.data:GetWeaponAt(i);local recipe=self.rules:Recipe(weapon.ItemId)
        if recipe and self:Accessible(weapon) then
            found=true;local legacy=state(weapon);local name=self:Name(weapon);local memories={}
            for j=0,legacy.DeedCount-1 do memories[#memories+1]=self:DeedText(legacy:GetDeedAt(j)) end
            add(string.format(L.ForgeWeaponIdentity,name,weapon.Id),#memories>0 and table.concat(memories,'\n') or L.ForgeNoDeeds)
            local ok,reason=self:CanForge(weapon)
            add(string.format(legacy.Forged and L.ForgeReforgeAction or L.ForgeFirstAction,name),
                recipe.description..'\n'..a.camp.rules:CostText(recipe)..'\n'..(ok and L.ForgeReady or reason),'forge_forge',weapon.Id,ok)
            if legacy.Forged and legacy.PathId==0 then
                for _,path in ipairs(self.rules.paths:All()) do
                    ok,reason=self.rules:CanAdvance(legacy,path.id)
                    add(string.format(L.ForgePathAction,path.name),path.description..'\n'..(ok and L.ForgeChoosePath or reason),'forge_path',weapon.Id,ok,path.id)
                end
            elseif legacy.PathId>0 then
                local path=self.rules.paths:Get(legacy.PathId)
                add(path.name,path.description)
                add(string.format(legacy.Awakened and L.ForgeTalkAction or L.ForgeAwakenAction,name),
                    legacy.Awakened and (legacy.WishState==2 and path.wishCompleted or legacy.WishState==1 and path.wishProgress or path.wish) or L.ForgeAwakenHint,
                    legacy.Awakened and 'forge_talk' or 'forge_awaken',weapon.Id,true)
            end
        end
    end
    if not found then add(L.ForgeNoWeapon,L.ForgeAcquireWeapon) end
    return rows
end
return Model
