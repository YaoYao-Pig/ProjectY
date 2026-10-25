-- Settled direct hits only; transient presentation data, never gameplay state.
local Audio={}
function Audio.Record(battle,event)
    if event.kind~='damage' or not event.attackHit or event.periodic or event.amount<=0 then return end
    if event.sourceId==event.targetId then return end
    local impact=assert(event.impact,'Attack audio requires settled impact metadata')
    local shot=assert(impact.shot,'Attack audio requires a shot index')
    assert(shot>=1,'Attack audio shot index must be positive')
    local key=table.concat({assert(event.sourceId),assert(event.targetId),shot},':')
    local seen=battle.audioSeen
    if not seen then seen={};battle.audioSeen=seen end
    if seen[key] then return end
    seen[key]=true
    local events=battle.audioEvents
    if not events then events={};battle.audioEvents=events end
    if #events==128 then table.remove(events,1) end
    events[#events+1]={shot=shot,critical=impact.critical==true}
end
function Audio.Drain(battle)
    local events=battle.audioEvents or {}
    Audio.Clear(battle)
    return events
end
function Audio.Clear(battle)
    battle.audioEvents=nil;battle.audioSeen=nil
end
return Audio
