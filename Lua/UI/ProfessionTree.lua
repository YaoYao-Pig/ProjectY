-- 职业树的只读布局；目录分支不添加学习前置，技能连线只取图谱配置。
local Tree={}
function Tree.Build(professions,atlas,professionId)
    local nodes,byId,groups,byCategory={},{},{},{}
    local function include(id)
        if byId[id] then return byId[id] end
        local source=atlas.nodes:Get(id)
        local node={id=id,glyphCode=source.glyphCode,categoryId=source.categoryId,prerequisiteIds=source.prerequisiteIds,depth=0}
        byId[id]=node;nodes[#nodes+1]=node
        for _,parentId in ipairs(source.prerequisiteIds) do node.depth=math.max(node.depth,include(parentId).depth+1) end
        return node
    end
    for _,course in ipairs(professions.courses:All()) do
        if course.professionId==professionId then include(course.skillId).course=course end
    end
    table.sort(nodes,function(a,b)
        if a.depth~=b.depth then return a.depth<b.depth end
        local aLevel,bLevel=a.course and a.course.minLevel or 0,b.course and b.course.minLevel or 0
        return aLevel==bLevel and a.id<b.id or aLevel<bLevel
    end)
    local layerRows={}
    for _,node in ipairs(nodes) do
        local group=byCategory[node.categoryId]
        if not group then
            group={category=atlas.categories:Get(node.categoryId),nodes={},layers={},columns=1}
            byCategory[node.categoryId]=group;groups[#groups+1]=group
        end
        group.nodes[#group.nodes+1]=node
        local layer=group.layers[node.depth] or {};group.layers[node.depth]=layer;layer[#layer+1]=node
        group.columns=math.max(group.columns,math.min(3,#layer))
        layerRows[node.depth]=math.max(layerRows[node.depth] or 0,math.ceil(#layer/3))
    end
    table.sort(groups,function(a,b) return a.category.order==b.category.order and a.category.id<b.category.id or a.category.order<b.category.order end)
    local width=0
    for i,group in ipairs(groups) do group.width=group.columns*120+24;width=width+group.width+(i>1 and 20 or 0) end
    local graphWidth=math.max(570,width);local left=(graphWidth-width)/2
    local headers={{id=professionId,name=professions.professions:Get(professionId).name,x=graphWidth/2,y=26,profession=true}}
    local edges={}
    local function line(x1,y1,x2,y2,fromId,toId)
        edges[#edges+1]={from={x=x1,y=y1},to={x=x2,y=y2},fromId=fromId,toId=toId}
    end
    local layerY={};local nextY=150
    for depth=0,#layerRows do
        layerY[depth]=nextY;nextY=nextY+(layerRows[depth] or 0)*118
    end
    for _,group in ipairs(groups) do
        local center=left+group.width/2
        headers[#headers+1]={name=group.category.name,x=center,y=78}
        line(graphWidth/2,48,graphWidth/2,52);line(graphWidth/2,52,center,52);line(center,52,center,56)
        local rootRows={}
        for depth,layer in pairs(group.layers) do
            for i,node in ipairs(layer) do
                node.x=left+84+((i-1)%3)*120;node.y=layerY[depth]+math.floor((i-1)/3)*118
                if #node.prerequisiteIds==0 then
                    rootRows[node.y]=math.max(rootRows[node.y] or 0,node.x)
                    line(node.x,node.y-46,node.x,node.y-28)
                end
            end
        end
        local bottom=104
        for y,right in pairs(rootRows) do bottom=math.max(bottom,y-46);line(left+8,y-46,right,y-46) end
        if next(rootRows) then
            line(center,100,center,104);line(center,104,left+8,104)
            if bottom>104 then line(left+8,104,left+8,bottom) end
        end
        left=left+group.width+20
    end
    for _,node in ipairs(nodes) do
        for _,id in ipairs(node.prerequisiteIds) do
            local parent=byId[id];line(parent.x,parent.y+72,node.x,node.y-28,id,node.id)
        end
    end
    return {nodes=nodes,byId=byId,headers=headers,edges=edges,width=graphWidth,height=math.max(342,nextY-118+78)}
end
return Tree
