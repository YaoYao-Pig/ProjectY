// 验证 Editor 使用的同一启动器：首次启动、复用、端口冲突和工程身份检查。
import test from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import fs from 'node:fs';
import { ensurePreview } from '../launch.mjs';
import { previewIdentity } from '../server.mjs';
import { projectRoot } from '../../ConfigEditor/exporter.mjs';
import { stopService } from '../../WebServices/manage.mjs';

const listen = server => new Promise(resolve => server.listen(0, '127.0.0.1', () => resolve(server.address().port)));
const close = server => new Promise(resolve => server.close(resolve));

test('启动服务并复用当前工程，重复打开不再创建进程', { timeout: 15000 }, async t => {
  const reservation = http.createServer(), port = await listen(reservation);
  await close(reservation);
  const first = await ensurePreview({ port });
  t.after(async () => {
    // 只清理本测试创建的服务和日志，不按端口查杀已有服务。
    await stopService('map-preview', { port });
    fs.unlinkSync(first.log);
  });
  assert.equal(first.reused, false); assert.ok(first.pid);
  assert.deepEqual(await (await fetch(first.url + '/api/health')).json(), previewIdentity(projectRoot));
  const second = await ensurePreview({ port });
  assert.equal(second.reused, true); assert.equal(second.url, first.url); assert.equal(second.pid, undefined);
});

test('拒绝占用端口的其他服务、另一工程以及非法端口', async t => {
  let info = { tool: 'another-tool' };
  const server = http.createServer((request, response) => {
    response.setHeader('Content-Type', 'application/json'); response.end(JSON.stringify(info));
  });
  const port = await listen(server); t.after(() => close(server));
  await assert.rejects(ensurePreview({ port }), /其他服务或旧版本/);
  info = { protocol: 1, serviceId: 'map-preview', instanceId: 'test-instance', projectId: 'another-project' };
  await assert.rejects(ensurePreview({ port }), /另一份工程/);
  for (const value of [0, -1, 65536, 1.5, NaN]) await assert.rejects(ensurePreview({ port: value }), /端口/);
  assert.equal((await fetch('http://127.0.0.1:' + port)).status, 200, '冲突服务应继续运行');
});
