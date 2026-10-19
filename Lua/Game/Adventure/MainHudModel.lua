-- 仅构造 HUD 投影；按钮仍走远征命令，位置/血量/消费均不复制为可变业务状态。
local Model={}
function Model.Build(adventure)
    local data=adventure.data;local stats=adventure.battle.stats
    local model={phase=data.Phase,title='边境远征',subtitle='选择目的地，开始这一程。',coins=adventure.player.Coins,
        rows={},menu={},party={},health={},logs={},interaction=nil,town=false}
    local function actor(row)
        local mount=row.MountedAnimal
        local name=adventure.narrative and adventure.narrative.npcs:ActorName(row) or stats:Template(row).name
        local effects=adventure.battle.gameEffects:Rows(row)
        if mount then for _,effect in ipairs(adventure.battle.gameEffects:Rows(mount)) do
            effect.name=effect.name..' · 坐骑';effect.body='坐骑：'..stats:Template(mount).name..'\n'..effect.body
            effects[#effects+1]=effect
        end end
        return {id=row.Id,name='Lv.'..row.Growth.Level..' '..name..(mount and (' · '..stats:Template(mount).name) or ''),
            hp=mount and mount.HP or row.HP,maxHP=mount and mount.MaxHP or row.MaxHP,healthId=mount and mount.Id or row.Id,team=row.Team,
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
        model.title='边境远征 · 大地图';model.subtitle='种子 '..data.Seed..' · 左键前往 · 空格暂停/继续 · 1 / 2 / 3 调速'
        model.rows[#model.rows+1]={title=travel.active and ('前往 · '..travel.destination) or '小队待命',
            body=travel.active and string.format('%s · %s · 预计 %.0f 分钟',travel.terrain,travel.paused and '已暂停' or '行进中',travel.remaining)
                or ((travel.paused and '时间已暂停' or '小队原地待命 · 时间继续流逝')..(travel.message~='' and ('\n'..travel.message) or '')),
            command='hud_follow',available=true}
        model.rows[#model.rows+1]={title=travel.paused and '▶ 继续时间' or 'Ⅱ 暂停时间',body='空格切换 · 同时控制小队、商队与敌人',command='travel_pause',available=true}
        for key,speed in ipairs({1,2,4}) do model.rows[#model.rows+1]={title=(travel.speed==speed and '● ' or '')..speed..' 倍时间',body='数字键 '..key..' · 同步调整行进与游戏时间',command='travel_speed',a=speed,available=true} end
        local groups={dungeon={},forest={},battlefield={},town={},event={}}
        for _,site in ipairs(adventure.sites) do
            if not site.travelStop or adventure.areas:AreaId(site) then
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
                body=reason or (kind=='battlefield' and '重返战场 · 领取遗留战利品' or kind=='forest' and '野生动物 · 驯服坐骑 · 哥布林' or kind=='dungeon' and '装备、材料与守卫宝库' or kind=='town' and '服务台按 E 交互' or '旅途中的抉择'),command='visit',a=site.id,available=ok}
            end
        end
        for _,kind in ipairs({'forest','battlefield','dungeon','town','event'}) do for _,row in ipairs(groups[kind]) do model.rows[#model.rows+1]=row end end
    elseif data.Areas.ActiveSiteId>0 then
        local areas=adventure.areas;local area,state=areas:ActiveLayout(),data.Areas.Active
        model.town=area.areaType==areas.townType;model.title=area.name
        model.subtitle='左键走格子 · E 交互 · 空格停止'
        if data.Phase=='area' then
            if data.ResultText~='' then model.rows[#model.rows+1]={title='最近结果',body=data.ResultText,command='snapshot',available=false} end
            model.rows[#model.rows+1]={title='定位小队并跟随',body='从全图视角回到同行者身边',command='hud_follow'}
            for _,loot in ipairs(adventure.equipment:LootSnapshot(areas)) do if not loot.looted or loot.canSearch then
                model.rows[#model.rows+1]={title=(loot.looted and '存放 · ' or loot.canSearch and '搜刮 · ' or '容器 · ')..loot.name,
                    body=loot.canSearch and '靠近后整理容器、存入或取出物品' or ('耐久 '..loot.durability..'/'..loot.maxDurability..' · 选择伤害技能攻击；锁定容器须先清除守卫'),
                    command='area_loot',a=loot.id,available=loot.canSearch}
            end end
            for _,obstacle in ipairs(adventure.obstacles:Snapshot()) do
                model.rows[#model.rows+1]={title='处理 · '..obstacle.name,body='走近后选择工具或徒手处理',command='area_move_cell',a=obstacle.cells[1]}
            end
            if model.town then for _,site in ipairs(area.facilities) do
                model.rows[#model.rows+1]={title='前往 · '..site.name,body='到达服务点附近后按 E',command='area_move_cell',a=site.entryIndex}
            end end
            if state.InteractionKind~=0 then
                local item=state.InteractionKind==1 and area.facilities[state.InteractionId]
                    or areas.config:GetTable('MapAreaTownNpcTable'):Get(area.npcs[state.InteractionId].templateId)
                if state.InteractionKind==2 and area.npcs[state.InteractionId].narrativeId then item=adventure.narrative.rules.npcs:Get(area.npcs[state.InteractionId].narrativeId) end
                model.interaction={title=item.name,body=item.description,caption='继续探索  [Esc]',command='area_close'}
            else
                model.prompt=require('Game.Adventure.InteractionPrompt').Find(adventure)
                model.interaction=model.prompt
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
            for _,option in ipairs({{2500,'短途边境'},{10000,'标准远征'},{30000,'广袤世界'},{100000,'十万格大陆'}}) do
                model.menu[#model.menu+1]={title='新游戏 · '..option[2],body=option[1]..' 格目标 · 随机种子 · 三人小队 · 当前未保存进度将舍弃，磁盘存档保留',command='campaign_start',a=option[1],available=true}
            end
        end
        model.menu[#model.menu+1]={title='技能图鉴 · 浏览',body='查询技能效果与前置；学习与加点请打开角色养成',command='hud_skill_atlas',available=true}
        local torch=require('Game.Adventure.Torch').Snapshot(adventure)
        model.menu[#model.menu+1]={title=torch.label,body='携带火炬可照亮小队周围；亮度只在局部探索生效',command='torch_toggle',available=torch.available}
        model.menu[#model.menu+1]={title='保存远征 [F5]',body=adventure.characterSaves.Status..' · 保存探索、敌群、战利品和剧情',command='save_characters',available=true}
        model.menu[#model.menu+1]={title='继续游戏',body='恢复最近一次手动存档；旧版队伍档会开始新地图',command='campaign_continue',available=adventure.characterSaves.HasSave}
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
