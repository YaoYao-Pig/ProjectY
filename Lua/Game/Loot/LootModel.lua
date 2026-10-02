-- Read-only grid projection; revealed state and remaining items live in map container data.
local Model={};Model.__index=Model
function Model.New(worldLoot)
    return setmetatable({loot=worldLoot,session=worldLoot.session,rules=worldLoot.equipment.rules},Model)
end
function Model:Rows()
    local rows={};local width=8;local x,y,lineHeight=0,0,0
    for i=0,self.session.Count-1 do
        local entry=self.session:GetAt(i);local item=self.rules.items:Get(entry.ItemId)
        local displayWidth,displayHeight=math.max(2,item.width),math.max(2,item.height)
        assert(displayWidth<=width,'Loot item exceeds source grid width')
        if x+displayWidth>width then x=0;y=y+lineHeight;lineHeight=0 end
        local known=entry.Revealed;local source=self.session.Area:GetLootAt(entry.ContainerId-1)
        rows[#rows+1]={key=entry.Key,itemId=entry.ItemId,kind=item.kind,name=known and item.name or '未搜索的物品',
            detail=known and ('来自：'..source.Name) or '正在搜索，揭示后可以拖入背包',iconPath=item.iconPath,count=entry.Count,
            slot='',compatible='',equipMask=0,width=item.width,height=item.height,displayWidth=displayWidth,displayHeight=displayHeight,
            x=x,y=y,rotated=false,revealed=known}
        x=x+displayWidth;lineHeight=math.max(lineHeight,displayHeight)
    end
    return rows,width,math.max(1,y+lineHeight)
end
function Model:Searching()
    for i=0,self.session.Count-1 do
        local entry=self.session:GetAt(i)
        if entry.Count>0 and not entry.Revealed then return entry end
    end
end
return Model
