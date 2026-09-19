import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { projectRoot, validateTables, exportTables } from './exporter.mjs';
import { validateCatalog, validateFolder } from './definitions.mjs';
import { readCatalog, scanSources, tableDirectory, atomicJson } from './workspace.mjs';
import { languageSource, parseLanguage, mergeLanguage } from './language.mjs';

const toolDirectory = path.dirname(fileURLToPath(import.meta.url));
export function createEditorServer({ root = projectRoot } = {}) {
  const token = crypto.randomBytes(32).toString('hex');
  const directory = tableDirectory(root);
  function state() {
    const { entries, folders } = scanSources(directory), catalog = readCatalog(root);
    return { tables: entries.map(entry => entry.table).sort((a, b) => a.name.localeCompare(b.name, 'en')), locations: Object.fromEntries(entries.map(entry => [entry.table.name, entry.folder])), folders, catalog };
  }
  const revision = () => crypto.createHash('sha256').update(JSON.stringify(state())).update(languageSource(root)).digest('hex');
  function send(response, status, data, type = 'application/json; charset=utf-8') {
    response.writeHead(status, { 'Content-Type': type, 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff',
      'Content-Security-Policy': "default-src 'self'; style-src 'self'; script-src 'self'; frame-ancestors 'none'; base-uri 'none'" });
    response.end(type.startsWith('application/json') ? JSON.stringify(data) : data);
  }
  async function body(request) {
    if (!request.headers['content-type']?.startsWith('application/json')) throw new Error('Expected application/json');
    let size = 0; const chunks = [];
    for await (const chunk of request) { size += chunk.length; if (size > 2 * 1024 * 1024) throw new Error('Request exceeds 2 MiB'); chunks.push(chunk); }
    return JSON.parse(Buffer.concat(chunks).toString('utf8'));
  }
  function checkedFolder(folder, folders, mustExist = true) {
    validateFolder(folder);
    if (mustExist && !folders.includes(folder)) throw new Error('Unknown folder: ' + folder);
    if (folders.some(item => item !== folder && item.toLowerCase() === folder.toLowerCase())) throw new Error('Case-colliding folder');
    for (const existing of folders) if (folder.toLowerCase().startsWith(existing.toLowerCase() + '/') && !folder.startsWith(existing + '/')) throw new Error('Case-colliding parent folder');
    return tableDirectory(root, folder);
  }
  return http.createServer(async (request, response) => {
    try {
      const expectedHost = '127.0.0.1:' + request.socket.localPort;
      if (request.headers.host !== expectedHost) return send(response, 403, { error: 'Use the displayed 127.0.0.1 URL' });
      if (request.headers.origin && request.headers.origin !== 'http://' + expectedHost) return send(response, 403, { error: 'Cross-origin request rejected' });
      const pathname = new URL(request.url, 'http://' + expectedHost).pathname;
      if (request.method === 'GET') {
        if (pathname === '/api/tables') return send(response, 200, { ...state(), revision: revision(), token });
        if (pathname === '/api/language') return send(response, 200, { rows: parseLanguage(languageSource(root)), file: 'Lua/Language.lua' });
        const assets = { '/': ['public/index.html', 'text/html'], '/app.js': ['public/app.js', 'text/javascript'], '/styles.css': ['public/styles.css', 'text/css'], '/formula.mjs': ['formula.mjs', 'text/javascript'], '/definitions.mjs': ['definitions.mjs', 'text/javascript'] };
        if (assets[pathname]) {
          const [file, type] = assets[pathname]; return send(response, 200, fs.readFileSync(path.join(toolDirectory, file)), type + '; charset=utf-8');
        }
        return send(response, 404, { error: 'Not found' });
      }
      if (request.headers['x-editor-token'] !== token) return send(response, 403, { error: 'Editor token required; refresh the page' });
      const input = await body(request);
      if (input.revision !== revision()) return send(response, 409, { error: '工作区或 Language.lua 已变更，请先重新加载（409）。' });
      const workspace = state();
      if (pathname === '/api/export' && request.method === 'POST') return send(response, 200, { ...exportTables({ root }), revision: revision() });
      if (pathname === '/api/validate' && request.method === 'POST') {
        validateTables(workspace.tables.filter(table => table.name !== input.table.name).concat(input.table), workspace.catalog);
        return send(response, 200, { valid: true });
      }
      if (pathname === '/api/catalog' && request.method === 'PUT') {
        const catalog = validateCatalog(input.catalog);
        for (const module of catalog.modules) if (module.folder !== null) checkedFolder(module.folder, workspace.folders);
        validateTables(workspace.tables, catalog);
        atomicJson(path.join(root, 'Config/Catalog.json'), catalog);
        return send(response, 200, { revision: revision() });
      }
      if (pathname === '/api/folders' && request.method === 'POST') {
        if (!input.folder) throw new Error('Folder name is required');
        const destination = checkedFolder(input.folder, workspace.folders, false);
        if (fs.existsSync(destination)) throw new Error('Folder already exists');
        fs.mkdirSync(destination, { recursive: true });
        return send(response, 200, { revision: revision() });
      }
      if (pathname === '/api/folders' && request.method === 'DELETE') {
        if (!input.folder) throw new Error('Cannot remove source root');
        if (workspace.catalog.modules.some(module => module.folder === input.folder)) throw new Error('请先取消该目录的模块根节点标记');
        fs.rmdirSync(checkedFolder(input.folder, workspace.folders));
        return send(response, 200, { revision: revision() });
      }
      if (pathname === '/api/folders/move' && request.method === 'POST') {
        if (!input.from || !input.to || input.to.startsWith(input.from + '/')) throw new Error('Invalid folder move');
        const source = checkedFolder(input.from, workspace.folders), destination = checkedFolder(input.to, workspace.folders, false);
        if (fs.existsSync(destination)) throw new Error('Destination already exists');
        const catalog = workspace.catalog;
        for (const module of catalog.modules) if (module.folder === input.from || module.folder?.startsWith(input.from + '/')) module.folder = input.to + module.folder.slice(input.from.length);
        fs.mkdirSync(path.dirname(destination), { recursive: true }); fs.renameSync(source, destination);
        try { atomicJson(path.join(root, 'Config/Catalog.json'), catalog); }
        catch (error) { fs.renameSync(destination, source); throw error; }
        return send(response, 200, { revision: revision() });
      }
      if (pathname === '/api/language/sync' && request.method === 'POST') {
        const merged = mergeLanguage(workspace.tables, languageSource(root));
        validateTables(merged.tables, workspace.catalog);
        if (merged.changed) atomicJson(path.join(tableDirectory(root, workspace.locations.LuaTxt ?? 'Localization'), 'LuaTxt.json'), merged.table);
        return send(response, 200, { revision: revision(), changed: merged.changed });
      }
      const match = /^\/api\/tables\/([A-Za-z][A-Za-z0-9_]*)$/.exec(pathname);
      if (!match) return send(response, 404, { error: 'Unknown endpoint' });
      const name = match[1], existing = workspace.tables.find(table => table.name === name);
      if (request.method === 'PUT') {
        if (input.table?.name !== name) throw new Error('File name must match table name');
        validateTables(workspace.tables.filter(table => table.name !== name).concat(input.table), workspace.catalog);
        const folder = input.folder ?? workspace.locations[name] ?? '';
        const filename = path.join(checkedFolder(folder, workspace.folders), name + '.json');
        const oldFile = existing && path.join(tableDirectory(root, workspace.locations[name]), name + '.json');
        atomicJson(filename, input.table);
        if (oldFile && oldFile !== filename) fs.unlinkSync(oldFile);
        return send(response, 200, { revision: revision() });
      }
      if (request.method === 'DELETE') {
        if (!existing) return send(response, 404, { error: 'Unknown table' });
        validateTables(workspace.tables.filter(table => table.name !== name), workspace.catalog);
        fs.unlinkSync(path.join(tableDirectory(root, workspace.locations[name]), name + '.json'));
        return send(response, 200, { revision: revision() });
      }
      return send(response, 405, { error: 'Unsupported method' });
    } catch (error) { if (!response.headersSent) send(response, 400, { error: error.message }); }
  });
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const port = Number(process.env.PORT || 4173);
  const server = createEditorServer();
  server.listen(port, '127.0.0.1', () => console.log('Config editor: http://127.0.0.1:' + server.address().port));
  server.on('error', error => { console.error(error.message); process.exitCode = 1; });
}
