import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { readSources, validateTables, exportTables } from '../ConfigEditor/exporter.mjs';
import { atomicJson, readCatalog, tableDirectory } from '../ConfigEditor/workspace.mjs';
import { adjustmentKey } from './public/hold-adjustments.mjs';

export const gripFields = ['mainPosition', 'mainRotation', 'offPosition', 'offRotation'];
const digest = value => crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
const reject = (status, message) => { throw Object.assign(new Error(message), { status }); };

export function createGripStore(root) {
  const filename = path.join(tableDirectory(root, 'Equipment'), 'EquipmentGripTable.json');
  function read() {
    if (fs.lstatSync(filename).isSymbolicLink()) reject(400, '握点配置不能是链接文件');
    const table = JSON.parse(fs.readFileSync(filename, 'utf8'));
    if (table.name !== 'EquipmentGripTable') reject(400, '握点配置表名无效');
    return table;
  }
  function readWeapons() {
    const file = path.join(path.dirname(filename), 'EquipmentWeaponTable.json');
    if (fs.lstatSync(file).isSymbolicLink()) reject(400, '武器配置不能是链接文件');
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  }
  const adjustmentFile = path.join(path.dirname(filename), 'EquipmentHoldAdjustmentTable.json');
  function readAdjustments() {
    if (fs.lstatSync(adjustmentFile).isSymbolicLink()) reject(400, '持握修正不能是链接文件');
    const table = JSON.parse(fs.readFileSync(adjustmentFile, 'utf8')), seen = new Set();
    for (const row of table.rows) {
      const key = adjustmentKey(row.weaponId, row.moduleId, row.hand);
      if (seen.has(key)) reject(400, '重复的武器持握修正：' + key);
      if (!Array.isArray(row.rotationOffset) || row.rotationOffset.length !== 3 || !row.rotationOffset.every(Number.isFinite)) reject(400, '武器旋转修正必须是有限 Vector3：' + key);
      seen.add(key);
    }
    return table;
  }
  const revision = table => digest({ table, weapons: readWeapons(), adjustments: readAdjustments(), modules: fs.readFileSync(path.join(path.dirname(filename), 'EquipmentMotionModuleTable.json'), 'utf8') });
  function state() {
    const table = read();
    const weapons = readWeapons();
    return { rows: table.rows, adjustments: readAdjustments().rows, weapons: weapons.rows.map(w => ({ id: w.id, gripId: w.gripId })), revision: revision(table) };
  }
  function save(input) {
    const table = read();
    if (input.revision !== revision(table)) reject(409, '握点或武器配置已被其他页面或工具修改；请重新读取配置后再编辑。当前草稿尚未写入。');
    if (!Number.isSafeInteger(input.id)) reject(400, '握点 ID 无效');
    const row = table.rows.find(r => r.id === input.id);
    if (!row) reject(404, '握点不存在');
    if (!input.values || Object.keys(input.values).length !== gripFields.length || gripFields.some(k => !Object.hasOwn(input.values, k))) reject(400, '必须提供四个握点向量');
    for (const key of gripFields) {
      const value = input.values[key];
      if (!Array.isArray(value) || value.length !== 3 || !value.every(v => typeof v === 'number' && Number.isFinite(v))) reject(400, key + ' 必须是三个有限数值');
      row[key] = [...value];
    }
    const tables = readSources(path.join(root, 'Config/Tables'));
    validateTables(tables.map(t => t.name === table.name ? table : t), readCatalog(root));
    // Only the four editable vectors change. Other rows, schema and fields are preserved.
    atomicJson(filename, table);
    return { row, revision: revision(table) };
  }
  function exportConfig(input) {
    if (input.revision !== revision(read())) reject(409, '握点或武器配置已变化，请先重新读取');
    return exportTables({ root });
  }
  function saveAdjustment(input) {
    if (input.revision !== revision(read())) reject(409, '握点、武器或持握修正已变化，请重新读取；当前草稿保留。');
    if (!Number.isSafeInteger(input.weaponId) || !Number.isSafeInteger(input.moduleId) || !['main','off'].includes(input.hand)) reject(400, '武器 / 模组 / 主副手标识无效');
    const rotation = input.rotationOffset;
    if (rotation !== null && (!Array.isArray(rotation) || rotation.length !== 3 || !rotation.every(v => typeof v === 'number' && Number.isFinite(v)))) reject(400, '武器旋转必须是三个有限数值');
    const table = readAdjustments(), key = adjustmentKey(input.weaponId, input.moduleId, input.hand);
    const existing = table.rows.find(row => adjustmentKey(row.weaponId, row.moduleId, row.hand) === key);
    if (rotation === null) table.rows = table.rows.filter(row => row !== existing);
    else if (existing) existing.rotationOffset = [...rotation];
    else table.rows.push({ id: Math.max(0, ...table.rows.map(row=>row.id)) + 1, weaponId: input.weaponId, moduleId: input.moduleId, hand: input.hand, rotationOffset: [...rotation] });
    const tables = readSources(path.join(root, 'Config/Tables'));
    validateTables(tables.map(t => t.name === table.name ? table : t), readCatalog(root));
    atomicJson(adjustmentFile, table);
    return { revision: revision(read()) };
  }
  return { state, save, saveAdjustment, exportConfig };
}
