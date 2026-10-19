"""Exercise salvage Lua against source-table rows without exporting or opening Unity."""
import json
import os
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[2]
os.chdir(root)
sys.path.insert(0, str(root / 'Tools'))
from LuaRuntime.runtime import LuaRuntime


def lua(value):
    if isinstance(value, dict):
        return '{' + ','.join('[' + lua(key) + ']=' + lua(item) for key, item in value.items()) + '}'
    if isinstance(value, list):
        return '{' + ','.join(lua(item) for item in value) + '}'
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, (int, float)):
        return str(value)
    raise TypeError(type(value))


names = ['Adventure/CombatSkillTable', 'Adventure/CombatEffectTable', 'Adventure/CharacterLoadoutTable',
         'Equipment/EquipmentWeaponTable', 'Equipment/EquipmentLootTable', 'Loot/LootEntryTable']
tables = {}
for name in names:
    document = json.loads((root / ('Config/Tables/' + name + '.json')).read_text(encoding='utf-8'))
    defaults = {field['name']: field['default'] for field in document['fields'] if 'default' in field}
    tables[document['name']] = [defaults | row for row in document['rows']]
with LuaRuntime(root) as runtime:
    runtime.execute(('SalvageSourceRows=' + lua(tables)).encode('utf-8'), '@salvage_source_fixture')
    script = root / 'Tools/Tests/equipment_salvage_core.lua'
    runtime.execute(script.read_bytes(), '@' + str(script))
