-- Read-only grid projection; revealed state and remaining items live in map container data.
local Model={};Model.__index=Model
function Model.New(worldLoot)
    return setmetatable({loot=worldLoot,session=worldLoot.session,rules=worldLoot.equipment.rules},Model)
end
function Model:Rows()
    local rows={};local width=6;local x,y,lineHeight=0,0,0
    local selected=self.session.SelectedContainerId;local grid=selected~=0 and self.session.Grid or nil
    if grid then width=grid.Width end
    for i=0,self.session.Count-1 do
        local entry=self.session:GetAt(i);local item=self.rules.items:Get(entry.ItemId)
        if selected==0 or entry.ContainerId==selected then
        local displayWidth,displayHeight=item.width,item.height
        assert(displayWidth<=width,'Loot item exceeds source grid width')
        local rowX,rowY,rotated=x,y,false
        if grid then
            local place=entry.Count>0 and assert(grid:Find(entry.Key),'Container item is missing its placement') or nil
            rowX,rowY=place and place.X or -1,place and place.Y or -1;rotated=place~=nil and place.Rotated or false
            if rotated then displayWidth,displayHeight=item.height,item.width end
        else
            if x+displayWidth>width then x=0;y=y+lineHeight;lineHeight=0 end
            rowX,rowY=x,y;x=x+displayWidth;lineHeight=math.max(lineHeight,displayHeight)
        end
        local known=entry.Revealed;local source=self.session.Area:GetLootAt(entry.ContainerId-1)
        rows[#rows+1]={key=entry.Key,itemId=entry.ItemId,kind=item.kind,name=known and item.name or '未搜索的物品',
            detail=known and ('来自：'..source.Name) or '正在搜索，揭示后可以拖入背包',iconPath=item.iconPath,count=entry.Count,
            slot='',compatible='',equipMask=0,width=item.width,height=item.height,displayWidth=displayWidth,displayHeight=displayHeight,
            x=rowX,y=rowY,rotated=rotated,revealed=known}
        end
    end
    return rows,width,grid and grid.Height or math.max(6,y+lineHeight)
end
function Model:Searching()
    for i=0,self.session.Count-1 do
        local entry=self.session:GetAt(i)
        if entry.Count>0 and not entry.Revealed and (self.session.SelectedContainerId==0 or entry.ContainerId==self.session.SelectedContainerId) then return entry end
    end
end
return Model
