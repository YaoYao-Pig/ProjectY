"""Label actual Unity captures without changing model pixels or inventing renders."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]
rows=json.loads((ROOT/'manifest.json').read_text(encoding='utf-8'))
font_path='C:/Windows/Fonts/msyh.ttc'
title=ImageFont.truetype(font_path,32)
label=ImageFont.truetype(font_path,23)
small=ImageFont.truetype(font_path,17)
background=(16,20,26)

sheet=Image.new('RGB',(1440,1300),background)
draw=ImageDraw.Draw(sheet)
draw.text((32,20),'枪械扩展 · 写实比例修订',font=title,fill=(222,225,229))
draw.text((32,66),'实际 Unity 模型与装配预览',font=small,fill=(155,166,178))
for index,row in enumerate(r for r in rows if r['kind']=='weapon'):
    x=index%2*720;y=110+index//2*390
    sheet.paste(Image.open(ROOT/'Previews'/f"{row['id']}.png").convert('RGB'),(x,y))
    draw.text((x+32,y+340),row['name'],font=label,fill=(215,219,224))
sheet.save(ROOT/'Previews/contact-sheet.png')

supplies=[r for r in rows if r['kind']!='weapon']
sheet=Image.new('RGB',(1440,1060),background);draw=ImageDraw.Draw(sheet)
draw.text((32,22),'弹匣、改装配件与弹药',font=title,fill=(222,225,229))
for index,row in enumerate(supplies):
    x=index%3*480;y=90+index//3*240
    capture=Image.open(ROOT/'Previews'/f"{row['id']}.png").convert('RGB')
    capture.thumbnail((480,240));sheet.paste(capture,(x,y))
    draw.text((x+24,y+208),row['name'],font=small,fill=(215,219,224))
sheet.save(ROOT/'Previews/accessories.png')
print('Saved labeled Unity weapon and accessory sheets')
