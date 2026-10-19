package.path='Lua/?.lua;'..package.path
local Prompt=require('Game.Adventure.InteractionPrompt')
local cells={{index=1},{index=2},{index=3}}
local connected=true
local area={cells=cells,facilities={{id=10,entryIndex=2,interactionRadius=1,name='铁匠服务台'}},npcs={{id=1,templateId=7}}}
function area:Neighbors(cell)if connected and cell.index==1 then return {cells[2],cells[3]}end;return {}end
local npc={Present=true,CellIndex=2};local state={CellIndex=1,SiteId=1,InteractionKind=0,GetNpcAt=function()return npc end}
local loot={id=20,cellIndex=3,name='木箱',canSearch=true,near=true,looted=false}
local adventure={data={Phase='area',Areas={Active=state}},areas={ActiveLayout=function()return area end,
    config={GetTable=function(_,name)assert(name=='MapAreaTownNpcTable');return {Get=function()return {name='铁匠'}end}end}},
    shop={rules={Resolve=function()return {id=1}end}},equipment={LootSnapshot=function()return {loot}end},
    obstacles={Snapshot=function()return {}end}}
local sent
function adventure:AreaCommand(command,a,b)sent={command,a,b};return true end
local row=Prompt.Find(adventure)
assert(row.kind==2 and row.id==1 and row.cellIndex==2 and row.action=='交易')
assert(Prompt.Execute(adventure) and sent[1]==row.command and sent[2]==row.a and sent[3]==row.b)
npc.Present=false;assert(Prompt.Find(adventure).kind==1)
area.facilities={};assert(Prompt.Find(adventure).kind==3)
loot.looted=true;assert(Prompt.Find(adventure).action=='存放')
loot.near=false;npc.Present=true;connected=false;assert(Prompt.Find(adventure)==nil,'Screen-near NPC across an impassable edge must not get an E prompt')
connected=true;state.InteractionKind=2;assert(Prompt.Find(adventure)==nil)
state.InteractionKind=0;adventure.data.Phase='battle';assert(Prompt.Find(adventure)==nil and not Prompt.Execute(adventure))
assert(loadfile('Lua/Game/Adventure/MainHudModel.lua'));assert(loadfile('Lua/UI/Widget/HudInteraction.lua'))
print('PASS shared E/HUD target, NPC/service priority, loot/storage, graph reachability and interaction/phase guards')
