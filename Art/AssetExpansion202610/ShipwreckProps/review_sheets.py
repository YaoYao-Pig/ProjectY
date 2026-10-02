"""Contact sheets from actual Blender four-view renders, not illustration substitutes."""
import json
from pathlib import Path
from PIL import Image, ImageDraw
ROOT=Path(__file__).parent
rows=json.loads((ROOT/'manifest.json').read_text(encoding='utf8'))
for page in range(4):
    sheet=Image.new('RGB',(1280,1700),'#171c23');d=ImageDraw.Draw(sheet)
    for j,row in enumerate(rows[page*5:page*5+5]):
        for i,view in enumerate(['front','side','back','hero']):
            im=Image.open(ROOT/'Previews'/(row['name']+'_'+view+'.png')).convert('RGB');im=im.resize((320,320))
            sheet.paste(im,(i*320,j*340));d.text((i*320+8,j*340+318),row['slug']+' / '+view,fill='#ddd9ce')
    path=ROOT/'Previews'/('review_sheet_'+str(page+1)+'.jpg');sheet.save(path,quality=93);print(path)
sheet=Image.new('RGB',(1600,1320),'#171c23');d=ImageDraw.Draw(sheet)
for j,row in enumerate(rows):
    im=Image.open(ROOT/'Previews'/(row['name']+'_hero.png')).convert('RGB');im=im.resize((320,320));x=(j%5)*320;y=(j//5)*330
    sheet.paste(im,(x,y));d.text((x+8,y+308),row['slug'],fill='#ddd9ce')
sheet.save(ROOT/'Previews/collection_hero.jpg',quality=95)
