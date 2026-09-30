import fs from 'node:fs';
import path from 'node:path';
import {readWorkspace,patchWorkspace,exportNarrative} from '../Narrative/workspace.mjs';
import {validateTables} from '../ConfigEditor/exporter.mjs';
import {narrativeGraph} from '../Narrative/rules.mjs';
import {modules,labels,optionalReferences} from './modules.mjs';
import {editorStatus,queueJob,assetFile,hash} from './assets.mjs';
import {validate as validateAppearance} from '../CharacterPreview/public/rules.mjs';
export {readWorkspace};
export function snapshot(root){
  const state=readWorkspace(root),tables=validateTables(state.entries.map(e=>e.table),state.catalog);
  return {revision:state.revision,projectId:hash(fs.realpathSync(root)),tables,catalog:state.catalog,modules,labels,editor:editorStatus(root),graph:graph(tables)};
}
export function graph(tables){
  const story=narrativeGraph(tables),edges=[...story.edges],nodes=[];
  for(const table of tables)for(const row of table.rows){
    const key=`${table.name}:${row[table.key]}`;nodes.push({key,table:table.name,id:row[table.key],label:row.name||row.text||row.description||String(row[table.key])});
    if(story.nodes.some(n=>n.key===key))continue;
    for(const f of table.fields.filter(f=>f.ref))for(const id of f.type.endsWith('[]')?row[f.name]:[row[f.name]])edges.push({from:key,to:`${f.ref}:${id}`,label:f.name});
    for(const [field,target] of Object.entries(optionalReferences[table.name]||{}))if(row[field])edges.push({from:key,to:`${target}:${row[field]}`,label:field});
  }
  return {nodes,edges};
}
export function impact(root,key){
  const g=snapshot(root).graph;if(!g.nodes.some(n=>n.key===key))throw new Error('Unknown entity '+key);
  const seen=new Set([key]),queue=[key];for(let i=0;i<queue.length;i++)for(const e of g.edges)if(e.to===queue[i]&&!seen.has(e.from)){seen.add(e.from);queue.push(e.from);}
  return {key,affected:g.nodes.filter(n=>seen.has(n.key)),edges:g.edges.filter(e=>seen.has(e.from)&&seen.has(e.to))};
}
function validateAssets(root,input){
  if(input.operations?.some(o=>['EquipmentAssetTable','EquipmentItemTable','EquipmentWearableTable'].includes(o.table))){
    const state=readWorkspace(root),tables=new Map(state.entries.map(e=>[e.table.name,structuredClone(e.table)]));
    for(const op of input.operations){const t=tables.get(op.table);if(!t)continue;const id=op.op==='upsert'?op.row?.[t.key]:op.id;t.rows=t.rows.filter(r=>r[t.key]!==id);if(op.op==='upsert')t.rows.push(op.row);}
    const touchedItems=new Set(input.operations.filter(o=>['EquipmentItemTable','EquipmentWearableTable'].includes(o.table)).map(o=>o.row?.id??o.id));
    const touchedAssets=new Set(input.operations.filter(o=>o.table==='EquipmentAssetTable').map(o=>o.row?.id??o.id));
    const assets=tables.get('EquipmentAssetTable').rows;let fitPaths;
    for(const item of tables.get('EquipmentItemTable').rows.filter(r=>r.kind==='wearable'&&(touchedItems.has(r.id)||touchedAssets.has(r.assetId)))){
      const wearable=tables.get('EquipmentWearableTable').rows.find(r=>r.id===item.id),asset=assets.find(r=>r.id===item.assetId);
      if(wearable&&asset&&['head','chest','legs','feet','back'].includes(wearable.mount)){
        if(!fitPaths)fitPaths=new Set(JSON.parse(fs.readFileSync(path.join(root,'Tools/CharacterPreview/public/data/characters.json'),'utf8')).gearFits.map(f=>f.sourcePath));
        if(!fitPaths.has(asset.prefabPath))throw new Error(`防具 ${item.id} 缺少角色体型贴合资源：${asset.prefabPath}。请先通过现有角色资源管线制作并导出 GearFit，或选择已经适配的模型。`);
      }
    }
  }
  for(const op of input.operations||[])if(op.table==='CharacterLoadoutTable'&&op.op==='upsert'&&op.row.appearanceJson){
    const rules=JSON.parse(fs.readFileSync(path.join(root,'Assets/GameFramework/Resources/CharacterAppearanceCatalog.json'),'utf8'));
    validateAppearance(rules,JSON.parse(op.row.appearanceJson));
  }
  for(const op of input.operations||[])if(op.table==='EquipmentAssetTable'&&op.op==='upsert'){
    assetFile(root,op.row.modelPath);
    if(!/^Assets\/DynamicAsset\/ContentCenter\/Prefabs\/Asset_\d+\.prefab$/.test(op.row.prefabPath))assetFile(root,op.row.prefabPath);
  }
}
export function review(root,input){validateAssets(root,input);return patchWorkspace(root,input,{dryRun:true,editableTables:readWorkspace(root).entries.map(e=>e.table.name)});}
export function save(root,input,{exportConfig=false}={}){
  review(root,input);
  const saved=patchWorkspace(root,input,{editableTables:readWorkspace(root).entries.map(e=>e.table.name)});
  if(!exportConfig)return {...saved,sourceSaved:true,exported:false};
  try{return {...saved,...publish(root,saved.revision),sourceSaved:true};}
  catch(error){return {...saved,sourceSaved:true,exported:false,error:error.message};}
}
export function publish(root,revision){
  const result=exportNarrative(root,revision);
  let assetJob=null,assetError='';
  try{assetJob=queueJob(root,'sync');}catch(e){assetError=e.message;}
  return {revision:result.revision,exported:true,assetJob,assetError,reloadRequired:true};
}
