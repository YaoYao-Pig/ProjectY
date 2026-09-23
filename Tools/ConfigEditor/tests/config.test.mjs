import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { compileFormula, evaluateFormula } from '../formula.mjs';
import { validateTable, validateTables, encodeTable, exportTables, readSources, luaString } from '../exporter.mjs';
import { createEditorServer } from '../server.mjs';
import { validateCatalog, resolveEnum, applyColumn, moduleForFolder } from '../definitions.mjs';
import { scanSources, atomicJson, readCatalog } from '../workspace.mjs';
import { parseLanguage, mergeLanguage, textTable } from '../language.mjs';

const original = () => structuredClone(readSources().filter(table => ['Rewards', 'RewardGroups'].includes(table.name)));
test('sample tables validate with defaults and foreign keys', () => {
  const tables = original(); delete tables[1].rows[0].enabled;
  assert.equal(validateTables(tables).find(x => x.name === 'Rewards').rows[0].enabled, true);
});
test('reject duplicate keys, unknown/missing fields, wrong types, ranges and enum values', () => {
  for (const mutate of [
    t => t.rows.push(structuredClone(t.rows[0])), t => t.rows[0].extra = 1,
    t => delete t.rows[0].base, t => t.rows[0].base = '10', t => t.rows[0].base = -1,
    t => t.rows[0].id = 2147483648, t => t.rows[0].category = 'invalid', t => t.rows[0].enabled = 1,
    t => t.fields.push(structuredClone(t.fields[0])), t => t.key = 'amount',
    t => t.rows[0].tags = 'tag', t => t.rows[0].amount = 'os.execute("x")'
  ]) { const table = original().find(x => x.name === 'Rewards'); mutate(table); assert.throws(() => validateTable(table)); }
});
test('validate defaults even for empty tables', () => {
  const table = original()[0]; table.rows = []; table.fields[2].default = 'wrong'; assert.throws(() => validateTable(table));
});
test('foreign keys reject dangling references and mismatched types', () => {
  const tables = original(); tables[0].rows[0].rewards = [999]; assert.throws(() => validateTables(tables), /missing Rewards/);
  tables[0].rows[0].rewards = ['1']; tables[0].fields[1].type = 'string[]'; assert.throws(() => validateTables(tables), /type mismatch/);
});
test('table names cannot collide on Windows', () => {
  const table = original()[1]; const copy = structuredClone(table); copy.name = 'rewards'; assert.throws(() => validateTables([table, copy]), /case-colliding/);
});
test('table names cannot overwrite the generated manifest or target Windows devices', () => {
  for (const name of ['Manifest', 'manifest', 'CON', 'LPT1', undefined]) {
    const table = original()[1]; table.name = name; assert.throws(() => validateTable(table), /table name/);
  }
});
test('formula precedence, associativity and negative modulo agree with Lua', () => {
  for (const [source, expected] of [['1 + 2 * 3', 7], ['2 ^ 3 ^ 2', 512], ['-2 ^ 2', -4], ['2 ^ -2', .25], ['-5 % 3', 1], ['max(2, min(4, 8))', 4], ['clamp(base * level ^ 2, 0, 1000)', 1000], ['floor(2.9)+ceil(1.2)+abs(-3)', 7]]) {
    assert.equal(evaluateFormula(compileFormula(source, ['base', 'level']), { base: 25, level: 10 }), expected, source);
  }
});
test('formula rejects injection, missing variables, bad arity and numerical faults', () => {
  for (const value of ['os.execute(1)', 'while true do end', 'level + 1', 'min(1)', 'min(1,2,3)', '1; return 2', '1e999', '2 ** 3']) assert.throws(() => compileFormula(value));
  for (const value of ['1/0', '1%0', '(-1)^0.5', 'clamp(1,2,0)', '10^999']) assert.throws(() => evaluateFormula(compileFormula(value), {}));
  assert.throws(() => evaluateFormula(compileFormula('x', ['x']), {}), /Missing/);
});
test('binary format has version, schema fingerprint and row count; row ordering is deterministic', () => {
  const table = original()[1]; const first = encodeTable(validateTable(table)); table.rows.reverse();
  const second = encodeTable(validateTable(table)); assert.deepEqual(first, second);
  assert.equal(first.binary.toString('ascii', 0, 4), 'YCFG'); assert.equal(first.binary.readUInt16LE(4), 1);
  assert.equal(first.binary.readUInt32LE(6), 64); assert.equal(first.binary.readUInt32LE(74), 2);
  table.fields[1].description = 'schema change'; assert.notDeepEqual(encodeTable(validateTable(table)).binary, first.binary);
});
test('Lua string literal preserves non-ASCII and control bytes', () => {
  assert.equal(luaString('a\n"\\中'), '"a\\010\\034\\092\\228\\184\\173"');
});
test('export validates whole set before writes, is reproducible, and removes stale generated outputs', t => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'project-y-config-test-')); t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const inputs = original(); const first = exportTables({ root, inputs }); assert.equal(first.written.length, 6);
  assert.ok(fs.existsSync(path.join(root, 'Lua/_Gen/Rewards.lua')));
  assert.ok(fs.existsSync(path.join(root, 'Lua/_Gen/Manifest.lua')));
  assert.equal(fs.existsSync(path.join(root, 'Assets/GameFramework/Resources/Lua')), false);
  assert.equal(exportTables({ root, inputs }).written.length, 0);
  const file = path.join(root, 'Assets/GameFramework/Resources/_Gen/Config/Rewards.bytes'); const bytes = fs.readFileSync(file);
  const invalid = structuredClone(inputs); invalid[1].rows[0].base = -100;
  assert.throws(() => exportTables({ root, inputs: invalid })); assert.deepEqual(fs.readFileSync(file), bytes);
  exportTables({ root, inputs: [inputs[1]] }); assert.equal(fs.existsSync(path.join(root, 'Assets/GameFramework/Resources/_Gen/Config/RewardGroups.bytes')), false);
  assert.equal(fs.existsSync(path.join(root, 'Lua/_Gen/RewardGroups.lua')), false);
});
test('HTTP editor requires local origin/token and detects save conflicts', async t => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'project-y-editor-test-')); const directory = path.join(root, 'Config/Tables'); fs.mkdirSync(directory, { recursive: true });
  for (const table of original()) fs.writeFileSync(path.join(directory, table.name + '.json'), JSON.stringify(table));
  const server = createEditorServer({ root }); await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(async () => { await new Promise(resolve => server.close(resolve)); fs.rmSync(root, { recursive: true, force: true }); });
  const base = `http://127.0.0.1:${server.address().port}`;
  const session = await (await fetch(base + '/api/tables')).json();
  const payload = { table: session.tables[1], revision: session.revision };
  const send = (url, method, body, headers = {}) => fetch(base + url, { method, headers: { 'Content-Type': 'application/json', 'X-Editor-Token': session.token, ...headers }, body: JSON.stringify(body) });
  assert.equal((await send('/api/export', 'POST', payload, { 'X-Editor-Token': 'bad' })).status, 403);
  assert.equal((await send('/api/export', 'POST', payload, { Origin: 'https://example.com' })).status, 403);
  payload.table.rows[0].base = 100;
  const saved = await send('/api/tables/Rewards', 'PUT', payload); assert.equal(saved.status, 200);
  assert.equal((await send('/api/tables/Rewards', 'PUT', payload)).status, 409);
  payload.revision = (await saved.json()).revision;
  assert.equal((await send('/api/export', 'POST', payload)).status, 200);
  assert.equal((await send('/api/tables/Rewards', 'DELETE', payload)).status, 400); // referenced by RewardGroups
  assert.equal((await fetch(base + '/../../package.json')).status, 404);
});

const catalogFixture = () => ({ version: 1, modules: [{ id: 'Items', folder: 'Items', description: 'Items module', enums: [{ name: 'Rarity', type: 'int', members: [{ name: 'Common', value: 0 }, { name: 'Rare', value: 7, description: 'Rare item' }] }], constants: [{ name: 'DefaultRarity', type: 'enum', enumRef: 'Items.Rarity', value: 0 }, { name: 'Enabled', type: 'bool', value: false }] }] });
const enumTable = () => ({ version: 1, name: 'Items', key: 'id', fields: [{ name: 'id', type: 'int' }, { name: 'rarity', type: 'enum', enumRef: 'Items.Rarity', description: '品质' }, { name: 'title', type: 'text', description: '名称' }], rows: [{ id: 1, rarity: 7, title: '道具' }] });
function temporary(t) { const root = fs.mkdtempSync(path.join(os.tmpdir(), 'project-y-workspace-')); t.after(() => fs.rmSync(root, { recursive: true, force: true })); return root; }

test('shared enums retain explicit integer values; text and descriptions survive export', () => {
  const catalog = validateCatalog(catalogFixture()), tables = validateTables([enumTable()], catalog);
  assert.equal(tables[0].fields[1].enumType, 'int');
  const encoded = encodeTable(tables[0]);
  assert.equal(encoded.binary.readInt32LE(78), 1); assert.equal(encoded.binary.readInt32LE(82), 7);
  assert.match(encoded.lua, /rarity 0\|7 品质/); assert.match(encoded.lua, /title string 名称/);
  const bad = enumTable(); bad.rows[0].rarity = '7'; assert.throws(() => validateTables([bad], catalog), /outside enum/);
  assert.throws(() => validateTables([enumTable()]), /Unknown enum/);
  catalog.modules[0].enums[0].type = 'string'; catalog.modules[0].enums[0].members.forEach(member => member.value = member.name);
  const textEnum = enumTable(); textEnum.rows[0].rarity = 'Rare'; catalog.modules[0].constants[0].value = 'Common';
  assert.equal(validateTables([textEnum], catalog)[0].rows[0].rarity, 'Rare');
});
test('catalog validates module identity, values, constants and folder roots', () => {
  for (const mutate of [
    c => c.modules.push(structuredClone(c.modules[0])),
    c => c.modules[0].folder = '../escape',
    c => c.modules[0].enums[0].members.push({ name: 'DuplicateValue', value: 7 }),
    c => c.modules[0].enums[0].members[0].name = '__proto__',
    c => c.modules[0].constants[0].value = 999,
    c => c.modules[0].constants[1].value = 'false'
  ]) { const catalog = catalogFixture(); mutate(catalog); assert.throws(() => validateCatalog(catalog)); }
  const catalog = catalogFixture(); catalog.modules[0].folder = null;
  assert.equal(resolveEnum({ type: 'enum', enumRef: 'Items.Rarity' }, validateCatalog(catalog)).values[1], 7);
  assert.equal(moduleForFolder(catalog, 'Items/Sub'), undefined); // Detaching a root does not remove definitions.
});
test('column changes preserve renamed values, initialize additions and reject collisions', () => {
  const input = enumTable(), catalog = catalogFixture();
  let result = applyColumn(input, { name: 'label', type: 'text', description: 'Human description' }, 'title', catalog);
  assert.equal(result.rows[0].label, '道具'); assert.equal('title' in result.rows[0], false); assert.equal(input.rows[0].title, '道具');
  result = applyColumn(result, { name: 'tags', type: 'string[]', default: ['new'] }, undefined, catalog);
  assert.deepEqual(result.rows[0].tags, ['new']);
  result = applyColumn(result, { name: 'key', type: 'int' }, 'id', catalog); assert.equal(result.key, 'key');
  assert.throws(() => applyColumn(result, { name: 'rarity', type: 'text' }, 'label', catalog), /重复/);
  assert.throws(() => applyColumn(result, { name: 'missing', type: 'int' }, 'noSuchColumn', catalog));
});
test('recursive sources allow folder moves while table identity stays globally unique', t => {
  const root = temporary(t), directory = path.join(root, 'Config/Tables');
  atomicJson(path.join(directory, 'Items/Nested/Items.json'), enumTable());
  fs.mkdirSync(path.join(directory, 'Empty'));
  const scan = scanSources(directory); assert.ok(scan.folders.includes('Empty')); assert.equal(scan.entries[0].folder, 'Items/Nested');
  atomicJson(path.join(directory, 'Other/Items.json'), enumTable());
  assert.throws(() => validateTables(readSources(directory), catalogFixture()), /case-colliding/);
});
const luaSource = '-- @localization-begin\n Confirm = "确认", -- 确认按钮\n Empty = "", -- 空文本\n Quoted = "a -- b\\n\\034", -- 引号\n-- @localization-end\n';
test('Language extraction reads literals/comments without executing Lua and preserves overrides', () => {
  const rows = parseLanguage(luaSource); assert.equal(rows[0].desc, '确认按钮'); assert.equal(rows[2].txt, 'a -- b\n"');
  const table = textTable('LuaTxt', 'test'); table.rows = [{ id: 'Confirm', txt: 'Table override', desc: 'old' }, { id: 'Manual', txt: 'manual', desc: '' }];
  const merged = mergeLanguage([table], luaSource);
  assert.equal(merged.table.rows.find(row => row.id === 'Confirm').txt, 'Table override');
  assert.equal(merged.table.rows.find(row => row.id === 'Confirm').desc, '确认按钮');
  assert.ok(merged.table.rows.some(row => row.id === 'Manual'));
  assert.equal(mergeLanguage(merged.tables, luaSource).changed, false);
  for (const bad of [luaSource.replace('"确认"', 'os.execute("anything")'), luaSource.replace('Empty =', 'Confirm ='), 'return {}']) assert.throws(() => parseLanguage(bad));
});
test('export syncs Language comments, preserves text overrides and rejects invalid source before writing', t => {
  const root = temporary(t); fs.mkdirSync(path.join(root, 'Lua'), { recursive: true });
  const source = path.join(root, 'Lua/Language.lua'); fs.writeFileSync(source, luaSource);
  exportTables({ root, inputs: original() });
  const filename = path.join(root, 'Config/Tables/Localization/LuaTxt.json'), table = JSON.parse(fs.readFileSync(filename));
  table.rows.find(row => row.id === 'Confirm').txt = 'Override'; atomicJson(filename, table);
  exportTables({ root, inputs: original().concat(table) });
  assert.equal(JSON.parse(fs.readFileSync(filename)).rows.find(row => row.id === 'Confirm').txt, 'Override');
  const before = fs.readFileSync(path.join(root, 'Lua/_Gen/LuaTxt.lua'));
  fs.writeFileSync(source, luaSource.replace('"确认"', 'someFunction()'));
  assert.throws(() => exportTables({ root, inputs: original().concat(table) }));
  assert.deepEqual(fs.readFileSync(path.join(root, 'Lua/_Gen/LuaTxt.lua')), before);
});
test('workspace HTTP supports modules, folders, table moves, enum reference protection and global revisions', async t => {
  const root = temporary(t); atomicJson(path.join(root, 'Config/Tables/Items/Items.json'), enumTable());
  atomicJson(path.join(root, 'Config/Catalog.json'), catalogFixture());
  const server = createEditorServer({ root }); await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  const base = 'http://127.0.0.1:' + server.address().port;
  let session = await (await fetch(base + '/api/tables')).json();
  const send = async (url, method, body = {}, expected = 200) => {
    const response = await fetch(base + url, { method, headers: { 'Content-Type': 'application/json', 'X-Editor-Token': session.token }, body: JSON.stringify({ revision: session.revision, ...body }) });
    const data = await response.json(); assert.equal(response.status, expected, JSON.stringify(data));
    if (response.ok) session = await (await fetch(base + '/api/tables')).json(); return data;
  };
  await send('/api/folders', 'POST', { folder: 'Data/Inventory' });
  await send('/api/tables/Items', 'PUT', { table: enumTable(), folder: 'Data/Inventory' });
  assert.equal(session.locations.Items, 'Data/Inventory'); assert.equal(fs.existsSync(path.join(root, 'Config/Tables/Items/Items.json')), false);
  const invalid = catalogFixture(); invalid.modules[0].enums[0].members.pop();
  await send('/api/catalog', 'PUT', { catalog: invalid }, 400);
  await send('/api/catalog', 'PUT', { catalog: { version: 1, modules: [] } }, 400);
  const detached = catalogFixture(); detached.modules[0].folder = null;
  await send('/api/catalog', 'PUT', { catalog: detached });
  await send('/api/folders', 'DELETE', { folder: 'Items' });
  detached.modules[0].folder = 'Data/Inventory'; await send('/api/catalog', 'PUT', { catalog: detached });
  await send('/api/folders/move', 'POST', { from: 'Data', to: 'Content' });
  assert.equal(session.locations.Items, 'Content/Inventory'); assert.equal(session.catalog.modules[0].folder, 'Content/Inventory');
  await send('/api/folders', 'POST', { folder: '../escaped' }, 400);
  await send('/api/folders', 'POST', { folder: 'content/Other' }, 400);
  await send('/api/folders', 'DELETE', { folder: 'Content/Inventory' }, 400);
  await send('/api/export', 'POST');
  assert.match(fs.readFileSync(path.join(root, 'Lua/_Gen/Catalog.lua'), 'utf8'), /DefaultRarity/);
  fs.mkdirSync(path.join(root, 'Lua'), { recursive: true }); fs.writeFileSync(path.join(root, 'Lua/Language.lua'), luaSource);
  await send('/api/language/sync', 'POST', {}, 409);
  session = await (await fetch(base + '/api/tables')).json();
  await send('/api/language/sync', 'POST'); assert.equal(session.locations.LuaTxt, 'Localization');
});
