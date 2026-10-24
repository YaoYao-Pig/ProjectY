package.path = 'Lua/?.lua;' .. package.path
local Loading = require('UI.LoadingSystem')
local Ctr = require('UI.Panel.LoadingCtr')
local Random = require('Game.Map.SeededRandom')
local count = 0
local function test(name, run) run(); count = count + 1; print('PASS ' .. name) end
local function rejects(run) assert(not pcall(run), 'Expected rejection') end
local rows = {
    {id=1,enabled=true,category='建议',content='提示 A',duration=2},
    {id=2,enabled=false,category='隐藏',content='不可见',duration=2},
    {id=3,enabled=true,category='骚话',content='提示 B',duration=3},
}
local ui = { Open=function(self,name,state) assert(name=='Loading'); self.state=state end,
    Close=function(self,name) assert(name=='Loading'); self.state=nil end }
local config = { GetTable=function(_,name) assert(name=='LoadingTipTable'); return {All=function() return rows end} end }
local loading = Loading()
loading:OnInit({systems={Get=function(_,name) return assert(({UI=ui,Config=config})[name]) end}})
test('exclusive ownership, monotonic progress and stale-token rejection',function()
    local id=loading:Begin('创建世界',{})
    assert(ui.state.progress==0 and #ui.state.tips==2)
    rejects(function() loading:Begin('重复',{}) end)
    loading:Report(id,.5,'生成中'); assert(ui.state.progress==.5)
    rejects(function() loading:Report(id,.4,'回退') end)
    rejects(function() loading:Report(id,0/0,'非法') end)
    rejects(function() loading:Report(id,1.1,'超出') end)
    loading:Finish(id); assert(not ui.state and not loading.active)
    local nextId=loading:Begin('再次创建',{})
    rejects(function() loading:Finish(id) end)
    assert(loading.active.token==nextId)
    loading:OnShutdown(); assert(not ui.state)
end)
test('opening failure releases ownership and exposes error',function()
    local open=ui.Open; ui.Open=function() error('missing prefab') end
    rejects(function() loading:Begin('失败',{}) end)
    assert(not loading.active);ui.Open=open
    rows[1].enabled=false;rows[3].enabled=false
    rejects(function() loading:Begin('无文案',{}) end)
    rows[1].enabled=true;rows[3].enabled=true
end)
test('tips rotate in paused time without immediate repeats; one tip is valid',function()
    local view={}
    for _,key in ipairs({'Title','Stage','Percent','TipCategory','Tip','Progress'})do view[key]={} end
    local ctrl=setmetatable({view=view},{__index=Ctr})
    local state={title='创建世界',font={},progress=0,stage='准备',tips={rows[1],rows[3]},random=Random(42)}
    ctrl:OnShow(state);assert(view.Percent.text=='0%')
    for i=1,20 do local previous=ctrl.tipIndex;ctrl:Tick(0,4);assert(previous~=ctrl.tipIndex) end
    state.progress=1;state.stage='完成';ctrl:Tick(0,0)
    assert(view.Percent.text=='100%' and view.Progress.value==1 and view.Stage.text=='完成')
    ctrl:OnHide();assert(not ctrl.state)
    state.tips={rows[1]};ctrl:OnShow(state);ctrl:Tick(0,20)
    assert(ctrl.tipIndex==1 and view.Tip.text=='提示 A')
end)

local Creation=require('Game.Adventure.CampaignCreation')
local adventure={data={Phase='map'},parties={data={}},camp={data={}},shop={data={}},
    narrative={data={}},equipment={worldLoot={session={}}}}
adventure.config={GetTable=function(_,name)
    if name=='CampaignStartTable' then return {Find=function(_,id)
        if id==1 then return {id=1,name='默认开场',description='',adventureRecipeId=5,coins=60} end
    end} end
    assert(name=='AdventureDemoTable');return {Get=function(_,id)assert(id==5);return {id=id}end}
end}
local snapshot=require('Game.Map.MapRenderSnapshot')
package.loaded['Game.Map.MapRenderSnapshot']=function(map) return {seed=map.seed} end
adventure.BuildWorld=function(self,seed,recipe,size,progress)
    assert(recipe==5 and size==2500);progress(.2,'地形');progress(1,'完成')
    return {map={seed=seed}}
end
test('preparation yields without committing; validates input and phase',function()
    for _,seed in ipairs({'-1','1.5','4294967296','abc'})do rejects(function()Creation.New(adventure,seed,2500)end)end
    rejects(function()Creation.New(adventure,'0',123)end)
    local job=Creation.New(adventure,'4294967295',2500);local progress=0;local steps=0
    while true do
        local done,value=Creation.Step(job);steps=steps+1
        if done then assert(value.seed==4294967295);break end
        assert(value>=progress and value<1);progress=value
    end
    assert(steps>=4 and job.ready and not job.committed)
    rejects(function()Creation.Step(job)end)
    adventure.data.Phase='battle';rejects(function()Creation.Commit(job)end)
    assert(not job.committed);adventure.data.Phase='map'
    adventure.BuildWorld=function()error('generation failure')end
    local failed=Creation.New(adventure,'0',2500)
    rejects(function()Creation.Step(failed)end);assert(failed.failed and not failed.committed)
end)
package.loaded['Game.Map.MapRenderSnapshot']=snapshot
print('Loading checks passed: '..count)
