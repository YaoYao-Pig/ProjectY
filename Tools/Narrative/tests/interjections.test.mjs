import test from 'node:test';
import assert from 'node:assert/strict';
import {readWorkspace} from '../workspace.mjs';
import {validateTables} from '../../ConfigEditor/exporter.mjs';
import {narrativeGraph} from '../rules.mjs';
const state=readWorkspace(process.cwd());
function tables(edit){const all=structuredClone(state.entries.map(e=>e.table));const get=(name,id)=>all.find(t=>t.name===name).rows.find(r=>r.id===id);edit?.(get,all);return validateTables(all,state.catalog);}
test('companion branches are reachable and included in impact graph',()=>{
  const all=tables(),graph=narrativeGraph(all);
  assert(graph.edges.some(e=>e.from==='DialogueInterjectionTable:2'&&e.to==='DialogueNodeTable:4156'));
  assert(graph.edges.some(e=>e.from==='ConditionTable:4036'&&e.to==='CombatTraitTable:3'));
});
test('reject actor scopes in ordinary choices and mission conditions, including nested scopes',()=>{
  assert.throws(()=>tables(g=>g('DialogueChoiceTable',1).conditionId=4041),/actor condition/);
  assert.throws(()=>tables(g=>g('MissionTable',100).completeConditionId=4037),/actor condition/);
});
test('reject automatic jumps, cross-dialogue edges and contextless kill checks',()=>{
  assert.throws(()=>tables(g=>g('DialogueInterjectionTable',1).nextNodeId=4156),/automatic speech/);
  assert.throws(()=>tables(g=>g('DialogueInterjectionTable',2).nextNodeId=3001),/cross-dialogue/);
  assert.throws(()=>tables(g=>g('DialogueInterjectionTable',2).conditionId=102),/kill_count/);
});
test('history uses structured kind, participant role and validated event identity',()=>{
  assert.throws(()=>tables(g=>g('ConditionTable',4037).key='made_up_past'),/actor_history/);
  assert.throws(()=>tables(g=>g('ConditionTable',4037).state='anyone'),/actor_history/);
  assert.throws(()=>tables(g=>g('ConditionTable',4037).targetId=1),/event ID/);
  assert.throws(()=>tables(g=>g('ConditionTable',4037).value=0),/actor_history/);
});
