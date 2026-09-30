import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {snapshot,review,save,publish,impact} from './workspace.mjs';
import {listAssets,preview,queueJob,readJob,editorStatus,assetFile} from './assets.mjs';
import {createCharacterServer} from '../CharacterPreview/server.mjs';
const directory=path.dirname(fileURLToPath(import.meta.url));
export function createContentServer({root=path.resolve(directory,'../..')}={}){
  const token=crypto.randomBytes(32).toString('hex'),character=createCharacterServer({root});
  return http.createServer(async(req,res)=>{
    const send=(status,value,type='application/json; charset=utf-8')=>{res.writeHead(status,{'Content-Type':type,'Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Content-Security-Policy':"default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; frame-src 'self'; frame-ancestors 'self'; base-uri 'none'"});res.end(type.startsWith('application/json')?JSON.stringify(value):value);};
    try{
      const host=`127.0.0.1:${req.socket.localPort}`;
      if(req.headers.host!==host||(req.headers.origin&&req.headers.origin!==`http://${host}`))return send(403,{error:'只允许本机同源访问'});
      const url=new URL(req.url,`http://${host}`);
      if(url.pathname.startsWith('/character/')){req.url=req.url.slice('/character'.length);return character.emit('request',req,res);}
      if(req.method==='GET'){
        if(url.pathname==='/api/workspace')return send(200,{...snapshot(root),token});
        if(url.pathname==='/api/assets')return send(200,{assets:listAssets(root)});
        if(url.pathname==='/api/preview')return send(200,preview(root,url.searchParams.get('path')));
        if(url.pathname==='/api/editor')return send(200,editorStatus(root));
        if(url.pathname==='/api/job')return send(200,readJob(root,url.searchParams.get('id')));
        if(url.pathname==='/api/impact')return send(200,impact(root,url.searchParams.get('key')));
        if(url.pathname==='/api/icon')return send(200,fs.readFileSync(assetFile(root,url.searchParams.get('path'),['.png'])),'image/png');
        const files={'/':['public/index.html','text/html'],'/app.mjs':['public/app.mjs','text/javascript'],'/preview.mjs':['public/preview.mjs','text/javascript'],'/styles.css':['public/styles.css','text/css'],'/modules.mjs':['modules.mjs','text/javascript'],'/authoring.mjs':['authoring.mjs','text/javascript'],'/README.md':['README.md','text/plain']};
        if(url.pathname==='/definitions.mjs')return send(200,fs.readFileSync(path.join(directory,'../ConfigEditor/definitions.mjs')),'text/javascript; charset=utf-8');
        if(files[url.pathname]){const [file,type]=files[url.pathname];return send(200,fs.readFileSync(path.join(directory,file)),type+'; charset=utf-8');}
        return send(404,{error:'Not found'});
      }
      if(req.method!=='POST')return send(405,{error:'Method not allowed'});
      if(req.headers['x-content-token']!==token)return send(403,{error:'请重新打开编辑中心获取会话凭据'});
      if(req.headers['content-type']?.split(';')[0]!=='application/json')return send(415,{error:'Expected JSON'});
      const chunks=[];let size=0;for await(const chunk of req){size+=chunk.length;if(size>4*1024*1024)return send(413,{error:'草稿超过 4 MiB'});chunks.push(chunk);}
      const input=JSON.parse(Buffer.concat(chunks).toString('utf8'));
      if(url.pathname==='/api/review')return send(200,review(root,input));
      if(url.pathname==='/api/save')return send(200,save(root,input,{exportConfig:true}));
      if(url.pathname==='/api/export')return send(200,publish(root,input.revision));
      if(url.pathname==='/api/preview')return send(202,queueJob(root,'preview',input.path));
      if(url.pathname==='/api/sync')return send(202,queueJob(root,'sync'));
      return send(404,{error:'Not found'});
    }catch(error){if(!res.headersSent)send(error.status||400,{error:error.message});else res.destroy(error);}
  });
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  const {startServiceHost}=await import('../WebServices/host.mjs');await startServiceHost('content-center');
}
