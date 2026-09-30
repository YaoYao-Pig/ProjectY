import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {scanSources,tableDirectory,readCatalog,atomicJson} from '../ConfigEditor/workspace.mjs';
import {validateTables,exportTables} from '../ConfigEditor/exporter.mjs';
import {languageSource} from '../ConfigEditor/language.mjs';
import {narrativeTables,narrativeGraph,validateNarrative} from './rules.mjs';
export function readWorkspace(root) {
  const {entries}=scanSources(tableDirectory(root)),catalog=readCatalog(root);
  const revision=crypto.createHash('sha256').update(JSON.stringify(entries.map(e=>({folder:e.folder,table:e.table})))).update(JSON.stringify(catalog)).update(languageSource(root)).digest('hex');
  return {entries,catalog,revision};
}
export function snapshot(root) {
  const state=readWorkspace(root),tables=validateTables(state.entries.map(e=>e.table),state.catalog);
  return {revision:state.revision,tables:tables.filter(t=>narrativeTables.includes(t.name)),graph:narrativeGraph(tables),
    references:Object.fromEntries(tables.filter(t=>!narrativeTables.includes(t.name)).map(t=>[t.name,t.rows.map(r=>({id:r[t.key],name:r.name||r.description||String(r[t.key])}))])),diagnostics:validateNarrative(tables)};
}
export function propose(root,input,{editableTables=narrativeTables}={}) {
  const state=readWorkspace(root);
  if(input.revision!==state.revision){const error=new Error('工作区已变化，请重新读取 revision 后合并修改（409）。');error.status=409;throw error;}
  if(!Array.isArray(input.operations)||input.operations.length===0||input.operations.length>1000)throw new Error('operations must contain 1..1000 changes');
  const changed=new Map(),touched=new Set();
  for(const operation of input.operations) {
    const {table:name,op}=operation;
    if(!editableTables.includes(name))throw new Error(`Table is not editable through these tools: ${name}`);
    const entry=state.entries.find(e=>e.table.name===name);if(!entry)throw new Error(`Unknown table: ${name}`);
    let table=changed.get(name);if(!table){table=structuredClone(entry.table);changed.set(name,table);}
    const id=op==='upsert'?operation.row?.[table.key]:operation.id;
    const keyType=table.fields.find(f=>f.name===table.key).type;
    if(keyType==='int'?!Number.isSafeInteger(id):typeof id!=='string'||!id)throw new Error('A valid primary key is required');
    const key=`${name}:${id}`;if(touched.has(key))throw new Error('Duplicate operation for '+key);touched.add(key);
    const index=table.rows.findIndex(r=>r[table.key]===id);
    if(op==='upsert'){if(index<0)table.rows.push(structuredClone(operation.row));else table.rows[index]=structuredClone(operation.row);}
    else if(op==='delete'){if(index<0)throw new Error('Unknown row '+key);table.rows.splice(index,1);}
    else throw new Error('Unknown operation: '+op);
  }
  const tables=validateTables(state.entries.map(e=>changed.get(e.table.name)||e.table),state.catalog);
  const changes=[...changed].map(([name,table])=>({table:name,before:state.entries.find(e=>e.table.name===name).table,after:table}));
  return {state,changed,tables,review:{revision:state.revision,valid:true,changes,diagnostics:validateNarrative(tables),graph:narrativeGraph(tables)}};
}
export function patchWorkspace(root,input,{dryRun=false,editableTables=narrativeTables}={}) {
  const proposal=propose(root,input,{editableTables});if(dryRun)return proposal.review;
  const cache=path.join(root,'Tools/ConfigEditor/.cache');fs.mkdirSync(cache,{recursive:true});
  const lock=path.join(cache,'write.lock');let fd;
  try{fd=fs.openSync(lock,'wx');}catch(error){if(error.code==='EEXIST')throw new Error('Another content write is active; retry after it finishes');throw error;}
  const written=[];
  try {
    if(readWorkspace(root).revision!==input.revision){const e=new Error('Workspace changed before commit');e.status=409;throw e;}
    for(const [name,table] of proposal.changed) {
      const entry=proposal.state.entries.find(e=>e.table.name===name),before=fs.readFileSync(entry.filename);
      if(JSON.stringify(JSON.parse(before.toString('utf8').replace(/^\uFEFF/,'')))!==JSON.stringify(entry.table))throw new Error('Source changed during commit: '+name);
      atomicJson(entry.filename,table);written.push({filename:entry.filename,before,after:fs.readFileSync(entry.filename)});
    }
    return {revision:readWorkspace(root).revision,changed:[...proposal.changed.keys()],diagnostics:proposal.review.diagnostics};
  }catch(error){for(const entry of written.reverse()){if(fs.readFileSync(entry.filename).equals(entry.after))fs.writeFileSync(entry.filename,entry.before);else error.message+='; external edit preserved at '+entry.filename;}throw error;}
  finally{fs.closeSync(fd);fs.unlinkSync(lock);}
}
export function impact(root,key) {
  const graph=snapshot(root).graph;
  if(!graph.nodes.some(n=>n.key===key))throw new Error('Unknown graph node: '+key);
  const affected=new Set([key]),queue=[key];
  for(let i=0;i<queue.length;i++)for(const edge of graph.edges)if(edge.to===queue[i]&&!affected.has(edge.from)){affected.add(edge.from);queue.push(edge.from);}
  return {key,affected:graph.nodes.filter(n=>affected.has(n.key)),edges:graph.edges.filter(e=>affected.has(e.from)&&affected.has(e.to))};
}
export function exportNarrative(root,revision) {
  if(readWorkspace(root).revision!==revision){const e=new Error('Workspace changed before export');e.status=409;throw e;}
  return {...exportTables({root}),revision:readWorkspace(root).revision};
}
