"""Archive searched reference images; all originals remain outside Unity Assets."""
from pathlib import Path
from PIL import Image, ImageDraw,ImageFont
from concurrent.futures import ThreadPoolExecutor
import json,urllib.request
BASE=Path(__file__).resolve().parents[1];R=BASE/'References'
refs=[
('sot_cutlasses','Sea of Thieves','https://vandal.elespanol.com/guias/guia-sea-of-thieves-trucos-y-consejos/combate-y-armas','https://media.vandal.net/i/928x522/4-2018/20184418282_1.jpg','海盗弯刃的长宽比、护手与刀柄层次'),
('sot_notable','Sea of Thieves','https://geekya.com/games/sot/items/notable-sea-dog-cutlass','https://geekya.com/sot-pv-images/athenawebsiteassets-a9awftf5fyfxandj.b01.azurefd.net/055c95ab064ea245a0504d7fea43ab096ab11ab829e497b78d35b35b6e4108a0.png','轻微弯曲刀背、铜制护拳与短握柄'),
('bb_cleaver','Bloodborne','https://www.creativeuncut.com/gallery-29/bb-cleaver-and-axe.html','https://www.creativeuncut.com/gallery-29/art/bb-cleaver-and-axe.jpg','粗齿刃、受损边缘和重新绑缚的旧兵器'),
('bb_boom','Bloodborne','https://www.creativeuncut.com/gallery-29/bb-boom-hammer.html','https://www.creativeuncut.com/gallery-29/art/bb-boom-hammer.jpg','重锤头与细长柄的质量对比，外露金属套箍'),
('er_anchor','Elden Ring','https://www.eurogamer.de/elden-ring-die-besten-tipps-und-tricks-fuer-einsteiger?page=95','https://assetsio.gnwcdn.com/073_Kodw0HQ.jpg?auto=webp&fit=bounds&format=jpg&height=2048&quality=85&width=2048','船具转兵器、弯爪和宽阔锚肩轮廓'),
('sot_harpoon','Sea of Thieves','https://www.pcgamer.com/sea-of-thieves-dark-relics-update-finally-sticks-harpoon-guns-on-rowboats/','https://cdn.mos.cms.futurecdn.net/czz2u32Q5D9hTrB2JbcvAK.jpg','海用索具、铜制连接件和鱼叉长轴方向'),
('sot_trident','Sea of Thieves','https://www.gamersdecide.com/articles/sea-of-thieves-best-weapons','https://www.gamersdecide.com/sites/default/files/authors/u158847/trident.jpg','海潮法器的青绿矿物、叉形负空间和旧木柄'),
('sot_faraway','Sea of Thieves','https://www.joachimcoppens.com/work/sea-of-thieves-2025-cosmetics','https://images.squarespace-cdn.com/content/v1/61031b1f9ff42a0bb713c097/d0a17f64-5ba4-44e6-9d78-01c8e20342ec/JC_Folio_2025_02_ItemsOfFarawayShores_low.jpg','原项目美术师展示的刀刃矿物层次和灯笼笼架结构'),
('sot_knife','Sea of Thieves','https://www.merciasquill.com/database/cosmetics/record/shadow-tide-throwing-knives','https://cdn.merciasquill.com/Game_Assets/Cosmetics/Throwing_Knives/Shadow_Tide_Throwing_Knives.png','短刀刃厚度与小尺寸握持比例'),
('sk_crossbow','The Elder Scrolls V: Skyrim','https://duskworld.ru/skyrim/crossbow.php','https://duskworld.ru/images/skyrim/weapon/dwarven-crossbow.jpg','有支撑的弩臂、弦槽、木托与铜色套件'),
('er_serpent','Elden Ring','https://note.com/pyon_pyoko/n/naf6b9e14bc18','https://assets.st-note.com/img/1668276117048-rNW0QUTrf0.jpg','蛇形反曲弓梢及有机弧线'),
('sk_glass','The Elder Scrolls V: Skyrim','https://en.m.uesp.net/wiki/Skyrim%3AGlass_Bow_of_the_Stag_Prince','https://images.uesp.net/7/71/SR-icon-weapon-Glass_Bow.png','弓臂向外反曲与中心握位的尺度关系'),
('bb_pistol','Bloodborne','https://www.creativeuncut.com/gallery-29/bb-pistol.html','https://www.creativeuncut.com/gallery-29/art/bb-pistol.jpg','旧式短铳木柄弯曲与金属机匣分层，仅研究外形'),
('sot_pistol','Sea of Thieves','https://www.fandomspot.com/sea-of-thieves-best-flintlocks/','https://static.fandomspot.com/images/07/17039/09-sailor-pistol-render-sea-of-thieves.jpg','水手短铳简洁厚重的枪口、护圈和掌柄比例')]
def fetch(ref):
    id,work,page,url,note=ref;p=R/(id+'.img')
    if not p.exists():
        req=urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0','Referer':page})
        p.write_bytes(urllib.request.urlopen(req,timeout=45).read())
    with Image.open(p) as im:size=list(im.size);im.verify()
    return dict(id=id,work=work,page_url=page,image_url=url,local_file=str(p),dimensions_px=size,influence_zh=note,reviewed=False,retrieved='2026-10-02',rights='Reference only. Original game/artist copyright retained. Never shipped as textures.')
rows=list(ThreadPoolExecutor(max_workers=5).map(fetch,refs))
(R/'reference_index.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf8')
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
for start in range(0,len(rows),4):
    subset=rows[start:start+4];sheet=Image.new('RGB',(1440,900),(38,42,46));d=ImageDraw.Draw(sheet)
    for i,row in enumerate(subset):
        im=Image.open(row['local_file']).convert('RGBA');im.thumbnail((700,410));x=i%2*720;y=i//2*450
        sheet.paste(im,(x+(720-im.width)//2,y+32),im);d.text((x+10,y+5),row['id']+' | '+row['work'],font=font,fill='white')
    sheet.save(R/('reference_board_%02d.jpg'%(start//4+1)))
print(json.dumps([{'id':r['id'],'size':r['dimensions_px']} for r in rows]))
