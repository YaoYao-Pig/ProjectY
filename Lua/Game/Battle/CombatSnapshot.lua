-- 同一角色在探索和战斗中导出相同显示契约，不持有长期 Lua/C# 句柄。
return function(actor,stats,appearances,area)
    local traits={}
    for i=0,actor.TraitCount-1 do traits[#traits+1]=stats.traits:Get(actor:GetTraitAt(i)).name end
    local cell=area and assert(area:Find(actor.Q,actor.R),'Combat actor outside area')
    local appearance=appearances:Template(actor.TemplateId,stats.equipment:ActorVisual(actor),actor.CustomizationJson)
    local mount=actor.MountedAnimal
    if mount then
        local species=stats.animals.species:Get(mount.AnimalSpeciesId)
        local body
        for _,part in ipairs(appearances:Template(mount.TemplateId).parts) do if part.slot=='body' then body=part end end
        appearance.riding={body=assert(body),seat={species.riderSeat[1],species.riderSeat[2],species.riderSeat[3]}}
    end
    local occupiedCells={}
    if area then for _,part in ipairs(assert(stats.animals:Cells(actor,area))) do occupiedCells[#occupiedCells+1]=part.index end end
    return {id=actor.Id,name=stats:Template(actor).name,team=actor.Team,hp=actor.HP,maxHP=actor.MaxHP,presentationActor=actor,
        ap=actor.AP,q=actor.Q,r=actor.R,guard=actor.Guard,moved=actor.Moved,mainUsed=actor.MainUsed,
        traits=table.concat(traits,' · '),appearance=appearance,cellIndex=cell and cell.index or 0,occupiedCells=occupiedCells}
end
