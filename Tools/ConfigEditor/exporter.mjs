import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { compileFormula } from './formula.mjs';
import { emptyCatalog, validateCatalog, resolveEnum } from './definitions.mjs';
import { readCatalog, scanSources, atomicJson } from './workspace.mjs';
import { languageSource, mergeLanguage } from './language.mjs';

export const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
export const sourceDirectory = path.join(projectRoot, 'Config/Tables');
const identifier = /^[A-Za-z][A-Za-z0-9_]*$/;
const fieldIdentifier = /^[A-Za-z_][A-Za-z0-9_]*$/;
const reserved = new Set(['__proto__', 'constructor', 'prototype']);
const reservedTableName = /^(?:manifest|catalog|con|prn|aux|nul|com[1-9]|lpt[1-9])$/i;
const types = new Set(['int', 'float', 'bool', 'string', 'text', 'enum', 'formula', 'int[]', 'float[]', 'bool[]', 'string[]']);
function fail(message) { throw new Error(message); }
function assert(condition, message) { if (!condition) fail(message); }
const object = value => value !== null && typeof value === 'object' && !Array.isArray(value);

export function validateTable(input, catalog = emptyCatalog()) {
  assert(object(input), 'Table must be an object');
  const table = structuredClone(input);
  assert(table.version === 1, 'Unsupported source version; expected 1');
  assert(typeof table.name === 'string' && identifier.test(table.name) && !reserved.has(table.name) && !reservedTableName.test(table.name), 'Invalid or reserved table name');
  assert(Array.isArray(table.fields) && table.fields.length > 0 && table.fields.length <= 128, `${table.name}: expected 1–128 fields`);
  table.fields = table.fields.map(field => field && resolveEnum(field, catalog));
  assert(Array.isArray(table.rows) && table.rows.length <= 100000, `${table.name}: rows must be an array (maximum 100000)`);
  const fields = new Set();
  for (const field of table.fields) {
    assert(object(field) && typeof field.name === 'string' && fieldIdentifier.test(field.name) && !reserved.has(field.name), `${table.name}: invalid field name`);
    assert(!fields.has(field.name), `${table.name}: duplicate field '${field.name}'`); fields.add(field.name);
    assert(types.has(field.type), `${table.name}.${field.name}: unsupported type '${field.type}'`);
    assert(field.description === undefined || typeof field.description === 'string', `${field.name}: description must be a string`);
    if (field.type === 'enum') {
      const kind = field.enumType || 'string';
      assert(['int', 'string'].includes(kind) && Array.isArray(field.values) && field.values.length > 0 && field.values.every(x => kind === 'int' ? Number.isInteger(x) && x >= -2147483648 && x <= 2147483647 : typeof x === 'string') && new Set(field.values).size === field.values.length, `${field.name}: enum requires unique ${kind} values`);
    }
    if (field.type === 'formula') assert(Array.isArray(field.variables) && field.variables.every(x => typeof x === 'string' && fieldIdentifier.test(x) && !reserved.has(x)) && new Set(field.variables).size === field.variables.length, `${field.name}: formula requires unique variable names`);
    if (field.ref !== undefined) assert(typeof field.ref === 'string' && identifier.test(field.ref) && ['int', 'string', 'int[]', 'string[]'].includes(field.type), `${field.name}: ref requires an int/string field or array`);
    if (field.min !== undefined) assert(['int', 'float', 'int[]', 'float[]'].includes(field.type) && Number.isFinite(field.min), `${field.name}: invalid min`);
    if (field.max !== undefined) assert(['int', 'float', 'int[]', 'float[]'].includes(field.type) && Number.isFinite(field.max), `${field.name}: invalid max`);
    if (field.min !== undefined && field.max !== undefined) assert(field.min <= field.max, `${field.name}: min exceeds max`);
  }
  const key = table.fields.find(field => field.name === table.key);
  assert(key && ['int', 'string'].includes(key.type), `${table.name}: key must be an int/string field`);
  function check(value, field, location, type = field.type) {
    if (type.endsWith('[]')) {
      assert(Array.isArray(value) && value.length <= 65535, `${location}: expected array with at most 65535 elements`);
      value.forEach((item, index) => check(item, field, `${location}[${index}]`, type.slice(0, -2))); return;
    }
    if (type === 'int') assert(Number.isInteger(value) && value >= -2147483648 && value <= 2147483647, `${location}: expected int32`);
    if (type === 'float') assert(typeof value === 'number' && Number.isFinite(value), `${location}: expected finite number`);
    if (type === 'int' || type === 'float') {
      if (field.min !== undefined) assert(value >= field.min, `${location}: below minimum ${field.min}`);
      if (field.max !== undefined) assert(value <= field.max, `${location}: above maximum ${field.max}`);
    }
    if (type === 'bool') assert(typeof value === 'boolean', `${location}: expected bool`);
    if (type === 'string' || type === 'text' || (type === 'enum' && field.enumType !== 'int')) assert(typeof value === 'string' && Buffer.byteLength(value) <= 1048576, `${location}: expected string (maximum 1 MiB)`);
    if (type === 'enum') assert(field.values.includes(value), `${location}: value is outside enum`);
    if (type === 'formula') {
      try { compileFormula(value, field.variables); } catch (error) { fail(`${location}: ${error.message}`); }
    }
  }
  for (const field of table.fields) if (Object.hasOwn(field, 'default')) check(field.default, field, `${table.name}.${field.name}.default`);
  const keys = new Set();
  table.rows.forEach((row, index) => {
    const location = `${table.name}.rows[${index}]`;
    assert(object(row), `${location}: expected object`);
    for (const name of Object.keys(row)) assert(fields.has(name), `${location}: unknown field '${name}'`);
    for (const field of table.fields) {
      if (!Object.hasOwn(row, field.name) && Object.hasOwn(field, 'default')) row[field.name] = structuredClone(field.default);
      assert(Object.hasOwn(row, field.name), `${location}: missing '${field.name}'`);
      check(row[field.name], field, `${location}.${field.name}`);
    }
    assert(row[table.key] !== '', `${location}: empty primary key`);
    assert(!keys.has(row[table.key]), `${location}: duplicate key '${row[table.key]}'`); keys.add(row[table.key]);
  });
  table.rows.sort((a, b) => a[table.key] < b[table.key] ? -1 : a[table.key] > b[table.key] ? 1 : 0);
  return table;
}

export function validateTables(inputs, catalog = emptyCatalog()) {
  catalog = validateCatalog(catalog);
  const tables = inputs.map(input => validateTable(input, catalog)).sort((a, b) => a.name < b.name ? -1 : a.name > b.name ? 1 : 0);
  const byName = new Map();
  for (const table of tables) {
    assert(!byName.has(table.name.toLowerCase()), `Duplicate/case-colliding table '${table.name}'`);
    byName.set(table.name.toLowerCase(), table);
    if (['LuaTxt', 'PrefabTxt'].includes(table.name)) {
      assert(table.key === 'id' && table.fields.length === 3 && ['id:string', 'txt:text', 'desc:string'].every(pair => table.fields.some(field => `${field.name}:${field.type}` === pair)), `${table.name}: required schema is id:string, txt:text, desc:string`);
    }
  }
  for (const table of tables) for (const field of table.fields) if (field.ref) {
    const target = tables.find(x => x.name === field.ref);
    assert(target, `${table.name}.${field.name}: missing table '${field.ref}'`);
    assert(field.type.replace('[]', '') === target.fields.find(x => x.name === target.key).type, `${table.name}.${field.name}: reference key type mismatch`);
    const keys = new Set(target.rows.map(row => row[target.key]));
    for (const row of table.rows) for (const value of (field.type.endsWith('[]') ? row[field.name] : [row[field.name]]))
      assert(keys.has(value), `${table.name}[${row[table.key]}].${field.name}: missing ${field.ref}[${value}]`);
  }
  return tables;
}

class Writer {
  chunks = [];
  bytes(value) { this.chunks.push(value); }
  numeric(method, length, value) { const buffer = Buffer.alloc(length); buffer[method](value, 0); this.bytes(buffer); }
  u8(value) { this.numeric('writeUInt8', 1, value); }
  u16(value) { this.numeric('writeUInt16LE', 2, value); }
  u32(value) { this.numeric('writeUInt32LE', 4, value); }
  i32(value) { this.numeric('writeInt32LE', 4, value); }
  f64(value) { this.numeric('writeDoubleLE', 8, value); }
  string(value) { const buffer = Buffer.from(value, 'utf8'); this.u32(buffer.length); this.bytes(buffer); }
  finish() { return Buffer.concat(this.chunks); }
}

// Decimal escapes are byte-oriented in Lua, preserving UTF-8 and all control characters exactly.
export function luaString(value) {
  return '"' + [...Buffer.from(value, 'utf8')].map(byte => byte >= 32 && byte <= 126 && byte !== 34 && byte !== 92 ? String.fromCharCode(byte) : '\\' + String(byte).padStart(3, '0')).join('') + '"';
}
export function luaLiteral(value) {
  if (typeof value === 'string') return luaString(value);
  if (typeof value === 'number' || typeof value === 'boolean') return String(value);
  if (Array.isArray(value)) return '{' + value.map(luaLiteral).join(',') + '}';
  if (object(value)) return '{' + Object.entries(value).map(([key, val]) => `[${luaString(key)}]=${luaLiteral(val)}`).join(',') + '}';
  throw new Error('Cannot emit Lua literal');
}
export function encodeTable(table) {
  const schema = { name: table.name, key: table.key, fields: table.fields };
  schema.fingerprint = crypto.createHash('sha256').update(JSON.stringify(schema)).digest('hex');
  const writer = new Writer(); writer.bytes(Buffer.from('YCFG')); writer.u16(1); writer.string(schema.fingerprint); writer.u32(table.rows.length);
  function write(value, field, type = field.type) {
    if (type.endsWith('[]')) { writer.u32(value.length); value.forEach(item => write(item, field, type.slice(0, -2))); return; }
    if (type === 'int') writer.i32(value);
    else if (type === 'enum' && field.enumType === 'int') writer.i32(value);
    else if (type === 'float') writer.f64(value);
    else if (type === 'bool') writer.u8(value ? 1 : 0);
    else if (type === 'formula') {
      const program = compileFormula(value, field.variables); writer.u16(program.length);
      for (const [opcode, operand] of program) {
        writer.u8(opcode); if (opcode === 1) writer.f64(operand); else if (opcode === 2) writer.string(operand);
      }
    } else writer.string(value);
  }
  for (const row of table.rows) for (const field of table.fields) write(row[field.name], field);
  const annotations = table.fields.map(field => `---@field ${field.name} ${field.type === 'int' || field.type === 'float' ? 'number' : field.type === 'text' ? 'string' : field.type === 'formula' ? 'ConfigFormula' : field.type === 'enum' ? field.values.map(luaLiteral).join('|') : field.type.replace('int', 'number').replace('float', 'number').replace('bool', 'boolean')}${field.description ? ' ' + field.description.replace(/[\r\n]/g, ' ') : ''}`).join('\n');
  return { binary: writer.finish(), lua: `-- Generated by Tools/ConfigEditor/exporter.mjs. Do not edit.\n---@class ${table.name}Row\n${annotations}\nreturn ${luaLiteral(schema)}\n` };
}

export function readSources(directory = sourceDirectory) {
  return scanSources(directory).entries.map(entry => entry.table).sort((a, b) => a.name < b.name ? -1 : a.name > b.name ? 1 : 0);
}
export function exportTables({ root = projectRoot, inputs = readSources(path.join(root, 'Config/Tables')), catalog = readCatalog(root) } = {}) {
  catalog = validateCatalog(catalog);
  const language = mergeLanguage(inputs, languageSource(root));
  const tables = validateTables(language.tables, catalog);
  assert(tables.length > 0, 'No config tables found');
  const outputs = new Map();
  for (const table of tables) {
    const encoded = encodeTable(table);
    outputs.set(`Assets/GameFramework/Resources/Config/${table.name}.bytes`, encoded.binary);
    outputs.set(`Lua/Generated/${table.name}.lua`, encoded.lua);
  }
  outputs.set('Lua/Generated/Manifest.lua', `-- Generated.\nreturn ${luaLiteral(tables.map(x => x.name))}\n`);
  {
    const Enums = {}, Constants = {};
    for (const module of catalog.modules) {
      Enums[module.id] = Object.fromEntries(module.enums.map(item => [item.name, Object.fromEntries(item.members.map(member => [member.name, member.value]))]));
      Constants[module.id] = Object.fromEntries(module.constants.map(item => [item.name, item.value]));
    }
    outputs.set('Lua/Generated/Catalog.lua', `-- Generated. Module folder roots do not affect these identities.\nreturn ${luaLiteral({ Enums, Constants })}\n`);
  }
  // Validate and encode the entire set before any output mutation; only replace changed files.
  // Editor build gate re-exports before packaging, so a process crash cannot silently ship a mixed schema.
  if (language.changed) {
    const existing = scanSources(path.join(root, 'Config/Tables')).entries.find(entry => entry.table.name === 'LuaTxt');
    atomicJson(existing?.filename || path.join(root, 'Config/Tables/Localization/LuaTxt.json'), language.table);
  }
  const written = [];
  for (const [relative, content] of outputs) {
    const destination = path.join(root, relative); const bytes = Buffer.from(content);
    if (fs.existsSync(destination) && fs.readFileSync(destination).equals(bytes)) continue;
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    const temporary = destination + '.tmp'; fs.writeFileSync(temporary, bytes); fs.renameSync(temporary, destination);
    written.push(relative);
  }
  // Remove only prior generated outputs recorded in our manifest, never unrelated assets.
  const manifestPath = path.join(root, 'Config/export-manifest.json');
  const previous = fs.existsSync(manifestPath) ? JSON.parse(fs.readFileSync(manifestPath, 'utf8')) : [];
  for (const relative of previous) {
    if (outputs.has(relative)) continue;
    assert(/^(?:Assets\/GameFramework\/Resources\/Config\/[A-Za-z][A-Za-z0-9_]*\.bytes|Lua\/Generated\/[A-Za-z][A-Za-z0-9_]*\.lua)$/.test(relative), 'Unsafe generated manifest path');
    fs.rmSync(path.join(root, relative), { force: true }); fs.rmSync(path.join(root, relative + '.meta'), { force: true });
  }
  fs.mkdirSync(path.dirname(manifestPath), { recursive: true });
  fs.writeFileSync(manifestPath, JSON.stringify([...outputs.keys()], null, 2) + '\n');
  return { tables: tables.length, rows: tables.reduce((sum, table) => sum + table.rows.length, 0), written };
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { console.log(JSON.stringify(exportTables(), null, 2)); }
  catch (error) { console.error(error.message); process.exitCode = 1; }
}
