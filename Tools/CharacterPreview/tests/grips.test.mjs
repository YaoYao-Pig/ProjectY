import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import * as THREE from '../public/vendor/three.module.min.js';
import { createCharacterServer } from '../server.mjs';
import { weaponRoot, unityPosition, unityRotation, toUnityRotation, applyGripPreview } from '../public/grip-math.mjs';
import { adjustmentKey } from '../public/hold-adjustments.mjs';

const root = path.resolve(import.meta.dirname, '../../..');
test('grip API persists only vectors, rejects conflicts / invalid input / cross-origin, and exports through the config pipeline', async () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'character-grips-'));
  fs.cpSync(path.join(root, 'Config/Tables'), path.join(tmp, 'Config/Tables'), { recursive: true });
  fs.copyFileSync(path.join(root, 'Config/Catalog.json'), path.join(tmp, 'Config/Catalog.json'));
  fs.mkdirSync(path.join(tmp, 'Lua')); fs.copyFileSync(path.join(root, 'Lua/Language.lua'), path.join(tmp, 'Lua/Language.lua'));
  const overrideFile = path.join(tmp,'Config/Tables/Equipment/EquipmentHoldAdjustmentTable.json');
  const overrideTable = JSON.parse(fs.readFileSync(overrideFile)); overrideTable.rows=[]; fs.writeFileSync(overrideFile,JSON.stringify(overrideTable));
  const file = path.join(tmp, 'Config/Tables/Equipment/EquipmentGripTable.json'), original = JSON.parse(fs.readFileSync(file));
  const server = createCharacterServer({ root: tmp }); await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const url = `http://127.0.0.1:${server.address().port}`;
  try {
    const state = await (await fetch(url + '/api/grips')).json(), id = state.rows[0].id;
    const values = { mainPosition: [.03,-.02,.07], mainRotation: [12,-24,31], offPosition: [.1,.2,-.3], offRotation: [-8,7,6] };
    const put = (body, headers = {}, method = 'PUT', route = '/api/grips') => fetch(url + route, { method, headers: { 'Content-Type': 'application/json', 'X-Editor-Token': state.token, ...headers }, body: typeof body === 'string' ? body : JSON.stringify(body) });
    assert.equal((await put({ id, revision: state.revision, values }, { 'X-Editor-Token': '' })).status, 403);
    assert.equal((await put({ id, revision: state.revision, values }, { Origin: 'https://example.org' })).status, 403);
    for (const invalid of [[1,2], [1,2,null], [1,2,'3']]) assert.equal((await put({ id, revision: state.revision, values: { ...values, mainPosition: invalid } })).status, 400);
    assert.equal((await put({ id, revision: state.revision, values: { ...values, poseId: 9 } })).status, 400);
    assert.equal((await put('{bad json')).status, 400);
    assert.equal((await put('x'.repeat(9000))).status, 413);
    assert.deepEqual(JSON.parse(fs.readFileSync(file)), original);
    const response = await put({ id, revision: state.revision, values }); assert.equal(response.status, 200); const saved = await response.json();
    const expected = structuredClone(original); Object.assign(expected.rows.find(r => r.id === id), values);
    assert.deepEqual(JSON.parse(fs.readFileSync(file)), expected);
    assert.equal((await put({ id, revision: state.revision, values })).status, 409);
    assert.equal((await put({ revision: saved.revision }, {}, 'POST', '/api/grips/export')).status, 200);
    assert(fs.readFileSync(path.join(tmp, 'Assets/GameFramework/Resources/_Gen/Config/EquipmentGripTable.bytes')).subarray(0,4).equals(Buffer.from('YCFG')));
    const reloaded = await (await fetch(url + '/api/grips')).json(); assert.deepEqual(reloaded.rows.find(r => r.id === id), saved.row);
    const adjustmentFile = path.join(tmp, 'Config/Tables/Equipment/EquipmentHoldAdjustmentTable.json');
    let revision = saved.revision;
    for (const [moduleId,hand,angle] of [[1,'main',15],[4,'main',25],[4,'off',-35],[2,'main',5]]) {
      const result = await put({ revision, weaponId:40, moduleId, hand, rotationOffset:[0,angle,0] }, {}, 'PUT', '/api/hold-adjustments');
      assert.equal(result.status,200); revision=(await result.json()).revision;
    }
    const adjustments = JSON.parse(fs.readFileSync(adjustmentFile)).rows;
    assert.equal(adjustments.length,4); assert.deepEqual(adjustments.map(row=>row.rotationOffset[1]),[15,25,-35,5]);
    assert.deepEqual(JSON.parse(fs.readFileSync(file)),expected,'Orientation editing must preserve geometric grip data');
    assert.equal((await put({revision:saved.revision,weaponId:40,moduleId:1,hand:'main',rotationOffset:[0,99,0]}, {}, 'PUT', '/api/hold-adjustments')).status,409);
    assert.equal((await put({revision,weaponId:40,moduleId:1,hand:'main',rotationOffset:[0,null,0]}, {}, 'PUT', '/api/hold-adjustments')).status,400);
    const reset = await put({revision,weaponId:40,moduleId:4,hand:'off',rotationOffset:null}, {}, 'PUT', '/api/hold-adjustments');
    assert.equal(reset.status,200); revision=(await reset.json()).revision;
    assert.equal(JSON.parse(fs.readFileSync(adjustmentFile)).rows.length,3,'Restoring default removes only the selected combination');
    assert.equal((await put({revision}, {}, 'POST', '/api/grips/export')).status,200);
    assert(fs.readFileSync(path.join(tmp,'Assets/GameFramework/Resources/_Gen/Config/EquipmentHoldAdjustmentTable.bytes')).subarray(0,4).equals(Buffer.from('YCFG')));
    const weaponFile = path.join(tmp, 'Config/Tables/Equipment/EquipmentWeaponTable.json'), weapons = JSON.parse(fs.readFileSync(weaponFile));
    weapons.rows[0].gripId = state.rows[1].id; fs.writeFileSync(weaponFile, JSON.stringify(weapons));
    assert.equal((await put({ id, revision, values })).status, 409, 'Weapon-to-grip mapping changes also invalidate the editor revision');
  } finally { server.closeAllConnections(); await new Promise(resolve => server.close(resolve)); fs.rmSync(tmp, { recursive: true, force: true }); }
});

const close = (a,b,epsilon = 1e-7) => assert(a.distanceTo(b) < epsilon, `${a.toArray()} != ${b.toArray()}`);
test('Unity grip coordinates align to the hand with nonzero rotation and nonuniform prefab scale', () => {
  const hand = new THREE.Object3D(); hand.position.set(.3,1.2,-.1); hand.quaternion.setFromEuler(new THREE.Euler(.2,-.5,.3));
  const arm = { mountPosition: [.02,.03,-.04], mountRotation: unityRotation([8,12,-9]).toArray() };
  const row = { mainPosition: [.06,-.08,.12], mainRotation: [21,-42,13] };
  const scale = [.8,1.2,.6], root = weaponRoot(hand, arm, row, scale);
  close(unityPosition(row.mainPosition).applyMatrix4(root), new THREE.Vector3().fromArray(arm.mountPosition).applyQuaternion(hand.quaternion).add(hand.position));
  const rotation = new THREE.Quaternion().setFromRotationMatrix(new THREE.Matrix4().extractRotation(root)).multiply(unityRotation(row.mainRotation));
  assert(rotation.angleTo(hand.quaternion.clone().multiply(new THREE.Quaternion().fromArray(arm.mountRotation))) < 1e-7);
  for (const angles of [[0,0,90],[21,-42,13],[-89,175,38]]) assert(unityRotation(toUnityRotation(unityRotation(angles))).angleTo(unityRotation(angles)) < 1e-7);
  // Unity Euler(0,0,90) sends the local X axis toward +Y even after the Z reflection.
  close(new THREE.Vector3(1,0,0).applyQuaternion(unityRotation([0,0,90])), new THREE.Vector3(0,1,0));
});

test('exported weapons retain attachment offsets; shared grips preserve arm length; dual-wield edits stay on their owning weapon', t => {
  const bundle = JSON.parse(fs.readFileSync(path.join(root, 'Tools/CharacterPreview/public/data/characters.json')));
  assert(bundle.loadouts.every(l => l.gripEditor?.version === 2), 'Re-export the character bundle from Unity before running grip preview integration tests');
  function sample(array, count, frame) {
    return Array.from({ length: count }, (_, i) => { const offset = (frame * count + i) * 10, o = new THREE.Object3D(); o.position.fromArray(array,offset); o.quaternion.fromArray(array,offset+3); o.scale.fromArray(array,offset+7); return o; });
  }
  for (const loadout of bundle.loadouts) for (const clip of loadout.animations) for (const frame of [0,Math.floor(clip.frameCount/2),clip.frameCount-1]) {
    const meta = loadout.gripEditor, bones = sample(clip.poses,bundle.bones.length,frame), meshes = sample(clip.attachmentPoses,loadout.meshes.length,frame);
    const rows = new Map(meta.weapons.map(w => [w.gripId,structuredClone(w)]));
    const adjustments = new Map(meta.weapons.map(w => [adjustmentKey(w.itemId,meta.moduleId,w.slot), {rotationOffset:[...w.rotationOffset]}]));
    const before = meshes.map(m => { m.updateMatrix(); return m.matrix.clone(); });
    const lengths = meta.arms.map(a => { const [u,l,h] = a.bones.map(i => bones[i]); return [u.position.distanceTo(l.position),l.position.distanceTo(h.position)]; });
    const base = applyGripPreview(meta,rows,bones,meshes,adjustments);
    meshes.forEach((m,i) => { m.updateMatrix(); assert.deepEqual(m.matrix.elements,before[i].elements); });
    const selected = meta.weapons.at(-1), row = rows.get(selected.gripId);
    row.mainPosition[0] += .025; row.mainRotation[1] += 11;
    if (meta.shared) { row.offPosition[2] += .03; row.offRotation[0] += 8; }
    const changed = applyGripPreview(meta,rows,bones,meshes,adjustments);
    assert(meshes.every(m => [...m.position.toArray(),...m.quaternion.toArray()].every(Number.isFinite)));
    meta.arms.forEach((a,i) => { const [u,l,h] = a.bones.map(j=>bones[j]); assert(Math.abs(u.position.distanceTo(l.position)-lengths[i][0]) < 1e-5); assert(Math.abs(l.position.distanceTo(h.position)-lengths[i][1]) < 1e-5); });
    for (const [i,w] of meta.weapons.entries()) for (const index of w.meshes) {
      const localBefore = base[i].clone().invert().multiply(before[index]); meshes[index].updateMatrix();
      const localAfter = changed[i].clone().invert().multiply(meshes[index].matrix);
      assert(localBefore.elements.every((n,j)=>Math.abs(n-localAfter.elements[j]) < 1e-5), loadout.id + ' attachment follows owning weapon');
    }
    if (meta.weapons.length === 2) for (const index of meta.weapons[0].meshes) {
      meshes[index].updateMatrix(); assert(before[index].elements.every((n,i)=>Math.abs(n-meshes[index].matrix.elements[i]) < 1e-5));
    }
  }
});

test('weapon orientation rotates the actual model in every clip and only for the selected weapon / module / hand', () => {
  const bundle = JSON.parse(fs.readFileSync(path.join(root,'Tools/CharacterPreview/public/data/characters.json')));
  const sample = (array,count,frame) => Array.from({length:count},(_,i)=>{
    const offset=(frame*count+i)*10,o=new THREE.Object3D();o.position.fromArray(array,offset);o.quaternion.fromArray(array,offset+3);o.scale.fromArray(array,offset+7);return o;
  });
  const rotation = matrix => new THREE.Quaternion().setFromRotationMatrix(new THREE.Matrix4().extractRotation(matrix)).normalize();
  for(const loadout of bundle.loadouts) for(const clip of loadout.animations) {
    const meta=loadout.gripEditor,frame=Math.floor(clip.frameCount/2),bones=sample(clip.poses,bundle.bones.length,frame),meshes=sample(clip.attachmentPoses,loadout.meshes.length,frame);
    const rows=new Map(meta.weapons.map(w=>[w.gripId,structuredClone(w)]));
    const adjustments=new Map(meta.weapons.map(w=>[adjustmentKey(w.itemId,meta.moduleId,w.slot),{rotationOffset:[...w.rotationOffset]}]));
    const selected=meta.weapons.at(-1),index=meta.weapons.indexOf(selected);
    adjustments.set(adjustmentKey(selected.itemId,meta.moduleId+100,selected.slot),{rotationOffset:[90,90,90]});
    const base=applyGripPreview(meta,rows,bones,meshes,adjustments);
    const before=meshes.map(mesh=>{mesh.updateMatrix();return mesh.matrix.clone();});
    adjustments.set(adjustmentKey(selected.itemId,meta.moduleId,selected.slot),{rotationOffset:[12,25,-8]});
    const after=applyGripPreview(meta,rows,bones,meshes,adjustments);
    const expected=rotation(base[index]).multiply(unityRotation(selected.rotationOffset).invert()).multiply(unityRotation([12,25,-8])).normalize();
    assert(rotation(after[index]).angleTo(expected)<1e-5,loadout.id+'/'+clip.id);
    assert(rotation(after[index]).angleTo(rotation(base[index]))>.1,'The weapon itself must visibly rotate');
    const localBefore=base[index].clone().invert().multiply(before[selected.meshes[0]]);
    meshes[selected.meshes[0]].updateMatrix();
    const expectedMesh=after[index].clone().multiply(localBefore);
    assert(rotation(expectedMesh).angleTo(rotation(meshes[selected.meshes[0]].matrix))<1e-5);
    if(meta.weapons.length===2)for(const meshIndex of meta.weapons[0].meshes){meshes[meshIndex].updateMatrix();assert(before[meshIndex].elements.every((n,i)=>Math.abs(n-meshes[meshIndex].matrix.elements[i])<1e-5),'Other hand remains unchanged');}
  }
});
