import fs from 'node:fs';
import path from 'node:path';

export function languageSource(root) {
  const filename = path.join(root, 'Lua/Language.lua');
  return fs.existsSync(filename) ? fs.readFileSync(filename, 'utf8') : '';
}
function decodeLiteral(source) {
  const value = source.slice(1, -1), bytes = [];
  const escapes = { a: 7, b: 8, f: 12, n: 10, r: 13, t: 9, v: 11, '\\': 92, '"': 34, "'": 39 };
  for (let i = 0; i < value.length;) {
    if (value[i] !== '\\') {
      const char = String.fromCodePoint(value.codePointAt(i)); bytes.push(Buffer.from(char)); i += char.length; continue;
    }
    i++; const char = value[i++];
    if (Object.hasOwn(escapes, char)) bytes.push(Buffer.from([escapes[char]]));
    else if (/[0-9]/.test(char || '')) {
      let digits = char; while (digits.length < 3 && /[0-9]/.test(value[i] || '')) digits += value[i++];
      if (Number(digits) > 255) throw new Error('Lua escape exceeds one byte'); bytes.push(Buffer.from([Number(digits)]));
    } else if (char === 'x' && /^[0-9a-f]{2}/i.test(value.slice(i))) {
      bytes.push(Buffer.from([parseInt(value.slice(i, i + 2), 16)])); i += 2;
    } else throw new Error(`Unsupported Lua string escape: \\${char}`);
  }
  return new TextDecoder('utf-8', { fatal: true }).decode(Buffer.concat(bytes));
}
export function parseLanguage(source) {
  if (!source) return [];
  const blocks = [...source.matchAll(/^[ \t]*-- @localization-begin\r?\n([\s\S]*?)^[ \t]*-- @localization-end[ \t]*\r?$/gm)];
  if (blocks.length !== 1) throw new Error('Language.lua needs exactly one @localization-begin/end block');
  const literal = `(?:"(?:\\\\.|[^"\\\\])*"|'(?:\\\\.|[^'\\\\])*')`;
  const pattern = new RegExp(`^\\s*(?:([A-Za-z_][A-Za-z0-9_]*)|\\[(${literal})\\])\\s*=\\s*(${literal})\\s*,?\\s*(?:--\\s?(.*))?$`);
  const rows = [], ids = new Set();
  for (const [index, line] of blocks[0][1].split(/\r?\n/).entries()) {
    if (!line.trim() || line.trimStart().startsWith('--')) continue;
    const match = pattern.exec(line);
    if (!match) throw new Error(`Language.lua entry ${index + 1}: use one literal key = "text", -- description per line`);
    const id = match[1] || decodeLiteral(match[2]);
    if (!id || ids.has(id)) throw new Error(`Language.lua duplicate/empty id: ${id}`);
    ids.add(id); rows.push({ id, txt: decodeLiteral(match[3]), desc: (match[4] || '').trim() });
  }
  return rows;
}
export function textTable(name, description) {
  return { version: 1, name, description, key: 'id', fields: [
    { name: 'id', type: 'string', description: '稳定文本标识' },
    { name: 'txt', type: 'text', description: '开发语言文本' },
    { name: 'desc', type: 'string', description: '用途与翻译说明', default: '' }
  ], rows: [] };
}
export function mergeLanguage(inputs, source) {
  if (!source) return { tables: inputs, changed: false };
  const entries = parseLanguage(source), tables = structuredClone(inputs);
  let table = tables.find(item => item.name === 'LuaTxt');
  if (!table) { table = textTable('LuaTxt', 'Language.lua 默认文本与可编辑覆盖'); tables.push(table); }
  const before = JSON.stringify(inputs.find(item => item.name === 'LuaTxt'));
  for (const entry of entries) {
    const row = table.rows.find(row => row.id === entry.id);
    if (row) row.desc = entry.desc; // Preserve explicit table text overrides.
    else table.rows.push(entry);
  }
  return { tables, table, changed: before !== JSON.stringify(table) };
}
