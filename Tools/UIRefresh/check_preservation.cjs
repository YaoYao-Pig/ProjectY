const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'../../Art/UIRefresh/2026-10-25');
const before=JSON.parse(fs.readFileSync(path.join(root,'state-before.json'),'utf8'));
const after=JSON.parse(fs.readFileSync(path.join(root,'state-current.json'),'utf8'));
const checks=[];
for(const old of before){
 const now=after.find(x=>x.path===old.path);if(!now)throw Error('Missing prefab '+old.path);
 for(const b of old.bindings){const n=now.bindings.find(x=>x.key===b.key);if(JSON.stringify(n)!==JSON.stringify(b))throw Error('Changed binding '+old.path+' '+b.key);}
 if(JSON.stringify(now.localized)!==JSON.stringify(old.localized))throw Error('Localization binding changed '+old.path);
 if(JSON.stringify(now.protectedViews)!==JSON.stringify(old.protectedViews))throw Error('Protected 3D structure changed '+old.path);
 for(const r of old.rects){const n=now.rects.find(x=>x.path===r.path);if(JSON.stringify(n)!==JSON.stringify(r))throw Error('Existing rect/components changed '+old.path+' '+r.path);}
 checks.push({path:old.path,oldBindingsPreserved:old.bindings.length,addedBindings:now.bindings.filter(x=>!old.bindings.some(y=>y.key===x.key)).map(x=>x.key),protectedViews:old.protectedViews.length,oldRectsPreserved:old.rects.length});
}
fs.writeFileSync(path.join(root,'preservation-check.json'),JSON.stringify({passed:true,checks},null,2));
console.log(JSON.stringify({passed:true,prefabs:checks.length,protected3DViews:checks.reduce((n,x)=>n+x.protectedViews,0),oldBindings:checks.reduce((n,x)=>n+x.oldBindingsPreserved,0),oldRects:checks.reduce((n,x)=>n+x.oldRectsPreserved,0)}));
