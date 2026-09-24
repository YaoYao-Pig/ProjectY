"""本次建筑与表现表的初始迁移；后续直接调源表，不能重放覆盖人工编辑。"""
import json,copy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];TABLES=ROOT/'Config/Tables'
def read(group,name):return json.loads((TABLES/group/(name+'.json')).read_text(encoding='utf-8-sig'))
def save(group,data):
    p=TABLES/group/(data['name']+'.json');p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def field(name,kind,description,**extra):return dict(name=name,type=kind,description=description,**extra)
def table(name,description,fields,rows):return dict(version=1,name=name,description=description,key='id',fields=fields,rows=rows)
assets=read('Map','MapAssetTable');lots=read('MapArea','MapAreaTownLotTable');rooms=read('MapArea','MapAreaTownInteriorTable');facilities=read('MapArea','MapAreaTownFacilityTable')
assert max(r['id'] for r in assets['rows'])==76,'迁移已经执行或资源编号已变化，请先核对源表'
specs=[('Bakery','面包房','bakery',1,[-2,-1,1],[-1,-1,1]),('Herbalist','药草铺','herbalist',2,[-2,2,-2],[-1,-1,1]),
       ('Chapel','小礼拜堂','chapel',1,[-2,2,-2,1],[-1,-1,1,1]),('Warehouse','货运仓库','warehouse',2,[-2,2,-2],[-1,-1,1]),
       ('Stable','马厩','stable',1,[-2,2,-2,1],[-1,-1,1,1]),('Watchtower','瞭望塔值守室','watchtower',1,[-2,2,-2],[-1,-1,1])]
# 六类共用通行尺度，模型轮廓与室内陈设各自制作，不能通过拉伸人物尺度伪装差异。
kit=[]
for i,(kind,label,key,npc,fq,fr) in enumerate(specs):
    asset_id=77+i*2;lot_id=25+i;fac_id=8+i
    for suffix,number in [('Structure',asset_id),('Cover',asset_id+1)]:
        a=copy.deepcopy(next(r for r in assets['rows'] if r['id']==64));a.update(id=number,name=label+('主体' if suffix=='Structure' else '上盖'),prefabPath='Assets/DynamicAsset/TownExpansionLowPoly/Models/TownEx_'+kind+'_'+suffix+'.fbx');assets['rows'].append(a)
    envelope={(q,r) for r in range(-2,3) for q in range(-5,6) if abs(q+r/2)<=3.5}
    fixtures=set(zip(fq,fr));floor={(q,r) for r in range(-1,2) for q in range(-4,5) if abs(q+r/2)<=2.5}-fixtures
    solid=sorted(envelope-floor-{(-1,2)},key=lambda p:(p[1],p[0]));floor=sorted(floor,key=lambda p:(p[1],p[0]))
    lot=copy.deepcopy(lots['rows'][0]);lot.update(id=lot_id,name=label,assetId=asset_id,footprintQ=[p[0] for p in solid],footprintR=[p[1] for p in solid]);lots['rows'].append(lot)
    room=copy.deepcopy(rooms['rows'][0]);room.update(id=lot_id,name=label+'首层',coverAssetId=asset_id+1,interiorQ=[p[0] for p in floor],interiorR=[p[1] for p in floor],floorColor='#968574' if kind in ['Chapel','Watchtower'] else '#8d7458');rooms['rows'].append(room)
    facilities['rows'].append(dict(id=fac_id,name=label,kind=key,description='可直接走入首层参观，在服务点附近查看介绍；上层和专属业务尚未开放。',lotIds=[lot_id],npcTemplateId=npc,interactionRadius=1))
    kit.append(dict(kind=kind,label=label,lotId=lot_id,assetId=asset_id,shell='TownEx_'+kind+'_Structure',cover='TownEx_'+kind+'_Cover',fixtures=list(map(list,sorted(fixtures))),halfWidth=7.75,halfDepth=3.55))
towns=read('MapArea','MapAreaTownTable')
additions={1:[8,9,11],2:[8,12],3:[10,11,13],4:[9],5:[8,9,10,11,12,13]}
for r in towns['rows']:r['facilityIds']+=additions[r['id']]
plots=read('MapArea','MapAreaRoyalPlacementTable');royal=read('MapArea','MapAreaRoyalTable')
for i,(district,q,r) in enumerate([(3,2,-2),(7,-4,0),(5,-6,2),(4,0,-5),(2,8,-3),(6,4,-4)]):
    plot_id=67+i;plots['rows'].append(dict(id=plot_id,name=specs[i][1],districtId=district,localQ=q,localR=r,lotIds=[],facilityId=8+i,role='facility',searchRadius=16,rotations=[0,1,2,3,4,5],required=True));royal['rows'][0]['placementIds'].append(plot_id)
districts=read('MapArea','MapAreaRoyalDistrictTable')
for r in districts['rows']:
    if r['id'] in [3,4,7]:r['searchRadius']=16
# 地表是单独的显示配方，绝不从颜色或图案推导通行能力。
surfaces=[(1,'城外草地',4,'#74805a',1.4,.15,.04,.03),(2,'裸露岩地',6,'#858075',1.8,.16,.08,.05),
 (3,'夯土小径',3,'#998568',.8,.13,.02,.02),(4,'旧城卵石',2,'#8b897d',.62,.20,.055,.12),
 (5,'整齐石板',1,'#a89d88',1.15,.15,.038,.12),(6,'广场拼石',1,'#b7a68b',1.8,.16,.035,.15),
 (7,'院落泥地',3,'#8b775c',.9,.12,.02,.02),(8,'园圃草地',4,'#66805a',1.0,.15,.025,.03),
 (9,'室内木板',5,'#95795b',.36,.16,.04,.13),(10,'室内旧石',1,'#a29987',.95,.14,.035,.1),
 (11,'宫殿地砖',1,'#bcb09a',1.5,.14,.027,.18),(12,'城外积雪',7,'#c7d4d5',2.0,.09,.02,.04),
 (13,'台地岩壁',6,'#817c71',2.0,.19,.06,.03)]
surface_rows=[dict(zip(['id','name','pattern','baseColor','tileMeters','contrast','jointWidth','smoothness'],r)) for r in surfaces]
surface_table=table('MapAreaSurfaceTable','城内外地表材质：世界米制图案与哑光反射',[field('id','int','材质编号'),field('name','string','显示名称'),field('pattern','int','0纯色 1石板 2卵石 3泥土 4草地 5木板 6岩石 7积雪',min=0,max=7),field('baseColor','string','低饱和基础色'),field('tileMeters','float','图案世界尺寸，米',min=.1),field('contrast','float','图案明暗幅度',min=0,max=.5),field('jointWidth','float','缝隙占图案宽度',min=0,max=.2),field('smoothness','float','材质平滑度',min=0,max=1)],surface_rows)
profile_fields=[field('id','int','地表配方编号'),field('name','string','配方名称')]+[field(k,'int',desc,ref='MapAreaSurfaceTable') for k,desc in [('roadId','街道'),('plazaId','广场'),('yardId','院落'),('gardenId','园地'),('bridgeId','石桥'),('cliffId','台地侧壁'),('trailId','城外路迹')]]+[field('transitionCells','int','城界土色过渡宽度',min=1,max=8),field('yardDistance','int','建筑周边院落宽度',min=1,max=4)]
profiles=table('MapAreaTownSurfaceTable','不同规模城镇的地面组合',profile_fields,[dict(id=i,name=name,roadId=road,plazaId=plaza,yardId=7,gardenId=8,bridgeId=5,cliffId=13,trailId=3,transitionCells=3,yardDistance=2) for i,name,road,plaza in [(1,'石铺街区',4,5),(2,'乡村土路',3,4),(3,'王城街道',5,6)]])
towns['fields'].append(field('surfaceProfileId','int','城镇地面配方',ref='MapAreaTownSurfaceTable'))
for r in towns['rows']:r['surfaceProfileId']=3 if r['id']==5 else 2 if r['id'] in [2,4] else 1
themes=read('MapArea','MapAreaTownThemeTable');themes['fields'].append(field('outsideSurfaceId','int','城外 Region 地表',ref='MapAreaSurfaceTable'))
for r in themes['rows']:r['outsideSurfaceId']=12 if r['regionType']==6 else 2 if r['regionType']==2 else 1
rooms['fields'].append(field('surfaceId','int','室内地面材质',ref='MapAreaSurfaceTable'))
for r in rooms['rows']:r['surfaceId']=11 if r['id']==17 else 10 if r['id'] in [2,4,27,30] else 9
for group,d in [('Map',assets),('MapArea',lots),('MapArea',rooms),('MapArea',facilities),('MapArea',towns),('MapArea',plots),('MapArea',royal),('MapArea',districts),('MapArea',themes),('MapArea',surface_table),('MapArea',profiles)]:save(group,d)
out=ROOT/'Art/TownExpansionLowPoly/Integration';out.mkdir(parents=True,exist_ok=True);(out/'kit-design.json').write_text(json.dumps(kit,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('新增六类可进入建筑、12 个模型关系和 13 种地表材质。')
