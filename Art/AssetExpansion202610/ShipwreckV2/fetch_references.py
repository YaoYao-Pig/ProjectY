from pathlib import Path
import json,urllib.request
from io import BytesIO
from PIL import Image,ImageDraw
root=Path(__file__).parent;refs=json.loads((root/'references.json').read_text(encoding='utf8'))
(root/'References').mkdir(exist_ok=True)
sheet=Image.new('RGB',(1400,930),'#1c2c30');draw=ImageDraw.Draw(sheet)
for i,r in enumerate(refs):
    path=root/r['local']
    if not path.exists():
        req=urllib.request.Request(r['image'],headers={'User-Agent':'Mozilla/5.0'})
        with urllib.request.urlopen(req,timeout=20) as response:data=response.read()
        Image.open(BytesIO(data)).convert('RGB').save(path)
    im=Image.open(path).convert('RGB');print(r['id'],im.size);im.thumbnail((690,420))
    x=i%2*700;y=i//2*465;sheet.paste(im,(x+(700-im.width)//2,y+30));draw.text((x+10,y+5),r['id'],fill='white')
sheet.save(root/'References/board.jpg')
