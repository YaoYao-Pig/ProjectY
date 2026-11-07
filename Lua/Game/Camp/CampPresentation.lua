local LuaLanguage=require('Language')
local Rich=require('Game.Equipment.EquipmentPresentation')
local P={}
local function materials(model,cost)
    local rows={}
    for i,id in ipairs(cost.itemIds) do
        local item=model.rules.items:Get(id)
        rows[#rows+1]={itemId=id,iconPath=item.iconPath,title=string.format(LuaLanguage.CampMaterialNeed,item.name,cost.itemCounts[i]),
            subtitle=string.format(LuaLanguage.CampMaterialSources,model.data:Stored(id),model.adventure.equipment.data:CountItem(id))}
    end
    return rows
end
function P.Party(a)
    local rows={}
    for i=0,a.data.PartyCount-1 do local actor=a.data:GetPartyAt(i)
        rows[#rows+1]=a.appearances:Template(actor.TemplateId,a.equipment.rules:ActorVisual(actor),actor.CustomizationJson)
    end
    return rows
end
local function jobState(model,id)
    local job=model.data:JobFor(id)
    if not job then return LuaLanguage.CampStationIdle end
    return model.adventure.narrative.data.Minutes>=job.ReadyAt and LuaLanguage.CampOrderReady or LuaLanguage.CampStationWorking
end
function P.Build(model,state)
    local a,data,rules=model.adventure,model.data,model.rules
    local minute=math.floor(a.narrative.data.Minutes%1440)
    local s={page=state.page,title=LuaLanguage.UICampTitleText,caption=string.format(LuaLanguage.UICampCaptionText,
        math.floor(a.narrative.data.Minutes/1440)+1,minute//60,minute%60,a.player.Coins,data.StoredTotal,rules:Capacity(data),data.JobCount),
        status=state.message,facilities={},rows={},materials={},secondary={},detailTitle='',detailText='',cost='',reason='',actionLabel=LuaLanguage.CampStartProduction,actionEnabled=false}
    for _,id in ipairs({1,4,3,2}) do
        local source=id==4 and 1 or id
        s.facilities[#s.facilities+1]={name=id==4 and LuaLanguage.CampForgeBuilding or rules.facilities:Get(id).name,
            status=id==3 and string.format(LuaLanguage.CampWarehouseStatus,data.StoredTotal,rules:Capacity(data)) or
                string.format(LuaLanguage.CampFacilityStatus,data:GetLevel(source),id==4 and LuaLanguage.CampForgeService or jobState(model,source))}
    end
    if state.page=='scene' then return s end
    if state.page=='loadout' then return model.loadout:Build(s,state) end
    if state.page=='roster' then return model.roster:Build(s,state) end
    local facility=state.facility or 1
    s.panelTitle=state.page=='forge' and LuaLanguage.ForgeSection or rules.facilities:Get(facility).name
    s.panelSubtitle=string.format(LuaLanguage.CampFacilityLevel,data:GetLevel(facility))
    if state.page=='storage' then return s end
    if state.page=='production' then
        local recipes=rules.byFacility[facility];local selected
        for _,recipe in ipairs(recipes) do if tostring(recipe.id)==state.selected then selected=recipe end end
        selected=selected or assert(recipes[1],'Production facility requires recipes');state.selected=tostring(selected.id)
        for _,recipe in ipairs(recipes) do
            local output=rules.items:Get(recipe.outputIds[1]);local _,reason=rules:CanProduce(data,a.equipment.data,a.player.Coins,recipe.id,a.narrative.data.Minutes)
            if data:GetLevel(facility)>=recipe.requiredLevel and data:JobFor(facility) then reason=jobState(model,facility) end
            s.rows[#s.rows+1]={key=tostring(recipe.id),title=recipe.name,itemId=output.id,iconPath=output.iconPath,
                subtitle=reason~='' and reason or string.format(LuaLanguage.CampRecipeTime,recipe.minutes),selected=recipe==selected}
        end
        local output=rules.items:Get(selected.outputIds[1]);local ok,reason=rules:CanProduce(data,a.equipment.data,a.player.Coins,selected.id,a.narrative.data.Minutes)
        s.detailTitle=selected.name;s.detailText=string.format(LuaLanguage.CampRecipeOutputs,rules:ItemsText(selected.outputIds,selected.outputCounts))
        if output.kind=='ammo' then
            s.detailText=s.detailText..'\n\n'..a.equipment.rules.ammunition:Get(output.id).description..'\n'..Rich.AmmoStats(a.equipment.rules,output.id)
        elseif output.kind=='weapon' then
            local definition=a.equipment.rules.weapons:Get(output.id)
            s.detailText=s.detailText..'\n\n'..string.format(LuaLanguage.CampWeaponTemplateDetails,a.equipment.rules.categories:Get(definition.categoryId).name,definition.level,
                definition.hands==1 and LuaLanguage.UIEquipmentPresentationCategory2 or LuaLanguage.UIEquipmentPresentationCategory)
            if definition.description~='' then s.detailText=s.detailText..'\n'..definition.description end
        elseif output.id==a.equipment.rules.torch.itemId then s.detailText=s.detailText..'\n\n'..a.equipment.rules.torch.description end
        s.cost=string.format(LuaLanguage.CampProductionCost,selected.minutes,selected.coins);s.materials=materials(model,selected)
        s.actionEnabled=ok;s.reason=reason;s.operation={command='camp_produce',id=selected.id,count=0};s.previewAsset=a.equipment.rules:Asset(output.assetId)
        local job=data:JobFor(facility);s.progress=0;s.canClaim=false;s.orderTitle=LuaLanguage.CampStationIdle;s.orderState=LuaLanguage.CampOrderHelp
        if job then
            local ready=a.narrative.data.Minutes>=job.ReadyAt;local row=rules.recipes:Get(job.RecipeId)
            s.orderTitle=rules:ItemsText(row.outputIds,row.outputCounts)
            s.progress=math.max(0,math.min(1,(a.narrative.data.Minutes-job.StartedAt)/(job.ReadyAt-job.StartedAt)))
            s.canClaim=ready and a.equipment:CanGrant(row.outputIds,row.outputCounts)
            s.orderState=ready and (s.canClaim and LuaLanguage.CampOrderReady or LuaLanguage.UICampText31) or string.format(LuaLanguage.CampOrderRemaining,math.ceil(job.ReadyAt-a.narrative.data.Minutes))
            s.actionLabel=ready and LuaLanguage.CampClaimFirst or LuaLanguage.CampStationWorking
        end
    elseif state.page=='upgrade' then
        s.panelTitle=LuaLanguage.CampUpgradeTitle
        for _,f in ipairs(rules.facilities:All()) do
            s.rows[#s.rows+1]={key=tostring(f.id),title=f.name,subtitle=string.format(LuaLanguage.CampFacilityLevel,data:GetLevel(f.id)),itemId=0,iconPath='',selected=f.id==facility}
        end
        local f=rules.facilities:Get(facility);local ok,reason,upgrade=rules:CanUpgrade(data,a.equipment.data,a.player.Coins,facility)
        s.detailTitle=f.name;s.detailText=f.description;s.actionEnabled=ok;s.actionLabel=data:GetLevel(facility)==0 and LuaLanguage.CampBuildAction or LuaLanguage.CampUpgradeAction
        s.reason=reason;s.previewFacility=facility;s.previewLevel=upgrade and upgrade.level or data:GetLevel(facility)
        if upgrade then s.materials=materials(model,upgrade);s.cost=string.format(LuaLanguage.CampUpgradeCost,upgrade.level,upgrade.coins);s.operation={command='camp_upgrade',id=facility,count=0} end
    elseif state.page=='forge' then
        local forge=a.forge;local weapon
        for i=0,a.equipment.data.WeaponCount-1 do local candidate=a.equipment.data:GetWeaponAt(i)
            if forge:Accessible(candidate) and forge.rules:Recipe(candidate.ItemId) and (not weapon or tostring(candidate.Id)==state.selected) then weapon=candidate end
        end
        if not weapon then s.detailTitle=LuaLanguage.ForgeNoWeapon;s.detailText=LuaLanguage.ForgeAcquireWeapon;s.actionLabel=LuaLanguage.CampForgeAction;return s end
        state.selected=tostring(weapon.Id)
        for i=0,a.equipment.data.WeaponCount-1 do local candidate=a.equipment.data:GetWeaponAt(i)
            if forge:Accessible(candidate) and forge.rules:Recipe(candidate.ItemId) then
                local item=rules.items:Get(candidate.ItemId);local condition=a.equipment.rules:Condition(candidate)
                s.rows[#s.rows+1]={key=tostring(candidate.Id),title=forge:Name(candidate),itemId=item.id,iconPath=item.iconPath,selected=candidate.Id==weapon.Id,
                    subtitle=string.format(LuaLanguage.CampWeaponIdentity,candidate.Id,condition.Current,condition.Maximum)}
            end
        end
        local recipe=forge.rules:Recipe(weapon.ItemId);local legacy=CS.ProjectY.Data.EquipmentLegacyData.Of(weapon)
        local descriptions={recipe.description}
        if legacy.DeedCount==0 then descriptions[#descriptions+1]=LuaLanguage.ForgeNoDeeds
        else for i=0,legacy.DeedCount-1 do descriptions[#descriptions+1]=forge:DeedText(legacy:GetDeedAt(i)) end end
        s.detailTitle=forge:Name(weapon);s.detailText=table.concat(descriptions,'\n\n');s.cost=string.format(LuaLanguage.CampForgeCost,recipe.coins)
        s.materials=materials(model,recipe);s.actionEnabled,s.reason=forge:CanForge(weapon)
        s.actionLabel=legacy.Forged and LuaLanguage.CampReforgeAction or LuaLanguage.CampForgeAction;s.operation={command='forge_forge',id=weapon.Id,count=0}
        s.previewWeapon=a.equipment.rules:WeaponVisual(weapon)
        for _,row in ipairs(forge:Rows()) do
            if row.id==weapon.Id and row.command and row.command~='forge_forge' then
                s.secondary[#s.secondary+1]={title=row.title,available=row.available,command=row.command,id=row.id,count=row.count}
                if row.body~='' then s.detailText=s.detailText..'\n\n'..row.body end
            end
        end
    else error('Unknown camp page: '..tostring(state.page)) end
    return s
end
function P.StorageDetail(model,row)
    if row.kind=='weapon' or row.kind=='wearable' then
        local equipment=model.adventure.equipment.data
        local entity=row.kind=='weapon' and equipment:GetWeapon(row.id) or equipment:GetWearable(row.id)
        local condition=model.adventure.equipment.rules:Condition(entity)
        return string.format(LuaLanguage.CampWeaponIdentity,row.id,condition.Current,condition.Maximum)
    end
    if row.kind=='magazine' then return Rich.MagazineSummary(model.adventure.equipment.rules,model.adventure.equipment.data:GetMagazine(row.id)) end
    return string.format(LuaLanguage.CampStoredItemInfo,row.count,row.width,row.height)
end
function P.Warehouse(model,selected)
    local bridge=CS.ProjectY.Data.CampWarehouseBridge;local grid=bridge.Grid(model.data);local rows={}
    for i=0,model.data.StorageCount-1 do
        local pile=model.data:GetStorageAt(i);local id=bridge.Key(pile);local p=assert(grid:Find(id));local item=model.rules.items:Get(pile.ItemId)
        local gear=id:sub(1)~='c' and id or '';local instance=gear~='' and tonumber(gear:sub(2)) or pile.ItemId
        local name,displayName,detail=item.name,Rich.Escape(item.name),'';local rules=model.adventure.equipment.rules;local equipment=model.adventure.equipment.data
        if item.kind=='weapon' or item.kind=='wearable' then
            local entity=item.kind=='weapon' and equipment:GetWeapon(instance) or equipment:GetWearable(instance)
            name=rules.affixes:Name(entity);displayName=Rich.Name(rules,entity)
            local condition=rules:Condition(entity);detail=string.format(LuaLanguage.CampWeaponIdentity,instance,condition.Current,condition.Maximum)
        elseif item.kind=='magazine' then detail=Rich.MagazineSummary(rules,equipment:GetMagazine(instance)) end
        local legendary=rules.affixes:Legendary(item.id)
        rows[#rows+1]={key=id,id=instance,itemId=pile.ItemId,kind=item.kind,name=name,displayName=displayName,count=pile.Count,
            detail=detail,iconPath=item.iconPath,slot='',compatible='',equipMask=0,width=item.width,height=item.height,x=p.X,y=p.Y,rotated=p.Rotated,
            legendary=legendary~=nil,rarityColor=legendary and legendary.color or ''}
    end
    return {width=grid.Width,height=grid.Height,selected=selected,items=rows}
end
return P
