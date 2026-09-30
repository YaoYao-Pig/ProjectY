return function(command)
    local story=require('Main'):Get('Narrative')
    if command=='data' then return story.data end
    error('Unknown narrative bridge command: '..tostring(command))
end
