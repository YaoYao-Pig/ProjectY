"""Diagnostic contact sheets only. Original model renders and textures are unchanged."""
from pathlib import Path
from PIL import Image, ImageDraw
import json
ROOT=Path(__file__).resolve().parent
(ROOT/'Previews').mkdir(exist_ok=True)
textures=json.loads((ROOT/'texture_manifest.json').read_text(encoding='utf8'))
for row in textures:
    original=Image.open(ROOT/row['file']).convert('RGB')
    tile=original.resize((384,384),Image.Resampling.LANCZOS)
    sheet=Image.new('RGB',(1152,1152))
    for y in range(3):
        for x in range(3):sheet.paste(tile,(384*x,384*y))
    sheet.save(ROOT/'Previews'/(row['id']+'_repeat3x3.png'))
if (ROOT/'manifest.json').exists():
    rows=json.loads((ROOT/'manifest.json').read_text(encoding='utf8'))
    for batch in range(0,len(rows),5):
        sheet=Image.new('RGB',(1280,5*348),(20,25,32));draw=ImageDraw.Draw(sheet)
        for i,row in enumerate(rows[batch:batch+5]):
            draw.text((12,i*348+3),row['name'],fill=(225,225,215))
            for k,view in enumerate(['front','side','back','hero']):
                path=ROOT/'Previews'/(row['name']+'_'+view+'.png')
                if path.exists():sheet.paste(Image.open(path).convert('RGB').resize((320,320)),(320*k,i*348+26))
        sheet.save(ROOT/'Previews'/('Review_%02d.png'%(batch//5+1)))
