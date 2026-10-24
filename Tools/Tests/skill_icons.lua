-- Targeted editor-free test of the actual exported runtime icon configuration.
package.path = 'Lua/?.lua;' .. package.path
local config = require('Config.ConfigSystem')()
config:OnInit({services = {ReadConfig = function(_, name)
    local file = assert(io.open('Assets/GameFramework/Resources/_Gen/Config/' .. name .. '.bytes', 'rb'))
    local bytes = file:read('*a'); file:close(); return bytes
end}})
local skills = config:GetTable('CombatSkillTable')
local icons = config:GetTable('BattleIconTable')
local recipes = config:GetTable('SkillIconRecipeTable')
local styles = config:GetTable('SkillIconStyleTable')
local published = 0
local covered = {}
for _, recipe in ipairs(recipes:All()) do
    local skill = skills:Get(recipe.skillId)
    assert(not covered[skill.id], 'Duplicate icon recipe for skill ' .. skill.id)
    covered[skill.id] = true
    assert(styles:Get(recipe.styleId).maxTextureSize >= 64)
    local icon = icons:Find(recipe.id)
    if icon then
        assert(skill.iconId == recipe.id)
        assert(icon.spritePath:match('^Assets/DynamicAsset/UI/Icons/Skills/') and not icon.spritePath:find('..', 1, true))
        local file = assert(io.open(icon.spritePath, 'rb'))
        assert(file:read(8) == '\137PNG\13\10\26\10'); file:close()
        published = published + 1
    else
        assert(icons:Get(skill.iconId))
    end
end
assert(recipes.Count == skills.Count, 'Every combat skill must have an icon recipe')
assert(published == skills.Count, 'Every combat skill must have a published icon')
print('PASS complete exported skill icon coverage, styles, PNG assets and runtime mappings: ' .. published)
