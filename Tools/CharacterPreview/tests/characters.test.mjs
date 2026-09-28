import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import { options, randomize, validate } from '../public/rules.mjs';
import { createCharacterServer, sourceStatus } from '../server.mjs';

const root = path.resolve(import.meta.dirname, '../../..');
const rules = JSON.parse(fs.readFileSync(path.join(root, 'Art/PawnCustomization/Integration/catalog.json'), 'utf8'));
test('five races, both sexes, compatible seeded combinations and JSON roundtrip', () => {
  assert.equal(rules.races.length, 5);
  for (const race of rules.races) for (const sex of ['male', 'female']) for (const seed of [0, 1, 42, 20260927, 2147483647]) {
    const a = randomize(rules, seed, race.id, sex);
    assert.deepEqual(a, randomize(rules, seed, race.id, sex));
    assert.deepEqual(validate(rules, JSON.parse(JSON.stringify(a))), a);
    assert.equal(options(rules, 'body', race.id, sex).length, 3);
    assert.equal(options(rules, 'head', race.id, sex).length, 2);
  }
  const dragon = randomize(rules, 42, 'dragon', 'female');
  assert.throws(() => validate(rules, { ...dragon, hair: 'hair_2' }), /不兼容/);
  assert.throws(() => validate(rules, { ...dragon, body: 'body_male_1' }), /不兼容/);
  assert.throws(() => validate(rules, { ...dragon, skin: 99 }), /颜色/);
  for (const seed of [-1, 1.5, 2147483648, NaN]) assert.throws(() => randomize(rules, seed));
});
test('Unity fixture agreement and real exported geometry / motion integrity', () => {
  const bundle = JSON.parse(fs.readFileSync(path.join(root, 'Tools/CharacterPreview/public/data/characters.json'), 'utf8'));
  assert.deepEqual(bundle.rules, rules);
  assert.equal(bundle.meshes.length, 113); assert.equal(bundle.bones.length, 23);
  assert.equal(bundle.gearFits.length, 42); assert.equal(bundle.coveredBodies.length, 42); assert.equal(bundle.loadouts.length, 11);
  assert.equal(bundle.rootOffset.length, 3); assert(Math.abs(bundle.rootOffset[1] - .14) < .0001);
  for (const fixture of bundle.randomFixtures) assert.deepEqual(randomize(rules, fixture.seed), fixture);
  for (const mesh of bundle.meshes) {
    assert.equal(mesh.positions.length, mesh.normals.length);
    assert.equal(mesh.positions.length / 3 * 4, mesh.weights.length);
    assert.equal(mesh.weights.length, mesh.joints.length);
    assert.equal(mesh.bindposes.length, 23 * 16);
    assert(mesh.positions.every(Number.isFinite));
    for (let i = 0; i < mesh.weights.length; i += 4) assert(Math.abs(mesh.weights.slice(i, i + 4).reduce((a, b) => a + b, 0) - 1) < .001);
    assert(mesh.joints.every(i => i >= 0 && i < 23));
    for (const g of mesh.groups) assert(g.indices.every(i => i >= 0 && i < mesh.positions.length / 3));
  }
  for (const animation of bundle.animations) {
    assert.equal(animation.poses.length, animation.frameCount * 23 * 10);
    assert(animation.poses.every(Number.isFinite));
    assert(animation.poses.slice(0, 230).some((v, i) => Math.abs(v - animation.poses[230 + i]) > 1e-6), animation.id + ' must animate');
  }
  const weaponIds = new Set();
  for (const loadout of bundle.loadouts) {
    assert(loadout.meshes.length > 0);
    for (const mesh of loadout.meshes) { assert(mesh.rigid); assert(!weaponIds.has(mesh.id)); weaponIds.add(mesh.id); assert.equal(mesh.bindposes.length, 0); assert.equal(mesh.weights.length, 0); }
    for (const animation of loadout.animations) { assert.equal(animation.poses.length, animation.frameCount * 230); assert(animation.poses.every(Number.isFinite)); assert(animation.duration > 0); assert.equal(animation.attachmentPoses.length, animation.frameCount * loadout.meshes.length * 10); assert(animation.attachmentPoses.every(Number.isFinite)); }
  }
  for (const race of rules.races) for (const sex of ['male','female']) for (let body = 0; body < 3; body++) {
    const id = `body_${sex}_${body}`;
    for (const path of [...new Set(bundle.gearFits.map(f => f.sourcePath))]) assert(bundle.gearFits.some(f => f.sourcePath === path && (!f.body || f.body === id) && (!f.race || f.race === race.id)), path + '/' + id + '/' + race.id);
    for (let mask=1;mask<8;mask++) assert(bundle.coveredBodies.some(c=>c.body===id&&c.mask===mask));
  }
});
test('source freshness detects changed and missing files', () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'character-source-'));
  try {
    fs.writeFileSync(path.join(tmp, 'mesh.fbx'), 'verified');
    const bundle = { dependencies: [{ path: 'mesh.fbx', sha256: crypto.createHash('sha256').update('verified').digest('hex') }] };
    assert.equal(sourceStatus(tmp, bundle).stale, false);
    fs.writeFileSync(path.join(tmp, 'mesh.fbx'), 'changed'); assert.equal(sourceStatus(tmp, bundle).stale, true);
    fs.unlinkSync(path.join(tmp, 'mesh.fbx')); assert.equal(sourceStatus(tmp, bundle).stale, true);
  } finally { fs.rmdirSync(tmp); }
});
test('local server serves UI and bundle, rejects writes and foreign origins', async () => {
  const server = createCharacterServer({ root }); await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const url = 'http://127.0.0.1:' + server.address().port;
  try {
    assert.equal((await fetch(url + '/')).status, 200);
    assert.equal((await fetch(url + '/data/characters.json')).status, 200);
    assert.equal((await fetch(url + '/api/source-status')).status, 200);
    assert.equal((await fetch(url + '/', { method: 'POST' })).status, 405);
    assert.equal((await fetch(url + '/', { headers: { Origin: 'https://example.org' } })).status, 403);
    assert.equal((await fetch(url + '/../../AGENTS.md')).status, 404);
  } finally { server.closeAllConnections(); await new Promise(resolve => server.close(resolve)); }
});
