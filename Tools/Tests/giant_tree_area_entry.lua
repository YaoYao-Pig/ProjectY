-- Isolated native services: production MapArea entry/deployment and root-only layout, no player saves.
local registry=require('Core.SystemRegistry')(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('MapArea',require('Game.MapArea.MapAreaSystem'),{'Config'})
local result
local ok,reason=xpcall(function()
    registry:Start()
    local data=Services.Adventure;data:Reset(42)
    local actor=data:AddPartyActor(1,1);actor:SetMaxHP(20);actor:Restore()
    local areas=registry:Get('MapArea')
    local site={id=91,pointId=400001,areaConfigId=72,worldWonderId=1,naturalKind='GiantTree',entryItemId=0,entryItemCount=0,
        source={regionId=1,regionConfigId=5,regionType=5,q=0,r=10,height=1,generationVersion=8,biomeWeights={{regionType=5,weight=1}}}}
    assert(areas:Enter(site,42))
    local layout,state=areas:ActiveLayout(),data.Areas.Active
    assert(data.Phase=='area' and data.Areas.ActiveSiteId==91 and layout.configId==72)
    assert(state.MemberCount==1 and state:GetMemberIdAt(0)==1 and not layout.cells[state.CellIndex].blocked)
    assert(state.KnownCount>0 and state.KnownCount<#layout.cells and data:HasVisited(91))
    local roots,base,ordinary=0,0,0
    for _,prop in ipairs(layout.props) do
        assert(prop.assetId~=1106 and prop.assetId~=1109,'The local root area must not display a miniature whole giant tree')
        if prop.assetId==1107 then roots=roots+1 elseif prop.assetId==1108 then base=base+1 else ordinary=ordinary+1 end
    end
    assert(roots>0 and base==1 and ordinary>0)
    local anchor,known=state.CellIndex,state.KnownCount
    data:LeaveArea();assert(data.Phase=='map')
    assert(areas:Enter(site,42) and data.Areas.Active==state and areas:ActiveLayout()==layout)
    assert(state.CellIndex==anchor and state.KnownCount==known,'Root-area revisit reset exploration state')
    result=string.format('PASS native tree entry: area72, %d roots, %d partial trunk, %d other props, living squad deployed, revisit retained',roots,base,ordinary)
end,debug.traceback)
registry:Shutdown()
assert(ok,reason)
return result
