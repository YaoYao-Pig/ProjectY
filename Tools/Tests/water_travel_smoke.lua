-- One fixed production world, two connected ports, actual clock and isolated disk save.
local registry=require('Main');local a=registry:Get('Adventure');local w=a.water;local report={}
a:Start(20261025,5,10000)
CS.ProjectY.Data.ExpeditionPersistence.ResetProfile(a.player,1000)
local first,last=assert(w.docks[2]),assert(w.docks[3]);local target=assert(w.sites[3])
assert(w.data:GetDock(2).Ready and w.data:GetDock(3).Ready)
a.fog:RevealAll()
a.travel.data:Relocate(first.landQ,first.landR)
assert(a:EnterSite(w.sites[2].id));w:DeployAtDock()
local layout=a.areas:ActiveLayout();local front=layout.waterfront
assert(a:AreaCommand('area_interact',2,front.npcId))
local ui=registry:Get('UI');local demo={MainHudFont=WaterSmokeFont,LastError='',BattleHUDRevision=0}
function demo:SetStoryOpen(value)self.open=value end
function demo:SendCommand(command,id,revision)local ok,reason=w:Command(command,id,revision);assert(ok,reason)end
ui:Open('Harbor',{demo=demo});assert(ui:IsOpen('Harbor'));ui:Close('Harbor')
assert(w:Open(2));assert(w:Command('water_buy',0,w.data.Revision));assert(a.player.Coins==820)
local route=assert(w:Route(2,3));assert(#route==31)
local before=a.narrative.data.Minutes
assert(w:Command('water_ferry',3,w.data.Revision));assert(a.player.Coins==780 and a.data.Phase=='map')
a.travel:Tick(1);assert(w.data.Mode=='ferry' and a.travel.data.Active)
local savedQ,savedR,progress=a.travel.data.Q,a.travel.data.R,a.travel.data.Progress
assert(require('Game.Adventure.CharacterSave').Write(a))
local ok,reason=require('Game.Adventure.CharacterSave').Read(a);assert(ok,reason)
assert(w.data.Mode=='ferry' and a.player.Coins==780 and a.travel.data.Q==savedQ and a.travel.data.R==savedR and math.abs(a.travel.data.Progress-progress)<1e-8 and a.travel.data.Paused)
report[#report+1]='PASS actual Harbor prefab/controller, fare and mid-voyage disk save/load'
assert(a.travel:Command('travel_resume'))
for i=1,8 do if a.data.Phase=='map' then a.travel:Tick(1) end end
assert(a.data.Phase=='area' and a.data.Areas.ActiveSiteId==target.id and w.data.Mode=='walk')
assert(w.data.BoatQ==first.waterQ and w.data.BoatR==first.waterR)
assert(a.narrative.data.Minutes>=before+60 and a.player.Coins==780)
assert(w:Open(3));assert(w:Command('water_ferry',2,w.data.Revision))
for i=1,8 do if a.data.Phase=='map' then a.travel:Tick(1) end end
assert(a.data.Phase=='area' and a.data.Areas.ActiveSiteId==w.sites[2].id)
assert(w:Open(2));assert(w:Command('water_board',0,w.data.Revision))
assert(w.data.Mode=='owned' and a.data.Phase=='map')
assert(a.travel:Plan(a.map:GetCell(first.landQ,first.landR),0));assert(w.data.Mode=='walk')
assert(a.travel:Plan(a.map:GetCell(first.waterQ,first.waterR),0));assert(w.data.Mode=='owned')
assert(a.travel:Plan(a.map:GetCell(first.landQ,first.landR),0));assert(w.data.Mode=='walk')
a.travel.data:Relocate(first.landQ,first.landR);assert(a:EnterSite(w.sites[2].id));w:DeployAtDock()
report[#report+1]='PASS production water route, world clock, destination landing, return ferry and wild reboarding'
local view=a:Snapshot();view.error=''
return {report=table.concat(report,'\n'),layout=a.areas:LayoutSnapshot(w),view=view,
    dockIndex=a.areas:ActiveLayout().waterfront.landingIndex}
