"""Run the focused party-story Lua checks directly against source tables, without exporting config or starting Unity."""
import json
import os
import pathlib
import sys

root = pathlib.Path(__file__).resolve().parents[2]
os.chdir(root)
sys.path.insert(0, str(root / 'Tools'))
from LuaRuntime.runtime import LuaRuntime


def lua_value(value):
    if value is None:
        return 'nil'
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, (list, tuple)):
        return '{' + ','.join(lua_value(item) for item in value) + '}'
    return '{' + ','.join('[' + lua_value(key) + ']=' + lua_value(item) for key, item in value.items()) + '}'


tables = {}
for folder, names in (
    ('Progression', ('PartyStoryRuleTable', 'PartyBondStageTable', 'PartyHonorTable', 'StoryLogTemplateTable')),
    ('Adventure', ('CombatTraitTable',)),
):
    for name in names:
        document = json.loads((root / 'Config' / 'Tables' / folder / (name + '.json')).read_text(encoding='utf-8-sig'))
        assert document['name'] == name
        tables[name] = document['rows']

with LuaRuntime(root) as runtime:
    scripts = (
        'Lua/Game/Progression/PartyStory.lua', 'Lua/Game/Progression/PartyStoryRules.lua',
        'Lua/Game/Progression/Chronicle.lua', 'Lua/UI/Panel/CharacterGrowthCtr.lua',
        'Tools/Tests/social_core.lua', 'Tools/Tests/social_integration.lua', 'Tools/Tests/social_ui_integration.lua',
    )
    runtime.execute(('for _,path in ipairs(' + lua_value(scripts) + ') do assert(loadfile(path)) end').encode('utf-8'), '@social_syntax')
    runtime.execute(('SocialSource=' + lua_value(tables)).encode('utf-8'), '@social_source_tables')
    runtime.execute((root / 'Tools' / 'Tests' / 'social_core.lua').read_bytes(), '@social_core.lua')
