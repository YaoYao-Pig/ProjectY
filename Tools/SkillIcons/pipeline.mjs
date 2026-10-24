import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { validateTable } from '../ConfigEditor/exporter.mjs';
import { readCatalog } from '../ConfigEditor/workspace.mjs';

export const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const tablesDirectory = 'Config/Tables/Adventure';
const jobsDirectory = 'Art/SkillIcons/Jobs';
const sourcesDirectory = 'Art/SkillIcons/Sources';
const assetsDirectory = 'Assets/DynamicAsset/UI/Icons/Skills';
const manifestRelative = 'Art/SkillIcons/manifest.json';
const tableNames = ['CombatSkillTable', 'BattleIconTable', 'SkillIconRecipeTable', 'SkillIconStyleTable'];
const digest = value => crypto.createHash('sha256').update(value).digest('hex');
const isHash = value => typeof value === 'string' && /^[a-f0-9]{64}$/.test(value);
const positiveInt = value => Number.isSafeInteger(value) && value > 0;
const slugPattern = /^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$/;
const crcTable = Array.from({ length: 256 }, (_, byte) => {
  let crc = byte;
  for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
  return crc >>> 0;
});
function crc32(bytes) {
  let crc = 0xffffffff;
  for (const byte of bytes) crc = (crc >>> 8) ^ crcTable[(crc ^ byte) & 0xff];
  return (crc ^ 0xffffffff) >>> 0;
}

function canonical(value) {
  if (Array.isArray(value)) return '[' + value.map(canonical).join(',') + ']';
  if (value && typeof value === 'object') return '{' + Object.keys(value).sort().map(key => JSON.stringify(key) + ':' + canonical(value[key])).join(',') + '}';
  return JSON.stringify(value);
}

// Reject both traversal and existing junction/symlink components before reads or writes.
function localPath(root, relative) {
  assert(typeof relative === 'string' && relative.length > 0 && !path.isAbsolute(relative), 'Expected a project-relative path');
  assert(!relative.includes('\\') && !relative.split('/').some(part => part === '..' || part === '.' || !part), `Unsafe project path: ${relative}`);
  const absoluteRoot = path.resolve(root);
  const filename = path.resolve(absoluteRoot, relative);
  assert(filename.startsWith(absoluteRoot + path.sep), `Path escapes project: ${relative}`);
  let current = absoluteRoot;
  for (const part of relative.split('/')) {
    current = path.join(current, part);
    const stat = fs.lstatSync(current, { throwIfNoEntry: false });
    if (stat) assert(!stat.isSymbolicLink(), `Linked paths are unsupported: ${relative}`);
  }
  return filename;
}

function readJson(root, relative) {
  const filename = localPath(root, relative);
  const text = fs.readFileSync(filename, 'utf8');
  return { filename, text, value: JSON.parse(text.replace(/^\uFEFF/, '')) };
}

function readConfiguration(root) {
  localPath(root, 'Config/Catalog.json');
  const catalog = readCatalog(root);
  const sources = Object.fromEntries(tableNames.map(name => [name, readJson(root, `${tablesDirectory}/${name}.json`)]));
  for (const name of tableNames) {
    assert.equal(sources[name].value.name, name, `Unexpected table name in ${name}.json`);
    validateTable(sources[name].value, catalog);
  }
  const skills = sources.CombatSkillTable.value.rows;
  const icons = sources.BattleIconTable.value.rows;
  const recipes = sources.SkillIconRecipeTable.value.rows;
  const styles = sources.SkillIconStyleTable.value.rows;
  const recipeSkills = new Set(), slugs = new Set();
  for (const style of styles) {
    assert(style.prompt.trim(), `Style ${style.id}: prompt is empty`);
    assert(positiveInt(style.maxTextureSize) && style.maxTextureSize <= 8192 && (style.maxTextureSize & (style.maxTextureSize - 1)) === 0,
      `Style ${style.id}: maxTextureSize must be a power of two up to 8192`);
  }
  for (const recipe of recipes) {
    assert.equal(recipe.id, 10000 + recipe.skillId, `Recipe ${recipe.id}: id must equal 10000 + skillId`);
    assert(skills.some(skill => skill.id === recipe.skillId), `Recipe ${recipe.id}: missing skill ${recipe.skillId}`);
    assert(styles.some(style => style.id === recipe.styleId), `Recipe ${recipe.id}: missing style ${recipe.styleId}`);
    assert(slugPattern.test(recipe.slug), `Recipe ${recipe.id}: invalid slug`);
    assert(recipe.subject.trim(), `Recipe ${recipe.id}: subject is empty`);
    assert(!recipeSkills.has(recipe.skillId), `Duplicate recipe for skill ${recipe.skillId}`);
    assert(!slugs.has(recipe.slug), `Duplicate recipe slug ${recipe.slug}`);
    recipeSkills.add(recipe.skillId); slugs.add(recipe.slug);
  }
  for (const skill of skills) assert(icons.some(icon => icon.id === skill.iconId), `Skill ${skill.id}: missing BattleIconTable[${skill.iconId}]`);
  return { sources, catalog, skills, icons, recipes, styles };
}

function snapshot(config, recipe) {
  const { id, name, description } = config.skills.find(skill => skill.id === recipe.skillId);
  return { pipelineVersion: 1, recipe, style: config.styles.find(style => style.id === recipe.styleId), skill: { id, name, description } };
}

export function buildPrompt(recipe, style) {
  return `${style.prompt}\n\nSubject: ${recipe.subject}`;
}

function snapshotHash(value) {
  return digest(canonical({ pipelineVersion: value.pipelineVersion, recipe: value.recipe, style: value.style, skill: value.skill }));
}

function assetRelative(slug, version) { return `${assetsDirectory}/${slug}-v${version}.png`; }
function sourceRelative(slug, version) { return `${sourcesDirectory}/${slug}-v${version}.png`; }

function checkSnapshot(entry) {
  assert.equal(entry.pipelineVersion, 1, 'Unsupported skill icon pipeline version');
  assert(entry.recipe && entry.style && entry.skill, 'Missing recipe/style/skill snapshot');
  assert(positiveInt(entry.version), 'Invalid icon version');
  assert.equal(entry.recipeId, entry.recipe.id, 'Recipe snapshot id mismatch');
  assert.equal(entry.skillId, entry.recipe.skillId, 'Recipe snapshot skill mismatch');
  assert.equal(entry.skillId, entry.skill.id, 'Skill snapshot id mismatch');
  assert.equal(entry.recipeId, 10000 + entry.skillId, 'Invalid recipe id');
  assert.equal(entry.recipe.styleId, entry.style.id, 'Style snapshot id mismatch');
  assert(slugPattern.test(entry.recipe.slug), 'Invalid snapshot slug');
  assert.equal(entry.prompt, buildPrompt(entry.recipe, entry.style), 'Prompt does not match its snapshot');
  assert(isHash(entry.recipeHash) && entry.recipeHash === snapshotHash(entry), 'Invalid recipe snapshot hash');
  assert.equal(entry.maxTextureSize, entry.style.maxTextureSize, 'Import size does not match its style');
  assert.equal(entry.assetPath, assetRelative(entry.recipe.slug, entry.version), 'Invalid asset path');
}

function readManifest(root) {
  const filename = localPath(root, manifestRelative);
  const source = fs.existsSync(filename) ? readJson(root, manifestRelative) : { filename, text: null, value: { version: 1, entries: [] } };
  const manifest = source.value;
  assert(manifest.version === 1 && Array.isArray(manifest.entries), 'Invalid skill icon manifest');
  const versions = new Set(), paths = new Set(), images = new Set();
  for (const entry of manifest.entries) {
    checkSnapshot(entry);
    assert(isHash(entry.sourceHash) && isHash(entry.assetHash), 'Invalid published image hash');
    assert.equal(entry.sourceHash, entry.assetHash, 'Source and published asset must be identical');
    assert.equal(entry.sourcePath, sourceRelative(entry.recipe.slug, entry.version), 'Invalid source archive path');
    assert(entry.reviewed === true, 'Published icon is missing visual review');
    assert(positiveInt(entry.width) && entry.width === entry.height, 'Invalid published dimensions');
    assert(typeof entry.publishedAt === 'string' && Number.isFinite(Date.parse(entry.publishedAt)), 'Invalid publish timestamp');
    const key = `${entry.recipeId}:${entry.version}`;
    assert(!versions.has(key), `Duplicate published version ${key}`); versions.add(key);
    const imageKey = `${entry.recipeId}:${entry.recipeHash}:${entry.sourceHash}`;
    assert(!images.has(imageKey), `Duplicate recipe/image publication ${entry.recipeId}`); images.add(imageKey);
    for (const relative of [entry.sourcePath, entry.assetPath]) {
      assert(!paths.has(relative), `Duplicate published path ${relative}`); paths.add(relative);
      localPath(root, relative);
    }
  }
  return source;
}

function latestEntries(manifest) {
  const result = new Map();
  for (const entry of manifest.entries) if (!result.has(entry.recipeId) || result.get(entry.recipeId).version < entry.version) result.set(entry.recipeId, entry);
  return result;
}

function selectedSkills(config, skillIds) {
  if (skillIds === undefined) return config.skills;
  assert(Array.isArray(skillIds) && skillIds.length > 0 && skillIds.every(positiveInt), 'Provide positive skill IDs');
  assert.equal(new Set(skillIds).size, skillIds.length, 'Duplicate skill IDs');
  return skillIds.map(id => {
    const skill = config.skills.find(row => row.id === id);
    assert(skill, `Unknown skill ${id}`); return skill;
  });
}

function assertUnchanged(source) {
  if (source.text === null) assert(!fs.existsSync(source.filename), `File appeared during publish: ${source.filename}`);
  else assert.equal(fs.readFileSync(source.filename, 'utf8'), source.text, `File changed during operation: ${source.filename}`);
}

function atomicJson(filename, value, previousText = '') {
  const newline = previousText?.includes('\r\n') ? '\r\n' : '\n';
  const text = (JSON.stringify(value, null, 2) + '\n').replace(/\n/g, newline);
  fs.mkdirSync(path.dirname(filename), { recursive: true });
  const temporary = filename + `.${crypto.randomUUID()}.tmp`;
  fs.writeFileSync(temporary, text, { flag: 'wx' });
  fs.renameSync(temporary, filename);
}

export function prepare({ root = projectRoot, skillIds } = {}) {
  const config = readConfiguration(root);
  const manifest = readManifest(root).value;
  const latest = latestEntries(manifest);
  const skills = selectedSkills(config, skillIds).filter(skill => skillIds !== undefined || config.recipes.some(recipe => recipe.skillId === skill.id));
  const jobs = skills.map(skill => {
    const recipe = config.recipes.find(row => row.skillId === skill.id);
    assert(recipe, `Skill ${skill.id}: add a SkillIconRecipeTable row before preparing`);
    const data = snapshot(config, recipe);
    const version = (latest.get(recipe.id)?.version ?? 0) + 1;
    const jobPath = `${jobsDirectory}/${recipe.id}.json`;
    localPath(root, jobPath); localPath(root, assetRelative(recipe.slug, version));
    return { ...data, recipeId: recipe.id, skillId: skill.id, recipeHash: snapshotHash(data),
      prompt: buildPrompt(recipe, data.style), transparentBackground: true,
      maxTextureSize: data.style.maxTextureSize, version, assetPath: assetRelative(recipe.slug, version),
      preparedAt: new Date().toISOString(), jobPath };
  });
  for (const source of Object.values(config.sources)) assertUnchanged(source);
  for (const job of jobs) atomicJson(localPath(root, job.jobPath), job);
  return { jobs, next: 'Generate one image per job with the built-in image_gen tool, transparent_background=true. Visually review at 32 px and 64 px before publish --reviewed.' };
}

// Structural validation only; genuine transparency and visual simplicity require the explicit review gate.
export function inspectPng(bytes) {
  assert(Buffer.isBuffer(bytes) && bytes.length >= 45 && bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])), 'Expected a PNG image');
  let offset = 8, dimensions, hasData = false, ended = false;
  while (offset < bytes.length) {
    assert(offset + 12 <= bytes.length, 'Truncated PNG chunk');
    const length = bytes.readUInt32BE(offset), type = bytes.toString('ascii', offset + 4, offset + 8);
    assert(offset + length + 12 <= bytes.length, 'Truncated PNG data');
    assert.equal(crc32(bytes.subarray(offset + 4, offset + length + 8)), bytes.readUInt32BE(offset + length + 8), `PNG ${type} checksum mismatch`);
    if (offset === 8) assert(type === 'IHDR' && length === 13, 'PNG must begin with IHDR');
    if (type === 'IHDR') {
      assert(!dimensions && length === 13, 'Invalid PNG IHDR');
      const width = bytes.readUInt32BE(offset + 8), height = bytes.readUInt32BE(offset + 12);
      const bitDepth = bytes[offset + 16], colorType = bytes[offset + 17];
      assert(width > 0 && width === height && width <= 8192, 'PNG must be square, between 1 and 8192 pixels');
      assert([4, 6].includes(colorType), 'PNG must have an alpha channel (RGBA or grayscale + alpha)');
      assert([8, 16].includes(bitDepth) && bytes[offset + 18] === 0 && bytes[offset + 19] === 0 && bytes[offset + 20] <= 1, 'Unsupported PNG encoding');
      dimensions = { width, height, colorType, bitDepth };
    }
    if (type === 'IDAT' && length > 0) hasData = true;
    offset += length + 12;
    if (type === 'IEND') {
      assert(length === 0 && offset === bytes.length, 'Invalid PNG end'); ended = true; break;
    }
  }
  assert(dimensions && hasData && ended, 'PNG is missing image data or IEND');
  return dimensions;
}

function verifyImages(root, entry) {
  for (const [relative, hash] of [[entry.sourcePath, entry.sourceHash], [entry.assetPath, entry.assetHash]]) {
    const bytes = fs.readFileSync(localPath(root, relative));
    assert.equal(digest(bytes), hash, `Image hash mismatch: ${relative}`);
    const dimensions = inspectPng(bytes);
    assert.equal(dimensions.width, entry.width, `Image width mismatch: ${relative}`);
    assert.equal(dimensions.height, entry.height, `Image height mismatch: ${relative}`);
  }
}

function verifyMapping(config, entry) {
  const skill = config.skills.find(row => row.id === entry.skillId);
  assert(skill && skill.iconId === entry.recipeId, `Skill ${entry.skillId}: expected iconId ${entry.recipeId}`);
  const icon = config.icons.find(row => row.id === entry.recipeId);
  assert(icon && icon.spritePath === entry.assetPath, `BattleIconTable[${entry.recipeId}]: spritePath mismatch`);
}

export function publish({ root = projectRoot, skillId, image, job: jobFilename, reviewed = false } = {}) {
  assert(reviewed === true, 'Visual review is required: inspect transparency, clear meaning, and simplicity at 32/64 px, then pass --reviewed');
  assert(positiveInt(skillId), 'Provide one positive skill ID');
  assert(typeof image === 'string' && path.isAbsolute(image), '--image must be an absolute PNG path');
  const config = readConfiguration(root);
  const manifestSource = readManifest(root);
  const recipe = config.recipes.find(row => row.skillId === skillId);
  assert(recipe, `Skill ${skillId}: missing recipe`);
  const expectedJobPath = localPath(root, `${jobsDirectory}/${recipe.id}.json`);
  assert(typeof jobFilename === 'string' && path.resolve(root, jobFilename) === expectedJobPath, `--job must be the prepared job ${expectedJobPath}`);
  const jobSource = readJson(root, `${jobsDirectory}/${recipe.id}.json`);
  const job = jobSource.value;
  checkSnapshot(job);
  assert.equal(job.skillId, skillId, 'Job belongs to another skill');
  assert.equal(job.transparentBackground, true, 'Job must request a transparent background');
  const current = snapshot(config, recipe);
  assert.equal(job.recipeHash, snapshotHash(current), 'Prepared job is stale: recipe, style, or skill text changed; prepare again');
  const bytes = fs.readFileSync(image);
  const dimensions = inspectPng(bytes), imageHash = digest(bytes);
  const latest = latestEntries(manifestSource.value).get(recipe.id);
  const previous = manifestSource.value.entries.find(entry => entry.recipeId === recipe.id && entry.recipeHash === job.recipeHash && entry.sourceHash === imageHash);
  if (previous) {
    verifyImages(root, previous); verifyMapping(config, latest);
    return { state: previous.version === latest.version ? 'unchanged' : 'already-published', entry: previous,
      currentAssetPath: latest.assetPath, next: `Already published as version ${previous.version}; current version ${latest.version} was retained. No new version was created.` };
  }
  const version = (latest?.version ?? 0) + 1;
  assert.equal(job.version, version, 'Prepared job targets an old version; prepare again before publishing a new image');
  const entry = { ...current, recipeId: recipe.id, skillId, version, recipeHash: job.recipeHash,
    sourceHash: imageHash, assetHash: imageHash, prompt: job.prompt,
    sourcePath: sourceRelative(recipe.slug, version), assetPath: assetRelative(recipe.slug, version),
    width: dimensions.width, height: dimensions.height, maxTextureSize: current.style.maxTextureSize,
    publishedAt: new Date().toISOString(), reviewed: true };
  const sourcePath = localPath(root, entry.sourcePath), assetPath = localPath(root, entry.assetPath);
  assert(!fs.existsSync(sourcePath) && !fs.existsSync(assetPath), 'Version destination already exists; no files were overwritten');
  const iconTable = structuredClone(config.sources.BattleIconTable.value);
  let icon = iconTable.rows.find(row => row.id === recipe.id);
  if (!icon) { icon = { id: recipe.id }; iconTable.rows.push(icon); }
  icon.name = current.skill.name; icon.spritePath = entry.assetPath;
  const skillTable = structuredClone(config.sources.CombatSkillTable.value);
  skillTable.rows.find(row => row.id === skillId).iconId = recipe.id;
  validateTable(iconTable, config.catalog); validateTable(skillTable, config.catalog);
  verifyMapping({ skills: skillTable.rows, icons: iconTable.rows }, entry);
  // All input/path/image/config checks precede the first filesystem mutation.
  for (const source of [...Object.values(config.sources), manifestSource, jobSource]) assertUnchanged(source);
  fs.mkdirSync(path.dirname(sourcePath), { recursive: true });
  fs.mkdirSync(path.dirname(assetPath), { recursive: true });
  fs.writeFileSync(sourcePath, bytes, { flag: 'wx' });
  fs.writeFileSync(assetPath, bytes, { flag: 'wx' });
  atomicJson(config.sources.BattleIconTable.filename, iconTable, config.sources.BattleIconTable.text);
  atomicJson(config.sources.CombatSkillTable.filename, skillTable, config.sources.CombatSkillTable.text);
  atomicJson(manifestSource.filename, { ...manifestSource.value, entries: [...manifestSource.value.entries, entry] }, manifestSource.text);
  return { state: 'published', entry, next: 'Run node Tools/ConfigEditor/exporter.mjs, then the Unity skill-icon import menu to apply Sprite/Point settings and synchronize icon references.' };
}

function describeStatus(config, manifest, root, skillIds) {
  const latest = latestEntries(manifest);
  return selectedSkills(config, skillIds).map(skill => {
    const recipe = config.recipes.find(row => row.skillId === skill.id);
    if (!recipe) return { skillId: skill.id, name: skill.name, state: 'unconfigured', iconId: skill.iconId };
    const currentHash = snapshotHash(snapshot(config, recipe));
    const entry = latest.get(recipe.id);
    if (entry) return { skillId: skill.id, name: skill.name, recipeId: recipe.id, state: entry.recipeHash === currentHash ? 'published' : 'stale', version: entry.version, assetPath: entry.assetPath, iconId: skill.iconId };
    const jobRelative = `${jobsDirectory}/${recipe.id}.json`;
    let state = 'pending';
    if (fs.existsSync(localPath(root, jobRelative))) {
      const job = readJson(root, jobRelative).value;
      checkSnapshot(job); state = job.recipeHash === currentHash ? 'prepared' : 'stale-job';
    }
    return { skillId: skill.id, name: skill.name, recipeId: recipe.id, state, iconId: skill.iconId };
  });
}

export function status({ root = projectRoot, skillIds } = {}) {
  const config = readConfiguration(root);
  const rows = describeStatus(config, readManifest(root).value, root, skillIds);
  const counts = {};
  for (const row of rows) counts[row.state] = (counts[row.state] ?? 0) + 1;
  return { counts, skills: rows };
}

export function validate({ root = projectRoot } = {}) {
  const config = readConfiguration(root), manifest = readManifest(root).value;
  for (const entry of manifest.entries) verifyImages(root, entry);
  for (const entry of latestEntries(manifest).values()) {
    const recipe = config.recipes.find(row => row.id === entry.recipeId);
    assert(recipe, `Published recipe ${entry.recipeId} no longer exists`);
    assert.equal(entry.recipeHash, snapshotHash(snapshot(config, recipe)), `Published recipe ${entry.recipeId} is stale; prepare and publish a new version`);
    verifyMapping(config, entry);
  }
  const skills = describeStatus(config, manifest, root);
  return { valid: true, published: latestEntries(manifest).size, archivedVersions: manifest.entries.length,
    pending: skills.filter(skill => skill.state !== 'published'),
    note: 'File hashes, recipe snapshots, and current config mappings checked. Unity import settings and visual quality require their separate review.' };
}
