-- Shared axial geometry for skill eligibility and its read-only preview.
local Hex=require('Game.Map.HexGrid')
local Shape={}
function Shape.Validate(shape)
    assert(shape=='hex' or shape=='line' or shape=='ring','Unknown skill shape: '..tostring(shape))
end
function Shape.Contains(shape,oq,or_,q,r,radius,minimum)
    Shape.Validate(shape)
    local distance=Hex.Distance(oq,or_,q,r)
    if distance<minimum or distance>radius then return false end
    if shape=='ring' then return distance==radius end
    if shape=='line' then return q==oq or r==or_ or q+r==oq+or_ end
    return true
end
-- Minimum range and rings use the nearest edges of complete footprints.
function Shape.Footprints(shape,origins,targets,radius,minimum)
    Shape.Validate(shape)
    local nearest=math.huge;local aligned=false
    for _,a in ipairs(origins)do for _,b in ipairs(targets)do
        local distance=Hex.Distance(a.q,a.r,b.q,b.r)
        nearest=math.min(nearest,distance)
        if distance<=radius and (a.q==b.q or a.r==b.r or a.q+a.r==b.q+b.r)then aligned=true end
    end end
    if nearest<minimum or nearest>radius then return false end
    if shape=='ring'then return nearest==radius end
    return shape=='hex' or aligned
end
function Shape.Cells(board,center,shape,radius)
    local result={}
    for q=center.q-radius,center.q+radius do for r=center.r-radius,center.r+radius do
        if Shape.Contains(shape,center.q,center.r,q,r,radius,0)then
            local cell=board:Find(q,r,center.layer)
            if cell and not cell.blocked and (cell.layer or 0)==(center.layer or 0)then result[#result+1]=cell end
        end
    end end
    return result
end
return Shape
