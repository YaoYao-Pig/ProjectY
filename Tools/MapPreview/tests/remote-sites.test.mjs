// 用真实工程读表与生成器验证：隐居群落与地牢均远离道路和普通城镇。
import test from 'node:test';
import assert from 'node:assert/strict';
import { generatePreview } from '../server.mjs';

test('secluded communities use small cottages and the same full-footprint isolation rules as dungeons', async () => {
  const map = await generatePreview({ seed: 20260921, regionIds: [1,2,3,4,5,6,1,4,5,6,1,5,2,6] });
  const groups = map.towns.filter(t => t.configId === 5), dungeons = map.towns.filter(t => t.configId === 4);
  console.log(JSON.stringify({ groups: groups.length, dungeons: dungeons.length, diagnostics: map.siteDiagnostics.filter(d => d.stage === 'AfterRoads') }));
  assert.ok(groups.length > 0 && dungeons.length > 0, 'Review seed must show both remote styles');
  const dungeonAsset = map.assets.find(a => a.id === 18), cottageAsset = map.assets.find(a => a.id === 19);
  assert.ok(dungeonAsset.prefabPath.endsWith('/Building_DungeonEntrance.fbx'));
  assert.equal(dungeonAsset.previewShape, 'dungeon');
  assert.ok(cottageAsset.prefabPath.endsWith('/Building_SecludedCottage.fbx'));
  assert.equal(cottageAsset.previewShape, 'cottage');
  const house = map.assets.find(a => a.id === 8);
  assert.ok(cottageAsset.referenceHeight < house.referenceHeight * .7);
  const distance = (a,b) => Math.max(Math.abs(a.q-b.q),Math.abs(a.r-b.r),Math.abs(a.q+a.r-b.q-b.r));
  const cell = id => map.cells[id-1];
  const roads = new Set(map.roads.flatMap(r => r.cells)), civilization = new Set();
  for (const town of map.towns.filter(t => t.role === 'settlement')) {
    civilization.add(town.center);
    for (const id of town.buildings) for (const c of map.buildings[id-1].cells) civilization.add(c);
    for (const id of town.roadIds) if (map.roads[id-1].kind === 'street') for (const c of map.roads[id-1].cells) civilization.add(c);
  }
  for (const town of [...groups,...dungeons]) {
    assert.equal(town.role, 'remote'); assert.equal(town.roadNetworkId, undefined); assert.deepEqual(town.roadIds, []);
    if (town.configId === 5) assert.ok(town.buildings.length >= 3 && town.buildings.length <= 5);
    for (const id of town.buildings) {
      const building = map.buildings[id-1];
      assert.equal(building.assetId, town.configId === 5 ? 19 : 18);
      for (const id of [...building.cells, building.entrance]) {
        assert.equal(cell(id).waterLevel, undefined);
        for (const other of roads) assert.ok(distance(cell(id),cell(other)) >= 8, 'Entire footprint must stay away from roads');
        for (const other of civilization) assert.ok(distance(cell(id),cell(other)) >= 12, 'Entire footprint must stay away from civilization');
      }
    }
  }
});
