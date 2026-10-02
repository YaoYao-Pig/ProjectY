"""Arrange actual renders for visual inspection. Never substitutes for viewing them."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,sys
base=Path(__file__).parent
group=sys.argv[1]
rows=json.loads((base/group/'manifest.json').read_text(encoding='utf8'))
out=base/group/'Previews'
views=['front','side','back','hero']
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',15)
for start in range(0,len(rows),5):
    batch=rows[start:start+5]
    sheet=Image.new('RGB',(1280,len(batch)*350),(20,24,31));d=ImageDraw.Draw(sheet)
    for i,row in enumerate(batch):
        d.text((10,i*350+3),row.get('title',row['name'])+' / '+row['name'],font=font,fill='white')
        for j,v in enumerate(views):
            p=out/(row['name']+'_'+v+'.png')
            if not p.exists():continue
            im=Image.open(p).convert('RGB');im.thumbnail((315,315))
            sheet.paste(im,(j*320,i*350+30));d.text((j*320+10,i*350+29),v,font=font,fill='#92a5ad')
    sheet.save(out/('review_%02d.jpg'%(start//5+1)))
hero=Image.new('RGB',(1200,((len(rows)+5)//6)*225),(20,24,31));d=ImageDraw.Draw(hero)
for i,row in enumerate(rows):
    p=out/(row['name']+'_hero.png')
    if not p.exists():continue
    im=Image.open(p).convert('RGB');im.thumbnail((196,196));x=i%6*200;y=i//6*225
    hero.paste(im,(x,y));d.text((x+4,y+195),row.get('title',row['name'][-22:]),font=font,fill='white')
hero.save(out/'overview.jpg')
print(group,len(rows))
