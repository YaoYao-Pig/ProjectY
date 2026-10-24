-- Native Edit Mode host supplies a PreviewScene UIHost, font and a new OS-temporary save path.
local path=Services.CharacterSaves.FilePath:gsub('\\','/'):lower()
assert(path:find('project%-y%-loading%-'),'An isolated save path is required')
local registry=require('Main')
local ui,loading,adventure=registry:Get('UI'),registry:Get('Loading'),registry:Get('Adventure')
local bridge=require('Game.Adventure.CampaignLoadingBridge')
local id=loading:Begin('创建世界',LoadingFixtureFont)
local ctrl=assert(ui.panels.Loading).ctrl
assert(Services.UI.IsWorldPaused and ui:IsOpen('Loading') and not ui:Back())
local previous=ctrl.tipIndex
ctrl:Tick(0,60);assert(ctrl.tipIndex~=previous)
loading:Report(id,.25,'检查界面');ctrl:Tick(0,0)
assert(ctrl.view.Percent.text=='25%' and math.abs(ctrl.view.Progress.value-.25)<.001)
loading:Finish(id);assert(not Services.UI.IsWorldPaused)
id=loading:Begin('创建世界',LoadingFixtureFont)
assert(ui.panels.Loading.ctrl==ctrl and ctrl.view.Percent.text=='0%','Cached screen must reset')
bridge('begin',id,'42',2500)
local initialId=CS.ProjectY.Data.CampaignSaves.CurrentId(adventure.characterSaves)
local steps=0
local render
while true do
    local done,value,stage=bridge('step',id);steps=steps+1
    assert(not adventure.map and adventure.data.PartyCount==0,'Preparation changed live world')
    assert(CS.ProjectY.Data.CampaignSaves.CurrentId(adventure.characterSaves)==initialId,'Preparation changed save identity')
    if done then render=value;break end
    loading:Report(id,value,stage);ctrl:Tick(0,1/60)
end
assert(steps>10 and #render.cells==2500)
LoadingFixture={id=id,steps=steps}
function CommitLoadingFixture()
    loading:Report(id,.94,'建立队伍并保存新远征')
    local state=bridge('commit',id)
    assert(not state.warning and adventure.data.Seed==42 and adventure.data.PartyCount==3)
    assert(CS.ProjectY.Data.CampaignSaves.CurrentId(adventure.characterSaves)~=initialId)
    assert(CS.System.IO.File.Exists(adventure.characterSaves.FilePath))
    assert(not pcall(bridge,'commit',id),'Duplicate commit was accepted')
    loading:Report(id,1,'世界已就绪');ctrl:Tick(0,0)
    assert(ctrl.view.Percent.text=='100%')
    return state
end
function CloseLoadingFixture()
    bridge('release',id)
    if loading.active then loading:Finish(id) end
    registry:Shutdown()
end
return render
