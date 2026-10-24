import test from 'node:test';
import assert from 'node:assert/strict';
import {readWorkspace} from '../workspace.mjs';
import {validateTables} from '../../ConfigEditor/exporter.mjs';
const state=readWorkspace(process.cwd());
function validate(edit){const all=structuredClone(state.entries.map(e=>e.table));const get=(name,id)=>all.find(t=>t.name===name).rows.find(r=>r.id===id);edit?.(get,all);return validateTables(all,state.catalog);}
test('event NPC has one recruit binding and no town schedule or placement',()=>{
  const all=validate(),npc=all.find(t=>t.name==='NpcTable').rows.find(r=>r.id===301);
  assert.equal(npc.locationKind,'event');
  assert.throws(()=>validate(g=>g('NpcTable',301).recruitable=false),/cannot recruit|event identity/);
  assert.throws(()=>validate(g=>g('SpecialEventTable',1).allyUnitId=1),/matching ally template/);
  assert.throws(()=>validate((g,all)=>all.find(t=>t.name==='NpcPlacementTable').rows.push({...g('NpcPlacementTable',1),id:99999,npcId:301})),/event identity/);
});
test('special event choices belong to their world and scene events',()=>{
  assert.throws(()=>validate(g=>g('SpecialEventTable',1).battleChoiceId=3011),/duplicate choice|belongs to another event/);
  assert.throws(()=>validate(g=>g('SpecialEventTable',1).sceneEventId=301),/duplicate world\/scene event/);
});
test('special event ally must occupy its unique slot in the area encounter',()=>{
  assert.throws(()=>validate(g=>g('SpecialEventTable',1).allyIndex=1),/ally encounter slot/);
  assert.throws(()=>validate(g=>g('MapAreaEncounterTable',60).encounterId=1),/configured encounter/);
  assert.throws(()=>validate(g=>g('MapAreaEncounterTable',60).groupCount=2),/configured encounter/);
  assert.throws(()=>validate(g=>g('MissionTable',1001).actionIds=[]),/mission must recruit/);
});
test('deserter travel, sheltered participation and recovery arrays are explicit',()=>{
  const all=validate(),row=all.find(t=>t.name==='SpecialEventTable').rows.find(r=>r.id===2);
  assert.equal(row.townRadius,0);assert.equal(row.allyParticipates,false);assert.equal(row.killAllyOnFailure,false);
  assert.deepEqual(row.initialInjuryPartIds,[5,6,3,4,2]);assert.deepEqual(row.injuryRecoveryMinutes,[1440,1440,2880,2880,4320]);
  assert.throws(()=>validate(g=>g('SpecialEventTable',2).initialInjuryDamage=[30]),/injury arrays/);
  assert.throws(()=>validate(g=>g('SpecialEventTable',2).initialInjuryDamage[0]=100),/recoverable/);
  assert.throws(()=>validate(g=>g('SpecialEventTable',2).initialInjuryPartIds[0]=6),/unique body parts/);
});
