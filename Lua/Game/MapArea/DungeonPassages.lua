-- 通道中心线保底净宽，外轮廓按连续噪声扩宽，并在中段形成局部洞厅。
local G=require('Game.MapArea.DungeonGeometry')
local Passages={}
function Passages.Carve(area,row,random,path,brush,connection)
    local desired,limits={},{}
    local chamber=random:Integer(0,1000)/1000<row.chamberChance
    local peak=math.floor(#path*random:Integer(35,65)/100)
    for i,cell in ipairs(path) do
        local noise=random:Noise(i,connection.a*11+connection.b*7,row.corridorWidthScale,2791)
        desired[i]=math.floor(row.corridorRadius+(row.corridorMaxRadius-row.corridorRadius+1)*noise)
        if chamber and math.abs(i-peak)<row.corridorMaxRadius*2 then desired[i]=row.corridorMaxRadius end
        limits[i]=row.corridorRadius
        for radius=row.corridorRadius+1,row.corridorMaxRadius do
            local valid=true
            G.Disk(cell.q,cell.r,radius,function(q,r)
                local covered=area:Find(q,r)
                -- 扩宽不能侵入任何房间，避免破坏预设、陈设或另开未规划的房门。
                if not G.Inside(area,covered,row.borderWidth) or covered.obstacleId>0 or covered.roomOwner>0 then valid=false end
            end)
            if not valid then break end
            limits[i]=radius
        end
        desired[i]=math.min(desired[i],limits[i])
    end
    -- 两向限制相邻断面的变化，不在墙角从 9 格突然收缩到 5 格。
    for i=2,#path do desired[i]=math.min(desired[i],desired[i-1]+1) end
    for i=#path-1,1,-1 do desired[i]=math.min(desired[i],desired[i+1]+1) end
    connection.radii={};connection.path={}
    for i,cell in ipairs(path) do
        connection.path[i]=cell.index;connection.radii[i]=desired[i]
        if desired[i]==row.corridorRadius then
            for _,covered in ipairs(brush[cell.index]) do G.Carve(area,covered,'corridor');covered.reserved=true end
        else
            G.Disk(cell.q,cell.r,desired[i],function(q,r)
                local covered=area:Find(q,r);G.Carve(area,covered,'corridor');covered.reserved=true
            end)
        end
    end
end
return Passages
