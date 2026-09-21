// 注册表是 Editor 和命令行的共同入口；运行状态保存在当前用户的临时目录中。
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

export const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
export function projectId(root) {
  const resolved = fs.realpathSync(root);
  return crypto.createHash('sha256').update(process.platform === 'win32' ? resolved.toLowerCase() : resolved).digest('hex');
}
export function readRegistry(root = projectRoot) {
  const registry = JSON.parse(fs.readFileSync(path.join(root, 'Tools/WebServices/services.json'), 'utf8'));
  if (registry.version !== 1 || !Array.isArray(registry.services) || !registry.services.length) throw new Error('Web 服务注册表格式无效');
  const ids = new Set();
  return registry.services.map(service => {
    if (!/^[a-z][a-z0-9-]*$/.test(service.id) || ids.has(service.id)) throw new Error('Web 服务 ID 无效或重复');
    ids.add(service.id);
    const module = path.resolve(root, service.module), relative = path.relative(root, module);
    if (!relative || relative.startsWith('..') || path.isAbsolute(relative) || !fs.statSync(module).isFile()) throw new Error('Web 服务模块必须位于工程内');
    if (typeof service.name !== 'string' || !service.name || !/^[A-Za-z][A-Za-z0-9_]*$/.test(service.factory)
      || !/^[A-Z][A-Z0-9_]*$/.test(service.portEnvironment)) throw new Error('Web 服务注册项缺少名称、工厂函数或端口变量');
    if (service.legacyHealth && (!/^\/api\/[a-z/-]+$/.test(service.legacyHealth.path)
      || typeof service.legacyHealth.tool !== 'string' || !Number.isInteger(service.legacyHealth.protocol))) throw new Error('旧版服务身份检查配置无效');
    const port = Number(process.env[service.portEnvironment] || service.port);
    checkPort(port);
    return { ...service, module, port };
  });
}
export function checkPort(port) {
  if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error('Web 服务端口必须为 1–65535 的整数');
}
export function runtimeFile(root, service, port, runtimeDirectory) {
  checkPort(port);
  if (!/^[a-z][a-z0-9-]*$/.test(service)) throw new Error('无效的服务 ID');
  const directory = runtimeDirectory || process.env.PROJECT_Y_WEB_RUNTIME_DIRECTORY || path.join(os.tmpdir(), 'project-y-web-services');
  return path.join(directory, `${projectId(root)}-${service}-${port}.json`);
}
export function readRuntime(filename) {
  try { return JSON.parse(fs.readFileSync(filename, 'utf8')); }
  catch (error) { if (error.code === 'ENOENT') return null; throw error; }
}
