import test from 'node:test';
import assert from 'node:assert/strict';
import {readWorkspace} from '../workspace.mjs';
import {validateTables} from '../../ConfigEditor/exporter.mjs';

const state=readWorkspace(process.cwd());
function tables(edit){
  const all=structuredClone(state.entries.map(entry=>entry.table));
  const rows=name=>all.find(table=>table.name===name).rows;
  const get=(name,id)=>rows(name).find(row=>row.id===id);
  edit?.(get,rows);
  return validateTables(all,state.catalog);
}

test('animal dialogue uses its bound species identity without a town placement',()=>{
  const all=tables(),rows=name=>all.find(table=>table.name===name).rows;
  const rule=rows('AnimalSpeechRuleTable').find(row=>row.id===1);
  const npc=rows('NpcTable').find(row=>row.id===rule.npcId);
  assert.equal(npc.locationKind,'animal');
  assert(rows('AnimalSpeciesTable').some(row=>row.unitId===npc.actorTemplateId));
  assert(npc.dialogueIds.some(id=>rows('DialogueTable').some(row=>row.id===id&&row.npcId===npc.id)));
});

test('animal identity rejects town placement, schedules and human recruitment',()=>{
  assert.throws(()=>tables(get=>get('NpcTable',401).recruitable=true),/animal identity cannot use/);
  assert.throws(()=>tables((get,rows)=>rows('NpcPlacementTable').push({...get('NpcPlacementTable',1),id:99999,npcId:401})),/animal identity cannot use/);
  assert.throws(()=>tables((get,rows)=>rows('NpcScheduleTable').push({...get('NpcScheduleTable',1),id:99999,npcId:401})),/animal identity cannot use/);
});

test('animal identity requires exactly one speech binding and an animal template',()=>{
  assert.throws(()=>tables((get,rows)=>rows('AnimalSpeechRuleTable').length=0),/requires one animal-speech binding/);
  assert.throws(()=>tables((get,rows)=>rows('AnimalSpeechRuleTable').push({...get('AnimalSpeechRuleTable',1),id:2})),/requires one animal-speech binding/);
  assert.throws(()=>tables(get=>get('NpcTable',401).actorTemplateId=705),/requires a configured animal species template/);
});

test('all four legendary animals preserve their original occupied cells when mounted',()=>{
  const all=tables(),rows=name=>all.find(table=>table.name===name).rows;
  for(const unitId of [701,702,703,704]){
    const animal=rows('AnimalSpeciesTable').find(row=>row.unitId===unitId);
    const body=rows('CombatBodyTable').find(row=>row.unitId===unitId);
    assert(animal?.rideable,`Legendary animal ${unitId} must be rideable`);
    assert.deepEqual(animal.footprintQ,body.footprintQ);
    assert.deepEqual(animal.footprintR,body.footprintR);
  }
});
