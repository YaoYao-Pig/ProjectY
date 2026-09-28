import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { createGripStore } from './grip-store.mjs';

const types = { '.html': 'text/html; charset=utf-8', '.css': 'text/css', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json', '.png': 'image/png' };
export function sourceStatus(root, bundle) {
  if (!bundle?.dependencies?.length) throw new Error('资源包缺少 Unity 来源记录');
  const changed = [];
  for (const file of bundle.dependencies) {
    const target = path.resolve(root, file.path), relative = path.relative(root, target);
    if (!relative || relative.startsWith('..') || path.isAbsolute(relative)) throw new Error('资源来源路径无效');
    if (!fs.existsSync(target) || crypto.createHash('sha256').update(fs.readFileSync(target)).digest('hex') !== file.sha256) changed.push(file.path);
  }
  return { stale: changed.length > 0, changed, exportedAt: bundle.exportedAt, dependencies: bundle.dependencies.length };
}
export function createCharacterServer({ root }) {
  const publicRoot = path.resolve(root, 'Tools/CharacterPreview/public');
  const token = crypto.randomBytes(24).toString('hex');
  // Static copies need no source tables. The editor store is opened only for editor requests.
  const grips = () => createGripStore(root);
  return http.createServer(async (request, response) => {
    const json = (status, value) => { response.writeHead(status, { 'Content-Type': types['.json'], 'Cache-Control': 'no-store' }); response.end(JSON.stringify(value)); };
    try {
      const host = `127.0.0.1:${request.socket.localPort}`;
      if (request.headers.host !== host || (request.headers.origin && request.headers.origin !== `http://${host}`)) return json(403, { error: '只允许本机访问' });
      const pathname = decodeURIComponent(new URL(request.url, `http://${host}`).pathname);
      if (pathname === '/api/grips' && request.method === 'GET') return json(200, { ...grips().state(), token });
      if ((['/api/grips', '/api/hold-adjustments'].includes(pathname) && request.method === 'PUT') || (pathname === '/api/grips/export' && request.method === 'POST')) {
        if (request.headers['x-editor-token'] !== token) return json(403, { error: '编辑凭据已失效，请重新读取配置' });
        if (request.headers['content-type']?.split(';')[0] !== 'application/json') return json(415, { error: '需要 JSON 请求' });
        const chunks = []; let size = 0;
        for await (const chunk of request) { size += chunk.length; if (size > 8192) return json(413, { error: '握点请求过大' }); chunks.push(chunk); }
        let input;
        try { input = JSON.parse(Buffer.concat(chunks).toString('utf8')); } catch { return json(400, { error: 'JSON 格式无效' }); }
        if (!input || typeof input !== 'object' || Array.isArray(input)) return json(400, { error: '请求内容无效' });
        return json(200, pathname.endsWith('/export') ? grips().exportConfig(input) : pathname === '/api/hold-adjustments' ? grips().saveAdjustment(input) : grips().save(input));
      }
      if (request.method !== 'GET' && request.method !== 'HEAD') return json(405, { error: '不支持的编辑操作' });
      if (pathname === '/api/source-status') {
        const bundle = JSON.parse(fs.readFileSync(path.join(publicRoot, 'data/characters.json'), 'utf8'));
        return json(200, sourceStatus(root, bundle));
      }
      if (pathname === '/api/health') return json(200, { tool: 'project-y-character-preview', protocol: 1 });
      const target = path.resolve(publicRoot, '.' + (pathname === '/' ? '/index.html' : pathname));
      const relative = path.relative(publicRoot, target);
      if (!relative || relative.startsWith('..') || path.isAbsolute(relative) || !types[path.extname(target)]) return json(404, { error: '文件不存在' });
      const data = fs.readFileSync(target);
      response.writeHead(200, { 'Content-Type': types[path.extname(target)], 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' });
      response.end(request.method === 'HEAD' ? undefined : data);
    } catch (error) { json(error.status || (error.code === 'ENOENT' ? 404 : 500), { error: error.code === 'ENOENT' ? '资源或配置缺失，请检查工程文件并在 Unity 导出角色网页资源。' : error.message }); }
  });
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const { startServiceHost } = await import('../WebServices/host.mjs');
  await startServiceHost('character-preview');
}
