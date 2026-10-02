"""Arrange original rendered views without altering their content."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json
BASE=Path(__file__).resolve().parents[1]
rows=json.loads((BASE/'manifest.json').read_text(encoding='utf8'))
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',15)
for start in range(0,len(rows),6):
    batch=rows[start:start+6];sheet=Image.new('RGB',(1536,len(batch)*300),(42,47,55));d=ImageDraw.Draw(sheet)
    for y,row in enumerate(batch):
        name=row['name'];d.text((12,y*300+8),name,fill='#f5e5c5',font=font)
        for x,view in enumerate(['front','side','back','hero']):
            p=BASE/'Previews'/(name+'_'+view+'.png')
            if p.exists():
                im=Image.open(p).convert('RGB');im.thumbnail((270,270));sheet.paste(im,(x*384+58,y*300+28))
            d.text((x*384+8,y*300+38),view,fill='#aaaaaa',font=font)
    sheet.save(BASE/'Previews'/('review_sheet_%02d.png'%(start//6+1)))
hero=Image.new('RGB',(1800,1500),(42,47,55));d=ImageDraw.Draw(hero)
for i,row in enumerate(rows[15:]):
    im=Image.open(BASE/'Previews'/(row['name']+'_hero.png')).convert('RGB');im.thumbnail((288,275))
    x=i%6*300;y=i//6*350;hero.paste(im,(x+6,y+25));d.text((x+6,y+305),row['name'].replace('AE_',''),fill='#e3d7bc',font=font)
hero.save(BASE/'Previews/terrain_decor_overview.png')
tiles=Image.new('RGB',(1500,900),(42,47,55));d=ImageDraw.Draw(tiles)
for i,row in enumerate(rows[:15]):
    im=Image.open(BASE/'Previews'/(row['name']+'_hero.png')).convert('RGB');im.thumbnail((285,260));x=i%5*300;y=i//5*300
    tiles.paste(im,(x,y));d.text((x+5,y+270),row['name'].replace('AE_Hex_',''),fill='#e3d7bc',font=font)
tiles.save(BASE/'Previews/terrain_tiles_overview.png')
print('6 full-view sheets, decoration overview, tile overview written')
