-- One life predicate shared by combat, exploration and projections. HP is never falsified.
local Life={}
function Life.Alive(actor)return CS.ProjectY.Data.DeathDoorState.Alive(actor)end
function Life.Dead(actor)return CS.ProjectY.Data.DeathDoorState.Dead(actor)end
function Life.Entered(actor)return CS.ProjectY.Data.DeathDoorState.Entered(actor)end
return Life
