-- 外部文件先完整准备和校验，再创建新地图并提交；失败不改当前队伍。
local Save={}
function Save.Validate(adventure,prepared)
    if adventure.narrative and not prepared.LegacyNarrative then require('Game.Narrative.NarrativeSave').Validate(adventure.narrative,prepared) end
    local config=adventure.config;local equipment=require('Game.Equipment.EquipmentRules').New(config,prepared.Equipment)
    local stats=require('Game.Battle.CombatStats')(config,prepared.Equipment)
    local effects=require('Game.Battle.GameEffects').New(stats,config:GetTable('CombatEffectTable'))
    local attributes={};for _,row in ipairs(config:GetTable('GrowthAttributeTable'):All()) do attributes[row.code]=true end
    for i=0,prepared.ActorCount-1 do
        local actor=prepared:GetActorAt(i);config:GetTable('CombatUnitTable'):Get(actor.TemplateId)
        effects:ValidateSaved(actor)
        equipment:MotionModule(actor)
        assert(adventure.appearances.templates[actor.TemplateId],'存档角色没有外观模板')
        for j=0,actor.TraitCount-1 do config:GetTable('CombatTraitTable'):Get(actor:GetTraitAt(j)) end
        local growth=actor.Growth
        for j=0,growth.AttributeCount-1 do assert(attributes[growth:GetAttributeNameAt(j)],'存档属性已不在配置中') end
        for j=0,growth.TreeCount-1 do config:GetTable('TalentTreeTable'):Get(growth:GetTreeAt(j)) end
        for j=0,growth.TalentCount-1 do local id=growth:GetTalentAt(j);local row=config:GetTable('TalentNodeTable'):Get(id);assert(growth:GetRank(id)<=row.maxRank,'存档天赋等级超过配置') end
        for j=0,growth.SkillCount-1 do config:GetTable('CombatSkillTable'):Get(growth:GetSkillAt(j)) end
        for j=0,growth.OfferCount-1 do config:GetTable('CombatSkillTable'):Get(growth:GetOfferAt(j)) end
        assert(stats:MaximumHP(actor)==actor.MaxHP,'角色生命上限与当前配置不一致，请迁移存档')
        local mount=actor.MountedAnimal
        if mount then
            effects:ValidateSaved(mount)
            local species=stats.animals.species:Get(mount.AnimalSpeciesId)
            assert(species.unitId==mount.TemplateId and species.rideable and mount.AnimalBond<=species.maximumBond,'存档坐骑与配置不一致')
            assert(stats:MaximumHP(mount)==mount.MaxHP,'坐骑生命上限与配置不一致')
        end
    end
    local data=prepared.Equipment
    for i=0,data.WeaponCount-1 do
        local weapon=data:GetWeaponAt(i);local definition=equipment.weapons:Get(weapon.ItemId)
        assert(equipment.items:Get(weapon.ItemId).kind=='weapon','存档武器类型无效')
        if weapon.Hand=='offhand' then assert(definition.hands==1,'双手武器不能在副手') end
        if weapon.Hand=='weapon' and definition.hands==2 then assert(not data:Offhand(weapon.OwnerActorId) and not data:Worn(weapon.OwnerActorId,'offhand'),'存档双手武器与副手冲突') end
        if weapon.MagazineId~=0 then assert(data:GetMagazine(weapon.MagazineId).ItemId==definition.magazineItemId,'存档弹匣不兼容') end
        for j=0,weapon.RuneCount-1 do
            local id=weapon:GetRuneSocketAt(j);local allowed=false;for _,socket in ipairs(definition.socketIds) do if socket==id then allowed=true end end
            assert(allowed,'存档配件槽已不存在');local rune=equipment.runes:Get(weapon:GetRune(id));local socket=equipment.sockets:Get(id)
            assert(rune.slotKind==socket.kind,'存档配件不兼容')
        end
    end
    for i=0,data.WearableCount-1 do local item=data:GetWearableAt(i);local definition=equipment.wearables:Get(item.ItemId)
        if item.OwnerActorId~=0 then assert(definition.slot==((item.Slot=='leftRing' or item.Slot=='rightRing') and 'ring' or item.Slot),'存档防具槽不兼容') end
    end
    for i=0,data.MagazineCount-1 do local item=data:GetMagazineAt(i);local definition=equipment.magazines:Get(item.ItemId)
        assert(item.Capacity==definition.capacity and item.AmmoItemId==definition.ammoItemId,'存档弹匣规格与配置不符') end
    for i=0,data.StackCount-1 do local row=data:GetStackAt(i);local item=equipment.items:Get(row.ItemId)
        assert(item.kind=='rune' or item.kind=='module' or item.kind=='ammo' or item.kind=='material','存档堆叠类型无效') end
end
function Save.Write(adventure)
    if adventure.narrative and adventure.narrative.data.DialogueOpen then return false,'请先结束对话再保存' end
    if adventure.data.Phase~='map' and adventure.data.Phase~='area' then return false,'只能在探索期间保存队伍' end
    local ok,err=pcall(function() adventure.characterSaves:Save(adventure.data,adventure.player) end)
    return ok,ok and '' or tostring(err)
end
function Save.Read(adventure)
    if adventure.narrative and adventure.narrative.data.DialogueOpen then return false,'请先结束对话再读取' end
    if adventure.data.Phase~='map' and adventure.data.Phase~='area' then return false,'只能在探索期间读取队伍' end
    local ok,prepared=pcall(function()
        local candidate=adventure.characterSaves:Prepare(adventure.data.Equipment);Save.Validate(adventure,candidate);return candidate
    end)
    if not ok then return false,tostring(prepared) end
    adventure:Start(prepared.Seed)
    adventure.characterSaves:Apply(prepared,adventure.data,adventure.player)
    if adventure.narrative then adventure.narrative.lastRevision=nil;adventure.narrative:Refresh() end
    return true
end
return Save
