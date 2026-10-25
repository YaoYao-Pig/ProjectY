-- A candidate owns only static layout until Commit. No live Data or save identity changes during Prepare.
local Language = require('Language')
local Preparation = require('Game.Adventure.CampaignPreparation')
local Creation = {Check = Preparation.Check, Step = Preparation.Step}

function Creation.New(adventure, seedText, size, startId, worldName)
    assert(type(seedText) == 'string' and seedText:match('^%d+$'), Language.UIStartMenuHintText)
    local seed = tonumber(seedText)
    assert(seed and math.tointeger(seed) and seed >= 0 and seed <= 4294967295, Language.UIStartMenuHintText)
    assert(size == 2500 or size == 10000 or size == 30000 or size == 100000, Language.CampaignInvalidSize)
    assert(worldName == nil or type(worldName) == 'string', 'World name must be text')
    local reason = Creation.Check(adventure); assert(not reason, reason)
    local profile = require('Game.Adventure.CampaignStarts').Get(adventure.config, startId)
    local job = { adventure = adventure, seed = seed, size = size, recipeId = profile.adventureRecipeId, profile = profile, worldName = worldName or '' }
    job.thread = coroutine.create(function()
        job.world = adventure:BuildWorld(seed, job.recipeId, size, function(value, stage)
            coroutine.yield(.02 + value * .56, stage)
        end)
        coroutine.yield(.6, Language.CampaignLoadingSnapshot)
        return require('Game.Map.MapRenderSnapshot')(job.world.map)
    end)
    return job
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
    CS.ProjectY.Data.CampaignSaves.NewCampaign(adventure.characterSaves, job.worldName)
    local saved, saveError = require('Game.Adventure.CharacterSave').Write(adventure)
    local snapshot = adventure:Snapshot()
    if not saved then snapshot.warning = string.format(Language.CampaignInitialSaveFailed, saveError) end
    return snapshot
end
return Creation
