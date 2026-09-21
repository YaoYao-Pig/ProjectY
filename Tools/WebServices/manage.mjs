// 命令行与 Editor 共用的服务管理器：按注册表启动、检查身份、凭实例令牌停止。
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { projectRoot, projectId, readRegistry, checkPort, runtimeFile, readRuntime } from './registry.mjs';

const directory = path.dirname(fileURLToPath(import.meta.url));
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
async function probe(root, service, port, retry = true) {
  let response;
  try { response = await fetch(`http://127.0.0.1:${port}/api/web-services/health`, { signal: AbortSignal.timeout(1000), headers: { Connection: 'close' } }); }
  catch (error) {
    if (error.cause?.code === 'ECONNREFUSED') return null;
    // 停止瞬间可能碰到刚关闭的连接；只重试一次，以新连接确认端口是否真正释放。
    if (retry && ['ECONNRESET', 'UND_ERR_SOCKET'].includes(error.cause?.code)) {
      await delay(60); return probe(root, service, port, false);
    }
    throw new Error('无法检查服务：' + (error.cause?.code || error.message));
  }
  const info = await response.json().catch(() => null);
  // 旧版已知服务只允许识别和打开，不伪装成受管实例，也不猜测 PID 进行强制关闭。
  if (response.status === 404 && service.legacyHealth) {
    const legacy = await fetch(`http://127.0.0.1:${port}${service.legacyHealth.path}`, { signal: AbortSignal.timeout(1000), headers: { Connection: 'close' } });
    const previous = await legacy.json().catch(() => null);
    if (legacy.ok && previous?.tool === service.legacyHealth.tool && previous.protocol === service.legacyHealth.protocol) {
      if (previous.projectId !== projectId(root)) throw new Error(`端口 ${port} 的服务属于另一份工程`);
      return { ...previous, legacy: true, serviceId: service.id };
    }
  }
  if (!response.ok || info?.protocol !== 1 || info.serviceId !== service.id || typeof info.instanceId !== 'string')
    throw new Error(`端口 ${port} 已被其他服务或旧版本占用，请先关闭旧服务或调整端口`);
  if (info.projectId !== projectId(root)) throw new Error(`端口 ${port} 的服务属于另一份工程`);
  return info;
}
function settings(id, options) {
  const root = fs.realpathSync(options.root || projectRoot), service = readRegistry(root).find(item => item.id === id);
  if (!service) throw new Error('未注册的 Web 服务：' + id);
  const port = options.port ?? service.port; checkPort(port);
  return { root, service, port, url: 'http://127.0.0.1:' + port,
    filename: runtimeFile(root, id, port, options.runtimeDirectory) };
}
export async function serviceStatus(id, options = {}) {
  const { root, service, port, url, filename } = settings(id, options);
  const base = { id, name: service.name, url, port };
  try {
    const info = await probe(root, service, port);
    if (!info) return { ...base, status: 'stopped', message: '未启动' };
    if (info.legacy) return { ...base, status: 'running', managed: false, legacy: true,
      message: '旧版运行中，可打开；首次需手动关闭旧服务，再从此处启动以启用统一停止' };
    const state = readRuntime(filename), managed = state?.instanceId === info.instanceId;
    return { ...base, status: 'running', pid: info.pid, instanceId: info.instanceId,
      managed, log: managed ? state.log : '', message: managed ? '运行中' : '运行中，但当前用户缺少停止凭证' };
  } catch (error) { return { ...base, status: 'conflict', message: error.message }; }
}
export async function ensureService(id, options = {}) {
  const { root, service, port, url } = settings(id, options);
  if (await probe(root, service, port)) return { ...(await serviceStatus(id, options)), reused: true };
  const log = path.join(os.tmpdir(), `project-y-web-${id}-${crypto.randomUUID()}.log`), descriptor = fs.openSync(log, 'a');
  let child;
  try {
    child = spawn(process.execPath, [path.join(directory, 'host.mjs'), id, String(port)], {
      cwd: root, detached: true, windowsHide: true, stdio: ['ignore', descriptor, descriptor],
      env: { ...process.env, PROJECT_Y_WEB_ROOT: root, PROJECT_Y_WEB_LOG: log,
        ...(options.runtimeDirectory ? { PROJECT_Y_WEB_RUNTIME_DIRECTORY: options.runtimeDirectory } : {}) },
    });
  } finally { fs.closeSync(descriptor); }
  let failure; child.on('error', error => { failure = error; }); child.unref();
  const deadline = Date.now() + (options.timeoutMs ?? 10000);
  try {
    while (Date.now() < deadline) {
      // 并发启动时以端口上的实例为准；只有一个宿主能成功监听，其他启动请求复用它。
      const info = await probe(root, service, port);
      if (info) return { ...(await serviceStatus(id, options)), reused: info.pid !== child.pid, log: info.pid === child.pid ? log : undefined };
      if (failure) throw failure;
      if (child.exitCode !== null) throw new Error('服务启动后退出');
      await delay(120);
    }
    throw new Error('服务启动超时');
  } catch (error) {
    // 启动失败只清理本次创建的子进程，绝不按端口或进程名批量终止。
    if (child.pid && child.exitCode === null) child.kill();
    const detail = fs.readFileSync(log, 'utf8').trim();
    throw new Error(error.message + '\n日志：' + log + (detail ? '\n' + detail.slice(-2500) : ''));
  }
}
export async function stopService(id, options = {}) {
  const { root, service, port, url, filename } = settings(id, options);
  const info = await probe(root, service, port);
  if (!info) return serviceStatus(id, options);
  if (info.legacy) throw new Error(service.name + '是旧版服务，不支持统一停止；请先手动关闭旧服务，再从 Editor 启动一次');
  const state = readRuntime(filename);
  if (!state || state.instanceId !== info.instanceId || state.projectId !== info.projectId)
    throw new Error('缺少当前服务的停止凭证，未执行停止');
  const response = await fetch(url + '/api/web-services/stop', { method: 'POST', signal: AbortSignal.timeout(2000),
    headers: { Connection: 'close', 'X-Project-Y-Service-Token': state.token, 'X-Project-Y-Service-Instance': info.instanceId } });
  if (response.status !== 202) throw new Error('服务拒绝停止请求：' + response.status);
  const deadline = Date.now() + (options.stopTimeoutMs ?? 35000);
  while (Date.now() < deadline) {
    const current = await probe(root, service, port);
    // 端口关闭后仍可能在完成已提交请求；宿主移除本实例记录才表示排空结束。
    if (!current && readRuntime(filename)?.instanceId !== info.instanceId)
      return { id, name: service.name, port, url, status: 'stopped', message: '已停止' };
    if (current && current.instanceId !== info.instanceId) throw new Error('旧实例已停止，但端口上出现了新实例；未继续停止新服务');
    await delay(120);
  }
  throw new Error('服务正在等待现有请求结束，停止超时；没有强制终止进程');
}
export async function manageServices(action, target = 'all', options = {}) {
  if (!['start', 'stop', 'status'].includes(action)) throw new Error('操作应为 start、stop 或 status');
  const registry = readRegistry(options.root || projectRoot), selected = target === 'all' ? registry : registry.filter(item => item.id === target);
  if (!selected.length) throw new Error('未注册的 Web 服务：' + target);
  // 一个服务失败仍处理其余注册项，结果逐项返回，避免部分成功被整体错误遮住。
  const services = await Promise.all(selected.map(async service => {
    try { return await ({ start: ensureService, stop: stopService, status: serviceStatus })[action](service.id, options); }
    catch (error) { return { id: service.id, name: service.name, status: 'error', message: error.message }; }
  }));
  return { ok: !services.some(item => item.status === 'error' || (action !== 'status' && item.status === 'conflict')), services };
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  manageServices(process.argv[2] || 'status', process.argv[3] || 'all').then(result => {
    console.log(JSON.stringify(result)); if (!result.ok) process.exitCode = 1;
  }).catch(error => { console.error(error.message); process.exitCode = 1; });
}
