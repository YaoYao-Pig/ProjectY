-- 定向检查只读布局到 xLua 显示快照的数组边界，不启动 Editor、不使用 C# 状态替身。
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local data=file:read('*a');file:close();return data
end}})
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(2,require('Game.MapArea.TownGenerator'),'MapAreaTownTable','MapAreaTownThemeTable')
local area=generator:Generate(2,20260924,11,{regionId=7,regionType=2,regionConfigId=2,q=0,r=0,height=1,
    biomeWeights={{regionType=2,weight=1}}})
local AreaSystem=require('Game.MapArea.MapAreaSystem')
local appearance=require('Game.Adventure.PawnAppearance').New(config)
-- 直接调用真实快照入口，只提供其读取依赖；不初始化探索会话或模拟移动状态。
local reader={config=config,appearance=appearance,ActiveLayout=function() return area end}
local function snapshot() return AreaSystem.LayoutSnapshot(reader) end
assert(#area.cells[1].corners==6 and rawlen(area.cells[1].corners)==0,'Fixture must use the real frozen layout')
local view=snapshot();local layers={}
assert(rawlen(view.cells)==#area.cells)
for i,cell in ipairs(view.cells) do
    local original=area.cells[i];layers[cell.layer]=true
    assert(rawlen(cell.corners)==6,'C# sees an empty corner array at cell '..i)
    assert(rawlen(cell.neighbors)==6,'C# sees an empty neighbor array at cell '..i)
    assert(rawlen(cell.color)==3,'Snapshot color must be a plain numeric array')
    for d=1,6 do
        assert(rawget(cell.corners,d)==original.corners[d])
        assert(rawget(cell.neighbors,d)==original.neighbors[d])
    end
    for c=1,3 do assert(rawget(cell.color,c)==original.color[c]) end
end
assert(layers[0] and layers[1])
-- 改显示快照不得反向污染静态布局或后续快照。
view.cells[1].corners[1]=-999;view.cells[1].neighbors[1]=-999;view.cells[1].color[1]=-999
local again=snapshot()
assert(again.cells[1].corners[1]==area.cells[1].corners[1])
assert(again.cells[1].neighbors[1]==area.cells[1].neighbors[1])
assert(again.cells[1].color[1]==area.cells[1].color[1])
assert(not pcall(function() area.cells[1].corners[1]=0 end),'Original layout must remain read-only')
-- 地牢没有坡面顶点时，平地快照同样给足六个高度和六个邻接索引（含边界 0）。
local Layout=require('Game.MapArea.MapAreaLayout')
local flat=Layout.New({id=1,name='快照检查',areaType=1,width=2,height=2,hexRadius=1.5,visionRadius=3,moveStepSeconds=.5},
    1,area.source,area.theme)
flat.props={};flat.corridorRadius=2
for _,cell in ipairs(flat.cells) do cell.height=.25;cell.wallHeight=3;cell.color={.2,.3,.4} end
reader.ActiveLayout=function() return Layout.Freeze(flat) end
for _,cell in ipairs(snapshot().cells) do
    assert(rawlen(cell.corners)==6 and rawlen(cell.neighbors)==6 and rawlen(cell.color)==3)
    for d=1,6 do assert(cell.corners[d]==.25 and cell.neighbors[d]>=0) end
end
print('PASS MapArea snapshot: real frozen town arrays, both layers, copy isolation and flat dungeon cells')
