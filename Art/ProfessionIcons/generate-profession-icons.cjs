// Hand-authored vector profession emblems. No external images or fonts are used.
// Usage: node generate-profession-icons.cjs [path-to-sharp]
// The SVG sources remain editable; PNG output is regenerated at 256 x 256.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const sharp = require(process.argv[2] || 'sharp');

const sourceDir = __dirname;
const projectDir = path.resolve(sourceDir, '../..');
const outputDir = path.join(projectDir, 'Assets/DynamicAsset/UI/Icons/Professions');
const gold = '#c8aa6a';
const ivory = '#f2e5ba';
const dark = '#33463b';

const professions = [
  { id: 1, name: 'Warrior', symbol: `
    <path d="M63 58 109 92 113 151 70 182 60 136Z" fill="${dark}"/>
    <path d="M70 72 99 98 102 143 73 165 68 132Z" stroke-width="3"/>
    <path d="M77 109 94 123 78 139" stroke="${ivory}"/>
    <path d="m137 57 17-29 13 32-18 89-14-4Z" fill="${ivory}"/>
    <path d="m155 50-14 94" stroke-width="3"/>
    <path d="m119 143 49 10-2 12-49-10Z" fill="${gold}"/>
    <path d="m134 160 15 3-8 37-15-3Z" fill="${dark}"/>
    <path d="m129 174 15 3m-18 11 15 3" stroke-width="3"/>
    <path d="m124 199 18 4-3 12-18-4Z" fill="${ivory}"/>
    <path d="M53 177q7 20 27 27m-24-17-14-1 7 13 15 3m4-4-1-15 12 9 3 16" stroke-width="4"/>
    <path d="M177 177q-2 22-18 34m17-19 15-6-3 15-17 8m-4-11-5-13-7 13 2 16" stroke-width="4"/>
  ` },
  { id: 2, name: 'Ranger', symbol: `
    <path d="M95 39q79 31 79 88t-79 90q43-40 43-90T95 39Z" fill="${dark}"/>
    <path d="m97 44 18 83-18 86" stroke="${ivory}" stroke-width="3"/>
    <path d="M48 127h152" stroke="${ivory}" stroke-width="7"/>
    <path d="m202 127-24-15 5 15-5 15Z" fill="${ivory}"/>
    <path d="m75 127-20-15H39l14 15-14 15h16Z" fill="${gold}"/>
    <path d="M55 181q27-17 39-41m-24 32-21-1 10-13 22 3m-4-6 0-19 16 4" stroke-width="4"/>
    <path d="M158 70q17 1 35-18m-17 15-1-17 14-7 1 17m-7 2 17 0 9-14-16 2" stroke-width="4"/>
  ` },
  { id: 3, name: 'Mage', symbol: `
    <path d="M58 176v-40q34-4 70 16 36-20 70-16v40q-36 0-70 17-34-17-70-17Z" fill="${dark}"/>
    <path d="M69 145v22q29 2 59 17 30-15 59-17v-22M128 153v31" stroke="${ivory}" stroke-width="4"/>
    <path d="M128 113v41" stroke-width="11"/>
    <path d="m121 123 14 1m-14 11 14 1" stroke="${ivory}" stroke-width="3"/>
    <path d="M105 78q-5 17 7 30l16 10 16-10q12-13 7-30l-12 15-11 6-11-6Z" fill="${gold}"/>
    <path d="m128 35 18 26-18 27-18-27Z" fill="${ivory}"/>
    <path d="m128 43 0 36" stroke-width="3"/>
    <path d="M88 57q-17 17-11 40m91-40q17 17 11 40m-91 7-5 9m85-9 5 9" stroke-width="4"/>
    <path d="m83 39 2 8m86-8-2 8M128 205v10m-8-5h16" stroke="${ivory}" stroke-width="3"/>
  ` },
  { id: 4, name: 'Artificer', symbol: `
    <path d="m114 42 28 0 4 17 16 7 16-9 20 20-9 16 7 16 18 5v28l-18 4-7 16 9 16-20 20-16-9-16 7-4 18h-28l-5-18-16-7-16 9-20-20 9-16-7-16-17-4v-28l17-5 7-16-9-16 20-20 16 9 16-7Z" fill="${dark}"/>
    <circle cx="128" cy="128" r="55" stroke-width="3"/>
    <path d="m96 70 51 38-15 20-51-38Z" fill="${ivory}"/>
    <path d="m125 119-33 47 11 8 35-46Z" fill="${gold}"/>
    <path d="M115 151h59l-12 17h-13v14h13v11h-57v-11h15v-18l-13-8Z" fill="${ivory}"/>
    <path d="m156 82 3 17m-8-9 15 0" stroke="${ivory}" stroke-width="4"/>
  ` },
  { id: 5, name: 'Knight', symbol: `
    <path d="M72 64q56-22 112 0v73q-4 48-56 78-52-30-56-78Z" fill="${dark}"/>
    <path d="M82 73q46-18 92 0v63q-4 41-46 67-42-26-46-67Z" stroke-width="3"/>
    <path d="M113 89q-6-18 2-32 17-24 48-17-17 8-22 27l-9 22Z" fill="${gold}"/>
    <path d="M101 108q0-26 27-26 28 0 28 26v45l-28 22-27-22Z" fill="${ivory}"/>
    <path d="m98 111 30 10 31-10-4 20-27 9-27-9Z" fill="${dark}"/>
    <path d="M128 87v30m0 25v24m-17-24v10m34-10v10" stroke="${dark}" stroke-width="4"/>
    <path d="m115 184 13 8 13-8" stroke-width="3"/>
  ` },
  { id: 6, name: 'Alchemist', symbol: `
    <path d="M108 61h40v15h-7v32l37 56q15 24-2 39H80q-17-15-2-39l37-56V76h-7Z" fill="${dark}"/>
    <path d="M115 79h26m-25 29h25" stroke="${ivory}" stroke-width="4"/>
    <path d="M95 153q20-11 33-2 14 10 33 0l18 31q3 8-5 12H82q-8-4-5-12Z" fill="${gold}"/>
    <circle cx="113" cy="171" r="6" fill="${dark}" stroke="none"/>
    <circle cx="143" cy="182" r="4" fill="${dark}" stroke="none"/>
    <circle cx="126" cy="131" r="5" fill="${ivory}" stroke="none"/>
    <circle cx="137" cy="42" r="8" stroke="${ivory}" stroke-width="4"/>
    <circle cx="110" cy="30" r="4" fill="${gold}" stroke="none"/>
    <path d="m66 79 4 14 14 4-14 4-4 14-4-14-14-4 14-4Z" fill="${ivory}" stroke-width="3"/>
    <path d="m184 111 3 10 10 3-10 3-3 10-3-10-10-3 10-3Z" fill="${ivory}" stroke-width="3"/>
  ` },
  { id: 7, name: 'Bard', symbol: `
    <path d="M73 65q-18 0-15 23l16 64q8 38 54 48 46-10 54-48l16-64q3-23-15-23-19-2-20 14-1 13 11 18l-12 51q-6 22-34 33-28-11-34-33L82 97q12-5 11-18-1-16-20-14Z" fill="${ivory}"/>
    <path d="M88 93h80v13H88Z" fill="${gold}"/>
    <path d="M105 106v50m15-50v65m15-65v65m15-65v50" stroke="${gold}" stroke-width="4"/>
    <path d="M108 201h40l7 13h-54Z" fill="${gold}"/>
    <path d="M116 56V35l25-6v21" stroke="${ivory}" stroke-width="5"/>
    <ellipse cx="108" cy="57" rx="9" ry="6" fill="${gold}" stroke="none"/>
    <ellipse cx="133" cy="51" rx="9" ry="6" fill="${gold}" stroke="none"/>
    <path d="M43 138q-9 10 0 20m170-20q9 10 0 20" stroke-width="3"/>
  ` },
  { id: 8, name: 'Cleric', symbol: `
    <path d="m128 28 8 23 24-10-5 26 26 4-19 18 19 18-26 4 5 26-24-10-8 23-8-23-24 10 5-26-26-4 19-18-19-18 26-4-5-26 24 10Z" fill="${gold}"/>
    <circle cx="128" cy="89" r="29" fill="${dark}"/>
    <path d="m128 70 13 19-13 19-13-19Z" fill="${ivory}" stroke-width="3"/>
    <path d="M96 141h64q-4 31-25 38v21h19v12h-52v-12h19v-21q-21-7-25-38Z" fill="${ivory}"/>
    <path d="M107 150h42q-6 16-21 17-15-1-21-17Z" fill="${dark}" stroke-width="3"/>
    <path d="M59 102v14m-7-7h14m131-7v14m-7-7h14" stroke-width="3"/>
  ` },
  { id: 9, name: 'Warlock', symbol: `
    <path d="M88 43q-37 41-18 86 14 34 58 53-49-2-72-33-39-54 32-106Z" fill="${gold}"/>
    <path d="M168 43q37 41 18 86-14 34-58 53 49-2 72-33 39-54-32-106Z" fill="${gold}"/>
    <path d="M73 111q55-49 110 0-55 49-110 0Z" fill="${dark}"/>
    <path d="M87 111q41-31 82 0-41 31-82 0Z" fill="${ivory}" stroke-width="3"/>
    <path d="m128 89 11 22-11 22-11-22Z" fill="${dark}"/>
    <path d="m128 40 0 29m-9-17 18 0" stroke="${ivory}" stroke-width="4"/>
    <path d="M128 151q-17 18-18 36-1 18 18 29 19-11 18-29-1-18-18-36Z" fill="${dark}"/>
    <path d="m128 170 0 28m-8-8 8 8 8-8" stroke="${ivory}" stroke-width="4"/>
  ` },
  { id: 10, name: 'Duelist', symbol: `
    <path d="m176 36-30 74-37 50-12-9 35-52Z" fill="${ivory}"/>
    <path d="m161 62-56 91" stroke-width="3"/>
    <path d="M91 145q-24 10-17 29 5 16 26 10 18-5 23-25m-34-15 37 23" stroke="${gold}" stroke-width="7"/>
    <path d="m91 174-20 29 10 7 20-29Z" fill="${gold}"/>
    <path d="m65 202 19 12-7 9-18-12Z" fill="${ivory}"/>
    <path d="m84 60 25 20 30 48-10 7-32-46Z" fill="${gold}"/>
    <path d="m124 129 22-13 6 9-22 14Z" fill="${ivory}"/>
    <path d="m137 136 16 24 8-6-15-24Z" fill="${gold}"/>
    <path d="M155 173q27-2 33-25 6 42-33 54m13-13 12 5m-2-16 13 2" stroke-width="4"/>
    <path d="m64 90 3 11 11 3-11 3-3 11-3-11-11-3 11-3Z" fill="${ivory}" stroke-width="3"/>
  ` },
  { id: 11, name: 'Beastmaster', symbol: `
    <path d="m68 42 44 30h32l44-30-2 64 15 34-29 36-22 15-22 24-22-24-22-15-29-36 15-34Z" fill="${dark}"/>
    <path d="m78 61 25 23-27 19Zm100 0-25 23 27 19Z" fill="${gold}" stroke-width="3"/>
    <path d="m77 117 30 14 21 42 21-42 30-14-9 37-23 12-19 28-19-28-23-12Z" fill="${ivory}"/>
    <path d="m87 119 21 11m61-11-21 11" stroke="${gold}" stroke-width="8"/>
    <path d="m116 160 24 0-12 14Z" fill="${dark}" stroke="${dark}" stroke-width="3"/>
    <path d="M128 175v12m-13-1 13 8 13-8" stroke="${dark}" stroke-width="4"/>
    <path d="m115 87 13 11 13-11m-13 14v29" stroke-width="4"/>
    <path d="m50 185 12 10m-15 2 12 10m144-22-12 10m15 2-12 10" stroke-width="4"/>
  ` },
];

function makeSvg(profession) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <title>${profession.name} profession emblem</title>
  <desc>Original editable gold and ivory heraldic symbol. Transparent background, 256 square canvas.</desc>
  <g stroke="${gold}" stroke-width="5.5" fill="none" stroke-linecap="round" stroke-linejoin="round">
    ${profession.symbol}
  </g>
</svg>\n`;
}

async function main() {
  fs.mkdirSync(outputDir, { recursive: true });
  const manifest = [];
  for (const profession of professions) {
    const svg = makeSvg(profession);
    fs.writeFileSync(path.join(sourceDir, `profession-${profession.id}.svg`), svg);
    const outputPath = path.join(outputDir, `profession-${profession.id}.png`);
    await sharp(Buffer.from(svg), { density: 288 }).resize(256, 256).png().toFile(outputPath);
    const buffer = fs.readFileSync(outputPath);
    const { data, info } = await sharp(buffer).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
    let pixels = 0;
    let minX = 256, minY = 256, maxX = -1, maxY = -1;
    for (let y = 0; y < info.height; y++) {
      for (let x = 0; x < info.width; x++) {
        if (data[(y * info.width + x) * 4 + 3] > 8) {
          pixels++;
          minX = Math.min(minX, x); minY = Math.min(minY, y);
          maxX = Math.max(maxX, x); maxY = Math.max(maxY, y);
        }
      }
    }
    if (info.width !== 256 || info.height !== 256 || pixels < 1000 || minX < 16 || minY < 16 || maxX > 239 || maxY > 239)
      throw new Error(`Invalid icon bounds for ${profession.name}`);
    manifest.push({ id: profession.id, name: profession.name, sha256: crypto.createHash('sha256').update(buffer).digest('hex'), bounds: [minX, minY, maxX, maxY], paintedPixels: pixels });
  }
  if (new Set(manifest.map(icon => icon.sha256)).size !== 11) throw new Error('Duplicate profession icons');
  fs.writeFileSync(path.join(sourceDir, 'manifest.json'), JSON.stringify({ canvasSize: 256, background: 'transparent', icons: manifest }, null, 2) + '\n');

  const columns = 6, cellWidth = 240, cellHeight = 285;
  const sheetWidth = columns * cellWidth, sheetHeight = 2 * cellHeight + 94;
  let sheet = `<svg xmlns="http://www.w3.org/2000/svg" width="${sheetWidth}" height="${sheetHeight}"><rect width="100%" height="100%" fill="#24382f"/><text x="32" y="42" fill="${ivory}" font-size="22" font-family="sans-serif" letter-spacing="3">PROFESSION EMBLEMS</text><text x="32" y="70" fill="${gold}" font-size="14" font-family="sans-serif">ORIGINAL VECTOR SET / 256 PX / TRANSPARENT / 64 PX CHECK</text>`;
  for (let index = 0; index < professions.length; index++) {
    const p = professions[index], x = index % columns * cellWidth, y = 94 + Math.floor(index / columns) * cellHeight;
    sheet += `<rect x="${x+12}" y="${y}" width="216" height="270" rx="4" fill="#2d4035" stroke="#62705a" stroke-width="1"/>`;
    sheet += `<g transform="translate(${x+24},${y+4}) scale(.75)" stroke="${gold}" stroke-width="5.5" fill="none" stroke-linecap="round" stroke-linejoin="round">${p.symbol}</g>`;
    sheet += `<text x="${x+120}" y="${y+205}" text-anchor="middle" fill="${ivory}" font-size="15" font-family="sans-serif">${p.id.toString().padStart(2,'0')}  ${p.name.toUpperCase()}</text>`;
    sheet += `<g transform="translate(${x+41},${y+207}) scale(.25)" stroke="${gold}" stroke-width="5.5" fill="none" stroke-linecap="round" stroke-linejoin="round">${p.symbol}</g>`;
    sheet += `<rect x="${x+128}" y="${y+210}" width="56" height="56" rx="28" fill="#e8ddbe"/><g transform="translate(${x+124},${y+206}) scale(.25)" stroke="${gold}" stroke-width="5.5" fill="none" stroke-linecap="round" stroke-linejoin="round">${p.symbol}</g>`;
  }
  sheet += '</svg>';
  await sharp(Buffer.from(sheet)).png().toFile(path.join(sourceDir, 'profession-icons-overview.png'));
  console.log(JSON.stringify({ outputDir, count: manifest.length, uniqueHashes: new Set(manifest.map(i => i.sha256)).size, overview: path.join(sourceDir, 'profession-icons-overview.png') }, null, 2));
}
main().catch(error => { console.error(error); process.exitCode = 1; });
