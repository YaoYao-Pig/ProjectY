-- Real exported portable-light configuration and production switch rules; no Editor or user save files.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local Torch=require('Game.Adventure.Torch')
local definition=config:GetTable('TorchTable'):Get(1)
local item=config:GetTable('EquipmentItemTable'):Get(definition.itemId)
assert(item.kind=='material' and item.width*item.height>0,'Torch must use the existing saved inventory stack contract')
local icon=assert(io.open(item.iconPath,'rb'));icon:close()
local asset=config:GetTable('EquipmentAssetTable'):Get(item.assetId)
for _,path in ipairs({asset.modelPath,asset.prefabPath}) do local file=assert(io.open(path,'rb'));file:close() end
local presentation=require('Game.Rendering.MapPresentation').Snapshot(config)
assert(presentation.torch.itemId==item.id and presentation.torch.intensity>0 and presentation.torch.range>0)
presentation.torch.range=0;assert(definition.range>0,'Snapshot leaked a mutable configuration row')
local count,values=0,{}
local data={Phase='map',Equipment={CountItem=function(_,id) assert(id==item.id);return count end},
    Narrative={GetValue=function(_,key) return values[key] or 0 end,SetValue=function(_,key,value) values[key]=value end}}
local adventure={config=config,data=data}
local state=Torch.Snapshot(adventure)
assert(not state.available and not state.enabled and not Torch.Toggle(adventure),'Missing physical torch must not create light')
count=1;state=Torch.Snapshot(adventure)
assert(state.available and state.enabled and state.count==1,'Owned torch defaults to lit')
assert(Torch.Toggle(adventure));assert(not Torch.Snapshot(adventure).enabled)
-- Reconstruct the projection over restored C# state: no Lua-only switch needs migration or caching.
local resumed={config=config,data=data}
assert(not Torch.Snapshot(resumed).enabled,'Saved extinguished flag was ignored')
assert(Torch.Toggle(resumed));assert(Torch.Snapshot(adventure).enabled)
count=0;assert(not Torch.Snapshot(adventure).enabled,'Transferred or stored torch still lit')
count=2;data.Phase='area';assert(Torch.Snapshot(adventure).enabled,'Inventory retrieval did not restore lighting')
assert(Torch.Toggle(adventure));assert(not Torch.Snapshot(adventure).enabled)
data.Phase='battle';assert(not Torch.Toggle(adventure),'Battle must preserve the pre-battle switch')
data.Phase='area';assert(Torch.Toggle(adventure));data.Phase='battle'
assert(Torch.Snapshot(adventure).enabled,'Battle must keep existing illumination')
Torch.ValidateSaved({Narrative=data.Narrative,LegacyNarrative=false})
Torch.ValidateSaved({LegacyNarrative=true})
values['flag:torch_extinguished']=2;assert(not pcall(Torch.Snapshot,adventure),'Invalid stored switch must fail visibly')
assert(not pcall(Torch.ValidateSaved,{Narrative=data.Narrative,LegacyNarrative=false}),'Invalid switch must be rejected before save commit')
print('PASS torch: exported light recipe/assets, ownership, toggle, restored state, transfer, battle guard')
