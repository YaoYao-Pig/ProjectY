// 本机预览服务：捕获工程文件、调用真实导表与 xLua，再把只读结果交给网页。
import http from 'node:http';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { projectRoot, readSources, exportTables, validateTables } from '../ConfigEditor/exporter.mjs';
import { readCatalog } from '../ConfigEditor/workspace.mjs';

const directory = path.dirname(fileURLToPath(import.meta.url));
// 启动器用工程路径摘要区分不同检出目录，避免打开另一份工程的预览。
export function previewIdentity(root) {
  const resolved = fs.realpathSync(root);
  return { tool: 'project-y-map-preview', protocol: 1,
    projectId: crypto.createHash('sha256').update(process.platform === 'win32' ? resolved.toLowerCase() : resolved).digest('hex') };
}
// 排除导表的 _Gen 与迁移前的 Generated 文件；本次所有 require 使用同一批源文件和重新导出的 schema。
function capture(root) {
  const inputs = readSources(path.join(root, 'Config/Tables')), catalog = readCatalog(root), lua = new Map();
  function visit(relative) {
    for (const entry of fs.readdirSync(path.join(root, relative), { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name, 'en'))) {
      if (relative === 'Lua' && ['_Gen', 'Generated'].includes(entry.name)) continue;
      const name = relative + '/' + entry.name;
      if (entry.isDirectory()) visit(name);
      else if (entry.isFile() && entry.name.endsWith('.lua')) lua.set(name, fs.readFileSync(path.join(root, name)));
    }
  }
  visit('Lua');
  const hash = crypto.createHash('sha256').update(JSON.stringify({ inputs, catalog }));
  for (const [name, bytes] of lua) hash.update(name).update('\0').update(bytes).update('\0');
  return { inputs, catalog, lua, revision: hash.digest('hex') };
}
// 选择器和参数摘要直接来自工程配表，不另维护一份地图配置。
function metadata(snapshot) {
  const tables = validateTables(snapshot.inputs, snapshot.catalog);
  const regions = tables.find(table => table.name === 'MapRegionTable');
  const module = snapshot.catalog.modules.find(item => item.id === 'Map');
  if (!regions || !module) throw new Error('Project map configuration is missing');
  return { revision: snapshot.revision, regions: regions.rows,
    regionTypes: module.enums.find(item => item.name === 'E_MapRegion').members,
    constants: Object.fromEntries(module.constants.map(item => [item.name, item.value])) };
}
export function validateRequest(input) {
  if (!Number.isInteger(input?.seed) || input.seed < 0 || input.seed > 0xffffffff) throw new Error('种子必须为 0–4294967295 的整数');
  if (!Array.isArray(input.regionIds) || !input.regionIds.length || input.regionIds.length > 65536 || input.regionIds.some(id => !Number.isInteger(id) || id < 1 || id > 2147483647))
    throw new Error('配方需要 1–65536 个有效的正整数配置 ID');
  if (input.targetCells !== undefined && (!Number.isInteger(input.targetCells) || input.targetCells < 1 || input.targetCells > 100000))
    throw new Error('目标格数必须为 1–100000 的整数，且不能超过配表 MaxCells');
  return { seed: input.seed, regionIds: input.regionIds, ...(input.targetCells === undefined ? {} : { targetCells: input.targetCells }) };
}
// 一次生成独占一个 Lua 状态，限制耗时和输出体积，失败时保留真实错误。
function runWorker(snapshotDirectory, input, root, python, timeoutMs) {
  return new Promise((resolve, reject) => {
    const child = spawn(python, ['-B', path.join(directory, 'worker.py'), snapshotDirectory], {
      cwd: root, windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'], env: { ...process.env, PYTHONIOENCODING: 'utf-8' },
    });
    const stdout = [], stderr = []; let size = 0, failure;
    const timer = setTimeout(() => { failure = new Error(`地图生成超过 ${timeoutMs / 1000} 秒，已终止本次任务`); child.kill(); }, timeoutMs);
    child.on('error', error => { clearTimeout(timer); reject(new Error('无法运行 Python/xLua：' + error.message)); });
    child.stdout.on('data', chunk => {
      size += chunk.length;
      if (size > 256 * 1024 * 1024) { failure = new Error('预览数据超过 256 MiB'); child.kill(); }
      else stdout.push(chunk);
    });
    child.stderr.on('data', chunk => { if (stderr.reduce((sum, item) => sum + item.length, 0) < 65536) stderr.push(chunk); });
    child.stdin.on('error', error => { if (error.code !== 'EPIPE') { failure = error; child.kill(); } });
    child.on('close', code => {
      clearTimeout(timer);
      if (failure) return reject(failure);
      if (code !== 0) return reject(new Error(Buffer.concat(stderr).toString('utf8').trim() || 'xLua worker exited with code ' + code));
      try { resolve(JSON.parse(Buffer.concat(stdout).toString('utf8'))); } catch { reject(new Error('xLua 未返回完整的预览 JSON')); }
    });
    child.stdin.end(JSON.stringify(input));
  });
}
export async function generatePreview(input, { root = projectRoot, python = process.env.PROJECT_Y_PYTHON || 'python', timeoutMs = 180000 } = {}) {
  input = validateRequest(input);
  const started = performance.now(), snapshot = capture(root);
  const tempRoot = path.resolve(os.tmpdir()), temporary = fs.mkdtempSync(path.join(tempRoot, 'project-y-map-preview-'));
  try {
    // 先写入捕获的源码，保证整个 worker 使用同一份已捕获内容。
    for (const [name, bytes] of snapshot.lua) {
      const destination = path.join(temporary, name); fs.mkdirSync(path.dirname(destination), { recursive: true }); fs.writeFileSync(destination, bytes);
    }
    // 复用 Unity 的导出器、schema、二进制格式与 ConfigSystem，仅在临时目录输出。
    exportTables({ root: temporary, inputs: snapshot.inputs, catalog: snapshot.catalog });
    const output = await runWorker(temporary, input, root, python, timeoutMs);
    return { ...output, sourceRevision: snapshot.revision, elapsedMs: Math.round(performance.now() - started), generatedAt: new Date().toISOString() };
  } finally {
    const target = path.resolve(temporary);
    if (path.dirname(target) !== tempRoot || !path.basename(target).startsWith('project-y-map-preview-')) throw new Error('Refusing to clean an unexpected snapshot path');
    fs.rmSync(target, { recursive: true, force: true });
  }
}
export function createPreviewServer({ root = projectRoot, python = process.env.PROJECT_Y_PYTHON || 'python' } = {}) {
  const identity = previewIdentity(root);
  const token = crypto.randomBytes(32).toString('hex'); let busy = false;
  const assets = { '/': ['index.html', 'text/html'], '/app.js': ['app.js', 'text/javascript'],
    '/renderer.js': ['renderer.js', 'text/javascript'], '/styles.css': ['styles.css', 'text/css'] };
  function send(response, status, data, type = 'application/json') {
    response.writeHead(status, { 'Content-Type': type + '; charset=utf-8', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff',
      'Content-Security-Policy': "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' blob: data:; frame-ancestors 'none'; base-uri 'none'" });
    response.end(type === 'application/json' ? JSON.stringify(data) : data);
  }
  return http.createServer(async (request, response) => {
    try {
      const host = '127.0.0.1:' + request.socket.localPort;
      if (request.headers.host !== host || (request.headers.origin && request.headers.origin !== 'http://' + host)) return send(response, 403, { error: '请使用本机 127.0.0.1 地址' });
      const pathname = new URL(request.url, 'http://' + host).pathname;
      if (request.method === 'GET') {
        if (pathname === '/api/health') return send(response, 200, identity);
        if (pathname === '/api/config') return send(response, 200, { ...metadata(capture(root)), token });
        if (assets[pathname]) { const [name, type] = assets[pathname]; return send(response, 200, fs.readFileSync(path.join(directory, 'public', name)), type); }
        return send(response, 404, { error: 'Not found' });
      }
      if (request.method !== 'POST' || pathname !== '/api/generate') return send(response, 404, { error: 'Not found' });
      if (request.headers['x-preview-token'] !== token) return send(response, 403, { error: '请刷新页面以获取预览会话' });
      if (busy) return send(response, 429, { error: '已有生成任务运行中，请稍后重试' });
      if (!request.headers['content-type']?.startsWith('application/json')) return send(response, 400, { error: 'Expected application/json' });
      let size = 0; const chunks = [];
      for await (const chunk of request) { size += chunk.length; if (size > 1024 * 1024) throw new Error('请求超过 1 MiB'); chunks.push(chunk); }
      const input = validateRequest(JSON.parse(Buffer.concat(chunks).toString('utf8')));
      if (busy) return send(response, 429, { error: '已有生成任务运行中，请稍后重试' });
      busy = true;
      try { send(response, 200, await generatePreview(input, { root, python })); }
      finally { busy = false; }
    } catch (error) { if (!response.headersSent) send(response, 400, { error: error.message }); }
  });
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  // 保留原命令行入口，服务的登记和停止统一交给 WebServices 宿主。
  import('../WebServices/host.mjs').then(({ startServiceHost }) => startServiceHost('map-preview', { root: process.env.MAP_PREVIEW_ROOT || projectRoot }))
    .catch(error => { console.error(error.message); process.exitCode = 1; });
}
