from pathlib import Path
import json, importlib.util
ROOT=Path(__file__).resolve().parent
changes={
'hornbow':('https://www.vgbaike.com/elden_ring/baike14959','https://media.vgbaike.com/database/2022/0620/20/33203_oqnzfv.png'),
'shortbow':('https://www.gamersky.com/handbook/202401/1694907_252.shtml','https://img1.gamersky.com/image2024/01/20240110_apl_435_24/13920_S.jpg'),
'arbalest':('https://note.com/pyon_pyoko/n/n660826ddbece','https://assets.st-note.com/img/1665331647999-N3RZHQW5Ug.jpg'),
'hunter_pistol':('https://www.gamedeveloper.com/design/hunter-s-pistol','https://eu-images.contentstack.com/v3/assets/blt740a130ae3c5d529/blt3ab1d9a2f9486e31/650e86df0d64cd4b7ab4a325/shot4.png'),
'metro_optics':('https://metrovideogame.fandom.com/wiki/Valve','https://vignette.wikia.nocookie.net/metro2033/images/c/ce/Exodus_-_Valve_1.png/revision/latest?cb=20181216175250'),
'metro_silenced_two':('https://www.pinterest.com/pin/507217976789031338/','https://i.pinimg.com/736x/22/de/c6/22dec66be832e00d5544fd867d5804ae.jpg'),
'kite':('https://www.vgbaike.com/elden_ring/item33098','https://media.vgbaike.com/database/2022/0620/20/33098_n5ydyd.png'),
'twinbird':('https://note.com/pyon_pyoko/n/n528fd7e9bae7','https://assets.st-note.com/img/1668699018303-D1tFh4ZJlL.jpg'),
'academy':('https://www.vgbaike.com/elden_ring/baike14925','https://media.vgbaike.com/database/2022/0620/20/33169_sggr7w.png'),
'lusat':('https://www.vgbaike.com/elden_ring/baike14928','https://media.vgbaike.com/database/2022/0620/20/33172_o0lknt.png')}
path=ROOT/'References/references.json';data=json.loads(path.read_text(encoding='utf8'))
for r in data['images']:
    if r['id'] in changes:r['page_url'],r['image_url']=changes[r['id']]
    if r['id']=='shortbow':r['title']='Elden Ring / Longbow item card';r['takeaway']='传统木长弓的长臂比例、弦距与包握区。'
    if r['id']=='metro_silenced_two':r['title']='Bloodborne / Ludwig rifle and repeating pistol concept';r['takeaway']='细窄接口和渐变枪口外壳的层次；借鉴哥特工业外观而非现实消声机构。'
path.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf8')
rows=json.loads((ROOT/'catalog.json').read_text(encoding='utf8'));refs={r['id']:r for r in data['images']}
for row in rows:row['references']=[refs[r['id']] for r in row['references']]
(ROOT/'catalog.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf8')
spec=importlib.util.spec_from_file_location('catalog',ROOT/'author_catalog.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);module.download_references()
