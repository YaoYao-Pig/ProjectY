import { compileFormula, evaluateFormula } from '/formula.mjs';
import { fieldTypes, defaultValue, enumOptions, validName, validateCatalog, moduleForFolder, applyColumn } from '/definitions.mjs';
const $ = id => document.getElementById(id);
const element = (tag, text, className) => { const node = document.createElement(tag); if (text !== undefined) node.textContent = text; if (className) node.className = className; return node; };
let ws = { tables: [], folders: [''], locations: {}, catalog: { version: 1, modules: [] } };
let revision, token, selected = 'Rewards', selectedFolder = '', draftFolder = '', draft, catalogDraft;
let view = 'table', catalogTab = 'enums', moduleId, dirty = false, schemaDirty = false, tableTab = 'data';
function status(message, error = false) { $('status').textContent = message; $('status').classList.toggle('error', error); }
function markDirty() { dirty = true; $('dirty-state').textContent = '有未保存修改'; }
function run(callback) { return Promise.resolve().then(callback).catch(error => status(error.message, true)); }
function button(text, callback, className) { const node = element('button', text, className); node.type = 'button'; node.onclick = () => run(callback); return node; }
function action(id, callback) { $(id).onclick = async () => { $(id).disabled = true; try { await callback(); } catch (error) { status(error.message, true); } finally { $(id).disabled = false; } }; }
function selectOptions(node, options, value) {
  node.replaceChildren();
  for (const option of options) { const item = element('option', option.label ?? option.value); item.value = option.value; node.append(item); }
  node.value = value ?? '';
}
function folderOptions(detachable = false) { return [...(detachable ? [{ value: '@none', label: '不绑定目录（保留模块定义）' }] : []), ...ws.folders.map(value => ({ value, label: value || '/ 根目录' }))]; }
function enumReferences() { return ws.catalog.modules.flatMap(module => module.enums.map(item => ({ value: module.id + '.' + item.name, label: module.id + '.' + item.name + ' · ' + (item.description || item.type) }))); }
async function api(url, method = 'GET', data) {
  const response = await fetch(url, { method, headers: { 'Content-Type': 'application/json', 'X-Editor-Token': token || '' }, body: data === undefined ? undefined : JSON.stringify({ ...data, revision }) });
  const result = await response.json(); if (!response.ok) throw new Error(result.error); return result;
}
function discard() {
  if (dirty && !confirm('放弃当前未保存的草稿？')) return false;
  dirty = false; schemaDirty = false; catalogDraft = structuredClone(ws.catalog);
  draft = structuredClone(ws.tables.find(table => table.name === selected));
  draftFolder = draft ? ws.locations[draft.name] : selectedFolder;
  if (!catalogDraft.modules.some(module => module.id === moduleId)) moduleId = catalogDraft.modules[0]?.id;
  render(); return true;
}
async function load() {
  const result = await api('/api/tables'); ws = result; revision = result.revision; token = result.token;
  if (selected && !ws.tables.some(table => table.name === selected)) selected = ws.tables[0]?.name;
  draft = structuredClone(ws.tables.find(table => table.name === selected));
  draftFolder = draft ? ws.locations[draft.name] : (ws.folders.includes(selectedFolder) ? selectedFolder : '');
  selectedFolder = draftFolder;
  catalogDraft = structuredClone(ws.catalog);
  if (!catalogDraft.modules.some(module => module.id === moduleId)) moduleId = catalogDraft.modules[0]?.id;
  dirty = false; schemaDirty = false; render();
}
function openTable(name) {
  if (!discard()) return;
  selected = name; draft = structuredClone(ws.tables.find(table => table.name === name));
  draftFolder = ws.locations[name] ?? selectedFolder; selectedFolder = draftFolder;
  view = 'table'; tableTab = 'data'; $('search').value = ''; render();
}
function openFolder(folder) {
  if (!discard()) return;
  selectedFolder = folder; selected = ws.tables.find(table => ws.locations[table.name] === folder)?.name ?? null;
  draft = structuredClone(ws.tables.find(table => table.name === selected)); draftFolder = folder; view = 'table'; render();
}
function openCatalog(tab, id = moduleId, highlight) {
  if (view !== 'catalog' && !discard()) return;
  view = 'catalog'; catalogTab = tab; moduleId = id || catalogDraft.modules[0]?.id; render();
  if (highlight) [...$('definition-list').children].find(node => node.dataset.name === highlight)?.scrollIntoView({ block: 'center' });
}
function renderTree() {
  $('tables').replaceChildren();
  for (const folder of ws.folders) {
    const depth = folder ? folder.split('/').length : 0;
    const module = ws.catalog.modules.find(item => item.folder === folder);
    const row = button((module ? '◇ ' : '▣ ') + (folder.split('/').at(-1) || '根目录') + (module ? ' · ' + module.id : ''), () => openFolder(folder), 'folder-node');
    row.style.paddingLeft = (10 + depth * 12) + 'px'; row.classList.toggle('selected-folder', folder === selectedFolder); $('tables').append(row);
    for (const table of ws.tables.filter(table => ws.locations[table.name] === folder)) {
      const item = button(table.name, () => openTable(table.name), 'table-node'); item.style.paddingLeft = (24 + depth * 12) + 'px';
      item.classList.toggle('active', view === 'table' && table.name === selected); item.append(element('small', table.rows.length)); $('tables').append(item);
    }
  }
}
function render() {
  renderTree();
  for (const mode of ['table', 'catalog', 'overview']) $(mode + '-workspace').hidden = view !== mode;
  $('overview-nav').classList.toggle('active', view === 'overview');
  $('enums-nav').classList.toggle('active', view === 'catalog' && catalogTab === 'enums');
  $('constants-nav').classList.toggle('active', view === 'catalog' && catalogTab === 'constants');
  $('table-count').textContent = ws.tables.length; $('module-count').textContent = catalogDraft?.modules.length ?? 0;
  $('dirty-state').textContent = dirty ? '有未保存修改' : '已同步';
  $('validate').hidden = view !== 'table'; $('save').hidden = view === 'overview';
  if (view === 'table') renderTable(); else if (view === 'catalog') renderCatalog(); else renderOverview();
}
function renderTable() {
  $('eyebrow').textContent = 'GAME DATA / TABLE EDITOR';
  $('title').textContent = draft?.name || (selectedFolder || '根目录'); $('description').textContent = draft?.description || '在当前目录新建或选择数据表';
  $('detail-label').textContent = '当前数据行'; $('detail-count').textContent = draft?.rows.length ?? 0;
  $('field-count').textContent = (draft?.fields.length ?? 0) + ' 个字段';
  selectOptions($('folder-select'), folderOptions(), draftFolder);
  $('table-description').value = draft?.description || '';
  selectOptions($('table-key'), (draft?.fields || []).filter(field => ['int', 'string'].includes(field.type)).map(field => ({ value: field.name })), draft?.key);
  for (const id of ['table-description', 'table-key', 'add-column', 'add-row', 'delete-table', 'validate', 'save']) $(id).disabled = !draft;
  $('schema').value = draft ? JSON.stringify({ version: draft.version, name: draft.name, description: draft.description, key: draft.key, fields: draft.fields }, null, 2) : '';
  for (const tab of ['data', 'schema']) { $(tab + '-view').hidden = tableTab !== tab; $(tab + '-tab').classList.toggle('active', tableTab === tab); }
  renderRows(); renderFields();
}
function renderRows() {
  $('columns').replaceChildren(); $('rows').replaceChildren(); if (!draft) return;
  for (const kind of ['name', 'type', 'description']) {
    const tr = element('tr', undefined, 'header-' + kind); tr.append(element('th', kind === 'name' ? '#' : kind === 'type' ? '类型' : '描述'));
    for (const field of draft.fields) {
      const th = element('th');
      if (kind === 'name') th.append(button(field.name + (field.name === draft.key ? ' ⚿' : ''), () => editColumn(field)));
      else if (kind === 'type') th.textContent = field.type + (field.enumRef ? ' · ' + field.enumRef : '') + (field.ref ? ' → ' + field.ref : '');
      else { const input = element('input'); input.value = field.description || ''; input.placeholder = '填写描述'; input.setAttribute('aria-label', field.name + ' 列描述'); input.oninput = () => { field.description = input.value; markDirty(); }; th.append(input); }
      tr.append(th);
    }
    tr.append(element('th')); $('columns').append(tr);
  }
  const query = $('search').value.toLowerCase();
  draft.rows.forEach((row, index) => {
    if (query && !JSON.stringify(row).toLowerCase().includes(query)) return;
    const tr = element('tr'); tr.append(element('td', String(index + 1).padStart(2, '0'), 'row-index'));
    for (const field of draft.fields) {
      const td = element('td'), input = element(field.type === 'enum' ? 'select' : field.type === 'text' ? 'textarea' : 'input');
      const options = field.type === 'enum' ? enumOptions(field, ws.catalog) : [];
      if (field.type === 'enum') {
        selectOptions(input, options.map((option, i) => ({ value: String(i), label: option.label })), String(options.findIndex(option => option.value === row[field.name])));
        if (!options.some(option => option.value === row[field.name])) { const missing = element('option', '无效值：' + row[field.name]); missing.value = '-1'; input.prepend(missing); input.value = '-1'; }
      } else if (field.type === 'bool') { input.type = 'checkbox'; input.checked = row[field.name] ?? field.default ?? false; }
      else input.value = field.type.endsWith('[]') ? (typeof row[field.name] === 'string' ? row[field.name] : JSON.stringify(row[field.name] ?? field.default ?? [])) : row[field.name] ?? field.default ?? '';
      input.dataset.type = field.type; input.setAttribute('aria-label', '第 ' + (index + 1) + ' 行 ' + field.name);
      input.oninput = () => {
        markDirty(); input.classList.remove('invalid');
        try {
          let value = input.value;
          if (field.type === 'bool') value = input.checked;
          else if (field.type === 'enum') { if (!options[Number(value)]) throw new Error('请选择有效枚举值'); value = options[Number(value)].value; }
          else if (field.type === 'int' || field.type === 'float') { if (!value.trim() || !Number.isFinite(Number(value))) throw new Error('请输入数字'); value = Number(value); }
          else if (field.type.endsWith('[]')) value = JSON.parse(value);
          if (field.type === 'formula') compileFormula(value, field.variables);
          row[field.name] = value; status('草稿已修改；保存时校验全表和共享定义。');
        } catch (error) { row[field.name] = input.value; input.classList.add('invalid'); status(field.name + ': ' + error.message, true); }
      };
      td.append(input); tr.append(td);
    }
    const cell = element('td'); cell.append(button('×', () => { draft.rows.splice(index, 1); markDirty(); renderTable(); }, 'danger')); tr.append(cell); $('rows').append(tr);
  });
}
function renderFields() {
  $('field-list').replaceChildren();
  for (const [index, field] of (draft?.fields || []).entries()) {
    const row = element('div', undefined, 'field-card');
    const info = element('div'); info.append(element('strong', field.name), element('small', field.type + (field.enumRef ? ' · ' + field.enumRef : '') + ' — ' + (field.description || '无描述')));
    const actions = element('div', undefined, 'actions');
    actions.append(button('编辑', () => editColumn(field)), button('↑', () => moveField(index, -1)), button('↓', () => moveField(index, 1)), button('删除', () => {
      if (schemaDirty) throw new Error('请先应用高级字段 JSON，再操作列');
      if (field.name === draft.key) throw new Error('请先更换主键再删除该列');
      if (!confirm('删除列 ' + field.name + ' 及其所有行数据？保存后生效。')) return;
      draft.fields.splice(index, 1); for (const item of draft.rows) delete item[field.name]; markDirty(); renderTable();
    }, 'danger')); row.append(info, actions); $('field-list').append(row);
  }
}
function moveField(index, offset) { if (schemaDirty) throw new Error('请先应用高级字段 JSON，再调整列顺序'); if (index + offset < 0 || index + offset >= draft.fields.length) return; [draft.fields[index], draft.fields[index + offset]] = [draft.fields[index + offset], draft.fields[index]]; markDirty(); renderTable(); }
function applySchema() {
  if (!draft || !schemaDirty) return;
  const schema = JSON.parse($('schema').value);
  if (schema.name !== draft.name || !Array.isArray(schema.fields)) throw new Error('表名不可改变，fields 必须为数组');
  const names = new Set();
  for (const field of schema.fields) { if (!validName(field.name) || !fieldTypes.includes(field.type) || names.has(field.name)) throw new Error('字段键名/类型无效或重复'); names.add(field.name); }
  if (draft.fields.some(field => !names.has(field.name)) && !confirm('新字段定义会删除缺失的列和对应数据，继续？')) throw new Error('已取消字段变更');
  const rows = draft.rows.map(row => Object.fromEntries(schema.fields.map(field => [field.name, Object.hasOwn(row, field.name) ? row[field.name] : defaultValue(field, ws.catalog)])));
  draft = { ...schema, rows }; schemaDirty = false; markDirty(); renderTable();
}
function ensureDraft() { if (!draft) throw new Error('请先创建或选择表'); applySchema(); }
async function save() {
  if (view === 'catalog') { await api('/api/catalog', 'PUT', { catalog: catalogDraft }); }
  else { ensureDraft(); await api('/api/tables/' + draft.name, 'PUT', { table: draft, folder: draftFolder }); selected = draft.name; }
  await load(); status('源文件已保存。导出后游戏使用新数据。');
}
function control(label, value = '', options) {
  const wrapper = element('label', label), input = element(options ? 'select' : 'input'); input.setAttribute('aria-label', label);
  if (options) selectOptions(input, options, value); else input.value = value;
  wrapper.append(input); $('dialog-fields').append(wrapper); return input;
}
function dialog(title, build, submit) {
  $('dialog-title').textContent = title; $('dialog-fields').replaceChildren(); $('dialog-error').textContent = '';
  const data = build();
  $('edit-form').onsubmit = async event => { event.preventDefault(); const submitButton = event.submitter; if (submitButton) submitButton.disabled = true; try { await submit(data); $('edit-dialog').close(); } catch (error) { $('dialog-error').textContent = error.message; } finally { if (submitButton) submitButton.disabled = false; } };
  $('edit-dialog').showModal();
}
function editColumn(original) {
  ensureDraft();
  dialog(original ? '编辑列 · ' + original.name : '添加列', () => {
    const name = control('键名', original?.name), description = control('描述（给人看）', original?.description);
    const type = control('类型', original?.type || 'string', fieldTypes.map(value => ({ value })));
    const enumRef = control('共享枚举', original?.enumRef || '', [{ value: '', label: '使用表内枚举（兼容旧表）' }, ...enumReferences()]);
    const values = control('表内枚举值（JSON 数组）', JSON.stringify(original?.values || []));
    const defaultInput = control('默认值（JSON，可留空）', original && Object.hasOwn(original, 'default') ? JSON.stringify(original.default) : '');
    const min = control('最小值（可留空）', original?.min ?? ''), max = control('最大值（可留空）', original?.max ?? '');
    const ref = control('引用表（可留空）', original?.ref ?? '', [{ value: '', label: '无' }, ...ws.tables.map(table => ({ value: table.name }))]);
    const variables = control('公式变量（逗号分隔）', original?.variables?.join(', ') || '');
    // 单值与数组枚举共用成员来源设置；数组单元格仍以 JSON 数组编辑。
    const refresh = () => { const isEnum = ['enum', 'enum[]'].includes(type.value); enumRef.parentElement.hidden = !isEnum; values.parentElement.hidden = !isEnum || !!enumRef.value; variables.parentElement.hidden = type.value !== 'formula'; };
    type.onchange = refresh; enumRef.onchange = refresh; refresh();
    return { name, description, type, enumRef, values, defaultInput, min, max, ref, variables };
  }, data => {
    const field = { name: data.name.value.trim(), type: data.type.value, description: data.description.value };
    if (['enum', 'enum[]'].includes(field.type)) { if (data.enumRef.value) field.enumRef = data.enumRef.value; else field.values = JSON.parse(data.values.value); }
    if (data.defaultInput.value.trim()) field.default = JSON.parse(data.defaultInput.value);
    for (const name of ['min', 'max']) if (data[name].value.trim()) { field[name] = Number(data[name].value); if (!Number.isFinite(field[name])) throw new Error('范围必须是数值'); }
    if (data.ref.value) field.ref = data.ref.value;
    if (field.type === 'formula') field.variables = data.variables.value.split(',').map(item => item.trim()).filter(Boolean);
    draft = applyColumn(draft, field, original?.name, ws.catalog); markDirty(); renderTable();
  });
}
function currentModule() { return catalogDraft.modules.find(module => module.id === moduleId); }
function renderCatalog() {
  const module = currentModule();
  $('eyebrow').textContent = 'SHARED DEFINITIONS / MODULES'; $('title').textContent = catalogTab === 'enums' ? '枚举管理' : '常量管理';
  $('description').textContent = module ? module.id + ' · ' + (module.folder === null ? '未绑定目录' : module.folder || '根目录') : '先创建模块，为枚举和常量提供稳定命名空间';
  $('detail-label').textContent = catalogTab === 'enums' ? '当前模块枚举' : '当前模块常量'; $('detail-count').textContent = module?.[catalogTab].length ?? 0;
  selectOptions($('module-select'), catalogDraft.modules.map(item => ({ value: item.id })), moduleId);
  selectOptions($('module-folder'), folderOptions(true), module?.folder ?? '@none'); $('module-description').value = module?.description || '';
  for (const id of ['module-folder', 'module-description', 'delete-module', 'new-definition']) $(id).disabled = !module;
  $('enum-tab').classList.toggle('active', catalogTab === 'enums'); $('constant-tab').classList.toggle('active', catalogTab === 'constants');
  $('new-definition').textContent = catalogTab === 'enums' ? '＋ 新增枚举' : '＋ 新增常量';
  $('definition-list').replaceChildren();
  for (const item of module?.[catalogTab] || []) {
    const row = element('article', undefined, 'definition-card'); row.dataset.name = item.name;
    const heading = element('div', undefined, 'toolbar'), info = element('div');
    info.append(element('strong', module.id + '.' + item.name), element('p', item.description || '无描述', 'hint'));
    const actions = element('div', undefined, 'actions');
    actions.append(button('编辑', () => editDefinition(item)), button('删除', () => {
      if (!confirm('删除定义 ' + item.name + '？保存时会检查所有引用。')) return;
      module[catalogTab] = module[catalogTab].filter(entry => entry !== item); markDirty(); renderCatalog();
    }, 'danger')); heading.append(info, actions); row.append(heading);
    if (catalogTab === 'enums') { const list = element('div', undefined, 'member-chips'); for (const member of item.members) list.append(element('span', member.name + ' = ' + member.value + (member.description ? ' · ' + member.description : ''))); row.append(list); }
    else row.append(element('code', item.type + (item.enumRef ? ' ' + item.enumRef : '') + ' = ' + JSON.stringify(item.value)));
    $('definition-list').append(row);
  }
  if (!module?.[catalogTab].length) $('definition-list').append(element('p', '暂无定义。点击右上角新增。', 'empty-state'));
}
function newModule(folder = null) {
  dialog('新建模块', () => ({ id: control('模块 ID', ''), description: control('模块描述', ''), folder: control('模块根目录', folder ?? '@none', folderOptions(true)) }), data => {
    const item = { id: data.id.value.trim(), description: data.description.value, folder: data.folder.value === '@none' ? null : data.folder.value, enums: [], constants: [] };
    const next = structuredClone(catalogDraft); next.modules.push(item); validateCatalog(next); catalogDraft = next; moduleId = item.id; view = 'catalog'; markDirty(); render();
  });
}
function editDefinition(original) {
  const module = currentModule(); if (!module) throw new Error('请先创建模块');
  const isEnum = catalogTab === 'enums';
  dialog((original ? '编辑' : '新增') + (isEnum ? '枚举' : '常量'), () => {
    const name = control('名称', original?.name), description = control('描述', original?.description);
    const type = control('值类型', original?.type || (isEnum ? 'int' : 'string'), (isEnum ? ['int', 'string'] : fieldTypes.filter(value => value !== 'formula')).map(value => ({ value })));
    if (isEnum) {
      const area = element('div', undefined, 'member-editor'), members = [];
      area.append(element('p', '成员键名 / 实际值 / 描述。整数值显式填写，增删成员不会重新编号。', 'hint'));
      const addMember = value => {
        const row = element('div', undefined, 'member-row');
        const fields = ['name', 'value', 'description'].map((key, i) => { const input = element('input'); input.value = value?.[key] ?? ''; input.placeholder = ['成员键名', '实际值', '描述'][i]; input.setAttribute('aria-label', input.placeholder); row.append(input); return input; });
        const entry = { fields, row }; members.push(entry); row.append(button('×', () => { members.splice(members.indexOf(entry), 1); row.remove(); })); area.append(row);
      };
      $('dialog-fields').append(area, button('＋ 添加成员', () => addMember()));
      for (const member of original?.members || [{ name: '', value: 0, description: '' }]) addMember(member);
      return { name, description, type, members };
    }
    const options = catalogDraft.modules.flatMap(item => item.enums.map(value => ({ value: item.id + '.' + value.name })));
    const enumRef = control('共享枚举', original?.enumRef || '', [{ value: '', label: '选择枚举' }, ...options]);
    const value = control('常量值（string/text 直接填；其他用 JSON）', original ? ['string', 'text'].includes(original.type) ? original.value : JSON.stringify(original.value) : '');
    // Catalog 的枚举数组常量同样绑定共享枚举，保存时逐项校验。
    const refresh = () => { enumRef.parentElement.hidden = !['enum', 'enum[]'].includes(type.value); }; type.onchange = refresh; refresh();
    return { name, description, type, enumRef, value };
  }, data => {
    const item = { name: data.name.value.trim(), description: data.description.value, type: data.type.value };
    if (isEnum) item.members = data.members.map(({ fields }) => {
      if (item.type === 'int' && !fields[1].value.trim()) throw new Error('整数枚举值不能为空');
      return { name: fields[0].value.trim(), value: item.type === 'int' ? Number(fields[1].value) : fields[1].value, description: fields[2].value };
    });
    else { item.value = ['string', 'text'].includes(item.type) ? data.value.value : JSON.parse(data.value.value); if (['enum', 'enum[]'].includes(item.type)) item.enumRef = data.enumRef.value; }
    const next = structuredClone(catalogDraft), collection = next.modules.find(entry => entry.id === module.id)[catalogTab], index = collection.findIndex(entry => entry.name === original?.name);
    if (index < 0) collection.push(item); else collection[index] = item;
    validateCatalog(next); catalogDraft = next; markDirty(); renderCatalog();
  });
}
function renderOverview() {
  $('eyebrow').textContent = 'WORKSPACE / QUICK FIND'; $('title').textContent = '全局总览'; $('description').textContent = '跨模块浏览表、枚举、常量和本地化文本入口';
  const entries = [];
  for (const table of ws.tables) {
    const folder = ws.locations[table.name], module = moduleForFolder(ws.catalog, folder);
    entries.push({ kind: 'table', name: table.name, description: table.description, module: module?.id, folder, detail: table.rows.length + ' 行 · ' + table.fields.length + ' 列 · 主键 ' + table.key, search: table.fields.map(field => field.name + ' ' + (field.description || '')).join(' '), locate: () => openTable(table.name) });
    for (const field of table.fields.filter(field => field.type === 'text')) entries.push({ kind: 'text', name: table.name + '.' + field.name, description: field.description, module: module?.id, folder, detail: '默认文本 · ' + table.rows.length + ' 行', locate: () => openTable(table.name) });
  }
  for (const module of ws.catalog.modules) for (const [collection, kind] of [['enums', 'enum'], ['constants', 'constant']]) {
    for (const item of module[collection]) entries.push({ kind, name: module.id + '.' + item.name, description: item.description, module: module.id, folder: module.folder, detail: kind === 'enum' ? item.members.map(member => member.name + '=' + member.value + ' ' + (member.description || '')).join(' · ') : JSON.stringify(item.value), locate: () => openCatalog(collection, module.id, item.name) });
  }
  $('detail-label').textContent = '可定位条目'; $('detail-count').textContent = entries.length;
  $('overview-rows').replaceChildren();
  const query = $('global-search').value.toLowerCase(), filter = $('kind-filter').value;
  for (const entry of entries.filter(entry => (!filter || filter === entry.kind) && (!query || JSON.stringify(entry).toLowerCase().includes(query)))) {
    const tr = element('tr'), name = element('td'); name.append(element('strong', entry.name), element('small', entry.description || ''));
    tr.append(element('td', { table: '数据表', enum: '枚举', constant: '常量', text: 'text' }[entry.kind]), name, element('td', (entry.module || '未归属模块') + ' · ' + (entry.folder === null ? '未绑定目录' : entry.folder || '/')), element('td', entry.detail));
    const actionCell = element('td'); actionCell.append(button('定位 ↗', entry.locate)); tr.append(actionCell); $('overview-rows').append(tr);
  }
}
action('reload', async () => { if (!discard()) return; await load(); status('工作区已重新加载。'); });
action('save', save);
action('validate', async () => { ensureDraft(); await api('/api/validate', 'POST', { table: draft }); status('校验通过：字段、枚举、公式和跨表引用有效。'); });
action('export', async () => { if (dirty) await save(); const result = await api('/api/export', 'POST', {}); await load(); status('导出成功：' + result.tables + ' 张表，' + result.rows + ' 行，更新 ' + result.written.length + ' 个文件。Language.lua 注释已同步到 LuaTxt.desc。'); });
action('new-table', () => {
  if (!discard()) return;
  dialog('新建数据表', () => ({ name: control('表名', ''), description: control('表描述', ''), folder: control('存储目录', selectedFolder, folderOptions()) }), data => {
    const name = data.name.value.trim();
    if (!/^[A-Za-z][A-Za-z0-9_]*$/.test(name) || ws.tables.some(table => table.name.toLowerCase() === name.toLowerCase())) throw new Error('表名无效或已存在');
    draft = { version: 1, name, description: data.description.value, key: 'id', fields: [{ name: 'id', type: 'int', description: '唯一标识', min: 1 }], rows: [] };
    selected = name; draftFolder = selectedFolder = data.folder.value; view = 'table'; markDirty(); render();
  });
});
action('new-folder', () => {
  if (!discard()) return;
  dialog('新建文件夹', () => ({ folder: control('相对目录路径（可用 / 分层）', selectedFolder ? selectedFolder + '/' : '') }), async data => {
    const folder = data.folder.value.trim(); await api('/api/folders', 'POST', { folder }); selected = null; selectedFolder = folder; await load(); view = 'table'; render();
  });
});
action('folder-rename', () => {
  if (!selectedFolder) throw new Error('根目录不能重命名');
  if (!discard()) return;
  const from = selectedFolder;
  dialog('重命名 / 移动目录', () => ({ to: control('新相对路径', from) }), async data => {
    const to = data.to.value.trim(); await api('/api/folders/move', 'POST', { from, to }); selectedFolder = to; await load(); status('目录已移动，模块 ID 与表名保持稳定。');
  });
});
action('folder-delete', async () => { if (!selectedFolder) throw new Error('根目录不能删除'); if (!discard() || !confirm('删除空目录 ' + selectedFolder + '？')) return; await api('/api/folders', 'DELETE', { folder: selectedFolder }); selected = null; selectedFolder = ''; await load(); });
action('folder-module', () => {
  if (!discard()) return;
  const existing = ws.catalog.modules.find(module => module.folder === selectedFolder);
  view = 'catalog'; catalogTab = 'enums'; render();
  if (existing) { moduleId = existing.id; render(); } else newModule(selectedFolder);
});
action('delete-table', async () => { ensureDraft(); if (!confirm('删除 ' + draft.name + ' 源文件？')) return; if (ws.tables.some(table => table.name === draft.name)) await api('/api/tables/' + draft.name, 'DELETE', {}); selected = null; await load(); });
action('add-column', () => editColumn());
action('add-row', () => {
  ensureDraft(); const row = Object.fromEntries(draft.fields.map(field => [field.name, defaultValue(field, ws.catalog)]));
  const key = draft.fields.find(field => field.name === draft.key);
  if (key?.type === 'int') row[key.name] = draft.rows.reduce((max, value) => Math.max(max, Number(value[key.name]) || 0), 0) + 1;
  draft.rows.push(row); markDirty(); renderTable();
});
action('apply-schema', () => { applySchema(); status('字段定义已应用，请保存。'); });
$('schema').oninput = () => { schemaDirty = true; markDirty(); };
$('search').oninput = renderRows;
$('table-description').oninput = () => { if (draft) { draft.description = $('table-description').value; markDirty(); } };
$('table-key').onchange = () => { if (draft) { draft.key = $('table-key').value; markDirty(); } };
$('folder-select').onchange = () => { selectedFolder = draftFolder = $('folder-select').value; if (draft) markDirty(); renderTree(); };
for (const tab of ['data', 'schema']) action(tab + '-tab', () => { applySchema(); tableTab = tab; renderTable(); });
action('overview-nav', () => { if (!discard()) return; view = 'overview'; render(); });
action('enums-nav', () => openCatalog('enums'));
action('constants-nav', () => openCatalog('constants'));
action('enum-tab', () => { catalogTab = 'enums'; renderCatalog(); });
action('constant-tab', () => { catalogTab = 'constants'; renderCatalog(); });
action('new-module', () => newModule());
action('delete-module', () => { const module = currentModule(); if (!module || !confirm('删除模块 ' + module.id + ' 及其定义？保存时检查引用。目录和表不会删除。')) return; catalogDraft.modules = catalogDraft.modules.filter(item => item !== module); moduleId = catalogDraft.modules[0]?.id; markDirty(); render(); });
action('new-definition', () => editDefinition());
$('module-select').onchange = () => { moduleId = $('module-select').value; renderCatalog(); };
$('module-folder').onchange = () => { currentModule().folder = $('module-folder').value === '@none' ? null : $('module-folder').value; markDirty(); };
$('module-description').oninput = () => { currentModule().description = $('module-description').value; markDirty(); };
$('global-search').oninput = renderOverview; $('kind-filter').onchange = renderOverview;
action('sync-language', async () => { await api('/api/language/sync', 'POST', {}); await load(); status('Language.lua 已同步：新键加入 LuaTxt，行尾注释更新 desc，保留已有 txt 覆盖。'); });
for (const id of ['dialog-close', 'dialog-cancel']) $(id).onclick = () => $('edit-dialog').close();
action('evaluate', () => { const variables = JSON.parse($('variables').value); $('formula-result').textContent = String(evaluateFormula(compileFormula($('formula').value, Object.keys(variables)), variables)); status('公式试算成功。'); });
window.addEventListener('beforeunload', event => { if (dirty) { event.preventDefault(); event.returnValue = ''; } });
load().then(() => status('工作区已就绪。表头支持描述；从字段键名或「添加列」编辑结构。')).catch(error => status(error.message, true));
