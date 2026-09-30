import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
import {snapshot,save,review,impact} from '../workspace.mjs';
import {createAuthoring} from '../authoring.mjs';
import {createContentServer} from '../server.mjs';
import {createProtocol} from '../mcp.mjs';
import {assetFile,queueJob} from '../assets.mjs';
import {sourceStatus} from '../../CharacterPreview/server.mjs';
import {hash} from '../assets.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
function fixture(t){const root=fs.mkdtempSync(path.join(os.tmpdir(),'project-y-content-'));fs.cpSync(path.join(project,'Config/Tables'),path.join(root,'Config/Tables'),{recursive:true});fs.copyFileSync(path.join(project,'Config/Catalog.json'),path.join(root,'Config/Catalog.json'));fs.mkdirSync(path.join(root,'Lua'));fs.copyFileSync(path.join(project,'Lua/Language.lua'),path.join(root,'Lua/Language.lua'));fs.mkdirSync(path.join(root,'Assets/Models'),{recursive:true});fs.writeFileSync(path.join(root,'Assets/Models/Test.fbx'),'fixture model');t.after(()=>fs.rmSync(root,{recursive:true,force:true}));return root;}
test('model-first recipe clones all supported item kinds and isolates weapon relationships',t=>{
  const root=fixture(t);fs.mkdirSync(path.join(root,'Tools/CharacterPreview/public/data'),{recursive:true});fs.writeFileSync(path.join(root,'Tools/CharacterPreview/public/data/characters.json'),JSON.stringify({gearFits:[{sourcePath:'Assets/Models/Test.fbx'}]}));for(const templateId of [1,2,11,13,21,31,40,51]){
    const state=snapshot(root),recipe=createAuthoring(state.tables).item({name:'新物品 '+templateId,modelPath:'Assets/Models/Test.fbx',templateId}),patch={revision:state.revision,operations:recipe.operations};
    assert.equal(review(root,patch).valid,true);assert.equal(snapshot(root).revision,state.revision);
    if(templateId===1){const weapon=recipe.operations.find(o=>o.table==='EquipmentWeaponTable').row,old=state.tables.find(t=>t.name==='EquipmentWeaponTable').rows.find(r=>r.id===1);assert.notEqual(weapon.gripId,old.gripId);assert.notEqual(weapon.requirementId,old.requirementId);assert(weapon.socketIds.every(id=>!old.socketIds.includes(id)));}
    const saved=save(root,patch);assert(saved.sourceSaved);assert(impact(root,`EquipmentAssetTable:${recipe.operations[0].row.id}`).affected.some(n=>n.table==='EquipmentItemTable'));
    assert.throws(()=>save(root,patch),e=>e.status===409);
  }
});
test('NPC recipe creates independent runtime templates, placement and full schedule; invalid equipment never commits',t=>{
  const root=fixture(t),state=snapshot(root),p=state.tables.find(t=>t.name==='NpcPlacementTable').rows[0];
  const recipe=createAuthoring(state.tables).npc({name:'特殊同伴',templateId:1,areaId:p.areaId,facilityId:p.facilityId,recruitable:true});
  const loadout=recipe.operations.find(o=>o.table==='CharacterLoadoutTable').row;loadout.weaponId=40;loadout.wearableIds=[51,52];
  const input={revision:state.revision,operations:recipe.operations};assert(review(root,input).valid);save(root,input);
  const saved=snapshot(root);assert.notEqual(saved.revision,state.revision);
  assert.throws(()=>save(root,{revision:saved.revision,operations:[{op:'upsert',table:'CharacterLoadoutTable',row:{...loadout,weaponId:44,offhandWeaponId:41}}]}),/two-handed/);
  assert.equal(snapshot(root).revision,saved.revision);
  assert.throws(()=>save(root,{revision:saved.revision,operations:[{op:'delete',table:'CombatUnitTable',id:loadout.unitId}]}),/missing/);
});
test('HTTP shares review/commit semantics and enforces origin/token; export reports absent Editor separately',async t=>{
  const root=fixture(t),server=createContentServer({root});await new Promise(r=>server.listen(0,'127.0.0.1',r));t.after(()=>new Promise(r=>server.close(r)));const url='http://127.0.0.1:'+server.address().port;
  const state=await(await fetch(url+'/api/workspace')).json();assert(state.tables.some(t=>t.name==='EquipmentItemTable'));
  assert.equal((await fetch(url+'/api/workspace',{headers:{Origin:'https://other.test'}})).status,403);
  assert.equal((await fetch(url+'/api/save',{method:'POST',headers:{'Content-Type':'application/json'},body:'{}'})).status,403);
  const trait={...state.tables.find(t=>t.name==='CombatTraitTable').rows[0],name:'HTTP 特质'};
  const result=await(await fetch(url+'/api/save',{method:'POST',headers:{'Content-Type':'application/json','X-Content-Token':state.token},body:JSON.stringify({revision:state.revision,operations:[{op:'upsert',table:'CombatTraitTable',row:trait}]})})).json();
  assert(result.sourceSaved);assert(result.exported);assert(result.assetError);assert(fs.existsSync(path.join(root,'Assets/GameFramework/Resources/_Gen/Config/CombatTraitTable.bytes')));
  assert.equal(snapshot(root).tables.find(t=>t.name==='CombatTraitTable').rows[0].name,'HTTP 特质');
});
test('MCP lifecycle, tools, review and revision conflict use the same application core',t=>{
  const root=fixture(t),rpc=createProtocol(root);assert.equal(rpc({jsonrpc:'2.0',id:1,method:'tools/list'}).error.code,-32000);
  assert.equal(rpc({jsonrpc:'2.0',id:2,method:'initialize',params:{protocolVersion:'2025-11-25'}}).result.protocolVersion,'2025-11-25');
  assert.equal(rpc({jsonrpc:'2.0',method:'notifications/initialized'}),null);
  const names=rpc({jsonrpc:'2.0',id:3,method:'tools/list'}).result.tools.map(t=>t.name);assert(names.includes('content_create_item'));
  const state=snapshot(root),trait=state.tables.find(t=>t.name==='CombatTraitTable').rows[0],input={revision:state.revision,operations:[{op:'upsert',table:'CombatTraitTable',row:{...trait,name:'MCP 特质'}}]};
  const call=(name,args)=>rpc({jsonrpc:'2.0',id:4,method:'tools/call',params:{name,arguments:args}}).result;
  assert(!call('content_review',{patch:input}).isError);assert.equal(snapshot(root).revision,state.revision);
  assert(!call('content_save',{patch:input}).isError);assert(call('content_save',{patch:input}).isError);
  const stdin=[{jsonrpc:'2.0',id:1,method:'initialize',params:{protocolVersion:'2025-11-25'}},{jsonrpc:'2.0',id:2,method:'tools/list'}].map(JSON.stringify).join('\n')+'\n';
  const process=spawnSync(globalThis.process.execPath,[path.join(project,'Tools/ContentCenter/mcp.mjs')],{input:stdin,encoding:'utf8'});assert.equal(process.status,0,process.stderr);const lines=process.stdout.trim().split('\n').map(JSON.parse);assert.equal(lines.length,2);assert.equal(lines[1].result.tools.length,names.length);
});
test('invalid model paths, incomplete batches and lost export leave explicit outcomes',t=>{
  const root=fixture(t);assert.throws(()=>assetFile(root,'Assets/../Config/Catalog.json'));assert.throws(()=>queueJob(root,'sync'),/Unity/);
  const state=snapshot(root),recipe=createAuthoring(state.tables).item({name:'bad',modelPath:'Assets/Models/Test.fbx',templateId:40});
  assert.throws(()=>save(root,{revision:state.revision,operations:recipe.operations.filter(o=>o.table!=='EquipmentGripTable')}),/missing/);assert.equal(snapshot(root).revision,state.revision);
  fs.mkdirSync(path.join(root,'Config/_Gen'),{recursive:true});fs.writeFileSync(path.join(root,'Config/_Gen/export-manifest.json'),'["../unsafe"]');
  const trait=state.tables.find(t=>t.name==='CombatTraitTable').rows[0];const result=save(root,{revision:state.revision,operations:[{op:'upsert',table:'CombatTraitTable',row:{...trait,name:'保存与导出区分'}}]},{exportConfig:true});assert(result.sourceSaved);assert.equal(result.exported,false);assert.match(result.error,/Unsafe/);
});
test('Unity virtual package dependencies resolve through the locked cache and detect real changes',t=>{
  const root=fixture(t),relative='Packages/com.example.preview/Shader.shader',directory=path.join(root,'Library/PackageCache/com.example.preview@1.2.3');fs.mkdirSync(directory,{recursive:true});fs.mkdirSync(path.join(root,'Packages'));fs.writeFileSync(path.join(root,'Packages/packages-lock.json'),JSON.stringify({dependencies:{'com.example.preview':{version:'1.2.3'}}}));
  const file=path.join(directory,'Shader.shader');fs.writeFileSync(file,'shader');const bundle={dependencies:[{path:relative,sha256:hash('shader')}],exportedAt:'fixture'};assert.equal(sourceStatus(root,bundle).stale,false);fs.writeFileSync(file,'changed');assert.equal(sourceStatus(root,bundle).stale,true);assert.throws(()=>sourceStatus(root,{dependencies:[{path:'../outside',sha256:''}]}),/路径/);
});
