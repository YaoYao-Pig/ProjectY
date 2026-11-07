import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { validateTable } from '../ConfigEditor/exporter.mjs';

const sources=new Map();
function collect(directory) {
  for (const entry of fs.readdirSync(directory,{withFileTypes:true})) {
    const filename=path.join(directory,entry.name);
    if (entry.isDirectory()) collect(filename);
    else if (entry.name.endsWith('.json')) sources.set(entry.name.slice(0,-5),filename);
  }
}
collect('Config/Tables');
const catalog=JSON.parse(fs.readFileSync('Config/Catalog.json','utf8'));
const read=name=>validateTable(JSON.parse(fs.readFileSync(assertPath(name),'utf8')),catalog);
function assertPath(name) { assert(sources.has(name),`Missing table ${name}`);return sources.get(name); }
const units=read('CombatUnitTable'),traits=read('CombatTraitTable'),mapping=read('UnitInspectionNpcTable');
const residents=read('MapAreaTownNpcTable');
const attributes=new Set(read('GrowthAttributeTable').rows.map(row=>row.code));
const traitIds=new Set(traits.rows.map(row=>row.id));
const unitIds=new Set(units.rows.map(row=>row.id));
const skillIds=new Set(read('CombatSkillTable').rows.map(row=>row.id));
for (const row of units.rows) {
  assert(row.traitIds.length>0,`Unit ${row.id} has no innate traits`);
  assert.equal(new Set(row.traitIds).size,row.traitIds.length,`Duplicate unit traits ${row.id}`);
  for (const id of row.traitIds) assert(traitIds.has(id),`Unknown trait ${id} on unit ${row.id}`);
  for (const id of row.skillIds) assert(skillIds.has(id),`Unknown skill ${id} on unit ${row.id}`);
  assert.equal(row.attributeNames.length,row.attributeValues.length);
  assert.equal(new Set(row.attributeNames).size,row.attributeNames.length);
  for (const name of row.attributeNames) assert(attributes.has(name),`Unknown attribute ${name}`);
  assert(row.attributeNames.includes('scouting'),`Unit ${row.id} needs an explicit scouting base`);
}
for (const row of traits.rows) assert(attributes.has(row.attribute),`Unknown trait attribute ${row.attribute}`);
for (const row of residents.rows) assert(mapping.rows.some(item=>item.id===row.id),`Unmapped town resident ${row.id}`);
for (const row of mapping.rows) {
  assert(residents.rows.some(item=>item.id===row.id));
  assert(unitIds.has(row.unitId));
}
for (const table of [units,traits,residents]) {
  for (const name of ['name','description']) {
    const field=table.fields.find(item=>item.name===name);
    if (field) assert.equal(field.type,'text');
  }
}
console.log(`PASS ${units.rows.length} unit templates, ${traits.rows.length} traits, ${mapping.rows.length} NPC mappings and localized text fields`);
