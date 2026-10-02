from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,sys
base=Path(__file__).parent
groups=sys.argv[1:] or ['Terrain','Dungeon','Items','Weapons']
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',16)
for group in groups:
    rows=json.loads((base/group/'manifest.json').read_text(encoding='utf8'))
    sheet=Image.new('RGB',(1500,((len(rows)+5)//6)*280),'#1f292c');d=ImageDraw.Draw(sheet)
    for i,r in enumerate(rows):
        p=base/group/'UnityPreviews'/(r['name']+'.png')
        if not p.exists():continue
        im=Image.open(p).convert('RGBA');im.thumbnail((248,248));x=i%6*250;y=i//6*280
        sheet.paste(im,(x,y),im)
        title=r.get('title',r.get('display_name_zh',r.get('name_zh',r['name'])))
        d.text((x+5,y+247),title[:24],fill='#d3d9bf',font=font)
    sheet.save(base/group/'UnityPreviews/overview.jpg')
    print(group,len(rows))
