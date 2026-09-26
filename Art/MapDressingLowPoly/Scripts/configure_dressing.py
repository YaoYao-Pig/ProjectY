"""首次建立装饰资源及生成配方；不能重放覆盖后续配表编辑。"""
import json,copy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];TABLES=ROOT/'Config/Tables'
def read(group,name):return json.loads((TABLES/group/(name+'.json')).read_text(encoding='utf-8-sig'))
def save(group,data):
    p=TABLES/group/(data['name']+'.json');p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def f(name,kind,description,**kw):return dict(name=name,type=kind,description=description,**kw)
def table(name,description,fields,rows):return dict(version=1,name=name,description=description,key='id',fields=fields,rows=rows)
assets=read('Map','MapAssetTable');props=read('MapArea','MapAreaPropTable')
assert max(r['id'] for r in assets['rows'])==88 and max(r['id'] for r in props['rows'])==16,'迁移已执行或编号已改变'
specs=[('FallenLog','倒木','nature',True,'#75634c'),('Stump','老树桩','nature',False,'#857054'),('Ferns','蕨类丛','nature',False,'#607650'),
 ('Mushrooms','蘑菇簇','nature',False,'#a27b69'),('Reeds','芦苇簇','nature',False,'#8b9364'),('Wildflowers','野花丛','nature',False,'#9a9477'),
 ('Cairn','路边石堆','nature',False,'#918b7f'),('StandingStones','古代立石','nature',True,'#8b9181'),
 ('Well','石井','town',False,'#ad9d80'),('Handcart','双轮货车','town',True,'#897354'),('Haystack','草垛','town',True,'#b59f6d'),
 ('Firewood','柴火垛','town',True,'#857053'),('DryingRack','晾晒架','town',True,'#9d927f'),('NoticeBoard','告示牌','town',False,'#9b8969'),
 ('WaterTrough','饮水槽','town',True,'#8b8e82'),('LanternPost','街边灯柱','town',False,'#af9264'),
 ('Rubble','坍塌碎石','dungeon',True,'#88867b'),('Bones','遗骨堆','dungeon',False,'#b8ae93'),('BrokenCart','破损矿车','dungeon',True,'#7e725e'),
 ('Candlestand','祭祀烛台','dungeon',False,'#ad9568'),('ChainPillar','锁链柱','dungeon',False,'#7b7a73'),('MineSupport','矿道木支架','dungeon',True,'#7f654c'),
 ('MossStatue','覆苔残像','dungeon',False,'#78846d'),('Crystals','晶簇','dungeon',False,'#6d9b9a')]
props['fields'].append(f('scaleMode','enum','grid 随地格缩放；meters 保持模型真实米制',values=['grid','meters']))
for row in props['rows']:row['scaleMode']='grid'
kit=[]
for i,(kind,label,group,large,color) in enumerate(specs):
    aid,pid=89+i,17+i
    row=copy.deepcopy(assets['rows'][-1]);row.update(id=aid,name=label,prefabPath='Assets/DynamicAsset/MapDressingLowPoly/Models/Decor_'+kind+'.fbx',footprintRadius=0,referenceHeight=1,previewColor=color,previewShape='rock')
    assets['rows'].append(row)
    # 大件沿一条轴占三格；窄件只占一格，保持家具真实大小。
    props['rows'].append(dict(id=pid,name=label,assetId=aid,blocksSight=kind in ['StandingStones','Haystack','NoticeBoard','ChainPillar','MineSupport','MossStatue'],
        scale=1,scaleMode='meters',footprintQ=[-1,0,1] if large else [0],footprintR=[0,0,0] if large else [0],placement='island' if group=='nature' else 'wall'))
    kit.append(dict(kind=kind,label=label,group=group,name='Decor_'+kind,assetId=aid,propId=pid,large=large))
world_fields=[f('id','int','规则编号'),f('name','string','规则名称'),f('assetId','int','装饰资源',ref='MapAssetTable'),f('regions','int[]','可用地貌类型'),
 f('density','float','候选格概率',min=0,max=1),f('maxSlope','float','最大邻格高差',min=0),f('minScale','float','最小缩放',min=.01),f('maxScale','float','最大缩放',min=.01),
 f('nearWater','bool','要求两格内有水'),f('nearRoad','bool','要求两格内有路'),f('clearance','int','避开建筑和已有装饰的格数',min=0,max=3)]
world=[]
for i,(regions,density,slope,lo,hi,water,road) in enumerate([
 ([1,5],.026,1.1,.30,.40,False,False),([1,5],.026,1.5,.65,.85,False,False),([1,3,4,5],.04,1.3,.8,1.1,False,False),
 ([3,5],.03,1.1,.9,1.15,False,False),([3,4,5],.12,1,.8,1.05,True,False),([1,3,4],.05,.9,.8,1.1,False,False),
 ([1,2,6],.026,2,.6,.9,False,False),([2,5,6],.015,1.4,.25,.35,False,False)]):
    world.append(dict(id=i+1,name=specs[i][1],assetId=89+i,regions=regions,density=density,maxSlope=slope,minScale=lo,maxScale=hi,nearWater=water,nearRoad=road,clearance=1))
world.append(dict(id=9,name='路旁废弃货车',assetId=98,regions=[1,2,5],density=.025,maxSlope=.8,minScale=.3,maxScale=.4,nearWater=False,nearRoad=True,clearance=1))
save('Map',table('MapDecorationRuleTable','大地图环境装饰：地貌、水岸和道路关联，保持建筑与道路净空',world_fields,world))
towns=read('MapArea','MapAreaTownTable');towns['fields'].append(f('dressingProfileId','int','环境陈设配方',ref='MapAreaTownDressingTable'))
for row in towns['rows']:row['dressingProfileId']=3 if row['id']==5 else 2 if row['id'] in [2,4] else 1
save('MapArea',table('MapAreaTownDressingTable','城镇与王城公共空地装饰，避开门口、道路和居民路线',[
 f('id','int','编号'),f('name','string','名称'),f('propIds','int[]','装饰池',ref='MapAreaPropTable'),f('count','int','放置上限',min=0,max=120),
 f('spacing','int','装饰之间最小格距',min=1,max=6),f('edgeDistance','int','距离道路或建筑的最大格距',min=1,max=6)],
 [dict(id=1,name='繁荣街区杂物',propIds=[25,26,27,28,29,30,31,32,19,22],count=28,spacing=2,edgeDistance=3),
  dict(id=2,name='乡村院落杂物',propIds=[18,19,22,25,26,27,28,29,31],count=22,spacing=2,edgeDistance=3),
  dict(id=3,name='王城街景与庭园',propIds=[25,26,27,28,29,30,31,32,19,22,23,24],count=54,spacing=2,edgeDistance=3)]))
styles=read('MapArea','MapAreaRoomStyleTable');presets=read('MapArea','MapAreaRoomPresetTable');dungeon=read('MapArea','MapAreaDungeonTable')
pools={1:[33,35,38,28,26,34],2:[35,36,37,28,30,34],3:[36,37,39,40,33],4:[34,36,37,39,33],5:[17,18,19,20,33,39,40]}
for data in [styles,presets]:
    data['fields'] += [f('dressingPropIds','int[]','追加环境陈设，不占战斗保留区',ref='MapAreaPropTable'),f('dressingCount','int','追加陈设上限',min=0,max=16),
        f('floorSurfaceIds','int[]','房间地面材质池，空数组使用 Region 配方',ref='MapAreaSurfaceTable'),f('wallSurfaceIds','int[]','房间墙材池',ref='MapAreaSurfaceTable')]
    for row in data['rows']:
        row['dressingPropIds']=pools[row['id'] if data is styles else {1:2,2:3,3:4}[row['id']]];row['dressingCount']=7 if data is styles else 5
        sid=row['id'] if data is styles else {1:2,2:3,3:4}[row['id']]
        row['floorSurfaceIds']={1:[16,14],2:[16,14],3:[14,20],4:[14,20],5:[]}[sid]
        row['wallSurfaceIds']={1:[23,24],2:[23,24],3:[24],4:[24,21],5:[]}[sid]
dungeon['fields'] += [f('basicDressingIds','int[]','小洞穴追加陈设',ref='MapAreaPropTable'),f('basicDressingCount','int','小洞穴陈设上限',min=0,max=8)]
for row in dungeon['rows']:row['basicDressingIds']=[17,19,20,33,34,40];row['basicDressingCount']=3
surfaces=read('MapArea','MapAreaSurfaceTable')
next(field for field in surfaces['fields'] if field['name']=='pattern')['max']=9
next(field for field in surfaces['fields'] if field['name']=='pattern')['description']='0纯色 1石板 2卵石 3泥土 4草地 5木板 6岩石 7积雪 8苔藓 9砌砖'
surfaces['fields'].append(f('detailColor','string','苔藓等覆盖层颜色'))
for row in surfaces['rows']:row['detailColor']=row['baseColor']
new_surfaces=[(14,'地牢旧石地板',1,'#888579',1.0,.22,.048,.10),(15,'潮湿苔石地板',8,'#7b8071',1.05,.35,.05,.10),
 (16,'地下木板地面',5,'#887056',.30,.25,.035,.08),(17,'洞穴泥土地面',3,'#76674f',1.4,.23,.02,.02),
 (18,'湿润石板',1,'#627976',.90,.23,.05,.28),(19,'霜冻岩面',7,'#b5c5c8',1.3,.17,.03,.10),(20,'暗灰祭庭石板',1,'#777582',1.35,.25,.06,.12),
 (21,'粗糙岩墙',6,'#888277',1.4,.26,.06,.03),(22,'苔藓石墙',8,'#838773',1.1,.40,.065,.07),(23,'木构板墙',5,'#7e624a',.32,.24,.045,.06),
 (24,'古代砖石墙',9,'#9a8a73',.95,.27,.055,.07),(25,'渗水岩墙',6,'#627775',1.2,.28,.04,.23),(26,'霜冻岩墙',7,'#9cafb7',1.2,.19,.035,.12)]
for values in new_surfaces:
    row=dict(zip(['id','name','pattern','baseColor','tileMeters','contrast','jointWidth','smoothness'],values));row['detailColor']='#465e3e' if row['pattern']==8 else row['baseColor'];surfaces['rows'].append(row)
themes=read('MapArea','MapAreaThemeTable');themes['fields'].append(f('surfaceProfileId','int','地牢基础材质与地貌覆盖',ref='MapAreaDungeonSurfaceTable'))
for row in themes['rows']:row['surfaceProfileId']=row['regionType']
surface_profiles=[]
for i,(name,floors,walls,cf,cw,chance) in enumerate([
 ('风化遗迹',[14,17],[21,24],14,24,.1),('山腹矿洞',[14,17,20],[21,24],17,21,.2),('潮湿地下遗迹',[15,18],[22,25],18,25,.65),
 ('河岸墓道',[15,18],[22,25],15,22,.45),('林下遗迹',[15,17],[22,21],15,22,.65),('冰封遗迹',[19,14],[26,21],19,26,.6)],1):
    surface_profiles.append(dict(id=i,name=name,floorIds=floors,wallIds=walls,corridorFloorId=cf,corridorWallId=cw,regionOverrideChance=chance,wallBand=3))
save('MapArea',table('MapAreaDungeonSurfaceTable','按房间功能与入口地貌选择成片材质，墙面跟随相邻房间',[
 f('id','int','编号'),f('name','string','名称'),f('floorIds','int[]','基础地面池',ref='MapAreaSurfaceTable'),f('wallIds','int[]','基础墙面池',ref='MapAreaSurfaceTable'),
 f('corridorFloorId','int','走廊地面',ref='MapAreaSurfaceTable'),f('corridorWallId','int','走廊与深墙材质',ref='MapAreaSurfaceTable'),
 f('regionOverrideChance','float','Region 材质覆盖功能房的概率',min=0,max=1),f('wallBand','int','房间墙面延伸格数',min=1,max=5)],surface_profiles))
for group,data in [('Map',assets),('MapArea',props),('MapArea',towns),('MapArea',styles),('MapArea',presets),('MapArea',dungeon),('MapArea',surfaces),('MapArea',themes)]:save(group,data)
out=ROOT/'Art/MapDressingLowPoly/Integration';out.mkdir(parents=True,exist_ok=True);(out/'kit.json').write_text(json.dumps(kit,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('已配置 24 类装饰、世界/城镇/地牢生成池及 13 种地牢材质。')
