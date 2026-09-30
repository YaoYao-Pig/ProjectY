import * as THREE from 'three';
import { OrbitControls } from './vendor/OrbitControls.js';
import { options, randomize, validate, tint } from './rules.mjs';
import { GripEditor } from './grip-editor.mjs';

const $ = id => document.getElementById(id);
const fail = error => { $('error').textContent = error.message || String(error); $('error').hidden = false; };
const clearError = () => { $('error').hidden = true; };
let bundle, descriptor, clip, playing = true, time = 0, models = [], animationButtons = [];
let rigidModels = [];
let gripEditor;
const gear = { head: '', chest: '', back: '', legs: false, feet: false, weapon: '' };
const pawnPath = 'Assets/DynamicAsset/PawnLowPoly/Models/', equipmentPath = 'Assets/DynamicAsset/EquipmentDemo/Models/';
let scene, camera, renderer, controls, character, bones, skeleton, platform;
const geometryCache = new Map();
const previousPosition = new THREE.Vector3(), nextPosition = new THREE.Vector3(), previousRotation = new THREE.Quaternion(), nextRotation = new THREE.Quaternion();
const previousScale = new THREE.Vector3(), nextScale = new THREE.Vector3();

function button(label, selected, callback, parent) {
  const b = document.createElement('button'); b.textContent = label; b.className = selected ? 'selected' : '';
  b.setAttribute('aria-pressed', String(selected)); b.addEventListener('click', () => { try { clearError(); callback(); } catch (e) { fail(e); } }); parent.append(b); return b;
}
function renderControls() {
  const rules = bundle.rules;
  const group = (id, items, current, callback) => { const root = $(id); root.replaceChildren(); for (const item of items) button(item.label, item.id === current, () => callback(item.id), root); };
  function changeIdentity(key, value) {
    descriptor[key] = value;
    const build = descriptor.body.slice(-1), face = descriptor.head.slice(-1);
    descriptor.body = `body_${descriptor.sex}_${build}`;
    descriptor.head = `head_${descriptor.race}_${descriptor.sex}_${face}`;
    if (!options(rules, 'hair', descriptor.race, descriptor.sex).some(m => m.id === descriptor.hair)) descriptor.hair = 'none';
    descriptor.skin = Math.min(descriptor.skin, rules.races.find(r => r.id === descriptor.race).colors.length - 1);
    apply();
  }
  group('races', rules.races, descriptor.race, v => changeIdentity('race', v));
  group('sex', [{ id: 'male', label: '男性' }, { id: 'female', label: '女性' }], descriptor.sex, v => changeIdentity('sex', v));
  for (const slot of ['body', 'head', 'hair']) group(slot, options(rules, slot, descriptor.race, descriptor.sex), descriptor[slot], v => { descriptor[slot] = v; apply(); });
  const palettes = { skin: rules.races.find(r => r.id === descriptor.race).colors, hairColor: rules.hairColors, clothColor: rules.clothColors };
  for (const [key, colors] of Object.entries(palettes)) {
    const root = $(key); root.replaceChildren();
    colors.forEach((color, i) => { const b = button('', descriptor[key] === i, () => { descriptor[key] = i; apply(); }, root); b.style.background = color; b.title = color; b.setAttribute('aria-label', `${{ skin: '肤色', hairColor: '发色', clothColor: '衣服颜色' }[key]} ${i + 1}`); });
  }
  const race = rules.races.find(r => r.id === descriptor.race);
  $('characterName').textContent = `${race.label} · ${descriptor.sex === 'male' ? '男性' : '女性'}`;
  $('characterSubtitle').textContent = [descriptor.body, descriptor.head, descriptor.hair].map(id => rules.modules.find(m => m.id === id).label).join(' / ');
  $('seed').value = descriptor.seed;
}
function geometry(part) {
  if (geometryCache.has(part.id)) return geometryCache.get(part.id);
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(part.positions, 3));
  g.setAttribute('normal', new THREE.Float32BufferAttribute(part.normals, 3));
  if (!part.rigid) { g.setAttribute('skinIndex', new THREE.Uint16BufferAttribute(part.joints, 4)); g.setAttribute('skinWeight', new THREE.Float32BufferAttribute(part.weights, 4)); }
  const indices = [];
  part.groups.forEach((group, i) => { g.addGroup(indices.length, group.indices.length, i); indices.push(...group.indices); });
  g.setIndex(indices); geometryCache.set(part.id, g); return g;
}
function apply() {
  validate(bundle.rules, descriptor);
  let mask = 0, coveredHair = false;
  const fits = [gear.head, gear.chest, gear.back, gear.legs ? equipmentPath + 'Equip_Trousers.fbx' : '', gear.feet ? equipmentPath + 'Equip_Boots.fbx' : ''].filter(Boolean).map(path => {
    const fit = bundle.gearFits.find(f => f.sourcePath === path && (!f.body || f.body === descriptor.body) && (!f.race || f.race === descriptor.race));
    if (!fit) throw new Error('当前体型或种族缺少装备贴合资源：' + path);
    mask |= fit.coverage; coveredHair ||= fit.hideHair; return fit;
  });
  const body = mask ? bundle.coveredBodies.find(b => b.body === descriptor.body && b.mask === mask)?.id : descriptor.body;
  if (!body) throw new Error('缺少装备遮挡身体网格');
  const ids = [body, descriptor.head, coveredHair ? 'none' : descriptor.hair, ...fits.map(f => f.id)];
  const parts = ids.filter(id => id !== 'none').map(id => {
    const p = bundle.meshes.find(m => m.id === id); if (!p) throw new Error('Unity 导出包缺少网格：' + id); return p;
  });
  const loadout = bundle.loadouts.find(l => l.id === gear.weapon);
  $('gripSummary').textContent = loadout ? `动作模组：${loadout.moduleName}\n主握点：${loadout.primaryGrip.slice(0,3).map(v=>v.toFixed(3)).join(' / ')} m\n副握点：${loadout.secondaryGrip.slice(0,3).map(v=>v.toFixed(3)).join(' / ')} m` : '空手模组';
  if (loadout) parts.push(...loadout.meshes);
  for (const mesh of models) { character.remove(mesh); mesh.material.forEach(m => m.dispose()); }
  models = parts.map(part => {
    const materials = part.groups.map(group => {
      const color = fits.some(f => f.id === part.id) ? group.material.color : tint(bundle.rules, descriptor, group.material.role, group.material.color);
      const c = typeof color === 'string' ? new THREE.Color(color) : new THREE.Color().setRGB(...color, THREE.SRGBColorSpace);
      return new THREE.MeshStandardMaterial({ color: c, roughness: .88, metalness: 0 });
    });
    const mesh = part.rigid ? new THREE.Mesh(geometry(part), materials) : new THREE.SkinnedMesh(geometry(part), materials); mesh.name = part.id;
    if (!part.rigid) mesh.bind(skeleton, new THREE.Matrix4()); mesh.frustumCulled = false; mesh.castShadow = true; mesh.receiveShadow = true;
    character.add(mesh); return mesh;
  });
  rigidModels = models.filter(m => !m.isSkinnedMesh);
  const triangles = parts.reduce((sum, part) => sum + part.groups.reduce((n, g) => n + g.indices.length / 3, 0), 0);
  $('modelCount').textContent = `${parts.length} MODULES · ${triangles.toLocaleString()} TRIANGLES`;
  $('gearNote').textContent = coveredHair ? '头饰覆盖发型，卸下后恢复。试穿不改变角色存档中的装备。' : '仅试穿，不改变角色存档中的装备。';
  gripEditor?.setLoadout(loadout);
  renderControls(); renderPose();
}
function currentAnimations() { return bundle.loadouts.find(l => l.id === gear.weapon)?.animations ?? bundle.animations; }
function setupGearControls() {
  const labels = { 'Pawn_Helmet.fbx': '头盔', 'Pawn_Hood.fbx': '兜帽', 'Pawn_MageHat.fbx': '法师帽', 'Pawn_ArmorPlate.fbx': '板甲', 'Pawn_ArmorLeather.fbx': '皮甲', 'Pawn_ArmorRobe.fbx': '法袍', 'Pawn_Cape.fbx': '披风', 'Pawn_Quiver.fbx': '箭袋' };
  const fill = (element, rows) => { element.replaceChildren(); for (const row of [{ id: '', label: '无' }, ...rows]) { const option = document.createElement('option'); option.value = row.id; option.textContent = row.label; element.append(option); } };
  for (const [slot, id] of [['head', 'gearHead'], ['chest', 'gearChest'], ['back', 'gearBack']]) {
    const paths = [...new Set(bundle.gearFits.filter(f => f.slot === slot).map(f => f.sourcePath))];
    fill($(id), paths.map(path => ({ id: path, label: labels[path.split('/').at(-1)] ?? path.split('/').at(-1) })));
    $(id).onchange = () => { try { clearError(); gear[slot] = $(id).value; apply(); fitCharacter(); } catch (e) { fail(e); } };
  }
  for (const [slot, id] of [['legs', 'gearLegs'], ['feet', 'gearFeet']]) $(id).onchange = () => { try { gear[slot] = $(id).checked; apply(); } catch (e) { fail(e); } };
  fill($('gearWeapon'), bundle.loadouts);
  $('gearWeapon').onchange = () => { try { gear.weapon = $('gearWeapon').value; rigidModels = []; gripEditor?.setLoadout(null); rebuildAnimations(); apply(); fitCharacter(); } catch (e) { fail(e); } };
}
function rebuildAnimations() {
  $('animations').replaceChildren();
  animationButtons = currentAnimations().map(c => { const b = button(c.label, c.id === 'Idle', () => selectClip(c.id), $('animations')); b.dataset.clip = c.id; return b; });
  selectClip('Idle');
}
function renderPose() {
  if (!clip) return;
  const cursor = THREE.MathUtils.clamp(time / clip.duration, 0, 1) * (clip.frameCount - 1), a = Math.floor(cursor), b = Math.min(a + 1, clip.frameCount - 1), alpha = cursor - a;
  for (let i = 0; i < bones.length; i++) {
    const offsetA = (a * bones.length + i) * 10, offsetB = (b * bones.length + i) * 10;
    previousPosition.fromArray(clip.poses, offsetA); nextPosition.fromArray(clip.poses, offsetB);
    previousRotation.fromArray(clip.poses, offsetA + 3); nextRotation.fromArray(clip.poses, offsetB + 3);
    previousScale.fromArray(clip.poses, offsetA + 7); nextScale.fromArray(clip.poses, offsetB + 7);
    bones[i].position.lerpVectors(previousPosition, nextPosition, alpha);
    bones[i].quaternion.slerpQuaternions(previousRotation, nextRotation, alpha);
    bones[i].scale.lerpVectors(previousScale, nextScale, alpha);
  }
  if (rigidModels.length) {
    if (!clip.attachmentPoses || clip.attachmentPoses.length !== clip.frameCount * rigidModels.length * 10) throw new Error('武器挂点采样不完整');
    for (let i = 0; i < rigidModels.length; i++) {
      const offsetA = (a * rigidModels.length + i) * 10, offsetB = (b * rigidModels.length + i) * 10;
      previousPosition.fromArray(clip.attachmentPoses, offsetA); nextPosition.fromArray(clip.attachmentPoses, offsetB);
      previousRotation.fromArray(clip.attachmentPoses, offsetA + 3); nextRotation.fromArray(clip.attachmentPoses, offsetB + 3);
      previousScale.fromArray(clip.attachmentPoses, offsetA + 7); nextScale.fromArray(clip.attachmentPoses, offsetB + 7);
      rigidModels[i].position.lerpVectors(previousPosition, nextPosition, alpha); rigidModels[i].quaternion.slerpQuaternions(previousRotation, nextRotation, alpha); rigidModels[i].scale.lerpVectors(previousScale, nextScale, alpha);
    }
  }
  gripEditor?.render(rigidModels);
  $('timeline').value = Math.round(time / clip.duration * 1000);
  $('time').textContent = `${time.toFixed(2)} / ${clip.duration.toFixed(2)} s`;
}
function selectClip(id) {
  clip = currentAnimations().find(c => c.id === id); if (!clip) throw new Error('动作不存在');
  platform.visible = clip.id === 'Idle';
  time = 0; playing = true; $('play').textContent = 'Ⅱ';
  animationButtons.forEach(b => { const selected = b.dataset.clip === id; b.classList.toggle('selected', selected); b.setAttribute('aria-pressed', String(selected)); });
  renderPose();
}
function fitCharacter() {
  if (!models.length) return;
  character.updateMatrixWorld(true); skeleton.update();
  const box = new THREE.Box3(); for (const model of models) box.expandByObject(model, true);
  const center = box.getCenter(new THREE.Vector3()), size = box.getSize(new THREE.Vector3());
  const direction = camera.position.clone().sub(controls.target).normalize();
  const distance = Math.min(8, Math.max(2, size.length() * .5 / Math.sin(THREE.MathUtils.degToRad(camera.fov / 2)) * 1.12));
  controls.target.copy(center); camera.position.copy(center).addScaledVector(direction, distance); controls.update();
}
function resetCamera() { camera.position.set(2.6, 1.85, -4.9); controls.target.set(0, .99, 0); controls.update(); if (models.length) fitCharacter(); }
function setupScene() {
  scene = new THREE.Scene(); camera = new THREE.PerspectiveCamera(30, 1, .01, 100);
  renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: false });
  renderer.setPixelRatio(Math.min(devicePixelRatio, 2)); renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.shadowMap.enabled = true; renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  renderer.toneMapping = THREE.ACESFilmicToneMapping; renderer.toneMappingExposure = 1.3;
  $('viewport').append(renderer.domElement); controls = new OrbitControls(camera, renderer.domElement);
  controls.enableDamping = true; controls.dampingFactor = .08; controls.minDistance = .3; controls.maxDistance = 8; controls.maxPolarAngle = Math.PI * .9;
  resetCamera(); scene.add(new THREE.HemisphereLight(0xf4f5e5, 0x6b7969, 2));
  const key = new THREE.DirectionalLight(0xffedd9, 3); key.position.set(-3, 5, -4); key.castShadow = true;
  key.shadow.mapSize.set(1024, 1024); key.shadow.camera.left = -2; key.shadow.camera.right = 2; key.shadow.camera.top = 3; key.shadow.camera.bottom = -1; key.shadow.bias = -.0005; scene.add(key);
  const fill = new THREE.DirectionalLight(0xc2d6d0, 1.5); fill.position.set(3, 3, 3); scene.add(fill);
  platform = new THREE.Mesh(new THREE.CylinderGeometry(.61, .64, .10, 12), new THREE.MeshStandardMaterial({ color: 0xb2b9a5, roughness: .95 }));
  platform.position.y = .03; platform.receiveShadow = true; platform.castShadow = true; scene.add(platform);
  // The display stand is decorative. Hide it during actions so it cannot occlude the actual exported pose.
  const floor = new THREE.Mesh(new THREE.PlaneGeometry(200, 200), new THREE.ShadowMaterial({ opacity: .12 })); floor.rotation.x = -Math.PI / 2; floor.position.y = -.03; floor.receiveShadow = true; scene.add(floor);
  character = new THREE.Group(); character.position.fromArray(bundle.rootOffset); scene.add(character);
  bones = bundle.bones.map(name => { const bone = new THREE.Bone(); bone.name = name; character.add(bone); return bone; });
  const inverses = bones.map((_, i) => new THREE.Matrix4().fromArray(bundle.meshes[0].bindposes, i * 16)); skeleton = new THREE.Skeleton(bones, inverses);
  const resize = () => { const rect = $('viewport').getBoundingClientRect(); camera.aspect = rect.width / rect.height; camera.updateProjectionMatrix(); renderer.setSize(rect.width, rect.height); };
  new ResizeObserver(resize).observe($('viewport')); resize();
  let last = performance.now();
  renderer.setAnimationLoop(now => {
    const dt = Math.max(0, Math.min((now - last) / 1000, .08)); last = now;
    if (clip && playing) {
      time += dt * Number($('speed').value);
      if (time >= clip.duration) { if (clip.loop) time %= clip.duration; else { time = clip.duration; playing = false; $('play').textContent = '▶'; } }
      renderPose();
    }
    controls.update(); renderer.render(scene, camera);
  });
}
async function checkSources() {
  // A copied static deployment remains usable; the Node service adds source freshness checking.
  let response;
  try { response = await fetch('./api/source-status', { cache: 'no-store' }); }
  catch { $('source').textContent = '独立资源包 · 无法检查工程更新'; return; }
  if (response.status === 404) { $('source').textContent = '独立资源包 · 导出于 ' + new Date(bundle.exportedAt).toLocaleString('zh-CN'); return; }
  if (!response.ok) throw new Error('无法核对资源来源');
  const state = await response.json();
  $('source').textContent = state.stale ? `源资源有 ${state.changed.length} 项变化，请在 Unity 重新同步并导出` : `Unity ${bundle.unityVersion} · 29 个角色模块 / ${bundle.gearFits.length} 个装备适配 · 已同步`;
  $('source').style.color = state.stale ? '#946338' : '';
  $('provenance').textContent = `导出时间：${new Date(bundle.exportedAt).toLocaleString('zh-CN')}\n${bundle.source}\n` + bundle.meshes.map(m => m.path).join('\n') + (state.stale ? '\n已变化：\n' + state.changed.join('\n') : '');
}
function download() {
  validate(bundle.rules, descriptor); const url = URL.createObjectURL(new Blob([JSON.stringify(descriptor, null, 2)], { type: 'application/json' }));
  const a = document.createElement('a'); a.href = url; a.download = `${descriptor.race}-${descriptor.sex}-${descriptor.seed}.json`; a.click(); setTimeout(() => URL.revokeObjectURL(url), 1000);
}
async function start() {
  const response = await fetch('./data/characters.json', { cache: 'no-store' }); if (!response.ok) throw new Error('尚未找到 Unity 资源包，请先在 Unity 执行「导出角色网页资源」。');
  bundle = await response.json(); if (bundle.version !== 1 || bundle.bones.length !== 23 || !bundle.meshes.length) throw new Error('角色资源包格式无效');
  descriptor = { version: bundle.rules.version, seed: 20260927, race: 'human', sex: 'female', body: 'body_female_1', head: 'head_human_female_0', hair: 'hair_2', skin: 0, hairColor: 1, clothColor: 0 };
  setupScene();
  gripEditor = new GripEditor({ scene, camera, canvas: renderer.domElement, controls, character, bones, bundle, renderPose,
    pause: () => { playing = false; $('play').textContent = '▶'; } });
  setupGearControls(); rebuildAnimations(); apply(); fitCharacter(); $('loading').hidden = true;
  await gripEditor.load().catch(e => gripEditor.status('无法读取握点配置：' + e.message, true));
  const query = new URLSearchParams(location.search);
  if (query.has('item')) {
    const itemId = Number(query.get('item'));
    const loadout = bundle.loadouts.find(l => l.gripEditor?.weapons.some(w => w.slot === 'main' && w.itemId === itemId));
    if (loadout) { gear.weapon = loadout.id; $('gearWeapon').value = loadout.id; rebuildAnimations(); apply(); fitCharacter(); }
    else fail(new Error('此武器尚未导出持握预览；请在内容中心同步 Unity 资源后重开。'));
  }
  if (query.get('embed') === '1' && window.parent !== window) {
    // Same-origin integration only. Parent owns the content draft and decides when to save.
    const use = document.createElement('button'); use.textContent = '将当前外观应用到角色草稿'; use.className = 'button outline';use.hidden=query.has('item');
    use.onclick = () => { validate(bundle.rules, descriptor); window.parent.postMessage({ type: 'content-appearance', descriptor }, location.origin); };
    document.querySelector('header').append(use);
    window.addEventListener('message', event => {
      if (event.origin !== location.origin || event.source !== window.parent) return;
      if (event.data?.type === 'content-grips-load') {
        for (const row of event.data.rows) if (gripEditor.rows.has(row.id)) gripEditor.rows.set(row.id, structuredClone(row));
        gripEditor.adjustments.clear();
        for (const row of event.data.adjustments) gripEditor.adjustments.set(`${row.weaponId}:${row.moduleId}:${row.hand}`, structuredClone(row));
        gripEditor.setLoadout(gripEditor.loadout); renderPose(); return;
      }
      if (event.data?.type !== 'content-appearance-load') return;
      try { descriptor = structuredClone(validate(bundle.rules, event.data.descriptor)); apply(); } catch (error) { fail(error); }
    });
    window.parent.postMessage({ type: 'content-character-ready' }, location.origin);
  }
  for (const id of ['random', 'replay', 'export']) $(id).disabled = false;
  const generate = fresh => {
    const seed = fresh ? crypto.getRandomValues(new Uint32Array(1))[0] & 0x7fffffff : Number($('seed').value);
    descriptor = randomize(bundle.rules, seed, $('lockRace').checked ? descriptor.race : undefined, $('lockSex').checked ? descriptor.sex : undefined); apply();
  };
  $('random').onclick = () => { try { clearError(); generate(true); } catch (e) { fail(e); } };
  $('replay').onclick = () => { try { clearError(); generate(false); } catch (e) { fail(e); } };
  $('export').onclick = () => { validate(bundle.rules, descriptor); $('exportJson').value = JSON.stringify(descriptor, null, 2); $('copyStatus').textContent = ''; $('exportDialog').showModal(); };
  $('downloadJson').onclick = download;
  $('copyJson').onclick = async () => { try { await navigator.clipboard.writeText($('exportJson').value); $('copyStatus').textContent = '已复制'; } catch { $('exportJson').select(); $('copyStatus').textContent = '请按 Ctrl+C 复制'; } };
  $('import').onchange = async event => { try { const file = event.target.files[0]; if (!file) return; const next = validate(bundle.rules, JSON.parse(await file.text())); descriptor = structuredClone(next); apply(); clearError(); } catch (e) { fail(e); } finally { event.target.value = ''; } };
  $('resetCamera').onclick = resetCamera;
  $('play').onclick = () => { if (time >= clip.duration) time = 0; playing = !playing; $('play').textContent = playing ? 'Ⅱ' : '▶'; };
  $('timeline').oninput = () => { playing = false; $('play').textContent = '▶'; time = Number($('timeline').value) / 1000 * clip.duration; renderPose(); };
  $('refresh').onclick = () => checkSources().catch(fail);
  await checkSources();
}
start().catch(fail);
