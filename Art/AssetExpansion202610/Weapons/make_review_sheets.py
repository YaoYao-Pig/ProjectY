"""Assemble already-rendered review views; no synthetic model images."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,sys
R=Path(__file__).resolve().parent
rows=json.loads((R/'manifest.json').read_text(encoding='utf8'))
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',15)
small=ImageFont.truetype('C:/Windows/Fonts/consola.ttf',13)
families=list(dict.fromkeys(x['category'] for x in rows))
if len(sys.argv)>1:families=[f for f in families if f in sys.argv[1:]]
for family in families:
    subset=[x for x in rows if x['category']==family]
    sheet=Image.new('RGB',(1280,5*342+36),'#20272e');d=ImageDraw.Draw(sheet)
    for k,view in enumerate(['front','side','back','hero']):d.text((k*320+12,8),view,fill='#d3d9d9',font=small)
    for j,row in enumerate(subset):
        for k,view in enumerate(['front','side','back','hero']):
            p=R/'Previews'/(row['name']+'_'+view+'.png');im=Image.open(p).convert('RGB');im.thumbnail((316,306))
            x=k*320+(320-im.width)//2;y=j*342+62;sheet.paste(im,(x,y))
        d.text((12,j*342+38),row['display_name']+'  '+row['name'],fill='#eee9df',font=font)
    path=R/'Previews'/('Review_'+family+'.jpg');sheet.save(path,quality=94)
print('Review contact sheets:',len(families))
