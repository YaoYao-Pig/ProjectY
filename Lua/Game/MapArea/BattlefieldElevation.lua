-- One continuous, single-layer terraced hill. The hex distance field is 1-Lipschitz,
-- so neighboring cells always differ by at most one climbable step.
local Hex=require('Game.Map.HexGrid')
local Elevation={}
function Elevation.Validate(profile)
    assert(profile.heightStep>0 and profile.heightStep<=2,'Battlefield height step must be in (0,2]')
    assert(math.tointeger(profile.minElevation) and math.tointeger(profile.maxElevation) and profile.minElevation>=2 and profile.maxElevation>=profile.minElevation and profile.maxElevation<=3,'Battlefield hills need two or three elevation levels')
    assert(math.tointeger(profile.plateauRadius) and profile.plateauRadius>=0 and profile.plateauRadius<=1,'Invalid battlefield summit radius')
end
function Elevation.Apply(board,profile,random)
    Elevation.Validate(profile)
    local candidates={}
    for _,cell in ipairs(board.cells)do
        local radius=Hex.Distance(0,0,cell.q,cell.r)
        if not cell.blocked and radius>0 and radius<=math.max(1,board.radius-2) then candidates[#candidates+1]=cell end
    end
    local center=assert(candidates[random:Integer(1,#candidates)],'No walkable battlefield summit')
    local levels=random:Integer(profile.minElevation,profile.maxElevation)
    for _,cell in ipairs(board.cells)do
        local distance=Hex.Distance(center.q,center.r,cell.q,cell.r)
        local tier=math.max(0,levels-math.max(0,distance-profile.plateauRadius))
        cell.elevation=tier;cell.height=tier*profile.heightStep
        -- The summit is a usable fighting surface; its ring connects to the already walkable center.
        if distance<=profile.plateauRadius then cell.blocked=false end
    end
    return {q=center.q,r=center.r,levels=levels,heightStep=profile.heightStep}
end
return Elevation
