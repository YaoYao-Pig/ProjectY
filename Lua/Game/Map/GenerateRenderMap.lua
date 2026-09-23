-- Unity 测试场景的调用入口：继续使用 Main 中已启动的 Config 与 Map 系统。
return function(seed, recipeText, targetCells)
    assert(type(recipeText) == 'string' and #recipeText > 0, 'Region recipe must not be empty')
    local recipe = {}
    for part in (recipeText .. ','):gmatch('(.-),') do
        assert(part:match('^%s*%d+%s*$'), 'Region recipe requires comma-separated positive IDs')
        recipe[#recipe + 1] = assert(math.tointeger(tonumber(part)))
    end
    local map = require('Main'):Get('Map'):Generate(seed, recipe, targetCells)
    return require('Game.Map.MapRenderSnapshot')(map)
end
