// 检查局部预览会剔除远处地块，同时保留视野内地面、水面及高处模型。
import test from 'node:test';
import assert from 'node:assert/strict';
import { MapRenderer } from '../public/renderer.js';

function fixture() {
  const cells = [];
  for (let r = -96; r <= 96; r += 8) for (let q = -96; q <= 96; q += 8)
    cells.push({ q, r, x: Math.sqrt(3) * (q + r / 2), z: 1.5 * r, height: (q - r) % 7, waterLevel: 9 });
  const renderer = Object.create(MapRenderer.prototype);
  renderer.options = { rotation: -25, tilt: 45, heightScale: 1 };
  renderer.fit = () => {};
  renderer.setData({ cells, assets: [{ id: 1, referenceHeight: 20 }],
    decorations: [{ cell: 1, assetId: 1, scale: 2 }], buildings: [], towns: [], regions: [], borders: [],
    hexRadius: 1, stats: { minHeight: -6, maxHeight: 6 } });
  renderer.width = 400; renderer.height = 300;
  return renderer;
}

test('visible chunk selection keeps every projected surface inside the viewport', () => {
  const renderer = fixture();
  for (const rotation of [-180, -25, 0, 91, 180]) for (const tilt of [15, 45, 90]) for (const heightScale of [0, 1, 4]) {
    Object.assign(renderer.options, { rotation, tilt, heightScale });
    const screen = (x, y, z) => {
      const point = renderer.project(x, y * heightScale, z);
      return { x: point.x * 8 + 137, y: point.y * 8 + 183 };
    };
    const visible = renderer.visibleCells(screen);
    assert.ok(visible.size < renderer.data.cells.length, 'Local view must discard distant chunks');
    renderer.data.cells.forEach((cell, index) => {
      for (const y of [renderer.base, cell.height, cell.waterLevel, renderer.maxSurface]) {
        const point = screen(cell.x, y, cell.z);
        if (point.x >= 0 && point.x <= renderer.width && point.y >= 0 && point.y <= renderer.height)
          assert.ok(visible.has(index), `Visible surface omitted at ${rotation}/${tilt}/${heightScale}`);
      }
    });
  }
});

test('an overview retains all cells and an empty distant view retains none', () => {
  const renderer = fixture();
  const overview = renderer.visibleCells((x, y, z) => ({ x: x / 4 + 200, y: z / 4 + 150 }));
  assert.equal(overview.size, renderer.data.cells.length);
  const distant = renderer.visibleCells((x, y, z) => ({ x: x + 10000, y: z + 10000 }));
  assert.equal(distant.size, 0);
});
