import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { readSources, validateTable } from '../ConfigEditor/exporter.mjs';
import { readCatalog } from '../ConfigEditor/workspace.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const manifest = JSON.parse(fs.readFileSync(path.join(root, 'Tools/ProfessionExpansion/content_manifest.json'), 'utf8'));
const sources = new Map(readSources(path.join(root, 'Config/Tables')).map(t => [t.name, t]));
const catalog = readCatalog(root);
const validated = new Map(manifest.sourceTableNames.map(name => [name, validateTable(sources.get(name), catalog)]));
const get = (name, id) => {
  const source = validated.get(name) ?? sources.get(name);
  const result = source.rows.find(row => row[source.key] === id);
  assert(result, `${name}: missing ${id}`);
  return result;
};
let checkedReferences = 0;
for (const [name, t] of validated) {
  for (const field of t.fields.filter(f => f.ref)) {
    for (const row of t.rows) {
      for (const value of field.type.endsWith('[]') ? row[field.name] : [row[field.name]]) {
        get(field.ref, value); checkedReferences++;
      }
    }
  }
}
const skillIds = new Set(manifest.activeSkillIds);
// Display startup requires unique skill profiles, including life skills and options.
const visualOwners = new Map(), visualStructures = new Map();
const visualFields = ['pattern','count','lifetime','size','radius','height','speed','gravity'];
for (const skill of sources.get('CombatSkillTable').rows) {
  const visual = get('VisualEffectTable', skill.visualEffectId);
  assert(!visualOwners.has(visual.id), `Skills ${visualOwners.get(visual.id)} and ${skill.id} share visualEffectId ${visual.id}`);
  visualOwners.set(visual.id, skill.id);
  const signature = JSON.stringify(visualFields.map(field => visual[field]));
  assert(!visualStructures.has(signature), `Skills ${visualStructures.get(signature)} and ${skill.id} have identical visual geometry and timing`);
  visualStructures.set(signature, skill.id);
}
assert.equal(skillIds.size, 46, '40 authored active/preparation/life skills + 5 options + 1 companion tool');
assert.equal(manifest.professions.length, 6);
const attributes = new Set(sources.get('GrowthAttributeTable').rows.map(r => r.code));
for (const p of manifest.professions) {
  const profession = get('ProfessionTable', p.id);
  assert(profession.treeIds.includes(p.treeId));
  assert.deepEqual(profession.initialSkillIds, [p.skillIds[0]]);
  const passive = get('PassiveSkillTable', p.passiveId);
  assert.equal(passive.triggerKind, manifest.passiveTriggers[p.passiveId]);
  assert(attributes.has(passive.iconAttribute));
  const node = get('TalentNodeTable', p.talentNodeId);
  assert.equal(node.passiveId, p.passiveId);
  for (const id of p.skillIds) {
    assert(sources.get('ProfessionSkillTable').rows.some(r => r.professionId === p.id && r.skillId === id));
  }
}
for (const id of skillIds) {
  const skill = get('CombatSkillTable', id);
  assert(attributes.has(get('SkillAtlasTable', id).glyphCode));
  assert(get('SkillDescriptionTable', id).body.length > 0);
  const icon = get('BattleIconTable', skill.iconId);
  assert(icon.spritePath && fs.existsSync(path.join(root, icon.spritePath)), `${id}: missing reusable icon sprite`);
  get('SkillIconRecipeTable', 10000 + id);
  if (skill.contexts.includes('life')) get('ProfessionExplorationTable', id);
}
for (const r of sources.get('ProfessionSkillTable').rows.filter(r => skillIds.has(r.skillId))) {
  assert.equal(r.attributeNames.length, r.attributeValues.length);
  for (const attr of r.attributeNames) assert(attributes.has(attr), `Unknown learning attribute ${attr}`);
}
for (const r of get('ProfessionCombatTable', 1801) ? sources.get('ProfessionCombatTable').rows : []) {
  if (r.materialId) { get('EquipmentItemTable', r.materialId); assert(r.materialCount > 0); }
  if (r.applyEffectId) get('CombatEffectTable', r.applyEffectId);
  if (r.baseSkillId) get('CombatSkillTable', r.baseSkillId);
}
for (const id of manifest.weaponIds) {
  const item=get('EquipmentItemTable',id), weapon=get('EquipmentWeaponTable',id);
  assert.equal(item.kind,'weapon');
  assert(weapon.socketIds.length===0, 'No unmodeled attachment sockets');
  const asset=get('EquipmentAssetTable',item.assetId);
  assert(fs.existsSync(path.join(root,asset.modelPath)), `Missing Blender export ${asset.modelPath}`);
  get('EquipmentGripTable',weapon.gripId);
  get('EquipmentRequirementTable',weapon.requirementId);
  assert(sources.get('ShopEntryTable').rows.some(r=>r.itemId===id && r.chance===100));
  get('WorldTradePriceTable',id);
}
for (const id of Object.values(manifest.materials)) {
  get('EquipmentItemTable',id); get('WorldTradePriceTable',id);
}
console.log(JSON.stringify({ok:true,tables:validated.size,checkedReferences,professions:6,authoredAbilities:46,activeRows:skillIds.size,uniqueSkillVisuals:visualOwners.size,weapons:12,materials:5}));
