"""城镇预设与资源关系的初始表源；后续通过配置工作台编辑，不重复初始化。"""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
FOLDER=ROOT/'Config/Tables/MapArea'
def field(name,kind,description,**extra):return dict(name=name,type=kind,description=description,**extra)
ID=field('id','int','稳定配置 ID',min=1)
NAME=field('name','string','显示名称')
def write(name,description,fields,rows):
    path=FOLDER/(name+'.json');assert not path.exists(),str(path)
    path.write_text(json.dumps(dict(version=1,name=name,description=description,key='id',fields=fields,rows=rows),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def read(path):return json.loads(path.read_text(encoding='utf-8'))
def save(path,value):path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def disk(radius):return [(q,r) for r in range(-radius,radius+1) for q in range(max(-radius,-r-radius),min(radius,-r+radius)+1)]
models=['Tavern','Smithy','Shop','Guild','Fountain','HouseA','HouseB','MarketStall','Handcart','LanternBench']
names=['暖炉酒馆','铁匠铺','杂货商店','冒险公会','广场喷泉','木架民居','石基民居','市集摊位','货运手车','路灯与长椅']
lots=[]
for i,(name,label) in enumerate(zip(models,names),1):
    building=i in [1,2,3,4,6,7]
    points=[(q,r) for q,r in disk(2) if r<2] if building else disk(1) if i in [5,8] else [(0,0)]
    lots.append(dict(id=i,name=label,assetId=35+i,scale=1,footprintQ=[p[0] for p in points],footprintR=[p[1] for p in points],entryQ=-1 if building else 0,entryR=2 if building else 2,kind='building' if building else 'street'))
write('MapAreaTownLotTable','街区摆件预设；地格足迹与模型同向旋转，建筑门前格不占用。',[
    ID,NAME,field('assetId','int','模型资源',ref='MapAssetTable'),field('scale','float','相对地格模型比例',min=.1,max=5),
    field('footprintQ','int[]','局部占地 q，与 r 一一对应'),field('footprintR','int[]','局部占地 r'),
    field('entryQ','int','门前交互格局部 q'),field('entryR','int','门前交互格局部 r'),
    field('kind','enum','建筑或街道陈设',values=['building','street'])],lots)
write('MapAreaTownFacilityTable','城镇功能设施；首版为门口信息入口，后续业务按稳定 kind 接入。',[
    ID,NAME,field('kind','enum','功能标识',values=['tavern','smithy','shop','guild','square']),
    field('description','text','靠近交互时的说明'),field('lotIds','int[]','可选外观预设',ref='MapAreaTownLotTable'),
    field('npcTemplateId','int','门前服务 NPC',ref='MapAreaTownNpcTable'),field('interactionRadius','int','门前交互半径，单位为格',min=1,max=3)
],[dict(id=i,name=n,kind=k,description=d,lotIds=[i],npcTemplateId=2 if i in [2,3] else 1,interactionRadius=1) for i,n,k,d in [
    (1,'酒馆','tavern','炉火、麦酒与旅人的消息在这里汇聚。住宿与招募业务待接入。'),
    (2,'铁匠铺','smithy','炉膛正热，门前陈列着新打的工具。锻造与修理业务待接入。'),
    (3,'商店','shop','货架与摊位供应旅途中需要的物资。买卖业务待接入。'),
    (4,'冒险公会','guild','布告栏记录来自各地的委托。任务与登记业务待接入。'),
    (5,'城镇广场','square','街道在喷泉周围交汇，居民在这里相遇与休息。')]])
write('MapAreaTownBlockTable','围绕中心旋转拼接的街区预设；第一槽为功能设施，其余为民居。',[
    ID,NAME,field('slotQ','int[]','街区内建筑槽 q'),field('slotR','int[]','街区内建筑槽 r'),field('slotRotation','int[]','各槽的六十度旋转次数'),
    field('decorQ','int[]','街旁陈设槽 q'),field('decorR','int[]','街旁陈设槽 r')
],[dict(id=1,name='对称门前街',slotQ=[0,-3,6],slotR=[0,-3,-3],slotRotation=[0,0,0],decorQ=[-3,3],decorR=[2,2]),
    dict(id=2,name='错落庭院街',slotQ=[0,-4,7],slotR=[0,-2,-4],slotRotation=[0,0,0],decorQ=[-3,3],decorR=[2,2]),
    dict(id=3,name='临街小院',slotQ=[0,-4,6],slotR=[0,-3,-2],slotRotation=[0,0,0],decorQ=[-3,3],decorR=[2,2])])
write('MapAreaTownTable','每种聚落的设施清单、街区组合、民居和居民规模。',[
    ID,NAME,field('facilityIds','int[]','本城拥有的设施，必须包含中心广场',ref='MapAreaTownFacilityTable'),
    field('blockIds','int[]','随机拼接的街区预设池',ref='MapAreaTownBlockTable'),field('houseLotIds','int[]','填充民居预设池',ref='MapAreaTownLotTable'),
    field('streetLotIds','int[]','街旁装饰预设池',ref='MapAreaTownLotTable'),field('houseCount','int','民居数量',min=0,max=14),
    field('residentCount','int','额外巡游居民数量',min=0,max=24),field('residentTemplateIds','int[]','巡游居民模板池',ref='MapAreaTownNpcTable'),
    field('blockDistance','int','街区中心距广场的轴向半径',min=10,max=16),field('plazaRadius','int','广场半径',min=3,max=6),
    field('streetRadius','int','道路半宽，至少为 1',min=1,max=3),field('treeCount','int','外围景观树数量',min=0,max=80)
],[dict(id=i,name=n,facilityIds=f,blockIds=[1,2,3],houseLotIds=[6,7],streetLotIds=[8,9,10],houseCount=h,residentCount=c,residentTemplateIds=[1,2],blockDistance=12,plazaRadius=4,streetRadius=1,treeCount=28) for i,n,f,h,c in [
    (1,'集市城镇',[1,2,3,4,5],10,10),(2,'小村庄',[1,2,3,5],6,5),(3,'城堡镇区',[1,2,3,4,5],12,8),(4,'隐居小聚落',[1,3,5],3,3)]])
write('MapAreaTownNpcTable','通用城镇居民；外观复用棋子装配，固定服务者与巡游居民共用模板。',[
    ID,NAME,field('description','text','居民身份说明'),field('partIds','int[]','棋子部件',ref='PawnPartTable'),field('stepSeconds','float','巡游每格间隔',min=.3,max=3),field('idleSeconds','float','抵达巡游节点的停留时间',min=0,max=20)
],[dict(id=1,name='城镇居民',description='住在附近的居民，正沿着街道闲逛。',partIds=[17,2],stepSeconds=1.15,idleSeconds=3),dict(id=2,name='工匠',description='熟悉城里的作坊和市集，身上带着日常工具。',partIds=[18,2],stepSeconds=1.3,idleSeconds=4)])
write('MapAreaTownThemeTable','大地图 Region 对城镇的地面、铺装和植被影响；街区仍保持平整。',[
    ID,NAME,field('regionType','enum','来源 Region',enumRef='Map.E_MapRegion'),field('floorColor','string','庭院地面颜色'),field('wallColor','string','边界颜色'),
    field('wallHeight','float','边界高度',min=0),field('heightNoise','float','地面噪声幅度',min=0),field('assetId','int','地面资源',ref='MapAssetTable'),
    field('roadColor','string','街道铺装颜色'),field('plazaColor','string','广场铺装颜色'),field('treeAssetId','int','景观树资源',ref='MapAssetTable'),field('treeScale','float','景观树相对比例',min=.1)
],[dict(id=i,name=n,regionType=i,floorColor=c,wallColor=c,wallHeight=0,heightNoise=0,assetId=1,roadColor='#aa977b',plazaColor='#c5b89d',treeAssetId=t,treeScale=1.5) for i,n,c,t in [
    (1,'平原城镇','#82926d',13),(2,'山地城镇','#969382',14),(3,'湖畔城镇','#7c9b87',13),(4,'河畔城镇','#88976d',13),(5,'林间城镇','#627c56',13),(6,'雪地城镇','#d7e4e6',15)]])
# 资源、身体与区域入口都走真实源表，禁止手写 _Gen 产物。
p=ROOT/'Config/Tables/Map/MapAssetTable.json';t=read(p)
for i,name in enumerate(models,36):
    t['rows'].append(dict(id=i,name='Town_'+name,prefabPath='Assets/DynamicAsset/TownLowPoly/Models/Town_'+name+'.fbx',previewShape='house',previewColor='#c9b994',referenceHeight=1,footprintRadius=1,tintMaterial=''))
save(p,t)
p=ROOT/'Config/Tables/Adventure/PawnPartTable.json';t=read(p)
for i,name,label in [(17,'Resident','居民身体'),(18,'Artisan','工匠身体')]:
    t['rows'].append(dict(id=i,name=label,slot='body',prefabPath='Assets/DynamicAsset/TownLowPoly/Models/NPC_'+name+'.fbx'))
save(p,t)
p=FOLDER/'MapAreaTable.json';t=read(p)
t['fields'].append(field('discovery','enum','探索方式：城镇全图已知，地牢逐步探索',values=['explore','open']))
for row in t['rows']:row['discovery']='explore' if row['areaType']==1 else 'open'
town=t['rows'][1];town.update(name='集市城镇',profileId=1,width=64,height=64,moveStepSeconds=.5)
for i,name,profile in [(3,'小村庄',2),(4,'城堡镇区',3),(5,'隐居小聚落',4)]:
    row=dict(town);row.update(id=i,name=name,profileId=profile,seedSalt=7159+i*137);t['rows'].append(row)
save(p,t)
p=FOLDER/'MapAreaEntranceTable.json';t=read(p)
for row in t['rows']:
    if row['townId']==1:row['areaId']=3
    elif row['townId']==3:row['areaId']=4
    elif row['townId']==5:row['areaId']=5
save(p,t)
print('Created six town source tables, ten scenery assets, two NPC bodies and four town profiles.')
