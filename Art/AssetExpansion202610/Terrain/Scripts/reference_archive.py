"""Archive already searched game screenshot references for local visual study."""
from pathlib import Path
import json, urllib.request
from PIL import Image, ImageOps, ImageDraw
ROOT=Path(__file__).resolve().parents[1]
R=ROOT/'References'
refs=[
('swamp_valheim_01','Swamp','Valheim','https://www.gamegrin.com/directory/game/valheim/images','https://www.gamegrin.com/assets/game/valheim/screenshots/valheim-screenshots-13.jpg','扭曲枯木、裸露板根、深褐泥与灰绿植物'),
('swamp_valheim_02','Swamp','Valheim','https://scalacube.com/blog/valheim/how-to-find-swamp-valheim','https://res.cloudinary.com/ddbybfkod/image/upload/v1749907478/blogs/Nemanja/how-to-find-swamp-valheim/img1_j7zozv.png','湿地疏密关系、枯枝与芦苇的高低对比'),
('dark_elden_01','DarkForest','Elden Ring: Shadow of the Erdtree','https://www.gamepressure.com/elden-ring/how-to-reach-the-abyssal-woods/z0114b8','https://www.gamepressure.com/elden-ring/gfx/word/961246390.jpg','深渊森林倾斜古树和钩状枝条'),
('dark_elden_02','DarkForest','Elden Ring: Shadow of the Erdtree','https://www.neoseeker.com/elden-ring-shadow-of-the-erdtree/walkthrough/Abyssal_Woods','https://cdn.staticneo.com/ew/b/be/Elden-Ring-SotE_AW-15.jpg','暗林冷灰树干、根部包石与抑制饱和度'),
('lava_minecraft_01','Lava','Minecraft','https://www.windowscentral.com/minecraft-guide-full-changelog-nether-update','https://cdn.mos.cms.futurecdn.net/rkMyB6S5XQc8HiXAKL29Da.jpg','玄武岩柱与窄熔岩脉的明暗层次'),
('lava_minecraft_02','Lava','Minecraft','https://www.windowscentral.com/minecraft-quick-guide-cheat-sheet-everything-new-nether-update','https://cdn.mos.cms.futurecdn.net/b8wSdWNynNFyNsCW4QE7So.jpg','柱状节理、熔岩裂隙与黑石薄壳'),
('volcano_elden_01','Volcano','Elden Ring','https://www.vidaextra.com/guias-y-trucos/truco-secreto-para-acceder-al-interior-volcan-elden-ring-este-proceso-que-debes-seguir','https://i.blogs.es/64f2cc/140322-eldenring-volcan/1200_630.jpeg','火山内壁层层退台和暗红灼烧边缘'),
('volcano_elden_02','Volcano','Elden Ring','https://www.eurogamer.de/elden-ring-gelmir-erreichen-und-betreten-karte-bruecke-haendler-und-alle-personen','https://assetsio.gnwcdn.com/gelmir.jpg?auto=webp&enable=upscale&fit=crop&format=png&height=900&quality=100&width=1200','盖利德以外的格密尔尖峰、灰烬和硫黄色矿层'),
('mushroom_minecraft_01','Mushroom','Minecraft','https://scalacube.com/blog/minecraft/the-rare-mushroom-field-in-minecraft','https://res.cloudinary.com/ddbybfkod/image/upload/v1710169038/blogs/Roman/the-rare-mushroom-field-in-minecraft/img1_j2iisi.jpg','蘑菇岛红白伞盖与褐色平顶菌盖的轮廓区别'),
('mushroom_minecraft_02','Mushroom','Minecraft','https://fr-minecraft.net/biome-14-champs-de-champignons.html','https://fr-minecraft.net/img/biomes/full/MushroomIsland_06.jpg','灰紫菌丝土与巨型菌柄、成簇低矮蘑菇的尺度对比')]
rows=[]
for id,biome,work,page,url,note in refs:
    path=R/(id+'.jpg')
    if not path.exists():
        req=urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'})
        data=urllib.request.urlopen(req,timeout=30).read()
        path.write_bytes(data)
    with Image.open(path) as im:
        size=list(im.size)
    rows.append(dict(id=id,biome=biome,work=work,page_url=page,image_url=url,local_file=str(path),dimensions_px=size,influence_zh=note,reviewed=False,retrieved='2026-10-01',rights='Reference only; original game copyright retained; not shipped as textures.'))
(R/'reference_index.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf8')
for start in (0,4,8):
    subset=rows[start:start+4]
    sheet=Image.new('RGB',(1400,450*((len(subset)+1)//2)),(28,32,39))
    dr=ImageDraw.Draw(sheet)
    for i,row in enumerate(subset):
        im=Image.open(row['local_file']).convert('RGB');im.thumbnail((690,405))
        x=(i%2)*700;y=(i//2)*450
        sheet.paste(im,(x,y+28));dr.text((x+10,y+5),row['id']+' | '+row['work'],fill='white')
    sheet.save(R/('references_'+str(start//4+1)+'.jpg'))
print(json.dumps([{'id':r['id'],'size':r['dimensions_px']} for r in rows]))
