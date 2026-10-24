import test from 'node:test';
import assert from 'node:assert/strict';
import {readWorkspace} from '../workspace.mjs';
import {validateTables} from '../../ConfigEditor/exporter.mjs';
import {narrativeGraph} from '../rules.mjs';
const state=readWorkspace(process.cwd());
function tables(edit){const rows=structuredClone(state.entries.map(e=>e.table));const get=(name,id)=>rows.find(t=>t.name===name).rows.find(r=>r.id===id);edit?.(get,rows);return validateTables(rows,state.catalog);}
test('six unique legends, three friendly and three hostile, with persistent mission links',()=>{
  const all=tables(),get=name=>all.find(t=>t.name===name).rows;
  assert.equal(get('LegendaryEncounterTable').length,6);
  assert.equal(get('WorldFactionTable').filter(r=>r.id>=11&&r.id<=16&&r.playerRelation>0).length,3);
  assert.equal(get('NpcPlacementTable').filter(r=>r.npcId>=101&&r.npcId<=106).length,0);
  assert.equal(get('MissionTable').filter(r=>r.id>=701&&r.id<=703).length,3);
  assert(narrativeGraph(all).edges.some(e=>e.to==='LegendaryEncounterTable:11'&&e.label.includes('defeated flag')));
});
test('reject duplicated identities, town schedules and unbounded legendary spawns',()=>{
  assert.throws(()=>tables(g=>g('WorldPartyTable',11).count=2),/one unique actor/);
  assert.throws(()=>tables(g=>g('NpcTable',101).locationKind='town'),/world-party|placement/);
  assert.throws(()=>tables(g=>g('NpcScheduleTable',1).npcId=101),/schedule/);
  assert.throws(()=>tables(g=>g('CombatUnitTable',702).traitIds=[101]),/exclusive trait reused/);
});
test('reject unsupported trait instructions and attacks hidden inside town dialogue or reward batches',()=>{
  assert.throws(()=>tables(g=>g('CombatTraitTable',101).onHitEffectIds=[6]),/unsupported on-hit/);
  assert.throws(()=>tables(g=>g('CombatTraitTable',101).attribute='nonexistent'),/unknown attribute/);
  assert.throws(()=>tables(g=>g('DialogueChoiceTable',1).worldAction='attack'),/terminal world-party/);
  assert.throws(()=>tables((g,all)=>{const choice=all.find(t=>t.name==='DialogueChoiceTable').rows.find(r=>r.worldAction==='attack');choice.actionIds=[1];}),/without reward/);
});
