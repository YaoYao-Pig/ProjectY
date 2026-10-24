local LuaLanguage = require('Language')
-- 仅构造 HUD 投影；按钮仍走远征命令，位置/血量/消费均不复制为可变业务状态。
local Model={}
function Model.Build(adventure)
    local data=adventure.data;local stats=adventure.battle.stats
    local model={phase=data.Phase,title=LuaLanguage.UIMainHudTitle17,subtitle=LuaLanguage.UIMainHudSubtitle3,coins=adventure.player.Coins,
        rows={},menu={},party={},health={},logs={},interaction=nil,town=false}
    local function actor(row)
        local mount=row.MountedAnimal
        local name=adventure.narrative and adventure.narrative.npcs:ActorName(row) or stats:Template(row).name
        local effects=adventure.battle.gameEffects:Rows(row)
        if mount then for _,effect in ipairs(adventure.battle.gameEffects:Rows(mount)) do
            effect.name=string.format(LuaLanguage.UIMainHudEffectName, (effect.name));effect.body=string.format(LuaLanguage.UIMainHudEffectBody, (stats:Template(mount).name), (effect.body))
            effects[#effects+1]=effect
        end end
        return {id=row.Id,name='Lv.'..row.Growth.Level..' '..name..(mount and (' · '..stats:Template(mount).name) or ''),
            hp=mount and mount.HP or row.HP,maxHP=mount and mount.MaxHP or row.MaxHP,healthId=mount and mount.Id or row.Id,
            team=data.Phase=='battle' and adventure.battle:PresentationTeam(row) or row.Team,
            ap=row.AP,maxAP=stats:Template(row).actionPoints,effects=effects,
            riderHP=mount and row.HP or nil,riderMaxHP=mount and row.MaxHP or nil}
    end
    for i=0,data.PartyCount-1 do
        local unit=data:GetPartyAt(i);local row=actor(unit)
        row.appearance=adventure.appearances:Template(unit.TemplateId,stats.equipment:ActorVisual(unit),unit.CustomizationJson)
        row.portraitKey=unit.Id..':'..data.Equipment.Revision..':'..unit.CustomizationJson
        model.party[#model.party+1]=row
    end
    if data.Phase=='map' then
        local travel=adventure.travel:Summary()
        model.timeControl={paused=travel.paused,speed=travel.speed}
        model.title=LuaLanguage.UIMainHudTitle16;model.subtitle=string.format(LuaLanguage.UIMainHudSubtitle2, (data.Seed))
        model.rows[#model.rows+1]={title=travel.active and (string.format(LuaLanguage.UIMainHudTitle5, (travel.destination))) or LuaLanguage.UIMainHudTitle15,
            body=travel.active and string.format(LuaLanguage.UIMainHudBody22,travel.terrain,travel.paused and LuaLanguage.UIMainHudBody21 or LuaLanguage.UIMainHudBody20,travel.remaining)
                or ((travel.paused and LuaLanguage.UIMainHudBody19 or LuaLanguage.UIMainHudBody18)..(travel.message~='' and ('\n'..travel.message) or '')),
            command='hud_follow',available=true}
        model.rows[#model.rows+1]={title=travel.paused and LuaLanguage.UIMainHudTitle14 or LuaLanguage.UIMainHudTitle13,body=LuaLanguage.UIMainHudBody17,command='travel_pause',available=true}
        for key,speed in ipairs({1,2,4}) do model.rows[#model.rows+1]={title=string.format(LuaLanguage.UIMainHudTitle12, (travel.speed==speed and '● ' or ''), (speed)),body=string.format(LuaLanguage.UIMainHudBody16, (key)),command='travel_speed',a=speed,available=true} end
        local groups={dungeon={},forest={},battlefield={},town={},event={}}
        for _,site in ipairs(adventure.sites) do
            if adventure.fog:Known(site.q,site.r) and (not site.travelStop or adventure.areas:AreaId(site)) then
            local ok,reason;local kind='event'
            local areaId=adventure.areas:AreaId(site)
            if areaId then
                ok,reason=adventure.areas:CanEnter(site)
                local areaType=adventure.areas.generator.definitions:Get(areaId).areaType
                kind=areaType==adventure.areas.townType and 'town' or 'dungeon'
                if areaType==adventure.areas.forestType then kind='forest' end
                if areaType==adventure.areas.battlefieldType then kind='battlefield' end
            else ok,reason=adventure.events:CanVisit(site) end
            groups[kind][#groups[kind]+1]={title=(data:HasVisited(site.id) and '✓ ' or '◇ ')..site.name,
                body=reason or (kind=='battlefield' and LuaLanguage.UIMainHudBody15 or kind=='forest' and LuaLanguage.UIMainHudBody14 or kind=='dungeon' and LuaLanguage.UIMainHudBody13 or kind=='town' and LuaLanguage.UIMainHudBody12 or LuaLanguage.UIMainHudBody11),command='visit',a=site.id,available=ok}
            end
        end
        for _,kind in ipairs({'forest','battlefield','dungeon','town','event'}) do for _,row in ipairs(groups[kind]) do model.rows[#model.rows+1]=row end end
    elseif data.Areas.ActiveSiteId>0 then
        local areas=adventure.areas;local area,state=areas:ActiveLayout(),data.Areas.Active
        model.town=area.areaType==areas.townType;model.title=area.name
        model.subtitle=LuaLanguage.UIMainHudSubtitle
        if data.Phase=='area' then
            if data.ResultText~='' then model.rows[#model.rows+1]={title=LuaLanguage.UIMainHudTitle11,body=data.ResultText,command='snapshot',available=false} end
            model.rows[#model.rows+1]={title=LuaLanguage.UIMainHudTitle10,body=LuaLanguage.UIMainHudBody10,command='hud_follow'}
            for _,loot in ipairs(adventure.equipment:LootSnapshot(areas)) do if not loot.looted or loot.canSearch then
                model.rows[#model.rows+1]={title=(loot.looted and LuaLanguage.UIMainHudTitle9 or loot.canSearch and LuaLanguage.UIMainHudTitle8 or LuaLanguage.UIMainHudTitle7)..loot.name,
                    body=loot.canSearch and LuaLanguage.UIMainHudBody9 or (string.format(LuaLanguage.UIMainHudBody8, (loot.durability), (loot.maxDurability))),
                    command='area_loot',a=loot.id,available=loot.canSearch}
            end end
            for _,obstacle in ipairs(adventure.obstacles:Snapshot()) do
                model.rows[#model.rows+1]={title=string.format(LuaLanguage.UIMainHudTitle6, (obstacle.name)),body=LuaLanguage.UIMainHudBody7,command='area_move_cell',a=obstacle.cells[1]}
            end
            if model.town then for _,site in ipairs(area.facilities) do
                model.rows[#model.rows+1]={title=string.format(LuaLanguage.UIMainHudTitle5, (site.name)),body=LuaLanguage.UIMainHudBody6,command='area_move_cell',a=site.entryIndex}
            end end
            if state.InteractionKind~=0 then
                local item=state.InteractionKind==1 and area.facilities[state.InteractionId]
                    or areas.config:GetTable('MapAreaTownNpcTable'):Get(area.npcs[state.InteractionId].templateId)
                if state.InteractionKind==2 and area.npcs[state.InteractionId].narrativeId then item=adventure.narrative.rules.npcs:Get(area.npcs[state.InteractionId].narrativeId) end
                model.interaction={title=item.name,body=item.description,caption=LuaLanguage.UIMainHudCaption,command='area_close'}
            else
                model.prompt=require('Game.Adventure.InteractionPrompt').Find(adventure)
            end
        end
        if data.Phase=='battle' or (data.Phase=='area' and area.areaType==areas.forestType) then
            for i=0,data.PartyCount-1 do local member=data:GetPartyAt(i);if member.HP>0 then model.health[#model.health+1]=actor(member) end end
            local visible={};for i=0,state.VisibleCount-1 do visible[state:GetVisibleAt(i)]=true end
            for i=0,state.EncounterCount-1 do local group=state:GetEncounterAt(i)
                for j=0,group.EnemyCount-1 do local enemy=group:GetEnemyAt(j);local cell=area:Find(enemy.Q,enemy.R)
                    if enemy.HP>0 and enemy.AnimalOwnerId==0 and visible[cell.index] then model.health[#model.health+1]=actor(enemy) end
                end
            end
        end
    elseif data.Phase=='battle' then
        for _,unit in ipairs(adventure.battle:Units()) do if unit.HP>0 then local row=actor(unit);row.screen=true;model.health[#model.health+1]=row end end
    end
    if data.Phase=='map' or data.Phase=='area' then
        if data.Phase=='map' then
            model.menu[#model.menu+1]={title=LuaLanguage.UIMainHudTitle4,body=LuaLanguage.UIMainHudBody5,command='campaign_menu',available=true}
        end
        model.menu[#model.menu+1]={title=LuaLanguage.UIMainHudTitle3,body=LuaLanguage.UIMainHudBody4,command='hud_skill_atlas',available=true}
        local torch=require('Game.Adventure.Torch').Snapshot(adventure)
        model.menu[#model.menu+1]={title=torch.label,body=LuaLanguage.UIMainHudBody3,command='torch_toggle',available=torch.available}
        model.menu[#model.menu+1]={title=LuaLanguage.UIMainHudTitle2,body=string.format(LuaLanguage.UIMainHudBody2, (adventure.characterSaves.Status)),command='save_characters',available=true}
        model.menu[#model.menu+1]={title=LuaLanguage.UIMainHudTitle,body=LuaLanguage.UIMainHudBody,command='campaign_load_menu',available=true}
    end
    local entries=adventure.growth.chronicle:Rows()
    for i=1,math.min(2,#entries) do
        local row=entries[i];local finish=utf8.offset(row.body,23)
        local body=finish and (row.body:sub(1,finish-1)..'…') or row.body
        model.logs[#model.logs+1]='【'..row.label..'】'..row.title..'\n'..body
    end
    return model
end
return Model
