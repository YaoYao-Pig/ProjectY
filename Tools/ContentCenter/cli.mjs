import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {snapshot,review,save,publish,impact} from './workspace.mjs';
import {listAssets,queueJob,readJob} from './assets.mjs';
import {createAuthoring} from './authoring.mjs';
export function runCommand(root,command,args={}){
  if(command==='review')return review(root,args.patch);
  if(command==='save')return save(root,args.patch,{exportConfig:args.exportConfig===true});
  if(command==='export')return publish(root,args.revision);
  if(command==='impact')return impact(root,args.key);
  if(command==='assets')return {assets:listAssets(root).filter(a=>a.path.toLowerCase().includes((args.query||'').toLowerCase()))};
  if(command==='asset_job')return queueJob(root,args.kind,args.path);
  if(command==='job')return readJob(root,args.id);
  const state=snapshot(root);
  if(command==='create_item'||command==='create_npc')return {revision:state.revision,...createAuthoring(state.tables)[command==='create_item'?'item':'npc'](args)};
  if(command==='snapshot')return state;
  if(command==='schema')return {revision:state.revision,modules:state.modules,tables:state.tables.filter(t=>!args.table||t.name===args.table).map(({rows,...schema})=>schema),catalog:state.catalog};
  if(command==='list'){
    const table=state.tables.find(t=>t.name===args.table);if(!table)throw new Error('Unknown table');
    const found=table.rows.filter(r=>JSON.stringify(r).toLowerCase().includes((args.query||'').toLowerCase()));
    const offset=args.offset??0,limit=args.limit??100;
    if(!Number.isSafeInteger(offset)||offset<0||!Number.isSafeInteger(limit)||limit<1||limit>500)throw new Error('offset>=0, limit 1..500 required');
    return {revision:state.revision,total:found.length,rows:found.slice(offset,offset+limit)};
  }
  if(command==='get'){const table=state.tables.find(t=>t.name===args.table),row=table?.rows.find(r=>r[table.key]===args.id);if(!row)throw new Error('Unknown entity');return {revision:state.revision,row};}
  if(command==='validate')return {revision:state.revision,valid:true};
  throw new Error('Unknown command '+command);
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  try{const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..'),args=process.argv[3]?JSON.parse(fs.readFileSync(process.argv[3],'utf8')):{};console.log(JSON.stringify(runCommand(root,process.argv[2],args),null,2));}
  catch(e){console.error(JSON.stringify({error:e.message,status:e.status||400}));process.exitCode=1;}
}
