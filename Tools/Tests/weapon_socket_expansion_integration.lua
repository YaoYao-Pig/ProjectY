-- Native C# inventory transactions and visual snapshots, isolated from the player's expedition.
local registry=require('Core.SystemRegistry')(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('Battle',require('Game.Battle.BattleSystem'),{'Config'})
registry:Register('Equipment',require('Game.Equipment.EquipmentSystem'),{'Config'})
local result
local ok,err=xpcall(function()
    registry:Start()
    local equipment,battle=registry:Get('Equipment'),registry:Get('Battle')
    local adventure=Services.Adventure;adventure:Reset(20261019)
    local actor=adventure:AddPartyActor(1,1);actor.Growth:Initialize(1,0,0,0)
    actor:SetMaxHP(battle.stats:MaximumHP(actor));actor:Restore()
    equipment:Start()
    local data,rules=equipment.data,equipment.rules
    local cases,weapons=0,0;local snapshots={}
    for _,definition in ipairs(rules.weapons:All())do if definition.kind~='staff' then
        data:Clear();local weapon=data:AddWeapon(definition.id);weapons=weapons+1
        for _,socketId in ipairs(definition.socketIds)do if socketId>=201 and socketId<=273 then
            local socket=rules.sockets:Get(socketId)
            for _,rune in ipairs(rules.runes:All())do if rune.slotKind==socket.kind then
                data:AddStack(rune.id,1)
                local count=data:CountItem(rune.id)
                local allowed,reason=equipment:Command('attach',actor.Id,weapon.Id,socketId,rune.id)
                assert(allowed,reason)
                assert(weapon:GetRune(socketId)==rune.id and data:CountItem(rune.id)==count-1)
                local view=rules:WeaponVisual(weapon);assert(#view.sockets==#definition.socketIds)
                local matched=false;for _,row in ipairs(view.sockets)do if row.id==socketId then matched=row.asset.id==rules.items:Get(rune.id).assetId end end
                assert(matched,'Installed component missing from the model snapshot')
                assert(equipment:Command('attach',actor.Id,weapon.Id,socketId,0))
                assert(weapon:GetRune(socketId)==0 and data:CountItem(rune.id)==count)
                cases=cases+1
            end end
            local incompatible=socket.kind=='grip' and 732 or 730
            data:AddStack(incompatible,1);local revision=data.Revision
            assert(not equipment:Command('attach',actor.Id,weapon.Id,socketId,incompatible))
            assert(data.Revision==revision,'Rejected attachment changed inventory')
        end end
        -- Populate all mounts together, including old mount kinds and the retained magazine.
        for _,socketId in ipairs(definition.socketIds)do
            local socket=rules.sockets:Get(socketId)
            if socket.kind=='magazine' then
                local mag=rules.magazines:Get(definition.magazineItemId)
                local instance=data:AddMagazine(mag.id,mag.ammoItemId,mag.capacity,mag.capacity)
                assert(equipment:Command('attach',actor.Id,weapon.Id,socketId,instance.Id))
            else
                local options={};for _,rune in ipairs(rules.runes:All())do if rune.slotKind==socket.kind then options[#options+1]=rune.id end end
                assert(#options>0,'Empty socket category')
                local runeId=options[(definition.id%#options)+1];data:AddStack(runeId,1)
                assert(equipment:Command('attach',actor.Id,weapon.Id,socketId,runeId))
            end
        end
        snapshots[#snapshots+1]={itemId=definition.id,view=rules:WeaponVisual(weapon)}
    end end
    assert(weapons==30 and cases==172,'Unexpected expansion install coverage')
    result={weapons=weapons,installCases=cases,snapshots=snapshots}
end,debug.traceback)
registry:Shutdown();if not ok then error(err,0)end
return result
