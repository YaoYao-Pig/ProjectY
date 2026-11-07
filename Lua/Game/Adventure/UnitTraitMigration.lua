-- One explicit pre-v43 upgrade. Only prepared actors are changed; acquired and removed story traits stay intact.
local Migration={}
function Migration.Prepare(adventure,prepared,stats)
    local bridge=CS.ProjectY.Data.UnitInspections
    if not bridge.NeedsTraitMigration(prepared) then return end
    local reason=require('Language').InspectionSaveInvalid
    local seen,plans,changed={},{},{}
    local function visit(actor)
        local previous=seen[actor.Id]
        if previous then assert(previous==actor,reason);return end
        seen[actor.Id]=actor
        local ids={}
        for _,id in ipairs(stats:Template(actor).traitIds) do
            if id>=7 and id<=11 and not actor:HasTrait(id) then
                stats.traits:Get(id);ids[#ids+1]=id
            end
        end
        if #ids>0 then
            -- Do not repair unrelated invalid HP records while applying a known configuration migration.
            assert(stats:MaximumHP(actor)==actor.MaxHP,reason)
            plans[#plans+1]={actor=actor,ids=ids};changed[actor.Id]=true
        end
        local animal=CS.ProjectY.Data.AnimalCompanionState.Bound(actor)
        if animal then visit(animal) end
    end
    for i=0,prepared.ActorCount-1 do visit(prepared:GetActorAt(i)) end
    local expedition=CS.ProjectY.Data.ExpeditionPersistence
    local parties
    if expedition.HasWorld(prepared) then
        parties=CS.ProjectY.Data.WorldPartiesData.Prepared(prepared)
        for i=0,parties.Count-1 do
            local party=parties:GetAt(i)
            for j=0,party.MemberCount-1 do visit(party:GetMemberAt(j)) end
        end
        for i=0,expedition.AreaCount(prepared)-1 do
            local area=expedition.Area(prepared,i)
            for j=0,area.EncounterCount-1 do
                local group=area:GetEncounterAt(j)
                for k=0,group.EnemyCount-1 do visit(group:GetEnemyAt(k)) end
            end
        end
    end
    for _,plan in ipairs(plans) do
        for _,id in ipairs(plan.ids) do plan.actor:AddTrait(id) end
        -- ResizeBody preserves existing part damage, injuries and zero-HP/death-door state; never Restore here.
        plan.actor:SetMaxHP(stats:MaximumHP(plan.actor))
    end
    if parties then
        for i=0,parties.Count-1 do
            local party=parties:GetAt(i)
            for j=0,party.MemberCount-1 do
                local actor=party:GetMemberAt(j)
                if changed[actor.Id] then party:SetMemberStrength(j,adventure.factions.rules:FullPower(actor,stats)) end
            end
        end
    end
    bridge.CompleteTraitMigration(prepared)
end
return Migration
