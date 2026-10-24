local Creation = require('Game.Adventure.CampaignCreation')
local active, token
return function(command, id, seedText, size, startId)
    if command == 'begin' then
        assert(not active, 'Campaign creation is already active')
        active = Creation.New(require('Main'):Get('Adventure'), seedText, size, startId)
        token = id
        return
    end
    if command == 'release' then
        if active then assert(token == id, 'Stale campaign loading token') end
        active, token = nil, nil
        return
    end
    assert(active and token == id, 'No matching campaign preparation')
    if command == 'step' then return Creation.Step(active) end
    if command == 'commit' then return Creation.Commit(active) end
    error('Unknown campaign loading command: ' .. tostring(command))
end
