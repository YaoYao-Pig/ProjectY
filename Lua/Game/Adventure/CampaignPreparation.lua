-- Shared staging contract: preparation never replaces the active session.
local Language = require('Language')
local Preparation = {}

function Preparation.Check(adventure)
    if adventure.data.Phase ~= 'map' and adventure.data.Phase ~= 'area' then return Language.CampaignFinishEvent end
    if adventure.parties.data.IsOpen then return Language.CampaignCloseParty end
    if adventure.camp.data.IsOpen then return Language.CampaignCloseCamp end
    if adventure.shop.data.IsOpen then return Language.CampaignCloseShop end
    if adventure.narrative.data.DialogueOpen then return Language.CampaignCloseDialogue end
    if adventure.equipment.worldLoot.session.Active then return Language.CampaignCloseLoot end
end

function Preparation.Step(job)
    assert(not job.ready and not job.failed, 'Campaign preparation has already ended')
    local ok, value, stage = coroutine.resume(job.thread)
    if not ok then job.failed = true; error(debug.traceback(job.thread, tostring(value)), 0) end
    if coroutine.status(job.thread) == 'dead' then
        job.ready = true; job.thread = nil
        return true, value
    end
    return false, value, stage
end

return Preparation
