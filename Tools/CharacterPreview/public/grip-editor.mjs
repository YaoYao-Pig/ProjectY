import * as THREE from './vendor/three.module.min.js';
import { TransformControls } from './vendor/TransformControls.js';
import { applyGripPreview, unityPosition, unityRotation, toUnityRotation } from './grip-math.mjs';
import { adjustmentKey, rotationOffsetFor } from './hold-adjustments.mjs';

const $ = id => document.getElementById(id);
const fields = ['mainPosition','mainRotation','offPosition','offRotation'];
const values = row => Object.fromEntries(fields.map(k => [k, [...row[k]]]));
const round = n => Math.round(n * 1e6) / 1e6;

export class GripEditor {
  constructor({ scene, camera, canvas, controls, character, bones, pause, renderPose, bundle }) {
    Object.assign(this, { camera, controls, character, bones, pause, renderPose, bundle });
    this.rows = new Map(); this.initial = new Map(); this.adjustments = new Map(); this.pending = new Set(); this.roots = [];
    this.proxy = new THREE.Object3D(); character.add(this.proxy);
    this.handles = new TransformControls(camera, canvas); this.handles.setSize(.7); this.handles.setSpace('local'); scene.add(this.handles.getHelper());
    this.markers = [0xe0a23b, 0x43a6c0].map(color => {
      const marker = new THREE.Mesh(new THREE.SphereGeometry(.015, 12, 8), new THREE.MeshBasicMaterial({ color, depthTest: false }));
      marker.renderOrder = 20; marker.visible = false; character.add(marker); return marker;
    });
    this.handles.addEventListener('dragging-changed', event => {
      controls.enabled = !event.value;
      if (event.value) { this.pause(); this.dragRoot = this.selectedRoot().clone(); this.dragOffset = [...rotationOffsetFor(this.adjustments, this.selection().weapon, this.meta.moduleId)]; clearTimeout(this.timer); }
      else { this.scheduleSave(); this.renderPose(); }
    });
    this.handles.addEventListener('objectChange', () => {
      if (!this.handles.dragging || !this.dragRoot) return;
      const { row, prefix } = this.selection();
      const rootRotation = new THREE.Quaternion().setFromRotationMatrix(new THREE.Matrix4().extractRotation(this.dragRoot));
      if (prefix === 'weapon') {
        this.setRotation(toUnityRotation(unityRotation(this.dragOffset).multiply(rootRotation.invert()).multiply(this.proxy.quaternion)).map(round));
      } else if (this.handles.mode === 'translate') {
        const p = this.proxy.position.clone().applyMatrix4(this.dragRoot.clone().invert());
        row[prefix + 'Position'] = [p.x, p.y, -p.z].map(round);
      } else row[prefix + 'Rotation'] = toUnityRotation(rootRotation.invert().multiply(this.proxy.quaternion)).map(round);
      this.edited(false); this.fillInputs();
    });
    for (const kind of ['Position','Rotation']) for (const [i, axis] of ['X','Y','Z'].entries()) {
      const label = document.createElement('label'); label.textContent = axis;
      const input = document.createElement('input'); input.type = 'number'; input.step = kind === 'Position' ? '.005' : '1';
      input.id = `grip${kind}${axis}`; input.setAttribute('aria-label', `握点${kind === 'Position' ? '位置' : '旋转'} ${axis}`);
      input.addEventListener('input', () => {
        if (input.value.trim() === '' || !Number.isFinite(input.valueAsNumber)) { this.invalid = true; clearTimeout(this.timer); this.status('请输入完整、有限的坐标数值', true); return; }
        const { row, prefix, weapon } = this.selection();
        if (prefix === 'weapon') { const angles = [...rotationOffsetFor(this.adjustments, weapon, this.meta.moduleId)]; angles[i] = input.valueAsNumber; this.setRotation(angles); }
        else row[prefix + kind][i] = input.valueAsNumber;
        this.invalid = [...$('gripFields').querySelectorAll('input')].some(el => !el.disabled && (el.value.trim() === '' || !Number.isFinite(el.valueAsNumber)));
        if (this.invalid) return;
        this.pause();
        this.edited();
      });
      label.append(input); $(`grip${kind}`).append(label);
    }
    $('gripEnabled').onchange = () => { if ($('gripEnabled').checked) this.pause(); this.updateAvailability(); this.renderPose(); };
    $('gripTarget').onchange = () => { this.invalid = false; this.updateTarget(); this.fillInputs(); this.renderPose(); };
    for (const mode of ['translate','rotate']) $('grip' + mode).onclick = () => {
      this.setMode(mode);
    };
    $('gripFocus').onclick = () => {
      const point = this.proxy.getWorldPosition(new THREE.Vector3()), direction = camera.position.clone().sub(controls.target).normalize();
      controls.target.copy(point); camera.position.copy(point).addScaledVector(direction, 1.1); controls.update();
    };
    $('gripReset').onclick = () => { const { row, prefix } = this.selection(); this.invalid = false; if (prefix === 'weapon') this.setRotation(null); else Object.assign(row, values(this.initial.get(row.id))); this.edited(); this.fillInputs(); };
    $('gripRetry').onclick = () => { this.blocked = false; this.flush(); };
    $('gripReload').onclick = () => this.load(true).catch(e => this.status(e.message, true));
    $('gripExport').onclick = () => this.exportConfig();
    window.addEventListener('beforeunload', event => { if (this.pending.size || this.saving || this.invalid) { event.preventDefault(); event.returnValue = ''; } });
  }
  status(message, error = false) { $('gripStatus').textContent = message; $('gripStatus').classList.toggle('save-error', error); }
  async load(discard = false) {
    if (this.saving) return;
    if (discard && (this.pending.size || this.invalid) && !window.confirm('重新读取将丢弃尚未保存的握点草稿，继续？')) return;
    clearTimeout(this.timer);
    const response = await fetch('./api/grips', { cache: 'no-store' });
    if (response.status === 404) { this.available = false; this.status('独立静态预览无法写入工程。请通过本机角色工坊服务打开。'); this.updateAvailability(); return; }
    const data = await response.json(); if (!response.ok) throw new Error(data.error);
    this.token = data.token; this.revision = data.revision; this.weaponConfigs = data.weapons;
    this.rows = new Map(data.rows.map(row => [row.id, structuredClone(row)]));
    this.adjustments = new Map(data.adjustments.map(row => [adjustmentKey(row.weaponId,row.moduleId,row.hand), structuredClone(row)]));
    this.initial = new Map(data.rows.map(row => [row.id, structuredClone(row)]));
    this.available = true; this.blocked = false; this.invalid = false; this.pending.clear();
    this.status(new URLSearchParams(location.search).get('embed')==='1'&&window.parent!==window?'配置已读取 · 修改将加入内容中心草稿':'配置已读取 · 修改后自动保存'); this.setLoadout(this.loadout); this.renderPose();
  }
  setLoadout(loadout) {
    const previousTarget = this.loadout === loadout ? $('gripTarget').value : '';
    this.loadout = loadout; this.meta = loadout?.gripEditor?.version === 2 ? loadout.gripEditor : null; this.roots = [];
    $('gripTarget').replaceChildren();
    if (this.meta && this.available) {
      for (const weapon of this.meta.weapons) {
        if (!this.rows.has(weapon.gripId) || !this.weaponConfigs.some(w => w.id === weapon.itemId && w.gripId === weapon.gripId)) {
          this.meta = null; this.status('武器与握点的对应关系已变化，请在 Unity 重新导出网页资源。', true); break;
        }
        for (const prefix of weapon.slot === 'main' && this.meta.shared ? ['weapon','main','off'] : ['weapon','main']) {
          const option = document.createElement('option'); option.value = `${weapon.slot}:${prefix}`;
          option.textContent = `${weapon.slot === 'main' ? '主手武器' : '副手武器'} · ${{weapon:'武器朝向',main:'主握点',off:'第二握点'}[prefix]}（${prefix === 'weapon' ? weapon.itemId : weapon.gripId}）`; $('gripTarget').append(option);
        }
      }
    }
    $('gripHint').textContent = !loadout ? '先选择武器组合。' : !this.meta ? '此资源包缺少新版武器朝向数据，请在 Unity 重新「导出角色网页资源」。' : '武器朝向按型号、持握模组和主副手分别保存。几何握点仍由所有使用它的组合共享。';
    if ([...$('gripTarget').options].some(option => option.value === previousTarget)) $('gripTarget').value = previousTarget;
    this.updateAvailability(); this.updateSummary(); if (this.active()) { this.pause(); this.fillInputs(); }
  }
  active() { return Boolean(this.available && this.meta && $('gripEnabled').checked); }
  updateAvailability() {
    $('gripEnabled').disabled = !this.available || !this.meta;
    $('gripFields').disabled = !this.active();
    $('gripExport').disabled = !this.available || this.saving || Boolean(this.pending.size) || this.invalid;
    if (!this.active()) { this.handles.detach(); this.markers.forEach(m => m.visible = false); }
    else { this.handles.attach(this.proxy); this.updateTarget(); this.fillInputs(); }
  }
  selection() {
    const [slot, prefix] = $('gripTarget').value.split(':');
    const weapon = this.meta.weapons.find(w => w.slot === slot);
    return { weapon, row: this.rows.get(weapon.gripId), prefix };
  }
  selectedRoot() { return this.roots[this.meta.weapons.indexOf(this.selection().weapon)]; }
  setMode(mode) { this.handles.setMode(mode); for (const m of ['translate','rotate']) $('grip' + m).classList.toggle('selected', m === mode); }
  setRotation(rotationOffset) {
    const { weapon } = this.selection(), moduleId = this.meta.moduleId;
    this.adjustments.set(adjustmentKey(weapon.itemId,moduleId,weapon.slot), { weaponId: weapon.itemId, moduleId, hand: weapon.slot, rotationOffset });
  }
  updateTarget() {
    if (!this.active()) return;
    const { prefix, weapon } = this.selection(), orientation = prefix === 'weapon';
    $('gripPositionLabel').hidden = orientation; $('gripPosition').hidden = orientation;
    for (const axis of ['X','Y','Z']) {
      $('gripPosition' + axis).disabled = orientation;
      $('gripRotation' + axis).setAttribute('aria-label', `${orientation ? '武器' : '握点'}旋转 ${axis}`);
    }
    $('griptranslate').disabled = orientation;
    if (orientation) this.setMode('rotate');
    $('gripRotationLabel').textContent = orientation ? '武器朝向偏移 / 度' : '手掌握点旋转 / 度';
    $('gripReset').textContent = orientation ? '恢复模组默认朝向' : '恢复本次打开时的值';
    const hasOverride = this.adjustments.get(adjustmentKey(weapon.itemId,this.meta.moduleId,weapon.slot))?.rotationOffset != null;
    $('gripScope').textContent = orientation ? `仅修改：武器 ${weapon.itemId} · ${this.loadout.moduleName} · ${weapon.slot === 'main' ? '主手' : '副手'}\n${hasOverride ? '使用专属旋转修正' : '继承模组默认朝向'}` : `共享几何握点 ${weapon.gripId} · 修改会影响所有引用它的组合`;
  }
  fillInputs() {
    if (!this.active()) return;
    const { row, prefix, weapon } = this.selection();
    for (const kind of ['Position','Rotation']) for (const [i, axis] of ['X','Y','Z'].entries()) {
      const vector = prefix === 'weapon' ? kind === 'Position' ? row.mainPosition : rotationOffsetFor(this.adjustments,weapon,this.meta.moduleId) : row[prefix + kind];
      $(`grip${kind}${axis}`).value = round(vector[i]);
    }
  }
  updateSummary() {
    if (!this.available || !this.meta) return;
    const main = this.rows.get(this.meta.weapons.find(w => w.slot === 'main').gripId);
    const offWeapon = this.meta.weapons.find(w => w.slot === 'off');
    const off = offWeapon ? this.rows.get(offWeapon.gripId).mainPosition : main.offPosition;
    $('gripSummary').textContent = `动作模组：${this.loadout.moduleName}\n主握点：${main.mainPosition.map(v=>v.toFixed(3)).join(' / ')} m\n副握点：${off.map(v=>v.toFixed(3)).join(' / ')} m`;
  }
  edited(save = true) {
    const { row, prefix, weapon } = this.selection();
    this.pending.add(prefix === 'weapon' ? adjustmentKey(weapon.itemId,this.meta.moduleId,weapon.slot) : row.id); this.status(this.blocked ? '保存已暂停，草稿保留；请重试或重新读取。' : '有修改 · 等待自动保存', this.blocked);
    $('gripExport').disabled = true; this.updateTarget(); this.updateSummary(); this.renderPose(); if (save) this.scheduleSave();
  }
  scheduleSave() { clearTimeout(this.timer); if (!this.blocked && !this.invalid) { if(new URLSearchParams(location.search).get('embed')==='1'&&window.parent!==window) this.flush(); else this.timer = setTimeout(() => this.flush(), 650); } }
  async request(url, method, input) {
    const response = await fetch(url, { method, headers: { 'Content-Type': 'application/json', 'X-Editor-Token': this.token }, body: JSON.stringify(input) });
    const data = await response.json(); if (!response.ok) throw new Error(data.error || '保存失败'); return data;
  }
  async flush() {
    if (this.saving || this.blocked || this.invalid || this.handles.dragging || !this.pending.size) return;
    if (new URLSearchParams(location.search).get('embed') === '1' && window.parent !== window) {
      const changes = [...this.pending].map(id => typeof id === 'string' ? { kind: 'adjustment', row: structuredClone(this.adjustments.get(id)) } : { kind: 'grip', row: structuredClone(this.rows.get(id)) });
      window.parent.postMessage({ type: 'content-grips', changes }, location.origin);
      this.pending.clear(); this.status('已加入内容中心草稿 · 请在内容中心保存并导出'); return;
    }
    this.saving = true;
    try {
      while (this.pending.size && !this.invalid && !this.handles.dragging) {
        const id = this.pending.values().next().value, orientation = typeof id === 'string';
        const current = () => orientation ? this.adjustments.get(id) : values(this.rows.get(id));
        const snapshot = structuredClone(current());
        this.status(`正在保存${orientation ? '武器朝向' : '握点'} ${id}…`);
        const result = await this.request(orientation ? './api/hold-adjustments' : './api/grips', 'PUT', orientation ? { ...snapshot, revision: this.revision } : { id, revision: this.revision, values: snapshot });
        this.revision = result.revision;
        $('source').textContent = '握点配置已保存 · Unity 网页资源重新导出后更新基准采样'; $('source').style.color = '#946338';
        if (JSON.stringify(snapshot) === JSON.stringify(current())) this.pending.delete(id);
      }
      if (!this.pending.size) this.status('已自动保存到工程配置 · 游戏生效前请导出配置');
    } catch (error) { this.blocked = true; this.status(error.message + '（草稿保留）', true); }
    finally { this.saving = false; $('gripExport').disabled = Boolean(this.pending.size) || this.invalid; }
  }
  async exportConfig() {
    if (new URLSearchParams(location.search).get('embed') === '1' && window.parent !== window) { this.status('请回到内容中心统一保存并导出'); return; }
    if (this.pending.size || this.saving || this.invalid) return;
    $('gripExport').disabled = true;
    try { await this.request('./api/grips/export', 'POST', { revision: this.revision }); this.status('已导出游戏配置；重新加载游戏配置后生效。网页动作采样可在 Unity 重新导出。'); }
    catch (error) { this.status(error.message, true); }
    finally { $('gripExport').disabled = false; }
  }
  render(meshes) {
    if (!this.meta || !this.available) return;
    this.roots = applyGripPreview(this.meta, this.rows, this.bones, meshes, this.adjustments);
    if (!this.active()) return;
    const { row, prefix } = this.selection(), root = this.selectedRoot();
    for (const [i, name] of ['main','off'].entries()) {
      this.markers[i].visible = i === 0 || this.meta.shared;
      this.markers[i].position.copy(unityPosition(row[name + 'Position']).applyMatrix4(root));
    }
    if (!this.handles.dragging) {
      this.proxy.position.copy(unityPosition(row[(prefix === 'weapon' ? 'main' : prefix) + 'Position']).applyMatrix4(root));
      this.proxy.quaternion.setFromRotationMatrix(new THREE.Matrix4().extractRotation(root));
      if (prefix !== 'weapon') this.proxy.quaternion.multiply(unityRotation(row[prefix + 'Rotation']));
    }
  }
}
