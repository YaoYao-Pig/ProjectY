// 编辑器与导出器共用类型定义；模块标识独立于可选的目录根路径。
export const fieldTypes = ['int', 'float', 'bool', 'string', 'text', 'enum', 'formula', 'int[]', 'float[]', 'bool[]', 'string[]', 'enum[]'];
export const identifier = /^[A-Za-z_][A-Za-z0-9_]*$/;
const reserved = new Set(['__proto__', 'constructor', 'prototype']);
const assert = (condition, message) => { if (!condition) throw new Error(message); };
export const validName = value => typeof value === 'string' && identifier.test(value) && !reserved.has(value);
export function validateFolder(value) {
  assert(typeof value === 'string', 'Folder must be a string');
  for (const segment of value ? value.split('/') : []) {
    assert(segment && segment !== '.' && segment !== '..' && !/[<>:"\\|?*\x00-\x1f]/.test(segment) && !/[. ]$/.test(segment) && !/^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)/i.test(segment), `Invalid folder: ${value}`);
  }
  return value;
}
export function emptyCatalog() { return { version: 1, modules: [] }; }
export function enumDefinition(catalog, reference) {
  const [moduleId, name, extra] = (reference || '').split('.');
  if (extra !== undefined) return undefined;
  return catalog.modules.find(module => module.id === moduleId)?.enums.find(item => item.name === name);
}
export function resolveEnum(field, catalog) {
  // 枚举数组与单值枚举共用成员定义；数组逐项校验由调用方负责。
  if (!['enum', 'enum[]'].includes(field.type) || !field.enumRef) return field;
  const definition = enumDefinition(catalog, field.enumRef);
  assert(definition, `Unknown enum: ${field.enumRef}`);
  return { ...field, enumType: definition.type, values: definition.members.map(member => member.value) };
}
export function enumOptions(field, catalog) {
  const definition = field.enumRef && enumDefinition(catalog, field.enumRef);
  return definition ? definition.members.map(member => ({ value: member.value, label: `${member.name} = ${member.value}${member.description ? ' · ' + member.description : ''}` })) : (field.values || []).map(value => ({ value, label: String(value) }));
}
export function defaultValue(field, catalog) {
  if (Object.hasOwn(field, 'default')) return structuredClone(field.default);
  if (field.type.endsWith('[]')) return [];
  if (field.type === 'enum') return enumOptions(field, catalog)[0]?.value ?? '';
  if (field.type === 'bool') return false;
  if (field.type === 'int' || field.type === 'float') return 0;
  return field.type === 'formula' ? '0' : '';
}
export function applyColumn(table, field, oldName, catalog) {
  if (!validName(field.name) || !fieldTypes.includes(field.type)) throw new Error('字段键名或类型无效');
  if (table.fields.some(item => item.name === field.name && item.name !== oldName)) throw new Error('字段键名重复');
  const next = structuredClone(table), index = next.fields.findIndex(item => item.name === oldName);
  if (oldName && index < 0) throw new Error('原字段不存在');
  if (index < 0) next.fields.push(field); else next.fields[index] = field;
  for (const row of next.rows) {
    row[field.name] = oldName && Object.hasOwn(row, oldName) ? row[oldName] : defaultValue(field, catalog);
    if (oldName && oldName !== field.name) delete row[oldName];
  }
  if (next.key === oldName) next.key = field.name;
  return next;
}
export function validateCatalog(input) {
  const catalog = structuredClone(input);
  assert(catalog?.version === 1 && Array.isArray(catalog.modules), 'Invalid catalog version/modules');
  const ids = new Set(), roots = new Set();
  function named(items, context) {
    assert(Array.isArray(items), `${context}: expected array`);
    const names = new Set();
    for (const item of items) {
      assert(item && validName(item.name) && !names.has(item.name), `${context}: invalid/duplicate name ${item?.name}`);
      assert(item.description === undefined || typeof item.description === 'string', `${context}: invalid description`);
      names.add(item.name);
    }
  }
  for (const module of catalog.modules) {
    assert(module && validName(module.id) && !ids.has(module.id.toLowerCase()), `Invalid/duplicate module: ${module?.id}`);
    ids.add(module.id.toLowerCase());
    assert(module.description === undefined || typeof module.description === 'string', 'Invalid module description');
    if (module.folder !== null) {
      validateFolder(module.folder);
      assert(!roots.has(module.folder.toLowerCase()), 'Two modules cannot share a folder root');
      roots.add(module.folder.toLowerCase());
    }
    named(module.enums, module.id + '.enums'); named(module.constants, module.id + '.constants');
    for (const item of module.enums) {
      assert(['int', 'string'].includes(item.type), `${module.id}.${item.name}: enum type must be int/string`);
      named(item.members, item.name);
      assert(item.members.length > 0, `${item.name}: enum needs members`);
      const values = new Set();
      for (const member of item.members) {
        assert(item.type === 'int' ? Number.isInteger(member.value) && member.value >= -2147483648 && member.value <= 2147483647 : typeof member.value === 'string', `${item.name}.${member.name}: invalid enum value`);
        assert(!values.has(member.value), `${item.name}: duplicate enum value`); values.add(member.value);
      }
    }
  }
  function check(value, type, field) {
    if (type.endsWith('[]')) return Array.isArray(value) && value.every(item => check(item, type.slice(0, -2), field));
    if (type === 'int') return Number.isInteger(value) && value >= -2147483648 && value <= 2147483647;
    if (type === 'float') return typeof value === 'number' && Number.isFinite(value);
    if (type === 'bool') return typeof value === 'boolean';
    if (type === 'string' || type === 'text') return typeof value === 'string';
    if (type === 'enum') return !!field.enumRef && resolveEnum(field, catalog).values.includes(value);
    return false;
  }
  for (const module of catalog.modules) for (const item of module.constants) {
    assert(typeof item.type === 'string' && check(item.value, item.type, item), `${module.id}.${item.name}: invalid constant type/value`);
  }
  return catalog;
}
export function moduleForFolder(catalog, folder) {
  return catalog.modules.filter(module => module.folder !== null && (module.folder === '' || folder === module.folder || folder.startsWith(module.folder + '/'))).sort((a, b) => b.folder.length - a.folder.length)[0];
}
