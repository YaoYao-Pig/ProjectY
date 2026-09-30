import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {snapshot,patchWorkspace,impact} from '../workspace.mjs';
import {createNarrativeServer} from '../server.mjs';
import {runCommand} from '../cli.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
function fixture(t){const root=fs.mkdtempSync(path.join(os.tmpdir(),'project-y-narrative-'));fs.cpSync(path.join(project,'Config/Tables'),path.join(root,'Config/Tables'),{recursive:true});fs.copyFileSync(path.join(project,'Config/Catalog.json'),path.join(root,'Config/Catalog.json'));fs.mkdirSync(path.join(root,'Lua'));fs.copyFileSync(path.join(project,'Lua/Language.lua'),path.join(root,'Lua/Language.lua'));t.after(()=>fs.rmSync(root,{recursive:true,force:true}));return root;}
test('batch creates linked nodes together; validates before writes; detects stale revisions',t=>{
  const root=fixture(t),before=snapshot(root);
  const mission={...before.tables.find(t=>t.name==='MissionTable').rows[0],id:300,name:'Batch mission',startConditionId:301,completeConditionId:1,actionIds:[]};
  const condition={...before.tables.find(t=>t.name==='ConditionTable').rows[0],id:301};
  const input={revision:before.revision,operations:[{op:'upsert',table:'MissionTable',row:mission},{op:'upsert',table:'ConditionTable',row:condition}]};
  assert.equal(patchWorkspace(root,input,{dryRun:true}).valid,true);assert.equal(snapshot(root).revision,before.revision);
  const saved=patchWorkspace(root,input);assert.notEqual(saved.revision,before.revision);assert.equal(runCommand(root,'get',['MissionTable','300']).row.name,'Batch mission');
  assert.throws(()=>patchWorkspace(root,input),/409/);
  const invalid={revision:saved.revision,operations:[{op:'delete',table:'ConditionTable',id:301}]};assert.throws(()=>patchWorkspace(root,invalid),/missing/);assert.equal(snapshot(root).revision,saved.revision);
  assert(impact(root,'ConditionTable:301').affected.some(n=>n.key==='MissionTable:300'));
});
test('cycles, schedules and cross-dialogue links rejected without touching source',t=>{
  const root=fixture(t),state=snapshot(root),before=state.revision;
  function edit(name,id,changes){const row={...state.tables.find(t=>t.name===name).rows.find(r=>r.id===id),...changes};return {revision:before,operations:[{op:'upsert',table:name,row}]};}
  assert.throws(()=>patchWorkspace(root,edit('ConditionTable',1,{kind:'not',conditionIds:[1]})),/cycle/);
  assert.throws(()=>patchWorkspace(root,edit('NpcScheduleTable',1,{endMinute:479})),/gap\/overlap/);
  assert.throws(()=>patchWorkspace(root,edit('DialogueChoiceTable',10,{nextNodeId:20})),/cross-dialogue/);
  assert.throws(()=>patchWorkspace(root,edit('ConditionTable',130,{kind:'kill_count',targetId:4,value:1})),/accepted mission/);
  assert.equal(snapshot(root).revision,before);
});
test('HTTP and CLI share validation, token and origin protections',async t=>{
  const root=fixture(t),server=createNarrativeServer({root});await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));t.after(()=>new Promise(resolve=>server.close(resolve)));
  const url='http://127.0.0.1:'+server.address().port,state=await(await fetch(url+'/api/workspace')).json();
  assert.equal(state.revision,runCommand(root,'validate').revision);
  assert.equal((await fetch(url+'/api/patch',{method:'POST',headers:{'Content-Type':'application/json'},body:'{}'})).status,403);
  assert.equal((await fetch(url+'/api/workspace',{headers:{Origin:'https://example.com'}})).status,403);
  const row={...state.tables.find(t=>t.name==='MissionTable').rows[0],name:'HTTP edit'};
  const response=await fetch(url+'/api/patch',{method:'POST',headers:{'Content-Type':'application/json','X-Narrative-Token':state.token},body:JSON.stringify({revision:state.revision,operations:[{op:'upsert',table:'MissionTable',row}]})});
  assert.equal(response.status,200);assert.equal(runCommand(root,'get',['MissionTable','100']).row.name,'HTTP edit');
});
