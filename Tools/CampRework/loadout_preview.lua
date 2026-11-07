-- Focused real-controller check with disposable services and a temporary save directory.
local registry=require('Core.SystemRegistry')(Services)
require('Game.Systems')(registry)
function CloseCampPreview() registry:Shutdown();CloseCampPreview=nil end
registry:Start()
local ui,a=registry:Get('UI'),registry:Get('Adventure')
a:Start(412)
local camp=a.camp;local loadout=camp.loadout;local torch=loadout.torch.itemId
local animals={}
for i=1,2 do
    local species=a.battle.stats.animals.species:Get(i==1 and 1 or 3)
    local animal=CS.ProjectY.Data.CombatActorData(91000+i,species.unitId)
    animal:InitializeAnimal(species.id,17+i);animal:SetMaxHP(a.battle.stats:MaximumHP(animal));animal:Restore()
    a.data:GetPartyAt(i-1):TameAndRide(animal,25);animals[i]=animal
end
assert(a.equipment:Grant(torch,2))
assert(camp:Open())
local definition=Services.UI:GetConfig('Camp');local view=Services.UI:CreateView('Camp')
AttachCampPreview(view)
local ctrl=require(definition.ControllerModule)(ui.context,view)
ctrl.panelName='Camp';ctrl.panel=Services.UI:GetPanel(view);ctrl:Bind()
ui.panels.Camp={name='Camp',ctrl=ctrl,view=view,definition=definition}
local demo={WorldCamera=CampWorldCamera,LastError='',BattleHUDRevision=0}
function demo:SetStoryOpen(value) self.storyOpen=value end
function demo:SendCommand(command,id,revision,count)
    local ok,reason
    if command=='camp_close' then camp:Close();ui:Close('Camp');return
    elseif command=='camp_loadout_mount' then ok,reason=loadout:Equip(1,id,count,revision)
    elseif command=='camp_loadout_pet' then ok,reason=loadout:Equip(2,id,count,revision)
    elseif command=='camp_loadout_torch' then ok,reason=loadout:EquipTorch(id,revision)
    elseif command=='snapshot' then return
    else error(command) end
    self.LastError=ok and '' or reason;self.BattleHUDRevision=self.BattleHUDRevision+1
end
local initialTime=CS.UnityEngine.Time.timeScale
ui:Open('Camp',{demo=demo});CaptureCamp('loadout-entry')
view:Get('Loadout').onClick:Invoke();assert(ctrl.state.page=='loadout')
assert(ctrl.snapshot.operation.id==a.data:GetPartyAt(0).Id)
ClickCamp('primary');assert(demo.LastError=='' and loadout:Selected(1)==animals[1])
assert(loadout:SpeedMultiplier()==1.25)
CaptureCamp('loadout-mount')
local before=a.fog.data.VisibleCount
ClickCamp('secondary:1');assert(ctrl.state.loadoutSlot==2)
-- The first candidate is already in the mount slot; the second animal remains available.
assert(not ctrl.snapshot.actionEnabled)
ClickCamp('row:2');ClickCamp('primary')
assert(demo.LastError=='' and loadout:Selected(2)==animals[2] and loadout:VisionBonus()==2)
assert(a.fog.data.VisibleCount>before,'Stationary equip did not expand visible cells')
local explored=a.fog.data.KnownCount
CaptureCamp('loadout-pet')
ClickCamp('row:0');ClickCamp('primary')
assert(loadout:VisionBonus()==0 and a.fog.data.VisibleCount==before and a.fog.data.KnownCount==explored,'Unequip lost discovery or kept expanded vision')
ClickCamp('row:2');ClickCamp('primary')
ClickCamp('secondary:2');assert(ctrl.state.loadoutSlot==3)
local stock=a.equipment.data:CountItem(torch)
ClickCamp('primary');assert(demo.LastError=='' and loadout.data.TorchItemId==torch and a.equipment.data:CountItem(torch)==stock-1)
CaptureCamp('loadout-torch')
local Torch=require('Game.Adventure.Torch')
a.narrative.data:AdvanceMinutes(24*60-a.narrative.data.Minutes%1440+20*60)
assert(Torch.Snapshot(a).worldEnabled)
assert(Torch.Toggle(a));assert(not Torch.Snapshot(a).worldEnabled)
assert(Torch.Toggle(a))
ClickCamp('back');ClickCamp('close')
assert(not Services.UI.IsWorldPaused and CS.UnityEngine.Time.timeScale==initialTime)
-- Native character save preparation validates every animal reference and preserves the transferred torch.
local Save=require('Game.Adventure.CharacterSave')
assert(Save.Write(a))
local prepared=a.characterSaves:Prepare(a.equipment.data);Save.Validate(a,prepared)
local saved=CS.ProjectY.Data.CampLoadoutData.For(CS.ProjectY.Data.CampData.Prepared(prepared))
assert(saved.MountAnimalId==animals[1].Id and saved.PetAnimalId==animals[2].Id and saved.TorchItemId==torch)
assert(prepared.Equipment:CountItem(torch)==stock-1)
assert(loadout:VisionBonus(prepared)==2)
-- Returning to the cached panel keeps bindings and releases its modal lease again.
assert(camp:Open());AttachCampPreview(view);ui:Open('Camp',{demo=demo});view:Get('Loadout').onClick:Invoke()
ClickCamp('back');ClickCamp('close');assert(not Services.UI.IsWorldPaused)
return 'PASS loadout: real buttons and animal previews, mount speed, immediate pet sight, discovery retention, torch transfer/night/switch, save preparation and cached UI lifecycle'
