-- Read-only diplomatic projection. Branches classify direct relationships, never ancestry.
local Language=require('Language')
local Tree={}
function Tree.Build(adventure,rootId)
    local factions=adventure.factions
    local definitions=adventure.config:GetTable('FactionTable')
    local function identity(id)
        if id==0 then return {id=0,name=Language.UIFactionPlayer,description=Language.UIFactionPlayerDescription} end
        local row=definitions:Get(id)
        return {id=id,name=row.name,description=row.description}
    end
    if rootId~=0 then factions.rules.policies:Get(rootId) end
    assert(factions:IsDiscovered(rootId),'Cannot inspect an undiscovered faction')
    local groups={{relation='allied',x=190,nodes={}},{relation='neutral',x=570,nodes={}},{relation='hostile',x=950,nodes={}}}
    local byRelation={};for _,group in ipairs(groups) do byRelation[group.relation]=group end
    local ids={0};for _,policy in ipairs(factions.rules.policies:All()) do ids[#ids+1]=policy.id end
    table.sort(ids)
    local nodes,edges,unknown={},{},{}
    local function line(x1,y1,x2,y2,relation)
        if x1~=x2 or y1~=y2 then edges[#edges+1]={from={x=x1,y=y1},to={x=x2,y=y2},relation=relation} end
    end
    local height=440
    for _,id in ipairs(ids) do if id~=rootId then
        if not factions:IsDiscovered(id) then
            unknown[#unknown+1]={id=id,name=Language.UIFactionUnknownName,relation='unknown',discovered=false}
        else
        local row=identity(id);row.discovered=true;local reputation=0
        if rootId==0 or id==0 then reputation=adventure.narrative.data:GetValue('reputation:'..(rootId==0 and id or rootId)) end
        row.value=factions.rules:Value(rootId,id,factions.data,reputation)
        row.relation=factions:Relation(rootId,id)
        local group=assert(byRelation[row.relation],'Unknown diplomatic relation')
        group.nodes[#group.nodes+1]=row
        end
    end end
    line(570,84,570,104,'neutral')
    for _,group in ipairs(groups) do
        line(570,104,group.x,104,group.relation);line(group.x,104,group.x,124,group.relation)
        local spine=group.x-156
        for i,row in ipairs(group.nodes) do
            row.x,row.y=group.x-130,192+(i-1)*80
            nodes[#nodes+1]=row
            line(spine,row.y+32,row.x,row.y+32,group.relation)
            height=math.max(height,row.y+88)
        end
        if #group.nodes>0 then
            line(group.x,164,group.x,178,group.relation);line(group.x,178,spine,178,group.relation)
            line(spine,178,spine,group.nodes[#group.nodes].y+32,group.relation)
        end
    end
    local unknownY=204
    for _,row in ipairs(nodes) do unknownY=math.max(unknownY,row.y+104) end
    for i,row in ipairs(unknown) do
        row.x=60+((i-1)%3)*380;row.y=unknownY+40+math.floor((i-1)/3)*80
        nodes[#nodes+1]=row;height=math.max(height,row.y+88)
    end
    return {root=identity(rootId),groups=groups,nodes=nodes,edges=edges,width=1140,height=height,unknownCount=#unknown,unknownY=unknownY}
end
return Tree
