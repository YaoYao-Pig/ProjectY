// 保留地图原有启动命令，生命周期委托统一 Web 服务管理器。
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { ensureService } from '../WebServices/manage.mjs';

export async function ensurePreview(options = {}) {
  const result = await ensureService('map-preview', options);
  return { url: result.url, reused: result.reused,
    ...(result.reused ? {} : { pid: result.pid, log: result.log }) };
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  ensurePreview().then(result => console.log(JSON.stringify(result))).catch(error => {
    console.error(error.message); process.exitCode = 1;
  });
}
