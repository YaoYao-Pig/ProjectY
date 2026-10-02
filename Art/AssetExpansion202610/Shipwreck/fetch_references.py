from pathlib import Path
import urllib.request,json,concurrent.futures
from io import BytesIO
from PIL import Image,ImageDraw
root=Path(__file__).parent
refs=json.loads((root/'References/references.json').read_text(encoding='utf8'))
def fetch(r):
    p=root/r['local']
    if not p.exists():
        req=urllib.request.Request(r['image'],headers={'User-Agent':'Mozilla/5.0'})
        with urllib.request.urlopen(req,timeout=25) as response:raw=response.read()
        Image.open(BytesIO(raw)).convert('RGB').save(p)
    return r['id'],Image.open(p).size
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    for result in pool.map(fetch,refs):print(result)
board=Image.new('RGB',(1400,940),'#202c2e');draw=ImageDraw.Draw(board)
for i,r in enumerate(refs):
    im=Image.open(root/r['local']);im.thumbnail((690,425));x=i%2*700;y=i//2*470
    board.paste(im,(x+(700-im.width)//2,y+30));draw.text((x+15,y+5),r['id'],fill='white')
board.save(root/'References/board.jpg')
