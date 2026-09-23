// 使用真实导表器、工程 xLua 与 Lua 源码验证预览链路，不复制算法作为预期值。
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { projectRoot } from '../../ConfigEditor/exporter.mjs';
import { generatePreview, createPreviewServer } from '../server.mjs';
import { buildingFootprint } from '../public/renderer.js';

// 相同种子与源码应重现布局，且不改写 Unity 工程的导表产物。
test('preview uses real config binaries and project Lua with deterministic output', async () => {
  const output = path.join(projectRoot, 'Assets/GameFramework/Resources/_Gen/Config/MapRegionTable.bytes');
  const before = fs.readFileSync(output);
  const input = { seed: 20260921, regionIds: [1, 2, 3, 4] };
  const first = await generatePreview(input), second = await generatePreview(input);
  assert.deepEqual(first.cells, second.cells); assert.deepEqual(first.borders, second.borders); assert.deepEqual(first.waterBodies, second.waterBodies);
  assert.deepEqual(first.towns, second.towns); assert.deepEqual(first.buildings, second.buildings); assert.deepEqual(first.roads, second.roads);
  assert.deepEqual(first.roadNetworks, second.roadNetworks);
  assert.ok(first.towns.length > 1 && first.buildings.length > 0 && first.roads.length > 0);
  for (const building of first.buildings) {
    assert.ok(first.towns[building.townId - 1].buildings.includes(building.id));
    for (const id of building.cells) assert.equal(first.cells[id - 1].buildingId, building.id);
    // 合并顶面的面积必须等于实际占地总面积，边界不包含内部共享边。
    const plot = buildingFootprint(building, first), points = plot.outline;
    const area = Math.abs(points.reduce((sum, p, i) => {
      const next = points[(i + 1) % points.length]; return sum + p.x * next.z - next.x * p.z;
    }, 0)) / 2;
    assert.ok(Math.abs(area - building.cells.length * 3 * Math.sqrt(3) / 2 * first.hexRadius ** 2) < 1e-6);
    assert.equal(plot.edges.length, 6 + 12 * building.footprintRadius);
    for (const edge of plot.edges) assert.ok(!building.cells.includes(edge.neighbor));
  }
  for (const town of first.towns) assert.match(town.groundColor, /^#[0-9a-f]{6}$/i);
  for (const road of first.roads) for (const id of road.cells) {
    assert.ok(first.cells[id - 1].roadIds.includes(road.id));
    assert.equal(first.cells[id - 1].waterLevel, undefined); assert.equal(first.cells[id - 1].buildingId, undefined);
  }
  assert.equal(first.sourceRevision, second.sourceRevision);
  assert.equal(first.regions.length, 4); assert.ok(first.cells.length > 0);
  assert.ok(first.waterBodies.length > 0); assert.ok(first.stats.waterCellCount > 0);
  assert.deepEqual(first.regions[0].enemies, []);
  assert.equal(first.regions[0].buildings[0].name, '地牢入口');
  assert.equal(first.assets.length, 19);
  assert.deepEqual(first.rivers, second.rivers); assert.deepEqual(first.decorations, second.decorations);
  for (const decoration of first.decorations) {
    assert.ok(first.cells[decoration.cell - 1]); assert.ok(first.assets.some(asset => asset.id === decoration.assetId));
  }
  for (const cell of first.cells) {
    assert.equal(cell.neighbors.length, 6);
    for (const neighbor of cell.neighbors.filter(Boolean)) assert.ok(first.cells[neighbor - 1]);
    assert.ok(cell.biomeWeights.length > 0);
    if (cell.waterLevel !== undefined) assert.ok(cell.waterLevel > cell.height && cell.waterDepth > 0);
  }
  assert.deepEqual(fs.readFileSync(output), before, 'Preview must not rewrite Unity config assets');
});

// 只修改临时副本，分别验证配表变化与算法源码变化会进入下一次生成。
test('saved config and algorithm edits are both picked up by a fresh worker', async t => {
  const tempRoot = path.resolve(os.tmpdir()), root = fs.mkdtempSync(path.join(tempRoot, 'project-y-preview-test-'));
  t.after(() => {
    assert.equal(path.dirname(path.resolve(root)), tempRoot);
    assert.ok(path.basename(root).startsWith('project-y-preview-test-'));
    fs.rmSync(root, { recursive: true, force: true });
  });
  for (const name of ['Config', 'Lua']) fs.cpSync(path.join(projectRoot, name), path.join(root, name), { recursive: true });
  const filename = path.join(root, 'Config/Tables/Map/MapRegionTable.json');
  const table = JSON.parse(fs.readFileSync(filename, 'utf8'));
  Object.assign(table.rows[0], { minX: 2, maxX: 2, minY: 2, maxY: 2, minHeight: 7, maxHeight: 7 });
  fs.writeFileSync(filename, JSON.stringify(table));
  const input = { seed: 1, regionIds: [1] }, first = await generatePreview(input, { root });
  assert.ok(first.cells.length > 0 && first.cells.length <= 4); assert.ok(first.cells.every(cell => cell.height === 7));
  assert.equal(first.regions[0].sizeX, 2); assert.equal(first.regions[0].sizeY, 2);
  Object.assign(table.rows[0], { minHeight: 1, maxHeight: 9 }); fs.writeFileSync(filename, JSON.stringify(table));
  const algorithm = path.join(root, 'Lua/Game/Map/GrasslandRegion.lua');
  const source = fs.readFileSync(algorithm, 'utf8');
  assert.ok(source.includes('return config.minHeight + (config.maxHeight - config.minHeight) * noise'));
  fs.writeFileSync(algorithm, source.replace('return config.minHeight + (config.maxHeight - config.minHeight) * noise', 'return config.maxHeight'));
  const second = await generatePreview(input, { root });
  assert.notEqual(first.sourceRevision, second.sourceRevision);
  assert.ok(second.cells.every(cell => cell.height === 9), 'Must execute the changed project Lua, not a separate preview algorithm');
});

// 输入或 Lua 失败之后必须释放忙碌状态，让下一次合法请求继续工作。
test('HTTP generation validates inputs, reports Lua errors and recovers for next request', async t => {
  const server = createPreviewServer(); await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  const base = 'http://127.0.0.1:' + server.address().port;
  const config = await (await fetch(base + '/api/config')).json();
  assert.ok(config.regions.length && config.token);
  const post = (input, token = config.token, extra = {}) => fetch(base + '/api/generate', {
    method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Preview-Token': token, ...extra }, body: JSON.stringify(input),
  });
  assert.equal((await post({seed: 1, regionIds: [1]}, 'wrong')).status, 403);
  assert.equal((await post({seed: 1, regionIds: [1]}, config.token, {Origin: 'https://example.com'})).status, 403);
  for (const input of [{seed: -1, regionIds: [1]}, {seed: 1.5, regionIds: [1]}, {seed: 1, regionIds: []}, {seed: 1, regionIds: ['1']}]) assert.equal((await post(input)).status, 400);
  const error = await post({ seed: 1, regionIds: [2147483647] }); assert.equal(error.status, 400);
  assert.match((await error.json()).error, /missing row/);
  const good = await post({ seed: 1, regionIds: [1] }); assert.equal(good.status, 200);
  assert.equal((await good.json()).stats.regionCount, 1);
});
