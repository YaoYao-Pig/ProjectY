local Bank={}
local function clone(row) local result={};for k,v in pairs(row) do result[k]=v end;return result end
function Bank.Recipe(area,row,config)
    if area.source.townRole=='remote' or not area.source.generationVersion or area.source.generationVersion<11 then return row end
    local result=clone(row);result.facilityIds={}
    for _,id in ipairs(row.facilityIds) do result.facilityIds[#result.facilityIds+1]=id end
    result.facilityIds[#result.facilityIds+1]=config:GetTable('EconomyRuleTable'):Get(1).bankFacilityId
    return result
end
function Bank.RoyalRecipe(area,recipe,config)
    if not area.source.generationVersion or area.source.generationVersion<11 then return recipe end
    local result=clone(recipe);result.placementIds={}
    for _,id in ipairs(recipe.placementIds) do result.placementIds[#result.placementIds+1]=id end
    result.placementIds[#result.placementIds+1]=config:GetTable('EconomyRuleTable'):Get(1).bankRoyalPlacementId
    return result
end
return Bank
