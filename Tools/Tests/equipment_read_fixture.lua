-- Read-only ordinary/full-condition physical gear for offline combat rule fixtures.
-- The rule implementation stays real; only the C# scalar accessors are substituted.
CS=CS or {};CS.ProjectY=CS.ProjectY or {};CS.ProjectY.Data=CS.ProjectY.Data or {}
CS.ProjectY.Data.EquipmentAffixData={Of=function(item)return assert(item.affixId,'Fixture equipment has no affix')end}
CS.ProjectY.Data.EquipmentConditionData={Of=function(item)return assert(item.condition,'Fixture equipment has no condition')end}
return function(id,itemId,owner)
    return {Id=id,ItemId=itemId,OwnerActorId=owner,Hand='weapon',MagazineId=0,affixId=1,
        condition={Current=100,Maximum=100,BaseMaximum=100,Efficiency=1,Broken=false},GetRune=function()return 0 end}
end
