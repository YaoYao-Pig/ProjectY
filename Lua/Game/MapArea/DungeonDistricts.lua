-- 先赋予房间功能分区，再在分区主厅附近排布附属空间；避免所有房间均匀散落。
local Hex=require('Game.Map.HexGrid')
local Districts={}
function Districts.Place(area,row,random,config,selected)
    area.districts={}
    local definitions=config:GetTable('MapAreaDistrictTable')
    local flip,swap=random:Integer(0,1)==1,random:Integer(0,1)==1
    for _,id in ipairs(row.districtIds) do
        local item=definitions:Get(id);local q,r=item.anchorQ,item.anchorR
        if flip then q,r=1-q,1-r end
        if swap then q,r=r,q end
        area.districts[id]={id=id,name=item.name,q=math.floor(q*(area.width-1)),r=math.floor(r*(area.height-1)),rotation=random:Integer(0,5)}
    end
    -- 先放主厅，再放大附属房；同分区沿用建筑轴向，天然洞穴允许自行转向。
    table.sort(selected,function(a,b)
        if (a.tier==3)~=(b.tier==3) then return a.tier==3 end
        return a.radius>b.radius or a.radius==b.radius and a.order<b.order
    end)
    for _,room in ipairs(selected) do
        local district=assert(area.districts[room.districtId],'Room references a district outside this dungeon profile')
        local low=row.borderWidth+room.radius;local bestScore
        assert(area.width>low*2 and area.height>low*2,'Dungeon dimensions cannot contain the configured rooms')
        for _=1,row.placementAttempts do
            local q=random:Integer(low,area.width-low-1);local r=random:Integer(low,area.height-low-1)
            local valid=true
            for _,other in ipairs(area.rooms) do
                if Hex.Distance(q,r,other.q,other.r)<=room.radius+other.radius+row.roomGap then valid=false;break end
            end
            if valid then
                local score=Hex.Distance(q,r,district.q,district.r)+random:Noise(q,r,12,room.order*971)*4
                if not bestScore or score<bestScore then bestScore=score;room.q=q;room.r=r end
            end
        end
        assert(bestScore,'Dungeon district placement exhausted; reduce room count/radius or enlarge the area')
        if room.tier==3 then district.q=room.q;district.r=room.r end
        room.id=#area.rooms+1;room.rotation=room.tier==1 and random:Integer(0,5) or district.rotation
        room.center=area:Find(room.q,room.r).index;room.combatRadius=math.min(row.combatRadius,room.radius-1)
        area.rooms[room.id]=room
    end
end
return Districts
