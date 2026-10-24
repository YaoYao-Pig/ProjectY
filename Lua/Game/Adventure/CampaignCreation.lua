-- A candidate owns only static layout until Commit. No live Data or save identity changes during Prepare.
local Creation = {}

function Creation.Check(adventure)
    if adventure.data.Phase ~= 'map' and adventure.data.Phase ~= 'area' then return '请先结束当前事件或战斗' end
    if adventure.parties.data.IsOpen then return '请先结束队伍交互' end
    if adventure.camp.data.IsOpen then return '请先关闭营地面板' end
    if adventure.shop.data.IsOpen then return '请先关闭商店' end
    if adventure.narrative.data.DialogueOpen then return '请先结束对话' end
    if adventure.equipment.worldLoot.session.Active then return '请先关闭战利品窗口' end
end

function Creation.New(adventure, seedText, size, startId)
    assert(type(seedText) == 'string' and seedText:match('^%d+$'), '种子须为 0 至 4294967295 的整数')
    local seed = tonumber(seedText)
    assert(seed and math.tointeger(seed) and seed >= 0 and seed <= 4294967295, '种子须为 0 至 4294967295 的整数')
    assert(size == 2500 or size == 10000 or size == 30000 or size == 100000, '请选择有效的世界大小')
    local reason = Creation.Check(adventure); assert(not reason, reason)
    local profile = require('Game.Adventure.CampaignStarts').Get(adventure.config, startId)
    local job = { adventure = adventure, seed = seed, size = size, recipeId = profile.adventureRecipeId, profile = profile }
    job.thread = coroutine.create(function()
        job.world = adventure:BuildWorld(seed, job.recipeId, size, function(value, stage)
            coroutine.yield(.02 + value * .56, stage)
        end)
        coroutine.yield(.6, '准备地图显示数据')
        return require('Game.Map.MapRenderSnapshot')(job.world.map)
    end)
    return job
end

function Creation.Step(job)
    assert(not job.ready and not job.failed, 'Campaign preparation has already ended')
    local ok, value, stage = coroutine.resume(job.thread)
    if not ok then job.failed = true; error(debug.traceback(job.thread, tostring(value)), 0) end
    if coroutine.status(job.thread) == 'dead' then
        job.ready = true; job.thread = nil
        return true, value
    end
    return false, value, stage
end

function Creation.Commit(job)
    assert(job.ready and not job.committed, 'Campaign is not ready or was already committed')
    local adventure = job.adventure
    local reason = Creation.Check(adventure); assert(not reason, reason)
    job.committed = true
    adventure:Start(job.seed, job.recipeId, job.size, job.world)
    require('Game.Presentation.VisualEffects').Clear(adventure.battle)
    adventure.narrative.data:SetValue('flag:campaign_start', job.profile.id)
    CS.ProjectY.Data.ExpeditionPersistence.ResetProfile(adventure.player, job.profile.coins)
    CS.ProjectY.Data.CampaignSaves.NewCampaign(adventure.characterSaves)
    local saved, saveError = require('Game.Adventure.CharacterSave').Write(adventure)
    local snapshot = adventure:Snapshot()
    if not saved then snapshot.warning = '世界已创建，但初始存档未保存：' .. saveError end
    return snapshot
end
return Creation
