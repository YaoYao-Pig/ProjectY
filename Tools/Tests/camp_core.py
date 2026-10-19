"""Read real camp source tables and run Lua rules without exporting or starting Unity."""
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

tables = {}
for path in [*sorted((root / 'Config/Tables/Camp').glob('*.json')), root / 'Config/Tables/Equipment/EquipmentItemTable.json']:
    document = json.loads(path.read_text(encoding='utf-8'))
    tables[document['name']] = document['rows']
with LuaRuntime(root) as runtime:
    runtime.execute(('CampSourceRows=' + lua(tables)).encode('utf-8'), '@camp_source_fixture')
    script = root / 'Tools/Tests/camp_core.lua'
    runtime.execute(script.read_bytes(), '@' + str(script))
