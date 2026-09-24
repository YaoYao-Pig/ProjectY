"""王城配方与模型映射的源表迁移；生成物统一交给 ConfigEditor 导出。"""
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TABLES = ROOT / 'Config/Tables'

def read(name):
    return json.loads((TABLES / (name + '.json')).read_text(encoding='utf-8-sig'))

def write(name, data):
    (TABLES / (name + '.json')).write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

def upsert(table, row):
    table['rows'] = [value for value in table['rows'] if value['id'] != row['id']] + [row]

models = [('Royal_Palace', '穹顶王宫'), ('Royal_Gatehouse', '双塔王城门楼'),
          ('Royal_Pavilion', '花园八角亭'), ('Royal_Fountain', '三层王家喷泉'),
          ('Royal_Statue', '守望者雕像'), ('Royal_Parterre', '几何花坛'),
          ('Royal_Cypress', '庭园柏树'), ('Royal_Bridge', '石桥栏廊'),
          ('Royal_Balustrade', '台地石栏'), ('Royal_Retaining', '御苑拱券挡墙')]
assets = read('Map/MapAssetTable')
for index, (name, title) in enumerate(models, 54):
    upsert(assets, dict(id=index, name=title, prefabPath=f'Assets/DynamicAsset/RoyalTownLowPoly/Models/{name}.fbx',
        previewShape='castle' if index in (54,55,56) else 'house', previewColor='#c9b994',
        referenceHeight=1, footprintRadius=1, tintMaterial=''))
write('Map/MapAssetTable', assets)

lots = read('MapArea/MapAreaTownLotTable')
def lot(id, asset, title, cells, door=(0,2), scale=1):
    upsert(lots, dict(id=id,name=title,assetId=asset,scale=scale,footprintQ=[p[0] for p in cells],
        footprintR=[p[1] for p in cells],entryQ=door[0],entryR=door[1],kind='building',houseUnits=0))
def rectangle(half, bottom, top, predicate=lambda u,r:True):
    return [(q,r) for r in range(bottom,top+1) for q in range(-half-abs(r),half+abs(r)+1)
            if abs(q+r/2)<=half and predicate(q+r/2,r)]
# 中庭与门洞从占地里扣除，整体模型仍为一栋建筑。
lot(17,54,'王宫与双翼',rectangle(13,-9,8,lambda u,r:r<=0 or abs(u)>=7),(0,1))
lot(18,55,'可穿越双塔门楼',rectangle(7,-2,2,lambda u,r:abs(u)>=3.5),(0,0))
lot(19,56,'花园亭',rectangle(2,-2,2),(-1,3))
lot(20,57,'王家喷泉',rectangle(2,-2,2),(-1,3))
lot(21,58,'纪念雕像',[(0,0)],(0,1))
lot(22,59,'方形刺绣花坛',rectangle(3,-2,2),(-1,3))
lot(23,60,'柏树',[(0,0)],(0,1))
write('MapArea/MapAreaTownLotTable',lots)

facilities=read('MapArea/MapAreaTownFacilityTable')
kind=next(f for f in facilities['fields'] if f['name']=='kind')
if 'palace' not in kind['values']:kind['values'].append('palace')
upsert(facilities,dict(id=6,name='王宫外苑',kind='palace',description='王宫主庭与高台花园向旅人开放。宫殿室内尚未开放。',lotIds=[17],npcTemplateId=1,interactionRadius=2))
upsert(facilities,dict(id=7,name='王家喷泉广场',kind='square',description='大道通往高台王宫，石桥下的小径连接下层外苑。',lotIds=[20],npcTemplateId=1,interactionRadius=2))
write('MapArea/MapAreaTownFacilityTable',facilities)

town=read('MapArea/MapAreaTownTable')
if not any(f['name']=='royalLayoutIds' for f in town['fields']):
    town['fields'].append(dict(name='royalLayoutIds',type='int[]',ref='MapAreaRoyalTable',default=[],description='王城轴线预设池；空数组使用普通山城策略'))
for r in town['rows']:r.setdefault('royalLayoutIds',[])
royal=copy.deepcopy(town['rows'][0]);royal.update(id=5,name='高台王城',facilityIds=[1,2,3,4,6,7],residentCount=16,houseCount=24,royalLayoutIds=[1])
upsert(town,royal);write('MapArea/MapAreaTownTable',town)

fields=[]
def field(name,type,description,**kw):fields.append(dict(name=name,type=type,description=description,**kw))
field('id','int','王城配方 ID',min=1);field('name','string','配方名称')
for name,desc in [('halfWidth','可走台地半宽'),('minR','宫殿背后边界'),('maxR','城门外边界'),('entryR','入口局部 r'),('bridgeR','高架桥局部 r'),('valleyMinR','下层小径北端')]:field(name,'int',desc)
field('boundaryR','int[]','由低到高的三道台地边界')
field('stairU','int[]','每道台阶/坡道中心横坐标 q+r/2')
field('terraceHeight','float','台地高度（米），仍受来源 Region 影响',min=3.5,max=5)
field('rampLength','int','宽阶梯水平跨度',min=8,max=12)
field('streetRows','int[]','横向步行街中心 r')
field('courtHalfWidth','int','宫殿中庭铺装半宽',min=1)
field('courtRows','int[]','宫殿中庭铺装起止 r')
field('bridgeAssetId','int','石桥护栏模型',ref='MapAssetTable')
field('railingAssetId','int','台地边缘石栏模型',ref='MapAssetTable')
field('retainingAssetId','int','台地拱券挡墙模型',ref='MapAssetTable')
field('placementIds','int[]','王宫、街区与花园预设组合',ref='MapAreaRoyalPlacementTable')
field('pavingColor','string','王城铺装主色')
recipe=dict(id=1,name='穹顶宫殿与四层御苑',halfWidth=34,minR=-36,maxR=38,entryR=36,bridgeR=12,valleyMinR=7,
    boundaryR=[17,3,-9],stairU=[-28,-8,8,28],terraceHeight=4.5,rampLength=8,streetRows=[30,12,-2,-18],
    bridgeAssetId=61,railingAssetId=62,retainingAssetId=63,courtHalfWidth=7,courtRows=[-23,-14],placementIds=[],pavingColor='#c6b48f')
placements=[]
def place(name,u,r,lots=(),facility=0,rotation=0):
    assert (2*u-r)%2==0
    i=len(placements)+1;placements.append(dict(id=i,name=name,localQ=int(u-r/2),localR=r,lotIds=list(lots),facilityId=facility,rotation=rotation));recipe['placementIds'].append(i)
# 奇数 r 允许半格横向中心，王宫采用偶数行以使主轴精确居中。
place('主宫殿',0,-24,facility=6)
place('南门',0,30,[18]);place('喷泉广场',14,12,facility=7)
for title,u,r,f in [('酒馆',-21,28,1),('铁匠',21,28,2),('商店',-21,8,3),('公会',21,8,4)]:place(title,u,r,facility=f)
for u in [-29,29]:
    for r in [-24,-3,10,30]:place('联排街区',u+(.5 if r%2 else 0),r,[14,15,16])
for u in [-21,21]:place('御苑凉亭',u,-24,[19])
for u in [-19,19]:
    for r in [-16,-2]:place('刺绣花园',u,r,[22])
for u in [-20,20]:
    for r in [-30,22]:place('御苑长花坛',u,r,[22])
for u in [-14,14]:place('前庭花坛',u,34,[22])
place('西苑喷泉',-14,12,[20]);place('宫殿中庭喷泉',0,-18,[20])
for u in [-14,14]:
    for r in [24,0,-12]:place('守望雕像',u,r,[21])
for u in [-24,-17,17,24]:
    for r in [-35,-20,-12,4,18,34]:
        if abs(u)==17 and r==34:continue
        place('行列柏树',u+(.5 if r%2 else 0),r,[23])
for u in [-12,12]:place('街市棚亭',u,28,[11,12,13])
royalTable=dict(version=1,name='MapAreaRoyalTable',description='王城轴线、台地、上下层道路与配置组合',key='id',fields=fields,rows=[recipe])
write('MapArea/MapAreaRoyalTable',royalTable)
pf=[dict(name='id',type='int',min=1,description='摆放 ID'),dict(name='name',type='string',description='预设名称'),
    dict(name='localQ',type='int',description='局部 q'),dict(name='localR',type='int',description='局部 r'),
    dict(name='lotIds',type='int[]',ref='MapAreaTownLotTable',description='随机外观池，设施项可为空'),
    dict(name='facilityId',type='int',min=0,description='设施 ID，0 表示陈设/住宅'),
    dict(name='rotation',type='int',min=0,max=5,description='六十度转向')]
write('MapArea/MapAreaRoyalPlacementTable',dict(version=1,name='MapAreaRoyalPlacementTable',description='王城分区组合；所有建筑、景观的资产关系来自 Lot 表',key='id',fields=pf,rows=placements))

areas=read('MapArea/MapAreaTable');area=copy.deepcopy(areas['rows'][1]);area.update(id=6,name='高台王城',profileId=5,width=128,height=128,seedSalt=97231);upsert(areas,area);write('MapArea/MapAreaTable',areas)
entrances=read('MapArea/MapAreaEntranceTable');upsert(entrances,dict(id=6,townId=6,areaId=6));write('MapArea/MapAreaEntranceTable',entrances)
world=read('Map/MapTownTable');city=next(r for r in world['rows'] if r['id']==2);city['maxCount']=2
capital=copy.deepcopy(city);capital.update(id=6,name='王城',maxCount=1,maxPerRegion=1,priority=100,groundColor='#c4ae7d',buildingIds=[5,4,2,3,2],requiredBuildingIds=[5],minBuildings=5,maxBuildings=14)
city['priority']=95;upsert(world,capital);write('Map/MapTownTable',world)
print('王城源表完成：10 个资源、6 号 MapArea、配置化预设布局')
