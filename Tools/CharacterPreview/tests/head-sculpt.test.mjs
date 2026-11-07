import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {options,randomize,headShapeWeights,tint} from '../public/rules.mjs';
const root=path.resolve(import.meta.dirname,'../../..');
const rules=JSON.parse(fs.readFileSync(path.join(root,'Art/PawnCustomization/Integration/catalog.json'),'utf8'));
test('new painted identities coexist with old heads and are reachable in compatible pools',()=>{
 const additions=rules.modules.filter(m=>m.source);assert.equal(additions.length,10);assert.equal(additions.filter(m=>m.sex==='female').length,3);
 const reached=new Set();for(const race of ['human','goblin'])for(const sex of ['male','female'])for(let seed=0;seed<512;seed++)reached.add(randomize(rules,seed,race,sex).head);
 for(const m of additions){assert(reached.has(m.id));assert(fs.existsSync(path.join(root,m.source)));assert(fs.existsSync(path.join(root,m.texture)));}
 for(const race of rules.races)for(const sex of ['male','female'])for(const suffix of [0,1])assert(options(rules,'head',race.id,sex).some(m=>m.id===`head_${race.id}_${sex}_${suffix}`));
});
test('seeded facial shape values agree with the actual Unity fixture',()=>{
 const fixture=JSON.parse(fs.readFileSync(path.join(root,'Art/HeadSculptExpansion202610/Integration/unity-validation.json'),'utf8'));
 const actual=headShapeWeights(42,'head_human_female_sculpt_00');assert.equal(actual.length,6);
 actual.forEach((value,i)=>assert(Math.abs(value-fixture.shapeFixture[i])<1e-6));
 assert.deepEqual(actual,headShapeWeights(42,'head_human_female_sculpt_00'));
 assert.notDeepEqual(actual,headShapeWeights(43,'head_human_female_sculpt_00'));
});
test('painted heads keep shared skin variation without double-tinting their base albedo',()=>{
 const a=randomize(rules,42,'human','female');a.head='head_human_female_sculpt_00';a.skin=0;
 assert.deepEqual(tint(rules,a,'HeadSculpt_human_female_00',[1,1,1]),[1,1,1]);
 const body=tint(rules,a,'Skin',[1,1,1]);assert.equal(body.length,3);assert(body.every(v=>v>0&&v<=1));
});
