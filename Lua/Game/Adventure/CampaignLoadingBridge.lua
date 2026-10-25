local Creation = require('Game.Adventure.CampaignCreation')
local active, token, operation
return function(command, id, seedText, size, startId, worldName)
    if command == 'begin' or command == 'begin_load' then
        assert(not active, 'Campaign loading is already active')
        local factory = command == 'begin' and Creation or require('Game.Adventure.CampaignRestoration')
        active = factory.New(require('Main'):Get('Adventure'), seedText, size, startId, worldName)
        operation = factory
        token = id
        return
    end
    if command == 'release' then
        if active then assert(token == id, 'Stale campaign loading token') end
        active, token, operation = nil, nil, nil
        return
    end
    assert(active and token == id, 'No matching campaign preparation')
    if command == 'step' then return operation.Step(active) end
    if command == 'commit' then return operation.Commit(active) end
    error('Unknown campaign loading command: ' .. tostring(command))
end
