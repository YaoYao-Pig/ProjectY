local Language = require('Language')
local Preparation = require('Game.Adventure.CampaignPreparation')
local Save = require('Game.Adventure.CharacterSave')
local Restoration = {Step = Preparation.Step}

function Restoration.New(adventure, saveId)
    assert(type(saveId) == 'string' and saveId ~= '', Language.CampaignSelectSave)
    local reason = Preparation.Check(adventure); assert(not reason, reason)
    local job = {adventure = adventure, saveId = saveId}
    job.thread = coroutine.create(function()
        coroutine.yield(.02, Language.CampaignLoadingRead)
        job.prepared, job.world = Save.Prepare(adventure, saveId, function(value, stage)
            coroutine.yield(.02 + value * .56, stage)
        end)
        coroutine.yield(.6, Language.CampaignLoadingSnapshot)
        return require('Game.Map.MapRenderSnapshot')(job.world.map)
    end)
    return job
end

function Restoration.Commit(job)
    assert(job.ready and not job.committed, 'Campaign is not ready or was already committed')
    local reason = Preparation.Check(job.adventure); assert(not reason, reason)
    job.committed = true
    Save.Commit(job.adventure, job.prepared, job.world)
    require('Game.Presentation.VisualEffects').Clear(job.adventure.battle)
    return job.adventure:Snapshot()
end

return Restoration
