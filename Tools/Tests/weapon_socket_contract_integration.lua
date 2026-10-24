-- Real exported Config + EquipmentRules + physical C# equipment, without world, battle, UI or save startup.
local config=require('Config.ConfigSystem')()
config:OnInit({services=Services})
local result={rows={},weaponCount=0,nonemptyCount=0,attachmentCount=0}
local ok,err=xpcall(function()
    Services.Adventure:Reset(20261025)
    local data=Services.Adventure.Equipment
    data.Grid:Configure(12,100)
    local rules=require('Game.Equipment.EquipmentRules').New(config,data)
    rules.affixes:Define(data)
    for _,item in ipairs(rules.items:All())do data.Grid:Define(item.id,item.width,item.height)end
    local prefabContracts={}
    for _,definition in ipairs(rules.weapons:All())do
        local item=rules.items:Get(definition.id)
        local asset=rules.assets:Get(item.assetId)
        local ids,seen={},{}
        for _,id in ipairs(definition.socketIds)do
            assert(not seen[id],'Duplicate configured weapon socket '..definition.id..'/'..id)
            assert(rules.sockets:Get(id).weaponItemId==definition.id,'Socket is owned by another weapon')
            seen[id]=true;ids[#ids+1]=id
        end
        local contract=table.concat(ids,',')
        local previous=prefabContracts[asset.prefabPath]
        assert(not previous or previous.contract==contract,
            'Shared weapon prefab has incompatible socket contracts: '..tostring(previous and previous.id)..'/'..definition.id..' '..asset.prefabPath)
        prefabContracts[asset.prefabPath]={id=definition.id,contract=contract}
        local weapon=data:AddWeapon(definition.id)
        local row={id=definition.id,assetId=item.assetId,modelPath=asset.modelPath,prefabPath=asset.prefabPath,
            socketIds=ids,empty=rules:WeaponVisual(weapon),attachmentCount=0}
        -- Fill each declared socket with one physically compatible item, then remove it again on the same weapon.
        for _,id in ipairs(ids)do
            local socket=rules.sockets:Get(id)
            if socket.kind=='magazine' then
                local magazine=rules.magazines:Get(definition.magazineItemId)
                local instance=data:AddMagazine(magazine.id,magazine.ammoItemId,magazine.capacity,magazine.spawnRounds)
                assert(data:AttachMagazine(weapon.Id,instance.Id),'Compatible magazine could not be installed')
            else
                local compatible
                for _,rune in ipairs(rules.runes:All())do if rune.slotKind==socket.kind then compatible=rune;break end end
                assert(compatible,'No configured attachment for socket kind '..socket.kind)
                data:AddStack(compatible.id,1)
                assert(data:SetRune(weapon.Id,id,compatible.id),'Compatible component could not be installed')
            end
            row.attachmentCount=row.attachmentCount+1
        end
        row.attached=rules:WeaponVisual(weapon)
        for _,id in ipairs(ids)do
            local socket=rules.sockets:Get(id)
            if socket.kind=='magazine' then assert(data:AttachMagazine(weapon.Id,0))
            else assert(data:SetRune(weapon.Id,id,0))end
        end
        row.cleared=rules:WeaponVisual(weapon)
        assert(#row.empty.sockets==#ids and #row.attached.sockets==#ids and #row.cleared.sockets==#ids)
        for index,socket in ipairs(row.attached.sockets)do
            assert(socket.id==ids[index] and socket.asset and socket.asset.id>0,'Filled socket is missing from real weapon visual')
            assert(row.empty.sockets[index].asset==nil and row.cleared.sockets[index].asset==nil,'Removed attachment survived the real visual snapshot')
        end
        result.rows[#result.rows+1]=row
        result.weaponCount=result.weaponCount+1
        result.attachmentCount=result.attachmentCount+row.attachmentCount
        if #ids>0 then result.nonemptyCount=result.nonemptyCount+1 end
    end
    assert(result.weaponCount==rules.weapons.Count and result.weaponCount>=57,'All current configured weapons must be checked')
    assert(result.nonemptyCount>0 and result.attachmentCount>0,'Nonempty compatible slot configurations must be exercised')
end,debug.traceback)
config:OnShutdown()
if not ok then error(err,0)end
return result
