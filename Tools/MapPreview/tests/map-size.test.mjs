// 尺寸回归使用真实导表与 xLua；默认一万格，显式设置 MAP_TEST_CELLS 可验证十万格。
import test from 'node:test';
import assert from 'node:assert/strict';
import { generatePreview, validateRequest } from '../server.mjs';

test('exact cell budget keeps the whole map and each partial region connected', { timeout: 200000 }, async () => {
  const targetCells = Number(process.env.MAP_TEST_CELLS || 10000);
  const map = await generatePreview({ seed: 20260921, regionIds: [1, 2, 3, 4, 5, 6, 1, 4, 5, 6], targetCells });
  assert.equal(map.targetCells, targetCells);
  assert.equal(map.cells.length, targetCells);
  assert.equal(new Set(map.cells.map(c => `${c.q}:${c.r}`)).size, targetCells);
  const visited = new Set([1]), queue = [1], groups = new Map();
  for (let i = 0; i < queue.length; i++) for (const id of map.cells[queue[i] - 1].neighbors)
    if (id && !visited.has(id)) { visited.add(id); queue.push(id); }
  assert.equal(visited.size, targetCells, 'Global map must remain connected after budget cropping');
  map.cells.forEach((cell, index) => {
    if (!groups.has(cell.regionId)) groups.set(cell.regionId, []);
    groups.get(cell.regionId).push(index + 1);
    assert.ok(Number.isFinite(cell.height));
  });
  for (const region of map.regions) {
    const cells = groups.get(region.instanceId), seen = new Set([cells[0]]), pending = [cells[0]];
    for (let i = 0; i < pending.length; i++) for (const id of map.cells[pending[i] - 1].neighbors)
      if (id && map.cells[id - 1].regionId === region.instanceId && !seen.has(id)) { seen.add(id); pending.push(id); }
    assert.equal(seen.size, region.cellCount, `Region ${region.instanceId} must remain connected`);
  }
  // 河流/聚落数量都是配表上限，严格选址允许为零，尺寸测试不要求为凑数放宽规则。
  assert.ok(map.decorations.length && map.waterBodies.length);
  const summary = { cells: targetCells, regions: map.regions.length, elapsedMs: map.elapsedMs,
    towns: map.towns.length, rivers: map.rivers.length, decorations: map.decorations.length,
    jsonMiB: +(Buffer.byteLength(JSON.stringify(map)) / 1048576).toFixed(1) };
  console.log(JSON.stringify(summary));
});

test('size input rejects invalid values without starting a worker', () => {
  for (const targetCells of [0, -1, 1.5, NaN, Infinity, '10000', 100001])
    assert.throws(() => validateRequest({ seed: 1, regionIds: [1], targetCells }));
  assert.deepEqual(validateRequest({ seed: 1, regionIds: [1] }), { seed: 1, regionIds: [1] });
});
