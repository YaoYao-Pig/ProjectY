// 只在临时端口检查生命周期；不终止正在使用的配表/预览服务，不修改工程配表。
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import http from 'node:http';
import { spawn } from 'node:child_process';
import { ensureService, stopService, serviceStatus, manageServices } from '../manage.mjs';
import { projectRoot, runtimeFile, readRuntime, projectId } from '../registry.mjs';

const listen = server => new Promise(resolve => server.listen(0, '127.0.0.1', () => resolve(server.address().port)));
const close = server => new Promise(resolve => server.close(resolve));
async function freePort() { const server = http.createServer(); const port = await listen(server); await close(server); return port; }

test('原命令行入口也会登记服务并接受统一停止', { timeout: 15000 }, async t => {
  for (const [id, module, variable] of [['config-editor', 'ConfigEditor', 'PORT'], ['map-preview', 'MapPreview', 'MAP_PREVIEW_PORT']]) {
    const port = await freePort();
    const child = spawn(process.execPath, [path.join(projectRoot, 'Tools', module, 'server.mjs')], {
      cwd: projectRoot, windowsHide: true, stdio: 'ignore', env: { ...process.env, [variable]: String(port) },
    });
    let failure; child.on('error', error => { failure = error; });
    t.after(async () => { await stopService(id, { port }); if (child.exitCode === null) child.kill(); });
    let status; const deadline = Date.now() + 5000;
    do {
      if (failure) throw failure;
      status = await serviceStatus(id, { port });
      if (status.status === 'running') break;
      await new Promise(resolve => setTimeout(resolve, 80));
    } while (Date.now() < deadline);
    assert.equal(status.status, 'running'); assert.equal(status.managed, true); assert.equal(status.pid, child.pid);
    assert.equal((await stopService(id, { port })).status, 'stopped');
  }
});

test('注册服务可启动、复用、打开实际页面并凭实例令牌停止，重复停止无副作用', { timeout: 20000 }, async t => {
  for (const id of ['config-editor', 'map-preview']) {
    const port = await freePort(), options = { port };
    let result;
    t.after(async () => { await stopService(id, options); if (result?.log) fs.rmSync(result.log, { force: true }); });
    assert.equal((await serviceStatus(id, options)).status, 'stopped');
    result = await ensureService(id, options);
    assert.equal(result.reused, false); assert.ok(result.managed && result.pid);
    assert.equal((await fetch(result.url)).status, 200);
    if (id === 'config-editor') assert.ok((await (await fetch(result.url + '/api/tables')).json()).tables.length);
    const reused = await ensureService(id, options);
    assert.equal(reused.reused, true); assert.equal(reused.instanceId, result.instanceId);
    // 网页 token、错误令牌或旧实例标识均不能停止当前服务。
    assert.equal((await fetch(result.url + '/api/web-services/stop', { method: 'POST' })).status, 403);
    const state = readRuntime(runtimeFile(projectRoot, id, port));
    const headers = { 'X-Project-Y-Service-Token': state.token, 'X-Project-Y-Service-Instance': 'old-instance' };
    assert.equal((await fetch(result.url + '/api/web-services/stop', { method: 'POST', headers })).status, 403);
    headers['X-Project-Y-Service-Instance'] = result.instanceId;
    assert.equal((await fetch(result.url + '/api/web-services/stop', { method: 'POST', headers: { ...headers, Origin: 'https://example.com' } })).status, 403);
    assert.equal((await serviceStatus(id, options)).status, 'running');
    assert.equal((await stopService(id, options)).status, 'stopped');
    assert.equal((await stopService(id, options)).status, 'stopped');
  }
});

test('并发启动同一注册项只保留一个实例', { timeout: 15000 }, async t => {
  const port = await freePort(), options = { port };
  t.after(async () => { await stopService('config-editor', options); });
  const results = await Promise.all([ensureService('config-editor', options), ensureService('config-editor', options)]);
  assert.equal(results[0].instanceId, results[1].instanceId); assert.equal(results[0].pid, results[1].pid);
  for (const result of results) if (result.log) t.after(() => fs.rmSync(result.log, { force: true }));
});

test('端口冲突、不同工程和失效凭证不会停止其他进程', async t => {
  let info = { tool: 'unrelated-tool' };
  const server = http.createServer((request, response) => { response.setHeader('Content-Type', 'application/json'); response.end(JSON.stringify(info)); });
  const port = await listen(server); t.after(() => close(server));
  for (const action of [ensureService, stopService]) await assert.rejects(action('config-editor', { port }), /其他服务或旧版本/);
  info = { protocol: 1, serviceId: 'config-editor', instanceId: 'other', projectId: 'other-project' };
  await assert.rejects(stopService('config-editor', { port }), /另一份工程/);
  info.projectId = projectId(projectRoot);
  await assert.rejects(stopService('config-editor', { port }), /凭证/);
  assert.equal((await fetch('http://127.0.0.1:' + port)).status, 200);
  await assert.rejects(manageServices('start', 'not-registered'), /未注册/);
});

test('全部操作从注册表读取服务，单项失败仍返回其余结果', { timeout: 15000 }, async t => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'project-y-web-registry-test-'));
  fs.mkdirSync(path.join(root, 'Tools/WebServices'), { recursive: true });
  fs.writeFileSync(path.join(root, 'fixture.mjs'), "import http from 'node:http'; export function create() { return http.createServer((q,s)=> { if(q.url === '/slow') { s.writeHead(200);s.flushHeaders();setTimeout(()=>s.end('saved'),250); } else s.end('ok'); }); }\n");
  const port = await freePort(), blocker = http.createServer((q, s) => s.end('unrelated')), blockedPort = await listen(blocker);
  fs.writeFileSync(path.join(root, 'Tools/WebServices/services.json'), JSON.stringify({ version: 1, services: [
    { id: 'alpha', name: '测试服务', module: 'fixture.mjs', factory: 'create', port, portEnvironment: 'PROJECT_Y_WEB_TEST_ALPHA_PORT' },
    { id: 'blocked', name: '被占用服务', module: 'fixture.mjs', factory: 'create', port: blockedPort, portEnvironment: 'PROJECT_Y_WEB_TEST_BLOCKED_PORT' },
  ] }));
  t.after(async () => {
    await stopService('alpha', { root }); await close(blocker);
    assert.equal(path.dirname(path.resolve(root)), path.resolve(os.tmpdir()));
    assert.ok(path.basename(root).startsWith('project-y-web-registry-test-'));
    // Windows 退出进程释放工作目录句柄可能稍晚于 close 通知，只对本测试目录做有限重试。
    fs.rmSync(root, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
  });
  const result = await manageServices('start', 'all', { root });
  assert.equal(result.ok, false); assert.equal(result.services[0].status, 'running'); assert.equal(result.services[1].status, 'error');
  t.after(() => { if (result.services[0].log) fs.rmSync(result.services[0].log, { force: true }); });
  // 停止应排空正在处理的请求，不能在保存或生成尚未完成时强制结束进程。
  const pending = await fetch(result.services[0].url + '/slow');
  const stopping = manageServices('stop', 'alpha', { root });
  assert.equal(await pending.text(), 'saved');
  assert.equal((await stopping).services[0].status, 'stopped');
});

test('旧版同工程地图仍能打开，但不会被误认作可自动停止的实例', async t => {
  const server = http.createServer((request, response) => {
    response.setHeader('Content-Type', 'application/json');
    if (request.url === '/api/health') response.end(JSON.stringify({ tool: 'project-y-map-preview', protocol: 1, projectId: projectId(projectRoot) }));
    else { response.writeHead(404); response.end('{}'); }
  });
  const port = await listen(server); t.after(() => close(server));
  const result = await ensureService('map-preview', { port });
  assert.equal(result.status, 'running'); assert.equal(result.reused, true); assert.equal(result.managed, false);
  await assert.rejects(stopService('map-preview', { port }), /旧版服务/);
  assert.equal((await fetch(result.url + '/api/health')).status, 200);
});
