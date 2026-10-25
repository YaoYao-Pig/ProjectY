-- Actual exported diplomacy, read-only projection and geometry; no Editor or world startup.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local Tree=require('UI.FactionTree')
local overrides,reputation={},{}
local function pair(a,b) return math.min(a,b)..':'..math.max(a,b) end
local adventure={config=config,narrative={data={GetValue=function(_,key)return reputation[key] or 0 end,
    SetValue=function(_,key,value)reputation[key]=value end}}}
adventure.factions=setmetatable({adventure=adventure,rules=require('Game.Adventure.FactionRules').New(config),
    data={FindRelation=function(_,a,b)return overrides[pair(a,b)]end}},require('Game.Adventure.WorldFactions'))
local roots={0};for _,policy in ipairs(adventure.factions.rules.policies:All()) do roots[#roots+1]=policy.id end
local function find(tree,id) for _,node in ipairs(tree.nodes) do if node.id==id then return node end end;error('Missing node '..id) end
local Language=require('Language')
local masked=Tree.Build(adventure,0)
assert(masked.unknownCount==#roots-1)
for _,group in ipairs(masked.groups) do assert(#group.nodes==0,'Unknown identities must not expose diplomatic groups') end
for _,node in ipairs(masked.nodes) do
    assert(node.name==Language.UIFactionUnknownName and not node.discovered and node.value==nil and node.description==nil and node.relation=='unknown')
end
assert(not pcall(Tree.Build,adventure,4),'Undiscovered faction must not be inspectable')
require('Game.Adventure.FactionDiscovery').Mark(adventure.factions,1)
local partial=Tree.Build(adventure,0)
assert(partial.unknownCount==masked.unknownCount-1 and find(partial,1).discovered and not find(partial,4).discovered)
for _,id in ipairs(roots) do require('Game.Adventure.FactionDiscovery').Mark(adventure.factions,id) end
print('PASS masked identities, hidden relations/values/descriptions, blocked unknown roots and first discovery')
for _,root in ipairs(roots) do
    local tree=Tree.Build(adventure,root);local seen={}
    assert(#tree.nodes==#roots-1 and tree.root.id==root)
    local total=0
    for _,group in ipairs(tree.groups) do
        total=total+#group.nodes
        for i,node in ipairs(group.nodes) do
            assert(node.id~=root and not seen[node.id]);seen[node.id]=true
            assert(node.relation==group.relation and node.relation==adventure.factions:Relation(root,node.id))
            assert(node.x>=0 and node.y>=0 and node.x+260<=tree.width and node.y+64<=tree.height)
            if i>1 then assert(node.y>=group.nodes[i-1].y+64) end
            local reverse=find(Tree.Build(adventure,node.id),root)
            assert(reverse.value==node.value and reverse.relation==node.relation,'Asymmetric projection')
        end
    end
    assert(total==#tree.nodes)
    for _,edge in ipairs(tree.edges) do
        assert(edge.from.x==edge.to.x or edge.from.y==edge.to.y,'Tree links must be orthogonal')
        for _,node in ipairs(tree.nodes) do
            local left,right=math.min(edge.from.x,edge.to.x),math.max(edge.from.x,edge.to.x)
            local top,bottom=math.min(edge.from.y,edge.to.y),math.max(edge.from.y,edge.to.y)
            assert(right<=node.x or left>=node.x+260 or bottom<=node.y or top>=node.y+64,'Branch crosses a faction card')
        end
    end
end
print('PASS all '..#roots..' roots: complete direct relationships, symmetry, no duplicate/self nodes, bounded cards and unobstructed branches')
overrides[pair(1,2)]={Value=70};overrides[pair(2,6)]={Value=70};overrides[pair(1,6)]={Value=0}
assert(find(Tree.Build(adventure,1),2).relation=='allied' and find(Tree.Build(adventure,1),6).relation=='neutral','Alliances must not propagate')
overrides[pair(1,6)]={Value=-100}
assert(find(Tree.Build(adventure,1),6).relation=='hostile','Saved diplomacy overrides must be visible')
overrides[pair(1,2)],overrides[pair(2,6)],overrides[pair(1,6)]=nil,nil,nil
reputation['reputation:4']=1000
assert(find(Tree.Build(adventure,0),4).value==100 and find(Tree.Build(adventure,4),0).value==100)
reputation['reputation:4']=-1000
assert(find(Tree.Build(adventure,0),4).value==-100)
reputation['reputation:4']=nil
assert(not pcall(Tree.Build,adventure,999999),'Unknown roots must fail visibly')
print('PASS runtime overrides, non-transitive alliances, clamped player reputation and invalid roots')
return adventure
