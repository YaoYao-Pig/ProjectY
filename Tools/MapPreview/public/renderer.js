// 仅绘制服务返回的世界坐标和高度；相机与着色选项不会改变地图算法结果。
// 只把 Lua 返回的实际占地转成显示轮廓，不扩张占地或修改地形数据。
// 用整数顶点坐标拼接外沿，避免浮点误差导致共享边留下细缝。
const footprintCorners = [[1, 1], [0, 2], [-1, 1], [-1, -1], [0, -2], [1, -1]];
export function buildingFootprint(building, data) {
  const members = new Set(building.cells), edges = [], starts = new Map();
  for (const id of building.cells) {
    const cell = data.cells[id - 1];
    const points = footprintCorners.map(([x, z]) => {
      const u = 2 * cell.q + cell.r + x, v = 3 * cell.r + z;
      return { key: `${u}:${v}`, x: u * Math.sqrt(3) * data.hexRadius / 2, z: v * data.hexRadius / 2 };
    });
    for (let side = 0; side < 6; side++) {
      const neighbor = cell.neighbors[5 - side];
      if (members.has(neighbor)) continue;
      const edge = { a: points[side], b: points[(side + 1) % 6], neighbor };
      if (starts.has(edge.a.key)) throw new Error('建筑占地外沿不是单一连续轮廓');
      starts.set(edge.a.key, edge); edges.push(edge);
    }
  }
  // 当前工程生成完整六边形占地，没有孔洞；发现异常应直接暴露，不能伪造连线。
  if (!edges.length) throw new Error('建筑占地没有外沿');
  const outline = [], first = edges[0];
  let edge = first;
  do {
    if (!edge || outline.length >= edges.length) throw new Error('建筑占地外沿无法闭合');
    outline.push(edge.a); edge = starts.get(edge.b.key);
  } while (edge !== first);
  if (outline.length !== edges.length) throw new Error('建筑占地包含分离轮廓');
  return { outline, edges };
}
const radians = degrees => degrees * Math.PI / 180;
export const regionColor = id => `hsl(${(id * 137.508 + 32) % 360} 29% 61%)`;
const heightColors = [[54,107,138],[85,163,148],[186,199,121],[216,179,115],[188,121,100]];
const mix = (a, b, t) => a.map((value, index) => value + (b[index] - value) * t);
const rgb = (values, shade) => `rgb(${values.map(value => Math.round(value * shade)).join(' ')})`;
function heightColor(t, shade = 1) {
  const position = Math.max(0, Math.min(1, t)) * (heightColors.length - 1), index = Math.min(3, Math.floor(position)), fraction = position - index;
  return `rgb(${heightColors[index].map((value, channel) => Math.round((value + (heightColors[index + 1][channel] - value) * fraction) * shade)).join(' ')})`;
}
// 射线交点奇偶法判断鼠标是否命中实际绘制的顶面或侧面。
function inside(point, polygon) {
  let result = false;
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    const a = polygon[i], b = polygon[j];
    if ((a.y > point.y) !== (b.y > point.y) && point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x) result = !result;
  }
  return result;
}
export class MapRenderer {
  constructor(canvas, onSelect) {
    this.canvas = canvas; this.context = canvas.getContext('2d'); this.onSelect = onSelect;
    this.options = { rotation: -25, tilt: 45, heightScale: 1, colorMode: 'natural', borders: false, grid: false, water: true, townPlots: true, buildings: true, roads: true, decorations: true };
    this.scale = 1; this.pan = { x: 0, y: 0 }; this.faces = []; this.selected = null; this.autoFit = true;
    this.resizeObserver = new ResizeObserver(() => { this.resize(); }); this.resizeObserver.observe(canvas);
    canvas.addEventListener('wheel', event => {
      event.preventDefault(); if (!this.data) return;
      const point = this.point(event), factor = Math.exp(-Math.max(-200, Math.min(200, event.deltaY)) * .002);
      const next = Math.max(.25, Math.min(250, this.scale * factor)), ratio = next / this.scale;
      this.pan.x = point.x - (point.x - this.pan.x) * ratio; this.pan.y = point.y - (point.y - this.pan.y) * ratio;
      this.scale = next; this.autoFit = false; this.schedule();
    }, { passive: false });
    canvas.addEventListener('pointerdown', event => {
      if (event.button !== 0) return;
      this.drag = { start: this.point(event), pan: { ...this.pan }, moved: false }; canvas.setPointerCapture(event.pointerId);
    });
    canvas.addEventListener('pointermove', event => {
      if (!this.drag) return;
      const point = this.point(event), dx = point.x - this.drag.start.x, dy = point.y - this.drag.start.y;
      if (Math.hypot(dx, dy) > 3) this.drag.moved = true;
      if (this.drag.moved) { this.autoFit = false; this.pan = { x: this.drag.pan.x + dx, y: this.drag.pan.y + dy }; canvas.classList.add('dragging'); this.schedule(); }
    });
    const end = event => {
      if (!this.drag) return;
      if (!this.drag.moved && event.type === 'pointerup') {
        const point = this.point(event); let selected = null;
        // 从最后绘制的面向前拾取，优先选中遮挡关系中最靠近视线的格子。
        for (let i = this.faces.length - 1; i >= 0; i--) {
          const face = this.faces[i];
          if (point.x >= face.bounds.minX && point.x <= face.bounds.maxX && point.y >= face.bounds.minY && point.y <= face.bounds.maxY && inside(point, face.points)) { selected = face.index; break; }
        }
        this.select(selected); this.onSelect(selected);
      }
      this.drag = null; canvas.classList.remove('dragging');
    };
    canvas.addEventListener('pointerup', end); canvas.addEventListener('pointercancel', end);
  }
  point(event) { const rect = this.canvas.getBoundingClientRect(); return { x: event.clientX - rect.left, y: event.clientY - rect.top }; }
  resize() {
    const rect = this.canvas.getBoundingClientRect(); this.width = rect.width; this.height = rect.height;
    this.ratio = Math.min(2, window.devicePixelRatio || 1);
    this.canvas.width = Math.round(rect.width * this.ratio); this.canvas.height = Math.round(rect.height * this.ratio);
    if (this.data && this.autoFit) this.fit(); else this.schedule();
  }
  // 双向记录真实 Border 关系；柱底仅用于展示厚度，不属于算法高度数据。
  setData(data) {
    this.data = data; this.selected = null;
    this.assets = new Map(data.assets.map(asset => [asset.id, asset]));
    // 同一占地的边界与配置颜色只计算一次，相机重绘时复用。
    this.buildingPlots = new Map(data.buildings.map(building => [building.id, buildingFootprint(building, data)]));
    this.townColors = new Map(data.towns.map(town => [town.id, [1, 3, 5].map(start => parseInt(town.groundColor.slice(start, start + 2), 16))]));
    this.typeNames = new Map(data.regions.map(region => [region.regionType, region.typeName]));
    this.boundaries = new Set();
    for (const border of data.borders) for (const edge of border.edges) {
      this.boundaries.add(edge.a + ':' + edge.b); this.boundaries.add(edge.b + ':' + edge.a);
    }
    this.base = data.stats.minHeight - data.hexRadius * 1.2;
    this.corners = Array.from({ length: 6 }, (_, index) => ({ x: Math.cos(radians(30 + index * 60)) * data.hexRadius, z: Math.sin(radians(30 + index * 60)) * data.hexRadius }));
    this.fit();
  }
  setOptions(options) {
    Object.assign(this.options, options);
    if (this.data && ['rotation', 'tilt', 'heightScale', 'buildings'].some(key => key in options) && this.autoFit) this.fit();
    else this.schedule();
  }
  select(index) { this.selected = index; this.schedule(); }
  // 从城镇列表定位到实际中心格，便于检查小比例地图中的建筑与道路。
  focus(index) {
    const cell = this.data.cells[index], point = this.project(cell.x, cell.height * this.options.heightScale, cell.z);
    this.scale = Math.max(this.scale, 22); this.pan = { x: this.width / 2 - point.x * this.scale, y: this.height / 2 - point.y * this.scale };
    this.autoFit = false; this.schedule();
  }
  // 在 XZ 地面旋转后做正交投影；depth 用于画家算法的远近排序。
  project(x, y, z) {
    const yaw = radians(this.options.rotation), elevation = radians(this.options.tilt);
    const horizontal = x * Math.cos(yaw) - z * Math.sin(yaw), depth = x * Math.sin(yaw) + z * Math.cos(yaw);
    return { x: horizontal, y: depth * Math.sin(elevation) - y * Math.cos(elevation), depth: depth * Math.cos(elevation) + y * Math.sin(elevation) };
  }
  // 同时纳入顶面与柱底，保证立体视角下整张地图位于画布可视范围。
  fit() {
    if (!this.data || !this.width || !this.height) return;
    let minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity;
    for (const cell of this.data.cells) for (const height of [Math.max(cell.height, cell.waterLevel ?? cell.height), this.base]) {
      const point = this.project(cell.x, height * this.options.heightScale, cell.z);
      minX = Math.min(minX, point.x); maxX = Math.max(maxX, point.x); minY = Math.min(minY, point.y); maxY = Math.max(maxY, point.y);
    }
    if (this.options.buildings) for (const building of this.data.buildings) {
      const cell = this.data.cells[building.cell - 1];
      const point = this.project(cell.x, (building.baseHeight + building.height + building.roofHeight) * this.options.heightScale, cell.z);
      minX = Math.min(minX, point.x); maxX = Math.max(maxX, point.x); minY = Math.min(minY, point.y); maxY = Math.max(maxY, point.y);
    }
    const margin = this.data.hexRadius * 2;
    this.scale = Math.max(.25, Math.min(90, (this.width - 70) / (maxX - minX + margin), (this.height - 170) / (maxY - minY + margin)));
    this.pan = { x: this.width / 2 - (minX + maxX) / 2 * this.scale, y: this.height / 2 - (minY + maxY) / 2 * this.scale };
    this.autoFit = true; this.schedule();
  }
  // 多个输入事件合并到同一帧重绘，拖动和滑杆不会重复提交整图绘制。
  schedule() { if (!this.scheduled) this.scheduled = requestAnimationFrame(() => { this.scheduled = null; this.draw(); }); }
  color(cell, shade = 1, water = false) {
    // 水面使用真实水深着色；关闭水面时可以直接观察湖床和河床。
    if (water) return rgb(mix([77, 165, 178], [36, 99, 132], Math.min(1, cell.waterDepth / 4)), shade);
    const range = this.data.stats.maxHeight - this.data.stats.minHeight;
    const t = range ? (cell.height - this.data.stats.minHeight) / range : .5;
    if (this.options.colorMode === 'height') return heightColor(t, shade);
    if (this.options.colorMode === 'transition') return heightColor(Math.min(1, cell.blendAmount * 2), shade);
    if (this.options.colorMode === 'natural') {
      // 颜色已由工程地貌配置与 biomeWeights 混合，网页不另维护地貌 ID 调色板。
      let color = cell.groundColor.map(value => value * 255);
      if (cell.waterLevel !== undefined) color = mix(color, [154, 145, 105], 0.7);
      const slope = Math.max(0, ...cell.neighbors.filter(Boolean).map(id => Math.abs(cell.height - this.data.cells[id - 1].height)));
      color = mix(color, [137, 131, 121], Math.min(0.55, slope / 7));
      return rgb(color, shade * (0.87 + Math.min(1, t) * 0.18));
    }
    const type = this.data.regions[cell.regionId - 1].regionType;
    const hue = this.options.colorMode === 'region' ? (cell.regionId * 137.508 + 32) % 360 : (type * 43 + 62) % 360;
    return `hsl(${hue} ${this.options.colorMode === 'region' ? 29 : 28}% ${(53 + t * 15) * shade}%)`;
  }
  draw() {
    const ctx = this.context; ctx.setTransform(this.ratio, 0, 0, this.ratio, 0, 0);
    ctx.fillStyle = '#e9eee6'; ctx.fillRect(0, 0, this.width, this.height);
    ctx.fillStyle = '#ccd7c666';
    for (let x = 16; x < this.width; x += 28) for (let y = 16; y < this.height; y += 28) ctx.fillRect(x, y, 1, 1);
    this.faces = []; if (!this.data) return;
    const screen = (x, y, z) => { const point = this.project(x, y * this.options.heightScale, z); return { x: point.x * this.scale + this.pan.x, y: point.y * this.scale + this.pan.y, depth: point.depth }; };
    const face = (points, index, top, shade, water = false, fill = null, plotId = null) => {
      const bounds = { minX: Math.min(...points.map(p => p.x)), maxX: Math.max(...points.map(p => p.x)), minY: Math.min(...points.map(p => p.y)), maxY: Math.max(...points.map(p => p.y)) };
      if (bounds.maxX < -2 || bounds.minX > this.width + 2 || bounds.maxY < -2 || bounds.minY > this.height + 2) return;
      this.faces.push({ points, index, top, bounds, shade, water, fill, plotId, depth: points.reduce((sum, point) => sum + point.depth, 0) / points.length });
    };
    this.data.cells.forEach((cell, index) => {
      // 城市地块模式下由整块平台替代各小格的顶面和内侧壁，关闭后恢复原始地形。
      if (this.options.townPlots && cell.buildingId) return;
      const points = this.corners.map(corner => screen(cell.x + corner.x, cell.height, cell.z + corner.z));
      face(points, index, true, 1);
      if (this.options.water && cell.waterLevel !== undefined) {
        const waterPoints = this.corners.map(corner => screen(cell.x + corner.x, cell.waterLevel, cell.z + corner.z));
        face(waterPoints, index, true, 1, true);
        // 水系可以沿途降水位；相邻水格之间补连续水幕，干岸仍由地形遮挡。
        for (let side = 0; side < 6; side++) {
          const a = this.corners[side], b = this.corners[(side + 1) % 6];
          const facing = (a.x + b.x) * Math.sin(radians(this.options.rotation)) + (a.z + b.z) * Math.cos(radians(this.options.rotation));
          const neighbor = this.data.cells[cell.neighbors[5 - side] - 1];
          const bottom = neighbor ? neighbor.waterLevel : cell.height;
          if (bottom !== undefined && bottom < cell.waterLevel - 1e-6 && facing >= 0)
            face([waterPoints[side], waterPoints[(side + 1) % 6], screen(cell.x+b.x,bottom,cell.z+b.z), screen(cell.x+a.x,bottom,cell.z+a.z)], index, false, .86, true);
        }
      }
      if (this.options.tilt >= 89.9 || this.options.heightScale === 0) return;
      for (let side = 0; side < 6; side++) {
        const a = this.corners[side], b = this.corners[(side + 1) % 6];
        const facing = (a.x + b.x) * Math.sin(radians(this.options.rotation)) + (a.z + b.z) * Math.cos(radians(this.options.rotation));
        if (facing < 0) continue;
        // 顶点绕序与 HexGrid 方向相反，5 - side 将侧边映射回 Lua 的六邻居槽位。
        const neighborId = cell.neighbors[5 - side], neighbor = neighborId ? this.data.cells[neighborId - 1] : null;
        // 只绘制高于邻居的外露部分；无邻居时延伸至统一柱底。
        const bottom = neighbor ? neighbor.height : this.base;
        if (bottom >= cell.height) continue;
        face([points[side], points[(side + 1) % 6], screen(cell.x + b.x, bottom, cell.z + b.z), screen(cell.x + a.x, bottom, cell.z + a.z)], index, false, .70 + side % 2 * .08);
      }
    });
    if (this.options.townPlots) for (const building of this.data.buildings) {
      const plot = this.buildingPlots.get(building.id), cell = this.data.cells[building.cell - 1], height = building.baseHeight + .025;
      const fill = this.options.colorMode === 'natural' ? rgb(this.townColors.get(building.townId), 1) : this.color({ ...cell, height: building.baseHeight });
      // 一栋建筑只有一个连续顶面。格子线、底色和选择高亮都不会再把它切成独立小块。
      face(plot.outline.map(p => screen(p.x, height, p.z)), building.cell - 1, true, 1, false, fill, building.id);
      for (const edge of plot.edges) {
        const neighbor = edge.neighbor ? this.data.cells[edge.neighbor - 1] : null;
        const bottom = neighbor ? (neighbor.buildingId ? this.data.buildings[neighbor.buildingId - 1].baseHeight + .025 : neighbor.height) : this.base;
        if (bottom >= height) continue;
        const dx = edge.b.x - edge.a.x, dz = edge.b.z - edge.a.z;
        const facing = dz * Math.sin(radians(this.options.rotation)) - dx * Math.cos(radians(this.options.rotation));
        if (facing < 0) continue;
        face([screen(edge.a.x, height, edge.a.z), screen(edge.b.x, height, edge.b.z), screen(edge.b.x, bottom, edge.b.z), screen(edge.a.x, bottom, edge.a.z)], building.cell - 1, false, 1, false, '#948365');
      }
    }
    // 道路按每格的真实高度拆成半段，台阶处画立面；不会把道路悬铺在水面上。
    // 表面贴片紧跟所属格顶面绘制，避免共面多边形按质心排序时被自己的地面覆盖。
    const overlays = new Map(), addOverlay = (index, points, fill) => {
      if (!overlays.has(index)) overlays.set(index, []);
      overlays.get(index).push({ points, fill });
    };
    if (this.options.roads) {
      const segments = new Map();
      for (const road of this.data.roads) for (let i = 1; i < road.cells.length; i++) {
        const a = road.cells[i - 1], b = road.cells[i], key = Math.min(a, b) + ':' + Math.max(a, b);
        if (!segments.has(key) || road.kind === 'road') segments.set(key, { a, b, main: road.kind === 'road' });
      }
      for (const segment of segments.values()) {
        const a = this.data.cells[segment.a - 1], b = this.data.cells[segment.b - 1];
        const dx = b.x - a.x, dz = b.z - a.z, length = Math.hypot(dx, dz), width = this.data.hexRadius * (segment.main ? .27 : .19);
        const px = -dz / length * width, pz = dx / length * width, mx = (a.x + b.x) / 2, mz = (a.z + b.z) / 2;
        for (const [cell, index] of [[a, segment.a - 1], [b, segment.b - 1]]) {
          const y = cell.height + .025;
          addOverlay(index, [screen(cell.x + px, y, cell.z + pz), screen(mx + px, y, mz + pz), screen(mx - px, y, mz - pz), screen(cell.x - px, y, cell.z - pz)], '#cbb38a');
          addOverlay(index, this.corners.map(c => screen(cell.x + c.x * width / this.data.hexRadius, y + .003, cell.z + c.z * width / this.data.hexRadius)), '#cbb38a');
        }
        if (a.height !== b.height) face([screen(mx + px, a.height + .025, mz + pz), screen(mx - px, a.height + .025, mz - pz), screen(mx - px, b.height + .025, mz - pz), screen(mx + px, b.height + .025, mz + pz)], segment.a - 1, false, 1, false, '#a28e6d');
      }
      for (const town of this.data.towns) {
        const cell = this.data.cells[town.center - 1];
        addOverlay(town.center - 1, this.corners.map(c => screen(cell.x + c.x * .65, cell.height + .03, cell.z + c.z * .65)), '#d7c5a1');
      }
    }
    // 装饰只按 Lua 给出的格子、模型类型和缩放绘制，不在浏览器重新撒树。
    if (this.options.decorations) for (const item of this.data.decorations) {
      const cell = this.data.cells[item.cell - 1], asset = this.assets.get(item.assetId);
      const height = asset.referenceHeight * item.scale, radius = this.data.hexRadius * item.scale * .42;
      const cone = (base, peak, width, fill) => {
        const ring = this.corners.map(c => screen(cell.x+c.x*width,base,cell.z+c.z*width));
        for (let i=0;i<6;i++) face([ring[i],ring[(i+1)%6],screen(cell.x,peak,cell.z)],item.cell-1,false,1,false,fill);
      };
      if (asset.previewShape === 'mountain') cone(cell.height,cell.height+height,.65*item.scale,asset.previewColor);
      else {
        const trunk = radius*.14;
        face([screen(cell.x-trunk,cell.height,cell.z),screen(cell.x+trunk,cell.height,cell.z),screen(cell.x+trunk,cell.height+height*.5,cell.z),screen(cell.x-trunk,cell.height+height*.5,cell.z)],item.cell-1,false,1,false,'#66594a');
        if (asset.previewShape === 'tree') {
          cone(cell.height+height*.38,cell.height+height,radius/this.data.hexRadius,asset.previewColor);
          cone(cell.height+height*.6,cell.height+height*.23,radius/this.data.hexRadius,'#486a3b');
        } else for (let layer=0;layer<3;layer++)
          cone(cell.height+height*(.22+layer*.21),cell.height+height*(.6+layer*.2),radius/this.data.hexRadius*(1-layer*.22),asset.previewColor);
      }
    }
    if (this.options.water) for (const fall of this.data.waterfalls) {
      const cell=this.data.cells[fall.to-1];
      face(this.corners.map(c=>screen(cell.x+c.x*.5,cell.waterLevel+.018,cell.z+c.z*.5)),fall.to-1,true,1,true,'#e4f4f1');
    }
    if (this.options.buildings) for (const building of this.data.buildings) {
      const asset = this.assets.get(building.assetId);
      const cell = this.data.cells[building.cell - 1], entrance = this.data.cells[building.entrance - 1];
      const yaw = Math.atan2(entrance.z - cell.z, entrance.x - cell.x), size = this.data.hexRadius * (building.footprintRadius + .52);
      const point = (x, y, z) => screen(cell.x + x * Math.cos(yaw) - z * Math.sin(yaw), y, cell.z + x * Math.sin(yaw) + z * Math.cos(yaw));
      const base = building.baseHeight + .025, eave = base + building.height, ridge = eave + building.roofHeight;
      // 墙体放在整块地基之上；建筑细节可独立关闭，城市地块继续保留。
      const corners = [[-size, -size * .65], [size, -size * .65], [size, size * .65], [-size, size * .65]];
      const floor = corners.map(([x, z]) => point(x, Math.min(...building.cells.map(id => this.data.cells[id - 1].height)), z));
      const bottoms = corners.map(([x, z]) => point(x, base, z)), tops = corners.map(([x, z]) => point(x, eave, z));
      for (let side = 0; side < 4; side++) {
        const next = (side + 1) % 4;
        if (!this.options.townPlots) face([floor[side], floor[next], bottoms[next], bottoms[side]], building.cell - 1, false, 1, false, side % 2 ? '#a5977d' : '#b2a38a');
        face([bottoms[side], bottoms[next], tops[next], tops[side]], building.cell - 1, false, 1, false, asset.previewColor);
      }
      const left = point(-size, ridge, 0), right = point(size, ridge, 0);
      const roofColor = asset.previewShape === 'dungeon' ? '#6f726e' : '#a8694e';
      face([tops[0], tops[1], right, left], building.cell - 1, true, 1, false, roofColor);
      face([left, right, tops[2], tops[3]], building.cell - 1, true, 1, false, asset.previewShape === 'dungeon' ? '#777c76' : '#875241');
      face([tops[0], left, tops[3]], building.cell - 1, false, 1, false, '#e4d3ad');
      face([tops[1], tops[2], right], building.cell - 1, false, 1, false, '#d9c69e');
      // 面向 Lua 选定入口的门，仅为占位模型的朝向提示。
      const front = size + .008;
      face([point(front, base, -.14 * size), point(front, base, .14 * size), point(front, base + building.height * .65, .14 * size), point(front, base + building.height * .65, -.14 * size)], building.cell - 1, false, 1, false, '#66594a');
      if (asset.previewShape === 'castle') for (const [tx,tz] of corners) {
        const ring=Array.from({length:8},(_,i)=>[tx+Math.cos(i*Math.PI/4)*size*.22,tz+Math.sin(i*Math.PI/4)*size*.22]);
        const towerTop=base+building.height*1.12;
        for (let i=0;i<8;i++) {
          const a=ring[i],b=ring[(i+1)%8];
          face([point(a[0],base,a[1]),point(b[0],base,b[1]),point(b[0],towerTop,b[1]),point(a[0],towerTop,a[1])],building.cell-1,false,1,false,i%2?'#b4a791':'#9e9482');
        }
        face(ring.map(([x,z])=>point(x,towerTop,z)),building.cell-1,true,1,false,'#c7bda6');
      }
    }
    // 先远后近覆盖；同深度时先画侧面再画顶面，减少边缘闪缝。
    this.faces.sort((a, b) => a.depth - b.depth || Number(a.top) - Number(b.top));
    for (const item of this.faces) {
      const cell = this.data.cells[item.index], points = item.points;
      ctx.beginPath(); ctx.moveTo(points[0].x, points[0].y); for (let i = 1; i < points.length; i++) ctx.lineTo(points[i].x, points[i].y); ctx.closePath();
      ctx.fillStyle = item.fill || this.color(cell, item.shade, item.water); ctx.fill();
      if (item.plotId) { ctx.strokeStyle = '#806f5055'; ctx.lineWidth = .8; ctx.stroke(); }
      if (this.options.grid && !item.fill && this.scale > 3) { ctx.strokeStyle = item.top ? '#344c363c' : '#32453421'; ctx.lineWidth = .6; ctx.stroke(); }
      if (item.top && !item.water && !item.fill) for (const overlay of overlays.get(item.index) || []) {
        ctx.beginPath(); ctx.moveTo(overlay.points[0].x, overlay.points[0].y);
        for (const point of overlay.points.slice(1)) ctx.lineTo(point.x, point.y);
        ctx.closePath(); ctx.fillStyle = overlay.fill; ctx.fill();
      }
      if (item.top && !item.fill && this.options.borders) {
        ctx.strokeStyle = '#243c37c9'; ctx.lineWidth = 1.5;
        for (let side = 0; side < 6; side++) {
          const neighbor = cell.neighbors[5 - side];
          if (neighbor && this.boundaries.has((item.index + 1) + ':' + neighbor)) {
            ctx.beginPath(); ctx.moveTo(points[side].x, points[side].y); ctx.lineTo(points[(side + 1) % 6].x, points[(side + 1) % 6].y); ctx.stroke();
          }
        }
      }
      const selectedBuilding = this.selected === null ? null : this.data.cells[this.selected].buildingId;
      if (item.top && (item.index === this.selected || (item.plotId && item.plotId === selectedBuilding))) {
        ctx.beginPath(); ctx.moveTo(points[0].x, points[0].y); for (let i = 1; i < points.length; i++) ctx.lineTo(points[i].x, points[i].y); ctx.closePath();
        ctx.fillStyle = '#fff8c36b'; ctx.fill(); ctx.strokeStyle = '#fff5c1'; ctx.lineWidth = 2.5; ctx.stroke();
      }
    }
    ctx.fillStyle = '#6b8064'; ctx.font = '10px Segoe UI'; ctx.fillText('XZ · 1 格半径 = ' + this.data.hexRadius, 22, this.height - 80);
  }
}
