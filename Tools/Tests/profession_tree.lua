-- Read-only profession layout against actual exported data; no Unity or business commands.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=file:read('*a');file:close();return bytes
end}})
local rules=require('Game.Progression.GrowthRules').New(config)
local Tree=require('UI.ProfessionTree')
local professions,atlas=rules.professions,rules.atlas
local count=0
local function test(name,fn)fn();count=count+1;print('PASS '..name)end
local function check(tree,professionId,source)
    local expected,expectedEdges={},{}
    local function visit(id)
        if expected[id] then return end
        expected[id]=true
        for _,parent in ipairs(source.nodes:Get(id).prerequisiteIds)do expectedEdges[parent..':'..id]=true;visit(parent) end
    end
    for id in pairs(professions.byProfession[professionId])do visit(id) end
    local seen,boxes={},{}
    local function box(id,x1,y1,x2,y2)
        assert(x1>=0 and y1>=0 and x2<=tree.width and y2<=tree.height,'Outside graph bounds: '..id)
        for _,other in ipairs(boxes)do
            assert(x2<=other.x1 or x1>=other.x2 or y2<=other.y1 or y1>=other.y2,'Overlapping nodes: '..id..' and '..other.id)
        end
        boxes[#boxes+1]={id=id,x1=x1,y1=y1,x2=x2,y2=y2}
    end
    for _,header in ipairs(tree.headers)do box(header.name,header.x-66,header.y-22,header.x+66,header.y+22) end
    for _,node in ipairs(tree.nodes)do
        assert(expected[node.id] and not seen[node.id],'Missing or duplicate course identity: '..node.id)
        assert(tree.byId[node.id]==node,'Lookup must point to the displayed node')
        seen[node.id]=true
        assert(node.course==professions.byProfession[professionId][node.id],'Cross-profession ancestors must not become current courses')
        -- Existing 100x91 widget: pivot.y=.7142857 puts the seal at y; expanded ring
        -- reaches y-34 and the new 110x18 state label reaches y+71.
        box(tostring(node.id),node.x-55,node.y-34,node.x+55,node.y+71)
    end
    for id in pairs(expected)do assert(seen[id],'Missing prerequisite closure node: '..id) end
    local actualEdges={}
    for _,edge in ipairs(tree.edges)do
        if edge.fromId then
            local key=edge.fromId..':'..edge.toId
            assert(expectedEdges[key] and not actualEdges[key],'Unexpected or duplicate prerequisite edge: '..key)
            actualEdges[key]=true
            assert(tree.byId[edge.fromId].depth<tree.byId[edge.toId].depth,'Prerequisites must precede descendants')
        else assert(edge.toId==nil,'Display-only branches must not claim prerequisite identities') end
    end
    for key in pairs(expectedEdges)do assert(actualEdges[key],'Missing prerequisite edge: '..key) end
end
test('all eleven professions preserve each course, prerequisite closure and bounded non-overlapping nodes',function()
    local all=professions.professions:All();assert(#all==11)
    for _,profession in ipairs(all)do check(Tree.Build(professions,atlas,profession.id),profession.id,atlas) end
end)
test('mage branches contain six arcane skills and one healing skill without invented dependencies',function()
    local tree=Tree.Build(professions,atlas,3);local groups={}
    assert(#tree.nodes==7 and #tree.headers==3)
    for _,node in ipairs(tree.nodes)do
        local name=atlas.categories:Get(node.categoryId).name
        groups[name]=(groups[name] or 0)+1
        assert(#node.prerequisiteIds==0)
    end
    assert(groups['奥术']==6 and groups['治疗']==1)
    for _,edge in ipairs(tree.edges)do assert(not edge.fromId and not edge.toId) end
end)
test('cross-profession prerequisite chains remain visible without adding learnable courses',function()
    local altered={nodes={Get=function(_,id)
        local row=atlas.nodes:Get(id)
        if id~=103 then return row end
        local copy={};for key,value in pairs(row)do copy[key]=value end;copy.prerequisiteIds={302};return copy
    end},categories=atlas.categories}
    local tree=Tree.Build(professions,altered,3);check(tree,3,altered)
    assert(#tree.nodes==9 and not tree.byId[301].course and not tree.byId[302].course)
    assert(tree.byId[103].depth==2)
end)
test('eligibility, learning and opportunity changes preserve node positions and graph bounds',function()
    local learned={};local growth={CurrentProfessionId=3,Level=1,PendingCount=1,HasSkill=function(_,id)return learned[id]==true end}
    local actor={Growth=growth}
    local stats={growth=rules,Get=function()return 0 end,Template=function()return {skillIds={}}end,
        equipment={SkillIds=function()local ids={};for id in pairs(learned)do ids[#ids+1]=id end;return ids end}}
    local before=Tree.Build(professions,atlas,3)
    assert(professions:CanLearn(actor,103,stats,atlas))
    learned[103]=true;growth.PendingCount=0;growth.Level=2
    assert(not professions:CanLearn(actor,103,stats,atlas))
    assert(atlas:State(103,actor,stats,atlas:Owned(actor,stats))=='owned')
    local after=Tree.Build(professions,atlas,3)
    assert(before.width==after.width and before.height==after.height and #before.nodes==#after.nodes)
    for _,node in ipairs(before.nodes)do
        local other=assert(after.byId[node.id]);assert(node.x==other.x and node.y==other.y)
    end
end)
print('Profession tree: '..count..' checks passed')
