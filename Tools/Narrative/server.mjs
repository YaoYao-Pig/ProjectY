import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {snapshot,impact,patchWorkspace,exportNarrative} from './workspace.mjs';
const directory=path.dirname(fileURLToPath(import.meta.url));
export function createNarrativeServer({root=path.resolve(directory,'../..')}={}) {
  const token=crypto.randomBytes(32).toString('hex');
  return http.createServer(async(request,response)=>{
    const send=(status,value,type='application/json; charset=utf-8')=>{response.writeHead(status,{'Content-Type':type,'Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Content-Security-Policy':"default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; frame-ancestors 'none'; base-uri 'none'"});response.end(type.startsWith('application/json')?JSON.stringify(value):value);};
    try {
      const host=`127.0.0.1:${request.socket.localPort}`;
      if(request.headers.host!==host||(request.headers.origin&&request.headers.origin!==`http://${host}`))return send(403,{error:'Use the local 127.0.0.1 URL'});
      const url=new URL(request.url,`http://${host}`);
      if(request.method==='GET') {
        if(url.pathname==='/api/workspace')return send(200,{...snapshot(root),token});
        if(url.pathname==='/rules.mjs')return send(200,fs.readFileSync(path.join(directory,'rules.mjs')),'text/javascript; charset=utf-8');
        if(url.pathname==='/api/impact')return send(200,impact(root,url.searchParams.get('key')));
        const assets={'/':['index.html','text/html'],'/app.js':['app.js','text/javascript'],'/styles.css':['styles.css','text/css']};
        if(assets[url.pathname]){const [file,type]=assets[url.pathname];return send(200,fs.readFileSync(path.join(directory,'public',file)),type+'; charset=utf-8');}
        return send(404,{error:'Not found'});
      }
      if(request.method!=='POST')return send(405,{error:'Method not allowed'});
      if(request.headers['x-narrative-token']!==token)return send(403,{error:'Reload the editor to obtain its write token'});
      if(!request.headers['content-type']?.startsWith('application/json'))return send(415,{error:'Expected JSON'});
      let size=0;const chunks=[];for await(const chunk of request){size+=chunk.length;if(size>2*1024*1024)throw new Error('Request exceeds 2 MiB');chunks.push(chunk);}
      const input=JSON.parse(Buffer.concat(chunks).toString('utf8'));
      if(url.pathname==='/api/review')return send(200,patchWorkspace(root,input,{dryRun:true}));
      if(url.pathname==='/api/patch')return send(200,patchWorkspace(root,input));
      if(url.pathname==='/api/export')return send(200,exportNarrative(root,input.revision));
      return send(404,{error:'Not found'});
    }catch(error){if(!response.headersSent)send(error.status||400,{error:error.message});}
  });
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url))import('../WebServices/host.mjs').then(({startServiceHost})=>startServiceHost('narrative')).catch(error=>{console.error(error.message);process.exitCode=1;});
