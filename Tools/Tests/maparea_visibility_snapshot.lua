-- Real C# visibility state -> compact Lua snapshot -> C# display arrays. Edit Mode only.
local Layout=require('Game.MapArea.MapAreaLayout')
local AreaSystem=require('Game.MapArea.MapAreaSystem')
local function fixture(width,height)
    local area=Layout.New({id=1,name='Visibility',areaType=2,width=width,height=height,hexRadius=1.5,
        visionRadius=5,moveStepSeconds=.5,discovery='open'},1,{regionId=1,regionType=1},{name='Visibility'})
    area.entryIndex=1;area.goalIndex=#area.cells;area.props={}
    for _,cell in ipairs(area.cells) do cell.blocked=false;cell.blocksSight=false;cell.height=0 end
    local state=CS.ProjectY.Data.MapAreaStateData(1,#area.cells,1)
    state:DeployMembers({1},{1})
    local system=AreaSystem();system.data={Active=state,ActiveSiteId=1};system.layouts={[1]=area}
    local function read()
        local row=system:Snapshot();row.constructionRevision=0
        return row,CS.ProjectY.Samples.MapAreaViewData.ReadState({area=row})
    end
    return area,state,read
end
local area,state,read=fixture(4,3)
local all={};for i=1,#area.cells do all[i]=i end;state:Reveal(all)
local full,fullView=read()
assert(full.fullVisibilityCount==12 and #full.known==0 and #full.visible==0)
assert(fullView.Known.Length==12 and fullView.Visible.Length==12)
for i=0,11 do assert(fullView.Known[i]==i and fullView.Visible[i]==i) end
state:Reveal({1,3,5})
local partial,partialView=read()
assert(partial.fullVisibilityCount==0 and #partial.known==12 and #partial.visible==3)
assert(partialView.Known.Length==12 and partialView.Visible.Length==3 and partialView.Visible[1]==2)
assert(fullView.Visible.Length==12 and fullView.Visible[11]==11,'Later visibility changed a detached full-map snapshot')
partial.fullVisibilityCount=nil
local legacy=CS.ProjectY.Samples.MapAreaViewData.ReadState({area=partial})
assert(legacy.Visible.Length==3 and legacy.Visible[2]==4,'Legacy explicit visibility stopped working')
state:Reveal({});local hidden,hiddenView=read()
assert(hidden.fullVisibilityCount==0 and hiddenView.Visible.Length==0 and hiddenView.Known.Length==12)
local second,secondState,readSecond=fixture(3,3)
local ids={};for i=1,#second.cells do ids[i]=i end;secondState:Reveal(ids)
local other,otherView=readSecond()
assert(other.fullVisibilityCount==9 and otherView.Visible.Length==9)
assert(fullView.Visible.Length==12 and fullView.Visible[11]==11,'Changing map size corrupted an older snapshot')
return 'PASS full/partial/empty/legacy visibility, 1-based to 0-based indices, immutable shared ranges and map-size changes'
