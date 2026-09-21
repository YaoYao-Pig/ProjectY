// 网页只负责配方输入、结果检查与显示选项；所有生成请求交给工程 Lua 链路。
import { MapRenderer, regionColor } from './renderer.js';
const $ = id => document.getElementById(id);
const number = value => new Intl.NumberFormat('zh-CN', { maximumFractionDigits: 2 }).format(value);
let config, map, busy = false;
const renderer = new MapRenderer($('map'), selectCell);
function element(tag, text, className) { const node = document.createElement(tag); if (text !== undefined) node.textContent = text; if (className) node.className = className; return node; }
function swatch(id) { const canvas = element('canvas', undefined, 'swatch'); canvas.width = canvas.height = 12; const ctx = canvas.getContext('2d'); ctx.fillStyle = regionColor(id); ctx.fillRect(0, 0, 12, 12); return canvas; }
function pairs(values) { const dl = element('dl'); for (const [label, value] of values) dl.append(element('dt', label), element('dd', value)); return dl; }
function status(message, error = false) { $('status').textContent = message; $('status').classList.toggle('error', error); }
async function request(url, options) {
  const response = await fetch(url, options), body = await response.json();
  if (!response.ok) throw new Error(body.error || `请求失败 (${response.status})`);
  return body;
}
// 刷新选择器和摘要；生成接口仍会独立捕获最新已保存的配表与源码。
async function reloadConfig() {
  config = await request('/api/config');
  $('region-config').replaceChildren(...config.regions.map(row => {
    const type = config.regionTypes.find(item => item.value === row.MapRegion), option = element('option', `${row.id} · ${type.description || type.name}`); option.value = row.id; return option;
  }));
  if (!$('recipe').value.trim() && config.regions.length) fillMixedRecipe();
  $('config-details').replaceChildren(pairs([['六边形半径', config.constants.HexRadius], ['高度噪声跨度', config.constants.HeightNoiseScale], ['边界过渡宽度', config.constants.BorderBlendWidth + ' 格'], ['道路最大高差', config.constants.RoadMaxStep], ['道路坡度代价', config.constants.RoadSlopeCost], ['格子数上限', number(config.constants.MaxCells)]]));
  for (const row of config.regions) $('config-details').append(element('p', `#${row.id}：${row.minX}–${row.maxX} × ${row.minY}–${row.maxY} 格 / 原始高度 ${row.minHeight}–${row.maxHeight}（过渡带可超出）`));
  $('generate').disabled = busy || !config.regions.length;
  $('random').disabled = busy || !config.regions.length;
  status(config.regions.length ? '配置已读取。修改工程文件后可直接重新生成。' : 'MapRegionTable 当前没有可生成的配置。', !config.regions.length);
}
// 支持逗号分隔与 JSON 数组，保留顺序和重复 ID。
function recipe() {
  const text = $('recipe').value.trim();
  if (!text) throw new Error('请填写 Region 配方');
  const values = text.startsWith('[') ? JSON.parse(text) : text.split(/[,，\s]+/).map(Number);
  if (!Array.isArray(values) || !values.length || values.some(value => !Number.isInteger(value) || value <= 0)) throw new Error('配方只能包含正整数配置 ID，以逗号分隔');
  return values;
}
// 配方取自实际配表 ID；新增或调整策略后刷新配置即可参与对照，不在网页硬编码 ID。
function fillMixedRecipe() {
  const ids = config.regions.map(row => row.id);
  $('recipe').value = Array.from({ length: Math.max(8, ids.length) }, (_, index) => ids[index % ids.length]).join(', ');
}
async function generate() {
  if (busy) return;
  try {
    const seed = Number($('seed').value), regionIds = recipe();
    if (!$('seed').value.trim() || !Number.isInteger(seed) || seed < 0 || seed > 0xffffffff) throw new Error('请输入有效的 uint32 种子');
    busy = true; $('generate').disabled = true; $('random').disabled = true; $('busy-overlay').hidden = false;
    status('正在捕获工程配置与源码并运行 xLua…');
    const result = await request('/api/generate', { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Preview-Token': config.token }, body: JSON.stringify({ seed, regionIds }) });
    // 仅成功时替换画布数据；失败时保留上一张地图并在状态区明确提示。
    map = result; renderer.setData(map);
    $('empty-state').hidden = true; $('download').disabled = false; $('screenshot').disabled = false;
    $('map-label').textContent = `SEED ${map.seed}`;
    $('stat-cells').textContent = number(map.stats.cellCount); $('stat-regions').textContent = map.stats.regionCount;
    $('stat-borders').textContent = map.stats.borderCount; $('stat-height').textContent = `${number(map.stats.minHeight)}–${number(map.stats.maxHeight)}`;
    const mainRivers = map.rivers.filter(river=>river.kind==='main').length;
    $('water-stats').textContent = `${number(map.stats.waterCellCount)} 个水域格 · ${map.stats.waterBodyCount} 片等高水面\n${mainRivers} 条主河 · ${map.rivers.length-mainRivers} 条支流 · ${map.waterfalls.length} 处瀑布\n${map.decorations.length} 个树木/地貌装饰`;
    $('waterfall-list').replaceChildren(...map.waterfalls.map(fall=>{
      const button=element('button',`瀑布 #${fall.id} · 落差 ${number(fall.drop)} · 湖泊 ${fall.poolCells.length} 格`,'town-item');
      button.addEventListener('click',()=>{selectCell(fall.to-1);renderer.focus(fall.to-1);});return button;
    }));
    $('town-stats').textContent = `${map.stats.townCount} 座城镇 · ${map.stats.buildingCount} 栋建筑\n${map.stats.roadCount} 条城镇道路 · ${map.stats.streetCount} 条内部街道` +
      (map.stats.roadNetworkCount > 1 ? `\n分为 ${map.stats.roadNetworkCount} 个道路网络（水域或坡度阻隔）` : map.stats.townCount ? '\n城镇道路全部连通' : '\n当前地形没有找到满足配表的城镇选址');
    $('town-list').replaceChildren(...map.towns.map(town => {
      const button = element('button', `${town.name} #${town.id} · ${town.buildings.length} 栋`, 'town-item');
      button.addEventListener('click', () => { selectCell(town.center - 1); renderer.focus(town.center - 1); });
      return button;
    }));
    $('metadata').textContent = `${number(map.stats.sharedEdges)} 条共享边 · ${map.elapsedMs} ms\n算法版本 v${map.generationVersion} · ${map.sourceRevision.slice(0, 10)}`;
    $('source-label').textContent = `工程快照 ${map.sourceRevision.slice(0, 12)}`;
    renderRegions(); selectCell(null); renderLegend(); status(`已生成 ${number(map.stats.cellCount)} 个格子；本次使用已保存的最新工程文件。`);
  } catch (error) { status(error.message + (map ? '\n画布保留上一次成功生成的结果。' : ''), true); }
  finally { busy = false; $('generate').disabled = !config?.regions.length; $('random').disabled = !config?.regions.length; $('busy-overlay').hidden = true; }
}
function renderRegions() {
  $('region-count').textContent = map.regions.length;
  $('region-list').replaceChildren(...map.regions.map(region => {
    const button = element('button', undefined, 'region-item'); button.dataset.region = region.instanceId;
    button.append(swatch(region.instanceId), element('span', `#${region.instanceId} · ${region.typeName}`, 'region-name'), element('span', `${region.cellCount} 格`, 'region-size'));
    button.addEventListener('click', () => selectCell(map.cells.findIndex(cell => cell.regionId === region.instanceId)));
    return button;
  }));
}
// 详情使用原始世界高度与候选配置，不读取经过视角或高度放大后的绘制值。
function selectCell(index) {
  renderer.select(index); const details = $('cell-details'); details.replaceChildren();
  for (const node of $('region-list').children) node.classList.toggle('selected', index !== null && Number(node.dataset.region) === map.cells[index].regionId);
  if (index === null || !map) {
    details.append(element('h2', '选中一个格子'), element('p', '在地图上点击顶面，查看坐标、高度和所在区域。', 'intro')); return;
  }
  const cell = map.cells[index], region = map.regions[cell.regionId - 1], heading = element('div', undefined, 'detail-heading');
  heading.append(swatch(region.instanceId), element('strong', `(${cell.q}, ${cell.r})`));
  details.append(heading, pairs([['地面高度 Y', number(cell.height)], ['策略原始高度', number(cell.baseHeight)], ['边界混合比例', number(cell.blendAmount * 100) + '%'], ['世界坐标 X / Z', `${number(cell.x)} / ${number(cell.z)}`],
    ['Region 实例', '#' + region.instanceId], ['区域配置 ID', region.configId], ['地貌类型', region.typeName], ['区域尺寸', `${region.sizeX} × ${region.sizeY}`],
    ['相邻格子', cell.neighbors.filter(Boolean).length], ['相邻区域', region.neighborIds.map(id => '#' + id).join(', ') || '无']]));
  if (cell.waterLevel !== undefined) details.append(pairs([['水体', (cell.waterKind === 'river' ? '河流' : '湖泊') + ' #' + cell.waterBodyId], ['水面高度', number(cell.waterLevel)], ['水深', number(cell.waterDepth)]]));
  if (cell.riverId) {
    const river=map.rivers[cell.riverId-1];
    details.append(pairs([['河段',`${river.kind==='main'?'主河':'支流'} #${river.id}`],['经过 Region',river.regionIds.join(', ')],['汇入河段',river.parentRiverId || '地图出口']]));
  }
  if (cell.decorationId) { const item=map.decorations[cell.decorationId-1], asset=map.assets.find(asset=>asset.id===item.assetId); details.append(pairs([['装饰资源',asset.name],['资源配置',asset.id]])); }
  if (cell.townId) {
    const town = map.towns[cell.townId - 1];
    details.append(pairs([['城镇', `${town.name} #${town.id}`], ['城镇样式配置', town.configId], ['建筑数量', town.buildings.length], ['道路网络', '#' + town.roadNetworkId]]));
  }
  if (cell.buildingId) {
    const building = map.buildings[cell.buildingId - 1];
    details.append(pairs([['生成建筑', `${building.name} #${building.id}`], ['建筑配置', building.configId], ['实际占地', `${building.cells.length} 格`], ['地基高度', number(building.baseHeight)], ['墙高 / 屋顶', `${number(building.height)} / ${number(building.roofHeight)}`]]));
  }
  if (cell.roadIds.length) details.append(pairs([['经过的道路', cell.roadIds.map(id => (map.roads[id - 1].kind === 'street' ? '街道' : '道路') + ' #' + id).join('、')]]));
  const candidates = element('div', undefined, 'candidates');
  for (const [label, rows] of [['建筑候选', region.buildings], ['敌人候选', region.enemies]]) {
    candidates.append(element('strong', label));
    if (!rows.length) candidates.append(element('span', '无适用配置'));
    for (const row of rows) candidates.append(element('span', `${row.name} #${row.id}`, 'candidate'));
  }
  candidates.append(element('p', '候选来自区域配置；生成的建筑为静态占地预览，尚未接入玩法实体。', 'hint')); details.append(candidates);
}
function renderLegend() {
  const mode = $('color-mode').value; $('legend-title').textContent = { natural: '自然地表', region: 'REGION INSTANCES', height: 'WORLD HEIGHT', terrain: 'TERRAIN TYPE', transition: '边界混合强度' }[mode];
  const content = $('legend-content'); content.replaceChildren(); if (!map) return;
  if (mode === 'natural') {
    content.append(element('span', '草坡 · 岩脊 · 湖岸 · 河谷 · 森林 · 冰雪'));
    if (renderer.options.townPlots) {
      const styles = new Map(map.towns.map(town => [town.configId, town]));
      for (const town of styles.values()) {
        const chip = element('span', undefined, 'legend-chip'), mark = element('canvas', undefined, 'swatch');
        mark.width = mark.height = 12; const context = mark.getContext('2d'); context.fillStyle = town.groundColor; context.fillRect(0, 0, 12, 12);
        chip.append(mark, document.createTextNode(`${town.name}地块`)); content.append(chip);
      }
    }
  }
  else if (mode === 'transition') content.append(element('div', undefined, 'height-ramp'), element('span', '冷色：区域主体 → 暖色：多区域混合'));
    else if (mode === 'height') { content.append(element('div', undefined, 'height-ramp'), element('span', `${number(map.stats.minHeight)} → ${number(map.stats.maxHeight)} 世界单位`)); }
  else if (mode === 'region') {
    for (const region of map.regions.slice(0, 8)) { const chip = element('span', undefined, 'legend-chip'); chip.append(swatch(region.instanceId), document.createTextNode('#' + region.instanceId)); content.append(chip); }
    if (map.regions.length > 8) content.append(element('span', `共 ${map.regions.length} 个区域`));
  } else content.append(element('span', [...new Set(map.regions.map(region => region.typeName))].join(' · ')));
}
// 相机控件只更新前端投影，不请求重新生成地图。
function camera(tilt) {
  $('tilt').value = tilt; $('tilt-value').textContent = tilt + '°'; renderer.setOptions({ tilt }); renderer.fit();
  $('top').classList.toggle('active', tilt === 90); $('oblique').classList.toggle('active', tilt !== 90); $('view-name').textContent = tilt === 90 ? '俯视平面' : '立体预览';
}
$('generate').addEventListener('click', generate);
$('random').addEventListener('click', () => { $('seed').value = crypto.getRandomValues(new Uint32Array(1))[0]; generate(); });
$('reload').addEventListener('click', () => reloadConfig().catch(error => status(error.message, true)));
$('mixed').addEventListener('click', () => { if (config.regions.length) fillMixedRecipe(); });
$('append').addEventListener('click', () => {
  try {
    const id = Number($('region-config').value), count = Number($('repeat').value);
    if (!Number.isInteger(count) || count < 1 || count > 65536 || !id) throw new Error('追加次数应为 1–65536');
    const ids = $('recipe').value.trim() ? recipe() : []; if (ids.length + count > 65536) throw new Error('配方最多 65536 项');
    $('recipe').value = ids.concat(Array(count).fill(id)).join(', ');
  } catch (error) { status(error.message, true); }
});
$('fit').addEventListener('click', () => renderer.fit());
$('top').addEventListener('click', () => camera(90)); $('oblique').addEventListener('click', () => camera(45));
$('clear-selection').addEventListener('click', () => selectCell(null));
for (const [id, property, suffix] of [['rotation', 'rotation', '°'], ['tilt', 'tilt', '°'], ['height-scale', 'heightScale', '×']]) {
  $(id).addEventListener('input', () => {
    const value = Number($(id).value); $(id + '-value').textContent = (id === 'height-scale' ? value.toFixed(1) : value) + suffix;
    renderer.setOptions({ [property]: value });
    if (id === 'tilt') { $('top').classList.toggle('active', value === 90); $('oblique').classList.toggle('active', value !== 90); $('view-name').textContent = value === 90 ? '俯视平面' : '立体预览'; }
  });
}
for (const id of ['borders', 'grid', 'water', 'townPlots', 'buildings', 'roads', 'decorations']) $(id).addEventListener('change', () => {
  renderer.setOptions({ [id]: $(id).checked }); if (id === 'townPlots') renderLegend();
});
$('color-mode').addEventListener('change', () => { renderer.setOptions({ colorMode: $('color-mode').value }); renderLegend(); });
// 导出当前成功结果；延后释放 Blob URL，确保浏览器完成下载接管。
function download(blob, name) { const url = URL.createObjectURL(blob), link = element('a'); link.href = url; link.download = name; link.click(); setTimeout(() => URL.revokeObjectURL(url), 1000); }
$('download').addEventListener('click', () => download(new Blob([JSON.stringify(map, null, 2)], { type: 'application/json' }), `map-${map.seed}-${map.sourceRevision.slice(0, 8)}.json`));
$('screenshot').addEventListener('click', () => { renderer.draw(); $('map').toBlob(blob => { if (blob) download(blob, `map-${map.seed}.png`); else status('无法导出画布图片', true); }); });
reloadConfig().then(() => { if (config.regions.length) return generate(); }).catch(error => status(error.message, true));
