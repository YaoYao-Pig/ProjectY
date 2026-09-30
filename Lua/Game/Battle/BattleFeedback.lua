-- Bridges settled battle notifications to the HUD-owned presentation system.
local Feedback={}
function Feedback.Changed(view,event)
    if event.kind=='battle_started' then view:Clear();return end
    if (event.kind~='damage' and event.kind~='heal') or event.amount<=0 then return end
    local actor=assert(event.target,'Health feedback requires the settled target')
    local health=actor.MountedAnimal or actor
    view:QueueHealth(actor.Id,health.Id,health.HP/health.MaxHP)
    if event.kind=='damage' then
        local impact=assert(event.impact,'Damage feedback requires impact metadata')
        if event.attackHit or impact.critical or impact.defeated then
            view:QueueImpact(impact.shot,impact.critical==true,impact.defeated==true)
        end
    end
end
return Feedback
