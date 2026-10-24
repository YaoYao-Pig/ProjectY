-- Real expedition/Data/UI in an isolated Editor host; its save service must point at an OS-temporary file.
assert(Services.CharacterSaves.FilePath:find('project%-y%-world%-fog%-'),'Isolated fog save path required')
local registry=require('Main');local adventure=registry:Get('Adventure');local ui=registry:Get('UI')
local Hex=require('Game.Map.HexGrid');local save=require('Game.Adventure.CharacterSave')
adventure:Start(42,5,2500)
local messages={};local function test(name,run)run();messages[#messages+1]='PASS '..name end
local fog=adventure.fog;local data=fog.data
test('new worlds reveal only the party radius and hide unknown sites and out-of-sight parties',function()
    assert(data.KnownCount>0 and data.KnownCount<2500 and data.KnownCount==data.VisibleCount)
    local snapshot=adventure:Snapshot()
    assert(#snapshot.sites<#adventure.sites)
    for _,site in ipairs(snapshot.sites) do assert(fog:Known(site.q,site.r)) end
    for _,row in ipairs(snapshot.worldParties.rows) do
        if row.kind~='stronghold' then local party=adventure.parties.data:Find(row.id);assert(fog:Visible(party.Travel.Q,party.Travel.R)) end
    end
end)
local first=data:GetVisibleAt(0)
test('actual route steps accumulate discovery and leave a remembered area behind',function()
    local travel=adventure.travel;local origin=adventure.map:GetCell(travel.data.Q,travel.data.R);local target
    for _,cell in ipairs(adventure.map:GetCells()) do
        if not cell.waterLevel and Hex.Distance(origin.q,origin.r,cell.q,cell.r)>fog.radius*2 then
            local route=travel.paths:FindPath(origin,cell,function(a,b)return travel:Cost(a,b)end)
            if route then target=cell;break end
        end
    end
    assert(target,'Fog fixture needs a reachable distant cell')
    assert(travel:Plan(target,0))
    while travel.data.Active do travel.data:Step(travel.data.RemainingMinutes);fog:Update() end
    assert(travel:Arrive())
    assert(data:IsKnown(first) and not data:IsVisible(first) and data.KnownCount>data.VisibleCount)
end)
test('v20 save and restore retain explored cells and rebuild only current sight',function()
    local known=data.KnownCount
    assert(save.Write(adventure));assert(save.Read(adventure))
    assert(fog.data==data and data.KnownCount==known and data:IsKnown(first) and not data:IsVisible(first))
    assert(adventure.travel.data.Paused,'Loading must keep the existing paused-travel contract')
end)
local demo={BattleHUDRevision=0,LastError='',SelectedCharacterId=0,SelectedCharacterSkill=0,
    WorldCamera=FogCamera,BattleAutoAI=false,IsBattleMoveSelected=true,SelectedBattleSkill=0}
function demo:SetMainHud(value)self.mainHud=value end
function demo:RenderedHealthActorIds()return {Length=0}end
function demo:CancelCharacterSkill()self.SelectedCharacterSkill=0 end
function demo:SendCommand(command,a)
    if command=='hud_follow' then self.followed=true;return end
    local ok,reason=adventure.travel:Command(command,a);assert(ok,reason);self.BattleHUDRevision=self.BattleHUDRevision+1
end
local hud=ui:Open('MainHud',{demo=demo})
test('saved MainHud buttons control resume, pause, 1/2/4 speed and squad focus',function()
    assert(hud.view.TimeControls.gameObject.activeInHierarchy and hud.view.Follow.gameObject.activeInHierarchy)
    hud.view.TimeStart.onClick:Invoke();hud:Refresh();assert(not adventure.travel.data.Paused and not hud.view.TimeStart.interactable)
    hud.view.TimeStart.onClick:Invoke();assert(not adventure.travel.data.Paused,'Start must be idempotent')
    hud.view.TimePause.onClick:Invoke();hud:Refresh();assert(adventure.travel.data.Paused and not hud.view.TimePause.interactable)
    for _,speed in ipairs({2,4,1}) do
        hud.view.TimeSpeed.onClick:Invoke();hud:Refresh()
        assert(adventure.travel.data.Speed==speed and hud.view.TimeSpeedText.text:find(tostring(speed)..'×',1,true))
        assert(adventure.travel.data.Paused,'Speed selection must not resume the world')
    end
    hud.view.Follow.onClick:Invoke();assert(demo.followed)
    assert(not Services.UI.IsWorldPaused,'MainHud controls must not acquire a modal pause lease')
end)
test('local exploration hides world-time controls but keeps squad focus',function()
    local site
    for _,row in ipairs(adventure.sites) do if row.areaConfigId==2 then site=row;break end end
    assert(site);assert(adventure.areas:Enter(site,adventure.data.Seed));hud:Refresh()
    assert(not hud.view.TimeControls.gameObject.activeSelf and hud.view.Follow.gameObject.activeInHierarchy)
    assert(not adventure.travel:Command('travel_resume'),'World clock controls must reject area exploration')
    assert(adventure:AreaCommand('area_leave'));hud:Refresh()
end)
FogTestReport=table.concat(messages,'\n');FogTestData=data;FogTestHud=hud
return adventure:MapSnapshot()
