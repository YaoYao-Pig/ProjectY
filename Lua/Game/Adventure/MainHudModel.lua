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
        return {id=row.Id,name=name..(mount and (' · '..stats:Template(mount).name) or ''),
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
        local groups={dungeon={},forest={},battlefield={},town={},event={}}
        for _,site in ipairs(adventure.sites) do
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
                body=reason or (kind=='battlefield' and '重返战场 · 领取遗留战利品' or kind=='forest' and '野生动物 · 驯服坐骑 · 哥布林' or kind=='dungeon' and '搜刮配件 · 探索故事' or kind=='town' and '服务台按 E 交互' or '旅途中的抉择'),command='visit',a=site.id,available=ok}
        end
        for _,kind in ipairs({'forest','battlefield','dungeon','town','event'}) do for _,row in ipairs(groups[kind]) do model.rows[#model.rows+1]=row end end
    elseif data.Areas.ActiveSiteId>0 then
        local areas=adventure.areas;local area,state=areas:ActiveLayout(),data.Areas.Active
        model.town=area.areaType==areas.townType;model.title=area.name
        model.subtitle=model.town and 'E 交互 · V 切换视角 · 空格停止' or '左键移动／处理障碍 · E 交互 · 空格停止'
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
                local row=adventure.obstacles.data:Get(state.SiteId,obstacle.id)
                if not model.interaction and adventure.obstacles:Near(row) then
                    model.interaction={title=obstacle.name,body='已装备的工具可以帮助处理',caption='处理  [E]',command='area_obstacle',a=obstacle.id}
                end
            end
            if model.town then for _,site in ipairs(area.facilities) do
                model.rows[#model.rows+1]={title='前往 · '..site.name,body='到达服务点附近后按 E',command='area_move_cell',a=site.entryIndex}
            end end
            if state.InteractionKind~=0 then
                local item=state.InteractionKind==1 and area.facilities[state.InteractionId]
                    or areas.config:GetTable('MapAreaTownNpcTable'):Get(area.npcs[state.InteractionId].templateId)
                if state.InteractionKind==2 and area.npcs[state.InteractionId].narrativeId then item=adventure.narrative.rules.npcs:Get(area.npcs[state.InteractionId].narrativeId) end
                model.interaction={title=item.name,body=item.description,caption='继续探索  [Esc]',command='area_close'}
            elseif model.town then
                local radius=1;for _,site in ipairs(area.facilities) do radius=math.max(radius,site.interactionRadius) end
                local distance,queue,head={[state.CellIndex]=0},{state.CellIndex},1
                while head<=#queue do local index=queue[head];head=head+1
                    if distance[index]<radius then for _,cell in ipairs(area:Neighbors(area.cells[index])) do
                        if not distance[cell.index] then distance[cell.index]=distance[index]+1;queue[#queue+1]=cell.index end
                    end end
                end
                local best=math.huge
                for _,site in ipairs(area.facilities) do if distance[site.entryIndex] and distance[site.entryIndex]<=site.interactionRadius and distance[site.entryIndex]<best then
                    best=distance[site.entryIndex];model.interaction={title=site.name,body='与服务台交互',caption='交互  [E]',command='area_interact',a=1,b=site.id}
                end end
                for _,npc in ipairs(area.npcs) do local live=state:GetNpcAt(npc.id-1);local steps=distance[live.CellIndex];if live.Present and steps and steps<=1 and (steps<best or (steps==best and npc.narrativeId)) then
                    local row=npc.narrativeId and adventure.narrative.rules.npcs:Get(npc.narrativeId) or areas.config:GetTable('MapAreaTownNpcTable'):Get(npc.templateId)
                    local merchant=adventure.shop and adventure.shop.rules:Resolve(area,npc)
                    best=steps;model.interaction={title=row.name,body=merchant and '查看商品、库存与价格' or '与这位旅人交谈',caption=merchant and '交易  [E]' or '交谈  [E]',command='area_interact',a=2,b=npc.id}
                end end
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
        model.menu[#model.menu+1]={title='技艺图谱',body='按领域与技法浏览技能、效果和前置关系',command='hud_skill_atlas',available=true}
        if adventure.narrative then
            if data.Phase=='map' then model.menu[#model.menu+1]={title='新建叙事示例 · 三人远征',body='重开地图，预留一个招募位置；不会覆盖磁盘存档',command='start_story',available=true} end
        end
        model.menu[#model.menu+1]={title='保存队伍',body=adventure.characterSaves.Status,command='save_characters',available=true}
        model.menu[#model.menu+1]={title='读取队伍 · 重新开始地图',body='恢复队伍、背包、任务和 NPC 状态；地图探索重新开始',command='load_characters',available=adventure.characterSaves.HasSave}
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
