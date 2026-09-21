// 承载注册服务的生命周期：健康检查、带实例凭证的停止、当前工程运行记录。
// 业务 HTTP 工厂仍归各工具；管理接口不修改业务数据，也不依赖 PID 查杀。
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { projectRoot, projectId, readRegistry, checkPort, runtimeFile, readRuntime } from './registry.mjs';

export async function startServiceHost(id, { root = projectRoot, port, runtimeDirectory = process.env.PROJECT_Y_WEB_RUNTIME_DIRECTORY, log = process.env.PROJECT_Y_WEB_LOG || '' } = {}) {
  root = fs.realpathSync(root);
  const service = readRegistry(root).find(item => item.id === id);
  if (!service) throw new Error('未注册的 Web 服务：' + id);
  port ??= service.port; checkPort(port);
  const module = await import(pathToFileURL(service.module));
  if (typeof module[service.factory] !== 'function') throw new Error('服务工厂不存在：' + service.factory);
  const server = module[service.factory]({ root });
  const handlers = server.listeners('request');
  if (handlers.length !== 1) throw new Error('Web 服务工厂必须提供一个 HTTP 请求处理器');
  server.removeAllListeners('request');
  const token = crypto.randomBytes(32).toString('hex'), instanceId = crypto.randomUUID();
  const identity = { protocol: 1, serviceId: id, projectId: projectId(root), instanceId, pid: process.pid };
  const filename = runtimeFile(root, id, port, runtimeDirectory);
  let stopping = false;
  const send = (response, status, body) => {
    response.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
    response.end(JSON.stringify(body));
  };
  const stop = () => {
    if (stopping) return;
    stopping = true;
    // 等待已经提交的保存/生成完成，停止接受新连接；空闲浏览器连接立即释放。
    server.close(); server.closeIdleConnections();
  };
  server.on('request', (request, response) => {
    const endpoint = request.url.split('?')[0];
    if (endpoint !== '/api/web-services/health' && endpoint !== '/api/web-services/stop') return handlers[0].call(server, request, response);
    const host = '127.0.0.1:' + port;
    if (request.headers.host !== host || (request.headers.origin && request.headers.origin !== 'http://' + host)) return send(response, 403, { error: '管理接口仅允许当前本机地址' });
    if (endpoint.endsWith('/health') && request.method === 'GET') return send(response, 200, identity);
    if (endpoint.endsWith('/stop') && request.method === 'POST') {
      if (request.headers['x-project-y-service-token'] !== token || request.headers['x-project-y-service-instance'] !== instanceId)
        return send(response, 403, { error: '服务实例凭证不匹配' });
      response.once('finish', stop); return send(response, 202, { stopping: true, instanceId });
    }
    send(response, 405, { error: '不支持的管理操作' });
  });
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(port, '127.0.0.1', () => { server.off('error', reject); resolve(); });
  });
  try {
    fs.mkdirSync(path.dirname(filename), { recursive: true });
    fs.writeFileSync(filename, JSON.stringify({ ...identity, token, port, url: 'http://127.0.0.1:' + port, log }), { mode: 0o600 });
  } catch (error) { server.close(); throw error; }
  server.once('close', () => {
    // 只有当前实例能删除自己的记录，避免误删新启动服务的凭证。
    if (readRuntime(filename)?.instanceId === instanceId) fs.unlinkSync(filename);
    process.off('SIGINT', stop); process.off('SIGTERM', stop);
  });
  process.once('SIGINT', stop); process.once('SIGTERM', stop);
  console.log(`${service.name}：http://127.0.0.1:${port}`);
  return server;
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  startServiceHost(process.argv[2], { root: process.env.PROJECT_Y_WEB_ROOT || projectRoot, port: Number(process.argv[3]) })
    .catch(error => { console.error(error.message); process.exitCode = 1; });
}
