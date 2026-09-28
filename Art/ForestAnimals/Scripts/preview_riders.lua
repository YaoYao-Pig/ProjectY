local config=require('Config.ConfigSystem')()
config:OnInit({services=Services})
local stats=require('Game.Battle.CombatStats')(config)
local appearances=require('Game.Adventure.PawnAppearance').New(config)
local rows={}
for id=1,3 do
    local rider=CS.ProjectY.Data.CombatActorData(id,id)
    rider:SetMaxHP(stats:MaximumHP(rider));rider:Restore()
    Services.Appearances:Create(rider,412+id,'human','female')
    local species=stats.animals.species:Get(id)
    local mount=CS.ProjectY.Data.CombatActorData(100+id,species.unitId)
    mount:InitializeAnimal(species.id,1);mount:SetMaxHP(stats:MaximumHP(mount));mount:Restore()
    rider:TameAndRide(mount,10)
    rows[#rows+1]=require('Game.Battle.CombatSnapshot')(rider,stats,appearances)
end
return rows
