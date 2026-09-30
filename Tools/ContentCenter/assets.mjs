import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {atomicJson} from '../ConfigEditor/workspace.mjs';
import {sourceFile} from '../CharacterPreview/source-files.mjs';

export const cacheDirectory=root=>path.join(root,'Tools/ContentCenter/.cache');
export const hash=value=>crypto.createHash('sha256').update(value).digest('hex');
export function assetFile(root,relative,extensions=['.fbx','.obj','.prefab','.glb','.gltf','.blend']) {
  if(typeof relative!=='string'||!relative.startsWith('Assets/')||relative.includes('\\'))throw new Error('请选择 Assets 内的工程资源');
  const base=fs.realpathSync(path.join(root,'Assets')),target=path.resolve(root,relative),rel=path.relative(base,target);
  if(!rel||rel.startsWith('..')||path.isAbsolute(rel)||!extensions.includes(path.extname(target).toLowerCase()))throw new Error('不支持的资源路径');
  let current=base;for(const part of rel.split(path.sep)){current=path.join(current,part);if(fs.lstatSync(current).isSymbolicLink())throw new Error('不允许链接资源');}
  if(!fs.statSync(target).isFile())throw new Error('资源不是文件');return target;
}
export function listAssets(root) {
  const result=[],skip=new Set(['XLua','Plugins','TextMesh Pro','StreamingAssets','_Gen']);
  function walk(directory){for(const entry of fs.readdirSync(directory,{withFileTypes:true})){
    if(entry.isSymbolicLink())continue;
    const full=path.join(directory,entry.name);
    if(entry.isDirectory()){if(!skip.has(entry.name))walk(full);}
    else if(/\.(fbx|obj|prefab|glb|gltf|blend)$/i.test(entry.name))result.push({path:path.relative(root,full).replaceAll('\\','/'),name:entry.name,format:path.extname(entry.name).slice(1).toUpperCase()});
  }}walk(path.join(root,'Assets'));return result;
}
export function editorStatus(root) {
  const file=path.join(cacheDirectory(root),'editor.json');
  if(!fs.existsSync(file))return {ready:false,message:'等待 Unity 内容中心桥接初始化（需要已打开的 Edit Mode）'};
  const state=JSON.parse(fs.readFileSync(file,'utf8'));
  return {...state,ready:state.ready&&Date.now()-Date.parse(state.updatedAt)<15000};
}
export function queueJob(root,kind,sourcePath='') {
  if(!['preview','sync'].includes(kind))throw new Error('Unknown asset job');
  if(kind==='preview')assetFile(root,sourcePath);
  const status=editorStatus(root);
  if(!status.ready)throw new Error(status.message||'Unity 未就绪；请在 Edit Mode 打开工程后重试资源同步');
  const id=crypto.randomUUID(),directory=path.join(cacheDirectory(root),'jobs');fs.mkdirSync(directory,{recursive:true});
  const configFiles=[];
  if(kind==='sync'){
    const walk=dir=>{for(const e of fs.readdirSync(dir,{withFileTypes:true})){const full=path.join(dir,e.name);if(e.isSymbolicLink())throw new Error('Linked source');if(e.isDirectory())walk(full);else if(e.name.endsWith('.json'))configFiles.push({path:path.relative(root,full).replaceAll('\\','/'),sha256:hash(fs.readFileSync(full))});}};
    walk(path.join(root,'Config/Tables'));
  }
  atomicJson(path.join(directory,id+'.request.json'),{id,kind,sourcePath,createdAt:new Date().toISOString(),configFiles});
  return {id,status:'queued'};
}
export function readJob(root,id) {
  if(!/^[0-9a-f-]{36}$/.test(id))throw new Error('Invalid job id');
  const prefix=path.join(cacheDirectory(root),'jobs',id),result=prefix+'.result.json';
  if(fs.existsSync(result))return JSON.parse(fs.readFileSync(result,'utf8'));
  const request=prefix+'.request.json';if(!fs.existsSync(request))throw new Error('Unknown job');
  const data=JSON.parse(fs.readFileSync(request,'utf8'));
  return {id,status:Date.now()-Date.parse(data.createdAt)>120000?'timeout':'queued',message:'等待 Unity 执行；超时后可在 Unity 检查 Console，任务不会自动重复提交'};
}
export function preview(root,sourcePath) {
  assetFile(root,sourcePath);
  const file=path.join(cacheDirectory(root),'previews',hash(sourcePath)+'.json');
  if(!fs.existsSync(file))return {ready:false};
  const data=JSON.parse(fs.readFileSync(file,'utf8'));
  const stale=data.dependencies.some(d=>{const file=sourceFile(root,d.path);return !fs.existsSync(file)||hash(fs.readFileSync(file))!==d.sha256;});
  return {ready:!stale,...data};
}
