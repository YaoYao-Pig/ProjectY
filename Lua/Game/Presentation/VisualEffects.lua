-- 已结算事实的短期表现队列；不参与玩法、随机流或存档。
local Effects={}
local maximumEvents=128
local function append(battle,event)
    local events=battle.vfxEvents
    if not events then events={};battle.vfxEvents=events end
    battle.vfxSequence=(battle.vfxSequence or 0)+1
    event.sequence=battle.vfxSequence
    if #events==maximumEvents then table.remove(events,1) end
    events[#events+1]=event
end
function Effects.Source(actor,cell)
    return {Id=actor.Id,Q=cell and cell.q or actor.Q,R=cell and cell.r or actor.R,layer=cell and cell.layer}
end
function Effects.Skill(battle,source,skill,target,shot,outcome,cell)
    assert(outcome=='hit' or outcome=='miss' or outcome=='cast','Invalid skill visual outcome')
    assert(target or cell,'Skill visual needs a target or cell')
    append(battle,{skillId=assert(skill.id),itemId=0,sourceId=source.Id,targetId=target and target.Id or 0,
        sourceQ=assert(source.Q),sourceR=assert(source.R),targetQ=cell and cell.q or target.Q,targetR=cell and cell.r or target.R,
        sourceLayer=type(source)=='table' and source.layer or -2147483648,targetLayer=cell and cell.layer or -2147483648,
        shot=shot or 1,outcome=outcome})
end
function Effects.Item(battle,itemId,actor,q,r,outcome,targetLayer)
    assert(outcome=='pickup' or outcome=='use','Invalid item visual outcome')
    append(battle,{skillId=0,itemId=itemId,sourceId=actor.Id,targetId=actor.Id,
        sourceQ=assert(actor.Q),sourceR=assert(actor.R),targetQ=q,targetR=r,
        sourceLayer=type(actor)=='table' and actor.layer or -2147483648,targetLayer=targetLayer or -2147483648,shot=1,outcome=outcome})
end
function Effects.Drain(battle)
    local events=battle.vfxEvents or {}
    battle.vfxEvents=nil
    return events
end
function Effects.Clear(battle)
    battle.vfxEvents=nil;battle.vfxSequence=0
end
return Effects
