"""Archive identified visual research; images are never used as model textures."""
import json, urllib.request, shutil
from pathlib import Path
from PIL import Image, ImageOps, ImageDraw
ROOT=Path(__file__).parent
REF=ROOT/'References';REF.mkdir(parents=True,exist_ok=True)
rows=[
('sot_rope','Sea of Thieves — Sail controls','https://kanobu.ru/news/kak-upravlyat-korablem-v-sea-of-thieves-v-odinochku-i-v-komande-403037/','https://u.kanobu.ru/editor/images/8/dbf2563c-ee31-4924-86fa-413848c23ed7.png','粗绳卷绕、暗铁缆座与船上绳具的功能轮廓，压低细节保持近景可辨'),
('sot_gear','Sea of Thieves — Season Four','https://www.seaofthieves.com/season-four','https://rare-assets.azureedge.net/compass/5ee6cf06463808c6eb84837eb6e7554e14135aaa.jpg','多段铜望远镜、宽罗盘圈、罩灯的明确外轮廓；简化装饰而保留用途'),
('sot_table','Sea of Thieves — Quest Table','https://rarethief.com/sea-of-thieves-how-to-use-the-quest-table/','https://rarethief.com/wp-content/uploads/2024/01/sea-of-thieves-season-11-quest-table.png','厚纸海图、封面书册、书写桌与暖色灯具的航海叙事组合'),
('sot_cabin','Sea of Thieves — Captain’s cabin','https://www.windowscentral.com/gaming/will-sea-of-thieves-ever-deliver-pve-only-play-for-those-who-hate-pvp','https://cdn.mos.cms.futurecdn.net/ZVqGmeMU6VuArfLWtoTx6C.png','航海书册、沙漏、海图、罗盘在桌面上的真实比例关系'),
('skyrim_household','The Elder Scrolls V: Skyrim — household clutter','https://www.nexusmods.com/skyrim/mods/112540','https://staticdelivery.nexusmods.com/mods/110/images/headers/112540_1657828679.jpg','原游戏木碗、陶碗、容器的宽口与厚边剪影，以及低饱和生活材质'),
('skyrim_tavern','The Elder Scrolls V: Skyrim — Rustic Clutter visual study','https://stepmodifications.org/forum/topic/14986-rustic-clutter-collection-special-edition-by-gamwich/','https://i.postimg.cc/JzQm3b8C/Shot128.png','浅碗、杯、罐的朴素手工体量；只参考形状，不复制模组贴图'),
('skyrim_smith','The Elder Scrolls V: Skyrim — Smithing workbench','https://www.carlsguides.com/skyrim/combat/smithing.php','https://www.carlsguides.com/skyrim/pictures/smithingworkbench.gif','修补工位的木铁组合、夹持与储物用品的功能尺寸'),
('lotr_pipe','The Lord of the Rings — Gandalf pipe, Weta replica','https://www.moviefigures.co.uk/products/weta-workshop-the-pipe-of-gandalf-the-grey-the-lord-of-the-rings-1-1-scale-collectible-prop-replica','https://www.moviefigures.co.uk/cdn/shop/files/WetaLordoftheRingsThePipeofGandalftheGrey1_1PropReplica2_1200x1200.jpg?v=1731594351','长弯柄与粗烟斗钵形成的非对称剪影，不复制雕纹'),
('lotr_bilbo','The Lord of the Rings — Hobbiton Weta pipe replica','https://shop.hobbitontours.com/products/the-pipe-of-gandalf-the-grey','https://shop.hobbitontours.com/cdn/shop/files/Collectables_Hobbiton_Merchandise-2025-SJP-185.jpg?v=1762209776&width=1080','另一实物视角中的木柄曲线与厚实钵口，日用小器物的温暖旧木材质'),
]
refs=[]
for id,work,page,url,study in rows:
    target=REF/(id+'.png')
    if not target.exists():
        request=urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'})
        raw=urllib.request.urlopen(request,timeout=50).read()
        import io
        Image.open(io.BytesIO(raw)).convert('RGB').save(target)
    refs.append(dict(id=id,work=work,page=page,image=url,local='References/'+target.name,study=study))
for group,category in [('Items','medical'),('Shipwreck',None)]:
    path=ROOT.parent/group/('references.json' if group=='Items' else 'References/references.json')
    old=json.loads(path.read_text(encoding='utf8'))
    selected=old[category] if category else [r for r in old if r['id']=='sot_supplies']
    for entry in selected:
        r=dict(entry);r['local']='References/'+r['id']+'.png'
        shutil.copyfile(ROOT.parent/group/'References'/(r['id']+'.png'),ROOT/r['local']);refs.append(r)
(REF/'references.json').write_text(json.dumps(refs,ensure_ascii=False,indent=2),encoding='utf8')
width=1400;tilew=350;tileh=280
board=Image.new('RGB',(width,((len(refs)+3)//4)*tileh),'#ddd9ce');d=ImageDraw.Draw(board)
for i,r in enumerate(refs):
    im=Image.open(ROOT/r['local']).convert('RGB');im.thumbnail((340,245))
    x=(i%4)*tilew;y=(i//4)*tileh;board.paste(im,(x+(tilew-im.width)//2,y+(245-im.height)//2))
    d.text((x+8,y+252),r['id'],fill='#222222')
board.save(REF/'reference_board.jpg',quality=93)
print(json.dumps({'references':len(refs),'board':str(REF/'reference_board.jpg')}))
