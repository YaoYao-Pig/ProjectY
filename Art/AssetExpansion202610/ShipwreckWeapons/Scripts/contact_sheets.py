from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
import json
BASE=Path(__file__).resolve().parents[1];P=BASE/'Previews'
rows=json.loads((BASE/'manifest.json').read_text(encoding='utf8'))
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',16)
for start in [0,5]:
    out=Image.new('RGB',(1600,1800),(38,43,50));d=ImageDraw.Draw(out)
    for i,row in enumerate(rows[start:start+5]):
        y=i*360;d.text((10,y+6),row['name'],fill='#f2e5cc',font=font)
        for j,view in enumerate(['front','side','back','hero']):
            im=Image.open(P/(row['name']+'_'+view+'.png')).convert('RGB');im.thumbnail((320,320));out.paste(im,(j*400+40,y+30));d.text((j*400+5,y+35),view,fill='#aabbcc',font=font)
    out.save(P/('review_sheet_%d.png'%(start//5+1)))
out=Image.new('RGB',(1600,840),(38,43,50));d=ImageDraw.Draw(out)
for i,row in enumerate(rows):
    im=Image.open(P/(row['name']+'_hero.png')).convert('RGB');im.thumbnail((315,360));x=i%5*320;y=i//5*420;out.paste(im,(x,y));d.text((x+5,y+369),row['name'].replace('SWW_',''),fill='#f2e5cc',font=font)
out.save(P/'overview.png')
print('2 review sheets and 10-item overview saved')
