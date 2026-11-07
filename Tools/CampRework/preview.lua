-- Disposable Edit Mode service graph. Real controller, configuration, transactions and prefab.
local registry=require('Core.SystemRegistry')(Services)
require('Game.Systems')(registry)
function CloseCampPreview() registry:Shutdown();CloseCampPreview=nil end
registry:Start()
local ui,a=registry:Get('UI'),registry:Get('Adventure')
a:Start(412);a.player:AddCoins(3000)
for _,id in ipairs({81,82,83}) do assert(a.equipment:Grant(id,70)) end
assert(a.equipment:Grant(40,1))
local camp=a.camp;assert(camp:Open())
-- Pre-create the ordinary cached entry so the Edit Mode host can attach the authored scene.
local definition=Services.UI:GetConfig('Camp');local view=Services.UI:CreateView('Camp')
AttachCampPreview(view)
local ctrl=require(definition.ControllerModule)(ui.context,view)
ctrl.panelName='Camp';ctrl.panel=Services.UI:GetPanel(view);ctrl:Bind()
ui.panels.Camp={name='Camp',ctrl=ctrl,view=view,definition=definition}
local demo={WorldCamera=CampWorldCamera,LastError='',BattleHUDRevision=0}
function demo:SetStoryOpen(value) self.storyOpen=value end
function demo:SendCommand(command,id,revision,count)
    local ok,reason=true,''
    if command=='camp_close' then camp:Close();ui:Close('Camp');return
    elseif command=='snapshot' then return
    elseif command=='forge_forge' then ok,reason=a.forge:Forge(id,revision)
    else
        local methods={camp_upgrade='Upgrade',camp_produce='Produce',camp_claim='Claim',camp_wait='Wait'}
        ok,reason=camp[assert(methods[command],command)](camp,id,revision,count)
    end
    self.LastError=ok and '' or reason;self.BattleHUDRevision=self.BattleHUDRevision+1
end
local time=CS.UnityEngine.Time.timeScale
ui:Open('Camp',{demo=demo});assert(Services.UI.IsWorldPaused and CS.UnityEngine.Time.timeScale==0)
CaptureCamp('camp-level-0')
ClickCamp('facility:0');assert(ctrl.state.page=='upgrade')
ClickCamp('primary');assert(camp.data:GetLevel(1)==1 and demo.LastError=='')
ClickCamp('back');ClickCamp('facility:0');assert(ctrl.state.page=='production')
ClickCamp('primary');assert(camp.data.JobCount==1 and demo.LastError=='')
CaptureCamp('camp-production')
ClickCamp('wait:0');assert(camp.data:GetJobAt(0).ReadyAt<=a.narrative.data.Minutes)
local ammo=a.equipment.data:CountItem(31);ClickCamp('claim');assert(a.equipment.data:CountItem(31)==ammo+12)
ClickCamp('back');ClickCamp('facility:1');assert(ctrl.state.page=='forge')
CaptureCamp('camp-forge');ClickCamp('primary');assert(demo.LastError=='')
ClickCamp('back');assert(camp:Upgrade(3,camp.data.Revision));assert(camp:Deposit(81,camp.data.Revision,12));assert(camp:Deposit(82,camp.data.Revision,6));assert(camp:Deposit(83,camp.data.Revision,8));ctrl:Refresh()
ClickCamp('facility:2');assert(ctrl.state.page=='storage')
CaptureCamp('camp-warehouse')
local original=a.equipment.data.Grid:Find('s81');local originalX,originalY=original.X,original.Y
local before=camp.data:Stored(81);DragCamp('s81:stock:8:4');assert(camp.data:Stored(81)>before,'Native drag failed: '..ctrl.state.message)
local bridge=CS.ProjectY.Data.CampWarehouseBridge;local moved
for i=0,camp.data.StorageCount-1 do local row=camp.data:GetStorageAt(i);if row.ItemId==81 then local key=bridge.Key(row);local place=bridge.Grid(camp.data):Find(key);if place.X==8 then moved=key end end end
assert(moved,'Native drag ignored the requested warehouse cell')
DragCamp(moved..':bag:'..originalX..':'..originalY);assert(camp.data:Stored(81)==before,'Native withdrawal failed: '..ctrl.state.message)
local storedGear={}
for _,kind in ipairs({'weapon','wearable','magazine'}) do
    local selected;for _,row in ipairs(ctrl.bagRows) do if row.kind==kind then selected=row;break end end
    assert(selected,'Fixture has no backpack '..kind)
    local old=a.equipment.data.Grid:Find(selected.key);local x,y=old.X,old.Y
    local tx=kind=='weapon' and 0 or kind=='wearable' and 4 or 8
    DragCamp(selected.key..':stock:'..tx..':3');assert(bridge.Find(camp.data,selected.key),'Equipment native deposit failed: '..ctrl.state.message)
    assert(a.equipment.data.Grid:Find(selected.key)==nil)
    DragCamp(selected.key..':bag:'..x..':'..y);assert(not bridge.Find(camp.data,selected.key),'Equipment native withdrawal failed: '..ctrl.state.message)
    DragCamp(selected.key..':stock:'..tx..':3');assert(bridge.Find(camp.data,selected.key))
    storedGear[#storedGear+1]={key=selected.key,id=selected.id,itemId=selected.itemId}
end
CaptureCamp('camp-warehouse-equipment')
ClickCamp('back')
for _,id in ipairs({1,2,3}) do while camp.data:GetLevel(id)<2 do assert(camp:Upgrade(id,camp.data.Revision)) end end
ctrl:Refresh();CaptureCamp('camp-level-2')
ClickCamp('facility:0');ClickCamp('row:4');CaptureCamp('camp-production-level-2')
ClickCamp('back');ClickCamp('close')
assert(not camp.data.IsOpen and not Services.UI.IsWorldPaused and CS.UnityEngine.Time.timeScale==time and not demo.storyOpen)
assert(camp:Open());AttachCampPreview(view);assert(ui:Open('Camp',{demo=demo})==ctrl);ClickCamp('back')
assert(not camp.data.IsOpen and not Services.UI.IsWorldPaused and not demo.storyOpen,'Cached camp Back did not release its session')
local save=require('Game.Adventure.CharacterSave');assert(save.Write(a))
local prepared=a.characterSaves:Prepare(a.equipment.data);save.Validate(a,prepared)
local restored=CS.ProjectY.Data.CampData.Prepared(prepared);assert(restored.StoredTotal==camp.data.StoredTotal and restored:GetLevel(1)==2)
assert(bridge.Grid(restored).Count==bridge.Grid(camp.data).Count)
for _,gear in ipairs(storedGear) do
    assert(bridge.Find(restored,gear.key) and prepared.Equipment.Grid:Find(gear.key)==nil,'Saved equipment lost its warehouse location')
end
CloseCampPreview()
return 'PASS native camp: real prefab/controller, production, forging, stack and equipment drag, target coordinates, cached reopen, pause release and equipment save roundtrip'
