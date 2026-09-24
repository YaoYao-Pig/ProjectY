-- 同一角色在探索和战斗中导出相同显示契约，不持有长期 Lua/C# 句柄。
return function(actor,stats,appearances,area)
    local traits={}
    for i=0,actor.TraitCount-1 do traits[#traits+1]=stats.traits:Get(actor:GetTraitAt(i)).name end
    local cell=area and assert(area:Find(actor.Q,actor.R),'Combat actor outside area')
    return {id=actor.Id,name=stats:Template(actor).name,team=actor.Team,hp=actor.HP,maxHP=actor.MaxHP,
        ap=actor.AP,q=actor.Q,r=actor.R,guard=actor.Guard,moved=actor.Moved,mainUsed=actor.MainUsed,
        traits=table.concat(traits,' · '),appearance=appearances:Template(actor.TemplateId,stats.equipment:ActorVisual(actor)),cellIndex=cell and cell.index or 0}
end
