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
bridge('begin',id,'42',2500,1,'  晨风群岛  ')
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
local restoreId,otherId,oldMap,restoredArea
function PrepareRestorationFixture()
    bridge('release',id);loading:Finish(id)
    local saves=CS.ProjectY.Data.CampaignSaves
    restoreId=saves.CurrentId(adventure.characterSaves)
    local site
    local dungeon=adventure.config:GetEnum('MapArea','E_MapAreaType').Dungeon
    for _,value in ipairs(adventure.sites) do
        if value.areaConfigId and adventure.areas.generator.definitions:Get(value.areaConfigId).areaType==dungeon then site=value;break end
    end
    assert(site,'Fixture requires a dungeon area')
    assert(adventure.areas:Enter(site,adventure.data.Seed))
    adventure.equipment:InitializeLoot(adventure.areas);adventure.obstacles:Initialize()
    assert(adventure.data.Phase=='area')
    restoredArea=adventure.data.Areas.ActiveSiteId
    assert(require('Game.Adventure.CharacterSave').Write(adventure))
    otherId=saves.NewCampaign(adventure.characterSaves,'Another world')
    assert(require('Game.Adventure.CharacterSave').Write(adventure))
    oldMap=adventure.map
    id=loading:Begin('加载世界',LoadingFixtureFont);bridge('begin_load',id,restoreId)
    local loadSteps=0
    while true do
        local done,value,stage=bridge('step',id);loadSteps=loadSteps+1
        assert(adventure.map==oldMap and saves.CurrentId(adventure.characterSaves)==otherId,'Read preparation changed the live session')
        if done then LoadingFixture.restoreSteps=loadSteps;assert(loadSteps>10);return value end
        loading:Report(id,value,stage);ctrl:Tick(0,1/60)
    end
end
function CommitRestorationFixture()
    loading:Report(id,.94,'恢复远征与队伍')
    local state=bridge('commit',id)
    local saves=CS.ProjectY.Data.CampaignSaves
    assert(saves.CurrentId(adventure.characterSaves)==restoreId and adventure.map~=oldMap)
    assert(adventure.data.Phase=='area' and adventure.data.Areas.ActiveSiteId==restoredArea)
    assert(require('Game.Adventure.CharacterSave').Write(adventure))
    local entries=saves.List(adventure.characterSaves);local names={}
    for i=0,entries.Length-1 do names[entries[i].Id]=entries[i].WorldName end
    assert(entries.Length==2 and names[restoreId]=='晨风群岛' and names[otherId]=='Another world')
    assert(not pcall(bridge,'commit',id),'Duplicate restore commit was accepted')
    loading:Report(id,1,'世界已就绪');ctrl:Tick(0,0);assert(ctrl.view.Percent.text=='100%')
    return state
end
function CloseLoadingFixture()
    bridge('release',id)
    if loading.active then loading:Finish(id) end
    registry:Shutdown()
end
return render
