-- A recipe equips existing starter instances; it never creates a second copy.
local Starter={}
function Starter.Plan(recipe,data,party,rules,stats,loadouts)
    assert(#recipe.equipUnitIds==#recipe.equipWeaponIds,'Starter weapon arrays differ')
    local plan,units,reserved={},{},{}
    for i,unitId in ipairs(recipe.equipUnitIds) do
        assert(not units[unitId],'Repeated starter unit');units[unitId]=true
        local actor
        for j=0,party.PartyCount-1 do
            local candidate=party:GetPartyAt(j)
            if candidate.TemplateId==unitId then assert(not actor,'Ambiguous starter unit');actor=candidate end
        end
        assert(actor,'Starter weapon has no matching party member')
        assert(#loadouts:Items(unitId)==0,'Recipe and character initial equipment overlap')
        assert(not data:Equipped(actor.Id) and not data:Offhand(actor.Id) and not data:Worn(actor.Id,'offhand'),'Starter hands must be empty')
        local itemId=recipe.equipWeaponIds[i];rules.weapons:Get(itemId)
        local allowed,reason=rules:CanEquip(actor,itemId,stats);assert(allowed,reason)
        local weapon
        for j=0,data.WeaponCount-1 do
            local candidate=data:GetWeaponAt(j)
            if candidate.ItemId==itemId and candidate.OwnerActorId==0 and not reserved[candidate.Id] and data.Grid:Find('w'..candidate.Id) then
                weapon=candidate;break
            end
        end
        assert(weapon,'Configured starter weapon is absent from the backpack')
        reserved[weapon.Id]=true;plan[#plan+1]={actorId=actor.Id,weaponId=weapon.Id}
    end
    return plan
end
function Starter.Apply(data,plan)
    for _,entry in ipairs(plan) do assert(data:Equip(entry.actorId,entry.weaponId),'Prepared starter equipment failed') end
end
return Starter
