from pathlib import Path
import json, urllib.request, concurrent.futures
from PIL import Image, ImageDraw
root=Path(__file__).parent
out=root/'References';out.mkdir(exist_ok=True)
data=json.loads((root/'references.json').read_text(encoding='utf8'))
def fetch(r):
    p=out/(r['id']+'.png')
    if not p.exists():
        req=urllib.request.Request(r['image'],headers={'User-Agent':'Mozilla/5.0'})
        with urllib.request.urlopen(req,timeout=25) as response:
            raw=response.read()
        from io import BytesIO
        im=Image.open(BytesIO(raw));im.convert('RGB').save(p)
    im=Image.open(p)
    return r['id'],im.size
refs=[r for v in data.values() for r in v]
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
    for result in pool.map(fetch,refs): print(result)
sheet=Image.new('RGB',(1200,6*360),'#20262e');draw=ImageDraw.Draw(sheet)
for i,r in enumerate(refs):
    im=Image.open(out/(r['id']+'.png')).convert('RGB');im.thumbnail((590,320))
    x=(i%2)*600;y=(i//2)*360
    sheet.paste(im,(x+(600-im.width)//2,y+25));draw.text((x+10,y+5),r['id'],fill='white')
sheet.save(out/'reference_board.jpg')
