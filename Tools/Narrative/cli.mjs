import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {snapshot,impact,patchWorkspace,exportNarrative} from './workspace.mjs';
import {conditionTargets,actionTargets} from './rules.mjs';
export function runCommand(root,command,args=[]) {
  if(command==='patch'||command==='review') {
    if(!args[0])throw new Error('Provide a JSON patch file containing revision and operations');
    return patchWorkspace(root,JSON.parse(fs.readFileSync(path.resolve(args[0]),'utf8').replace(/^\uFEFF/,'')),{dryRun:command==='review'});
  }
  if(command==='impact')return impact(root,args[0]);
  const state=snapshot(root);
  if(command==='snapshot')return state;
  if(command==='validate')return {valid:true,revision:state.revision,...state.diagnostics};
  if(command==='graph')return {revision:state.revision,...state.graph};
  if(command==='schema')return {revision:state.revision,dynamicReferences:{ConditionTable:conditionTargets,NarrativeActionTable:actionTargets},tables:state.tables.filter(t=>!args[0]||t.name===args[0]).map(t=>({name:t.name,description:t.description,fields:t.fields,nextId:Math.max(0,...t.rows.map(r=>r.id))+1}))};
  if(command==='list')return {revision:state.revision,tables:state.tables.filter(t=>!args[0]||t.name===args[0]).map(t=>({name:t.name,rows:t.rows.map(r=>({id:r.id,name:r.name||r.text||r.reason||r.kind||r.activity}))}))};
  if(command==='get') {
    const table=state.tables.find(t=>t.name===args[0]);if(!table)throw new Error('Unknown table');
    const row=table.rows.find(r=>r.id===Number(args[1]));if(!row)throw new Error('Unknown row');
    return {revision:state.revision,table:table.name,row,references:state.graph.edges.filter(e=>e.from===`${table.name}:${row.id}`||e.to===`${table.name}:${row.id}`)};
  }
  if(command==='export'){if(!args[0])throw new Error('export requires the current revision');return exportNarrative(root,args[0]);}
  throw new Error('Commands: list [table], get <table> <id>, schema [table], graph, impact <table:id>, snapshot, validate, review <patch.json>, patch <patch.json>, export <revision>');
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
  try{console.log(JSON.stringify(runCommand(root,process.argv[2],process.argv.slice(3)),null,2));}
  catch(error){console.error(JSON.stringify({error:error.message,status:error.status||400}));process.exitCode=1;}
}
