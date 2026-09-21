// 枚举数组覆盖共享枚举、默认值与真实 Lua 二进制读表，确保区域候选配置可用。
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { validateTable, encodeTable, luaString } from '../exporter.mjs';
import { validateCatalog, applyColumn, defaultValue } from '../definitions.mjs';

const catalog = () => ({ version: 1, modules: [{ id: 'Map', folder: null, enums: [
  { name: 'Region', type: 'int', members: [{ name: 'Grassland', value: 1 }, { name: 'Forest', value: 2 }] },
], constants: [{ name: 'Regions', type: 'enum[]', enumRef: 'Map.Region', value: [1, 2] }] }] });
const source = () => ({ version: 1, name: 'EnumArrays', key: 'id', fields: [
  { name: 'id', type: 'int' },
  { name: 'regions', type: 'enum[]', enumRef: 'Map.Region' },
  { name: 'tags', type: 'enum[]', values: ['plain', '林地'], default: [] },
], rows: [{ id: 1, regions: [2, 1], tags: ['林地', 'plain'] }, { id: 2, regions: [] }] });

test('enum arrays validate members, references, defaults and catalog constants', () => {
  const definitions = validateCatalog(catalog());
  const table = validateTable(source(), definitions);
  assert.equal(table.fields[1].enumType, 'int');
  assert.deepEqual(table.rows[1].tags, []);
  for (const value of [[3], ['1'], [null], 1, null]) {
    const input = source(); input.rows[0].regions = value;
    assert.throws(() => validateTable(input, definitions));
  }
  const badDefault = source(); badDefault.rows = []; badDefault.fields[2].default = ['invalid'];
  assert.throws(() => validateTable(badDefault, definitions), /outside enum/);
  const missing = source(); missing.fields[1].enumRef = 'Map.Missing';
  assert.throws(() => validateTable(missing, definitions), /Unknown enum/);
  const removed = catalog(); removed.modules[0].enums[0].members.pop();
  assert.throws(() => validateTable(source(), removed), /outside enum/);
  assert.throws(() => validateCatalog(removed), /invalid constant/);
  const malformed = source(); malformed.fields[2].values = [];
  assert.throws(() => validateTable(malformed, definitions), /enum requires/);
  const field = { name: 'extra', type: 'enum[]', enumRef: 'Map.Region' };
  assert.deepEqual(defaultValue(field, definitions), []);
  assert.deepEqual(applyColumn(source(), field, undefined, definitions).rows[0].extra, []);
});

test('enum array binaries round trip through project xLua with read-only values', t => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'project-y-enum-array-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const encoded = encodeTable(validateTable(source(), validateCatalog(catalog())));
  assert.match(encoded.lua, /regions \(1\|2\)\[\]/);
  fs.writeFileSync(path.join(directory, 'schema.lua'), encoded.lua);
  fs.writeFileSync(path.join(directory, 'table.bytes'), encoded.binary);
  const script = path.join(directory, 'read.lua');
  fs.writeFileSync(script, `package.path = 'Lua/?.lua;' .. package.path
local schema = dofile(${luaString(path.join(directory, 'schema.lua'))})
local file = assert(io.open(${luaString(path.join(directory, 'table.bytes'))}, 'rb'))
local bytes = file:read('*a'); file:close()
local data = require('Config.ConfigTable').Load(schema, bytes)
assert(data.Count == 2)
assert(data:Get(1).regions[1] == 2 and data:Get(1).regions[2] == 1)
assert(data:Get(1).tags[1] == ${luaString('林地')} and data:Get(1).tags[2] == 'plain')
assert(#data:Get(2).regions == 0 and #data:Get(2).tags == 0)
assert(not pcall(function() data:Get(1).regions[1] = 1 end))
assert(not pcall(function() data:Get(2).regions[1] = 1 end))
print('PASS enum array binary round trip')
`);
  const result = spawnSync('python', ['Tools/Tests/run_lua.py', script], { encoding: 'utf8' });
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stderr || result.stdout);
});
