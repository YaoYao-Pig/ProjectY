import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { deflateSync } from 'node:zlib';
import { prepare, publish, status, validate } from '../pipeline.mjs';
import { run } from '../cli.mjs';

const tableRelative = name => `Config/Tables/Adventure/${name}.json`;
const manifestRelative = 'Art/SkillIcons/manifest.json';
function write(root, relative, value) {
  const filename = path.join(root, relative);
  fs.mkdirSync(path.dirname(filename), { recursive: true });
  fs.writeFileSync(filename, JSON.stringify(value, null, 2) + '\n');
}
function read(root, relative) { return JSON.parse(fs.readFileSync(path.join(root, relative), 'utf8')); }
function change(root, name, edit) {
  const table = read(root, tableRelative(name)); edit(table); write(root, tableRelative(name), table);
}
function table(name, fields, rows) {
  return { version: 1, name, description: 'Fixture', key: 'id', fields: fields.map(([name, type]) => ({ name, type })), rows };
}
function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'skill-icons-test-'));
  t.after(() => {
    assert.equal(path.dirname(path.resolve(root)), path.resolve(os.tmpdir()));
    assert(path.basename(root).startsWith('skill-icons-test-'));
    fs.rmSync(root, { recursive: true, force: true });
  });
  write(root, tableRelative('CombatSkillTable'), table('CombatSkillTable', [['id', 'int'], ['name', 'text'], ['description', 'text'], ['iconId', 'int'], ['power', 'int']], [
    { id: 1, name: '斩击', description: '近战挥砍', iconId: 1, power: 7 },
    { id: 2, name: '射击', description: '远程射击', iconId: 2, power: 8 },
    { id: 3, name: '待配置技能', description: '保留原图标', iconId: 2, power: 9 },
  ]));
  write(root, tableRelative('BattleIconTable'), table('BattleIconTable', [['id', 'int'], ['name', 'string'], ['spritePath', 'string']], [
    { id: 1, name: 'Existing 1', spritePath: 'Assets/Old/one.png' },
    { id: 2, name: 'Existing 2', spritePath: 'Assets/Old/two.png' },
  ]));
  write(root, tableRelative('SkillIconRecipeTable'), table('SkillIconRecipeTable', [['id', 'int'], ['skillId', 'int'], ['slug', 'string'], ['styleId', 'string'], ['subject', 'string']], [
    { id: 10001, skillId: 1, slug: 'slash', styleId: 'simple-pixel', subject: 'One broad sword slash' },
    { id: 10002, skillId: 2, slug: 'shoot', styleId: 'simple-pixel', subject: 'One arrow' },
  ]));
  write(root, tableRelative('SkillIconStyleTable'), table('SkillIconStyleTable', [['id', 'string'], ['prompt', 'string'], ['maxTextureSize', 'int']], [
    { id: 'simple-pixel', prompt: 'Simple flat pixel icon, very few details, transparent background.', maxTextureSize: 256 },
  ]));
  return root;
}
function crc32(bytes) {
  let crc = 0xffffffff;
  for (const byte of bytes) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
  }
  return (crc ^ 0xffffffff) >>> 0;
}
function chunk(type, bytes) {
  const output = Buffer.alloc(bytes.length + 12);
  output.writeUInt32BE(bytes.length); output.write(type, 4); bytes.copy(output, 8);
  output.writeUInt32BE(crc32(output.subarray(4, -4)), output.length - 4); return output;
}
function png({ width = 2, height = 2, colorType = 6, value = 100 } = {}) {
  const header = Buffer.alloc(13); header.writeUInt32BE(width); header.writeUInt32BE(height, 4); header[8] = 8; header[9] = colorType;
  const channels = colorType === 6 ? 4 : colorType === 4 ? 2 : 3;
  const pixels = Buffer.alloc((width * channels + 1) * height, value);
  for (let y = 0; y < height; y++) pixels[y * (width * channels + 1)] = 0;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', header), chunk('IDAT', deflateSync(pixels)), chunk('IEND', Buffer.alloc(0))]);
}
function input(root, bytes = png()) { const filename = path.join(root, 'input.png'); fs.writeFileSync(filename, bytes); return filename; }
function publishOne(root, options = {}) {
  return publish({ root, skillId: 1, image: path.join(root, 'input.png'), job: 'Art/SkillIcons/Jobs/10001.json', reviewed: true, ...options });
}
function files(root) {
  const result = {};
  function walk(directory) {
    for (const item of fs.readdirSync(directory, { withFileTypes: true })) {
      const filename = path.join(directory, item.name);
      if (item.isDirectory()) walk(filename);
      else result[path.relative(root, filename)] = fs.readFileSync(filename).toString('base64');
    }
  }
  walk(root); return result;
}

test('prepare is offline, creates tracked prompts, and leaves all icon mappings intact', t => {
  const root = fixture(t);
  const beforeSkills = read(root, tableRelative('CombatSkillTable'));
  const result = prepare({ root });
  assert.equal(result.jobs.length, 2);
  assert.equal(result.jobs[0].prompt, 'Simple flat pixel icon, very few details, transparent background.\n\nSubject: One broad sword slash');
  assert.equal(result.jobs[0].assetPath, 'Assets/DynamicAsset/UI/Icons/Skills/slash-v1.png');
  assert.match(result.jobs[0].recipeHash, /^[a-f0-9]{64}$/);
  assert.equal(result.jobs[0].transparentBackground, true);
  assert.deepEqual(read(root, tableRelative('CombatSkillTable')), beforeSkills);
  assert.equal(fs.existsSync(path.join(root, 'Assets')), false);
  assert.deepEqual(status({ root }).counts, { prepared: 2, unconfigured: 1 });
  assert.equal(validate({ root }).pending.length, 3);
});

test('publish changes only the selected mapping and preserves user edits and pending icons', t => {
  const root = fixture(t);
  prepare({ root, skillIds: [1] }); input(root);
  change(root, 'CombatSkillTable', table => { table.rows[0].power = 42; table.rows[1].description = 'User edit'; });
  change(root, 'BattleIconTable', table => { table.rows[1].name = 'User icon note'; });
  const beforeSkills = read(root, tableRelative('CombatSkillTable'));
  const beforeIcons = read(root, tableRelative('BattleIconTable'));
  const result = publishOne(root);
  assert.equal(result.state, 'published');
  const skills = read(root, tableRelative('CombatSkillTable'));
  const icons = read(root, tableRelative('BattleIconTable'));
  const expectedSkills = structuredClone(beforeSkills); expectedSkills.rows[0].iconId = 10001;
  assert.deepEqual(skills, expectedSkills);
  assert.deepEqual(icons.rows.slice(0, 2), beforeIcons.rows);
  assert.deepEqual(icons.rows[2], { id: 10001, name: '斩击', spritePath: result.entry.assetPath });
  assert.deepEqual(fs.readFileSync(path.join(root, result.entry.sourcePath)), fs.readFileSync(path.join(root, result.entry.assetPath)));
  assert.deepEqual(fs.readFileSync(path.join(root, 'input.png')), fs.readFileSync(path.join(root, result.entry.assetPath)));
  assert.equal(Object.keys(files(root)).some(file => file.endsWith('.meta')), false);
  assert.equal(validate({ root }).published, 1);
  assert.deepEqual(validate({ root }).pending.map(row => row.skillId), [2, 3]);
});

test('visual review, stale jobs, malformed PNGs, and unsafe paths fail before any writes', t => {
  const root = fixture(t);
  prepare({ root, skillIds: [1] }); input(root);
  let before = files(root);
  assert.throws(() => publishOne(root, { reviewed: false }), /Visual review/);
  assert.deepEqual(files(root), before);
  change(root, 'SkillIconStyleTable', table => { table.rows[0].prompt += ' New style.'; });
  before = files(root);
  assert.throws(() => publishOne(root), /stale/);
  assert.deepEqual(files(root), before);
  prepare({ root, skillIds: [1] });
  for (const bytes of [Buffer.from('not an image'), png({ width: 2, height: 3 }), png({ colorType: 2 }), png().subarray(0, 40)]) {
    input(root, bytes); before = files(root);
    assert.throws(() => publishOne(root), /PNG|alpha|square/);
    assert.deepEqual(files(root), before);
  }
  input(root); before = files(root);
  assert.throws(() => publishOne(root, { job: '../10001.json' }), /prepared job/);
  assert.deepEqual(files(root), before);
  change(root, 'SkillIconRecipeTable', table => { table.rows[0].slug = '../escape'; });
  before = files(root);
  assert.throws(() => prepare({ root, skillIds: [1] }), /invalid slug/);
  assert.deepEqual(files(root), before);
});

test('image and recipe changes version assets; repeated source/recipe pairs are idempotent', t => {
  const root = fixture(t);
  prepare({ root, skillIds: [1] }); input(root);
  const first = publishOne(root);
  let before = files(root);
  assert.equal(publishOne(root).state, 'unchanged');
  assert.deepEqual(files(root), before);
  input(root, png({ value: 200 })); before = files(root);
  assert.throws(() => publishOne(root), /old version/);
  assert.deepEqual(files(root), before);
  prepare({ root, skillIds: [1] });
  const second = publishOne(root);
  assert.equal(second.entry.version, 2);
  assert.notEqual(first.entry.assetPath, second.entry.assetPath);
  assert.equal(validate({ root }).archivedVersions, 2);
  input(root); before = files(root);
  assert.equal(publishOne(root).state, 'already-published');
  assert.deepEqual(files(root), before);
  assert.equal(read(root, tableRelative('BattleIconTable')).rows.at(-1).spritePath, second.entry.assetPath);
  change(root, 'SkillIconRecipeTable', table => { table.rows[0].subject = 'A broader sword slash'; });
  assert.throws(() => validate({ root }), /stale/);
  prepare({ root, skillIds: [1] });
  const third = publishOne(root);
  assert.equal(third.entry.version, 3);
  assert.notEqual(third.entry.recipeHash, first.entry.recipeHash);
  assert.equal(validate({ root }).archivedVersions, 3);
});

test('validation detects tampered assets, source archives, snapshots, and config mappings', t => {
  const root = fixture(t);
  prepare({ root, skillIds: [1] }); input(root);
  const { entry } = publishOne(root);
  for (const relative of [entry.sourcePath, entry.assetPath]) {
    const filename = path.join(root, relative), original = fs.readFileSync(filename);
    fs.writeFileSync(filename, png({ value: 200 }));
    assert.throws(() => validate({ root }), /hash mismatch/);
    fs.writeFileSync(filename, original);
  }
  change(root, 'CombatSkillTable', table => { table.rows[0].iconId = 1; });
  assert.throws(() => validate({ root }), /expected iconId/);
  change(root, 'CombatSkillTable', table => { table.rows[0].iconId = 10001; });
  change(root, 'BattleIconTable', table => { table.rows.at(-1).spritePath = 'Assets/Wrong.png'; });
  assert.throws(() => validate({ root }), /spritePath mismatch/);
  change(root, 'BattleIconTable', table => { table.rows.at(-1).spritePath = entry.assetPath; });
  const manifest = read(root, manifestRelative); manifest.entries[0].recipe.subject = 'Tampered';
  write(root, manifestRelative, manifest);
  assert.throws(() => validate({ root }), /Prompt does not match/);
});

test('skill text changes invalidate jobs, unrelated fields do not', t => {
  const root = fixture(t);
  prepare({ root, skillIds: [1] }); input(root);
  change(root, 'CombatSkillTable', table => { table.rows[0].name = 'Updated slash'; });
  const before = files(root);
  assert.throws(() => publishOne(root), /stale/);
  assert.deepEqual(files(root), before);
  prepare({ root, skillIds: [1] });
  assert.equal(publishOne(root).entry.skill.name, 'Updated slash');
  assert.equal(validate({ root }).valid, true);
});

test('linked output folders cannot redirect writes outside the project', t => {
  const root = fixture(t), outside = fs.mkdtempSync(path.join(os.tmpdir(), 'skill-icons-outside-'));
  t.after(() => {
    assert.equal(path.dirname(path.resolve(outside)), path.resolve(os.tmpdir()));
    assert(path.basename(outside).startsWith('skill-icons-outside-'));
    fs.rmSync(outside, { recursive: true, force: true });
  });
  prepare({ root, skillIds: [1] }); input(root);
  fs.mkdirSync(path.join(root, 'Assets/DynamicAsset/UI/Icons'), { recursive: true });
  fs.symlinkSync(outside, path.join(root, 'Assets/DynamicAsset/UI/Icons/Skills'), process.platform === 'win32' ? 'junction' : 'dir');
  assert.throws(() => publishOne(root), /Linked paths/);
  assert.deepEqual(fs.readdirSync(outside), []);
  assert.equal(fs.existsSync(path.join(root, manifestRelative)), false);
});

test('CLI rejects ambiguous selectors and incomplete publication commands', () => {
  assert.match(run(['--help']), /--reviewed/);
  assert.throws(() => run(['prepare']), /requires --skill or --all/);
  assert.throws(() => run(['prepare', '--all', '--skill', '1']), /Choose/);
  assert.throws(() => run(['prepare', '--skill', '1,../2']), /positive IDs/);
  assert.throws(() => run(['publish', '--skill', '1,2']), /exactly one/);
  assert.throws(() => run(['publish', '--skill', '1']), /Visual review/);
  assert.throws(() => run(['validate', '--all']), /Unknown option/);
});
