package.path='Lua/?.lua;'..package.path
local Save=require('Game.Adventure.CharacterSave')
local Restoration=require('Game.Adventure.CampaignRestoration')
local bridge=require('Game.Adventure.CampaignLoadingBridge')
local count=0
local function test(name,run) run();count=count+1;print('PASS '..name) end
local function rejects(run) assert(not pcall(run),'Expected rejection') end
local current,failRead,failLayout,failValidation
local preparedCount,appliedCount,cleared=0,0,0
local function fixture()
    failRead,failLayout,failValidation=false,false,false
    local adventure={data={Phase='area',Equipment={}},parties={data={}},camp={data={}},shop={data={}},
        narrative={data={},Refresh=function(self) self.refreshed=true end},equipment={worldLoot={session={}}},
        characterSaves={id='current',worldName='Active world'},battle={},map='current map'}
    function adventure:RestorePrepared(prepared,world)
        appliedCount=appliedCount+1
        self.characterSaves.id=prepared.id;self.characterSaves.worldName=prepared.worldName
        self.map=world.map;self.data.Phase='area'
    end
    function adventure:Snapshot() return {map=self.map,id=self.characterSaves.id} end
    current=adventure;return adventure
end
CS={ProjectY={Data={CampaignSaves={PrepareSelected=function(service,id,equipment)
    assert(service==current.characterSaves and equipment==current.data.Equipment)
    preparedCount=preparedCount+1
    if failRead then error('broken save') end
    return {id=id,worldName='Saved world'}
end}}}}
Save.Validate=function(adventure,prepared)
    assert(adventure==current and prepared.id=='selected')
    if failValidation then error('invalid inventory') end
end
package.loaded['Game.Adventure.ExpeditionSave']={Prepare=function(adventure,prepared,progress)
    assert(adventure==current and prepared.id=='selected')
    if progress then progress(.2,'terrain');progress(.8,'areas') end
    if failLayout then error('changed layout') end
    if progress then progress(1,'validated') end
    return {map='restored map'}
end}
package.loaded['Game.Map.MapRenderSnapshot']=function(map) return {map=map} end
package.loaded['Game.Presentation.VisualEffects']={Clear=function() cleared=cleared+1 end}
package.loaded.Main={Get=function(_,name) assert(name=='Adventure');return current end}
local function prepare(job)
    local progress,steps=0,0
    while true do
        local done,value,stage=Restoration.Step(job);steps=steps+1
        assert(current.map=='current map' and current.characterSaves.id=='current' and current.characterSaves.worldName=='Active world')
        if done then assert(value.map=='restored map');return steps end
        assert(value>=progress and value<=.6 and type(stage)=='string');progress=value
    end
end
test('load yields through preparation, preserves live identity, and commits exactly once',function()
    local adventure=fixture();local before=appliedCount
    local job=Restoration.New(adventure,'selected');rejects(function() Restoration.Commit(job) end)
    assert(prepare(job)>=6 and appliedCount==before)
    local state=Restoration.Commit(job)
    assert(state.id=='selected' and state.map=='restored map' and adventure.characterSaves.worldName=='Saved world')
    assert(adventure.narrative.refreshed and appliedCount==before+1 and cleared==1)
    rejects(function() Restoration.Commit(job) end)
end)
test('read, validation and layout failures leave the current world and save untouched',function()
    for _,failure in ipairs({'read','validation','layout'}) do
        local adventure=fixture();local before=appliedCount
        failRead=failure=='read';failValidation=failure=='validation';failLayout=failure=='layout'
        local job=Restoration.New(adventure,'selected')
        rejects(function() prepare(job) end)
        assert(job.failed and not job.committed and appliedCount==before)
        assert(adventure.map=='current map' and adventure.characterSaves.id=='current')
        rejects(function() Restoration.Commit(job) end)
    end
end)
test('phase and interaction gates reject before preparation or commit',function()
    local adventure=fixture();local before=preparedCount
    adventure.data.Phase='battle';rejects(function() Restoration.New(adventure,'selected') end)
    adventure.data.Phase='map';adventure.shop.data.IsOpen=true
    rejects(function() Restoration.New(adventure,'selected') end);assert(preparedCount==before)
    adventure.shop.data.IsOpen=false;local job=Restoration.New(adventure,'selected');prepare(job)
    adventure.narrative.data.DialogueOpen=true;rejects(function() Restoration.Commit(job) end)
    assert(not job.committed and adventure.characterSaves.id=='current')
end)
test('loading bridge cancels prepared loads and rejects stale or competing operations',function()
    local adventure=fixture();local before=appliedCount
    bridge('begin_load',10,'selected')
    rejects(function() bridge('begin_load',11,'selected') end)
    rejects(function() bridge('step',9) end);rejects(function() bridge('release',9) end)
    while not bridge('step',10) do end
    bridge('release',10)
    assert(appliedCount==before and adventure.characterSaves.id=='current')
    rejects(function() bridge('commit',10) end)
    bridge('begin_load',11,'selected');while not bridge('step',11) do end
    assert(bridge('commit',11).id=='selected');bridge('release',11)
end)
test('synchronous compatibility uses the same prepare and commit contract',function()
    local adventure=fixture();failRead=true
    local ok,reason=Save.Read(adventure,'selected');assert(not ok and reason:find('broken save',1,true))
    assert(adventure.characterSaves.id=='current');failRead=false
    assert(Save.Read(adventure,'selected') and adventure.characterSaves.id=='selected')
end)
print('Campaign restoration checks passed: '..count)
