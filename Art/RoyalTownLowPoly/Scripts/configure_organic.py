"""将王城轴线样例迁为分区选址与沿街生长；只修改本次算法需要的源表。"""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[3]/'Config/Tables/MapArea'
def read(name):return json.loads((root/(name+'.json')).read_text(encoding='utf-8-sig'))
def write(name,data):(root/(name+'.json')).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def field(table,name,type,description,**kw):
    table['fields']=[f for f in table['fields'] if f['name']!=name]+[dict(name=name,type=type,description=description,**kw)]
recipe=read('MapAreaRoyalTable');recipe['description']='王城的地形约束、分区生长、道路评分与景观参数'
for name in ['streetRows','courtRows','courtHalfWidth','entryR','stairU']:
    recipe['fields']=[f for f in recipe['fields'] if f['name']!=name]
    for row in recipe['rows']:row.pop(name,None)
settings={
 'districtIds':('int[]',[1,2,3,4,5,6],'独立城市片区；围绕功能中心选址'),
 'boundaryAmplitude':('float[]',[2,3,4],'三层台地边缘起伏幅度，单位为格'),
 'contourScale':('float',19,'等高线变化尺度，控制城市级地形'),
 'outlineInset':('float',7,'左右城界独立向内收进的最大距离'),
 'stairBand':('int[]',[1,1,2,2,3,3],'每处坡道对应的台地边界序号'),
 'stairU':('int[]',[-21,24,-17,25,-9,21],'错位坡道的基础横坐标，不贯穿全城'),
 'stairJitter':('int',2,'坡道沿等高线的选址变化'),
 'valleyURange':('int[]',[6,10],'低径与桥的横向位置范围'),
 'entryOffsetR':('int',6,'入口在城门外沿正面的距离'),
 'roadNoise':('float',2.4,'平地道路对低频通行代价的响应'),
 'roadNoiseScale':('float',12,'道路弯曲的空间尺度'),
 'roadSlopeCost':('float',2.5,'道路单位爬升代价'),
 'roadReuse':('float',0.35,'已有街道代价倍率，鼓励连接和共用'),
 'roadLoopCount':('int',2,'骨干连通后补充的跨区回路数量'),
 'mainRoadRadius':('int',2,'主街扩宽半径；2 表示通常五格宽'),
 'laneRadius':('int',1,'住宅支巷半径'),
 'frontageDistance':('int',7,'住宅门口允许离既有街网的最大距离'),
 'frontageWeight':('float',3,'临街距离在地块评分中的权重'),
 'anchorWeight':('float',0.35,'靠近本片区目标位置的权重'),
 'clusterWeight':('float',0.4,'住宅优先靠近已有住宅的权重'),
 'plotNoiseWeight':('float',3,'候选地块评分的种子变化'),
 'candidateLimit':('int',32,'按评分排序后最多验证的完整地块数量'),
 'railingSpan':('int',3,'台地石栏每段占地宽度'),
}
for name,(kind,value,description) in settings.items():
    field(recipe,name,kind,description,**({'ref':'MapAreaRoyalDistrictTable'} if name=='districtIds' else {}))
    recipe['rows'][0][name]=value
recipe['rows'][0]['name']='地形引导的王城街区'
write('MapAreaRoyalTable',recipe)

fields=[dict(name='id',type='int',description='片区 ID',min=1),dict(name='name',type='string',description='功能片区'),
 dict(name='centerQ',type='int',description='局部中心 q'),dict(name='centerR',type='int',description='局部中心 r'),
 dict(name='shiftQ',type='int',description='片区中心独立变化范围 q',min=0),dict(name='shiftR',type='int',description='片区中心独立变化范围 r',min=0),
 dict(name='searchRadius',type='int',description='本片区地块候选范围',min=0),
 dict(name='role',type='enum',values=['palace','gate','market','craft','residential','garden'],description='分区职责'),
 dict(name='roadRadius',type='int',min=1,max=3,description='片区公共场地与道路半径')]
rows=[]
for id,title,u,r,sq,sr,radius,role in [(1,'高地宫苑',-6,-26,2,0,0,'palace'),(2,'旧南门',-12,30,3,0,0,'gate'),
 (3,'山腰市场',-14,10,2,1,10,'market'),(4,'门外工匠街',19,27,2,2,10,'craft'),
 (5,'东坡住宅',22,-18,2,2,17,'residential'),(6,'西侧御苑',-19,-6,2,1,18,'garden')]:
    rows.append(dict(id=id,name=title,centerQ=int(u-r/2),centerR=r,shiftQ=sq,shiftR=sr,searchRadius=radius,role=role,roadRadius=2))
write('MapAreaRoyalDistrictTable',dict(version=1,name='MapAreaRoyalDistrictTable',description='宫苑、市集、工匠街与住宅各自生长；不镜像复制左右片区',key='id',fields=fields,rows=rows))

plots=read('MapAreaRoyalPlacementTable')
plots['description']='片区内的地块意图：先设施和主路，再临街住宅，最后绿地陈设'
field(plots,'districtId','int','所属功能片区',ref='MapAreaRoyalDistrictTable')
field(plots,'role','enum','生成阶段',values=['landmark','facility','house','garden','detail'])
field(plots,'searchRadius','int','相对目标锚点的有限搜索半径',min=0,max=20)
field(plots,'rotations','int[]','允许的六方向朝向；住宅按临街评分选择')
field(plots,'required','bool','必需地块找不到合法位置时明确报错；可选景观记录未摆放原因')
plots['fields']=[f for f in plots['fields'] if f['name']!='rotation']
plots['rows']=[]
def add(name,district,u,r,pool=(),facility=0,role='garden',radius=9,rotations=(0,3),required=False):
    assert (2*u-r)%2==0
    plots['rows'].append(dict(id=len(plots['rows'])+1,name=name,districtId=district,localQ=int(u-r/2),localR=r,
        lotIds=list(pool),facilityId=facility,role=role,searchRadius=radius,rotations=list(rotations),required=required))
add('王宫',1,0,0,facility=6,role='landmark',radius=0,rotations=[0],required=True)
add('城门',2,0,0,[18],role='landmark',radius=0,rotations=[0],required=True)
add('市集喷泉',3,2,0,facility=7,role='facility',required=True)
add('旅人酒馆',3,-4,4,facility=1,role='facility',required=True,rotations=[0,1,2,3,4,5])
add('工匠铁铺',4,0,0,facility=2,role='facility',required=True,rotations=[0,1,2,3,4,5])
add('街角商店',3,5,-4,facility=3,role='facility',required=True,rotations=[0,1,2,3,4,5])
add('坡顶公会',5,0,6,facility=4,role='facility',required=True,rotations=[0,1,2,3,4,5])
for d,u,r in [(5,0,0),(5,2,-8),(5,-4,8),(5,4,12),(3,-4,-6),(3,5,8),(4,-5,4),(4,5,-4)]:
    add('沿街联排',d,u,r,[14,15,16],role='house',radius=14,rotations=[0,1,2,3,4,5],required=True)
add('宫殿中庭喷泉',1,0,8,[20],radius=0,rotations=[0],required=True)
add('御苑凉亭',6,-4,-12,[19],radius=9)
add('东坡观景亭',5,2,-12,[19],radius=8)
for d,u,r in [(6,-2,-6),(6,3,2),(6,5,10),(6,-5,8),(6,-2,-14),(4,-5,8),(1,-18,0),(5,4,-12)]:add('刺绣花坛',d,u,r,[22],radius=11)
for d,u,r in [(1,-5,10),(1,6,10),(3,-2,4),(5,2,2)]:add('街角雕像',d,u,r,[21],role='detail',radius=6)
for d in [1,5,6]:
    for u,r in [(-8,-4),(8,4),(4,-12),(-6,12),(-10,8),(9,-8)]:add('庭园柏树',d,u,r,[23],role='detail',radius=8,rotations=[0])
for u,r in [(-3,3),(3,-3),(6,4)]:add('街头摊亭',3,u+.5 if r%2 else u,r,[11,12,13],role='detail',radius=6)
recipe['rows'][0]['placementIds']=[r['id'] for r in plots['rows']]
write('MapAreaRoyalPlacementTable',plots);write('MapAreaRoyalTable',recipe)
town=read('MapAreaTownTable');royal=next(r for r in town['rows'] if r['id']==5);royal['rampWidth']=5;royal['bridgeWidth']=5
write('MapAreaTownTable',town)
print('王城：独立分区、错位台地、目的地街网与临街选址参数已写入源表')
