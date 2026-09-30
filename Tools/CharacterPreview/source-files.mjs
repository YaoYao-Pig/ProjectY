import fs from 'node:fs';
import path from 'node:path';
// Unity dependency lists use virtual Packages/name paths; Node sees the package cache.
export function sourceFile(root,relative){
  const target=path.resolve(root,relative),local=path.relative(root,target);
  if(!local||local.startsWith('..')||path.isAbsolute(local))throw new Error('资源来源路径无效');
  if(fs.existsSync(target)||!relative.startsWith('Packages/'))return target;
  const [prefix,name,...tail]=relative.split('/');
  if(!name||tail.some(p=>p==='..'||p==='.'||!p))throw new Error('Package dependency path is invalid');
  const cache=path.join(root,'Library/PackageCache');if(!fs.existsSync(cache))return target;
  const lockFile=path.join(root,'Packages/packages-lock.json');
  const version=fs.existsSync(lockFile)?JSON.parse(fs.readFileSync(lockFile,'utf8')).dependencies?.[name]?.version:undefined;
  const names=fs.readdirSync(cache,{withFileTypes:true}).filter(e=>e.isDirectory()&&e.name.startsWith(name+'@')).map(e=>e.name);
  const folder=names.includes(name+'@'+version)?name+'@'+version:names.length===1?names[0]:undefined;
  return folder?path.join(cache,folder,...tail):target;
}
