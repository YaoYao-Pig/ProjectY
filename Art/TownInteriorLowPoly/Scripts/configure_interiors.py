"""首轮室内资源与导航源表迁移；运行后由正式 exporter 生成 _Gen。"""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
def load(folder,name):return json.loads((ROOT/'Config/Tables'/folder/(name+'.json')).read_text(encoding='utf-8-sig'))
def save(folder,table):
    (ROOT/'Config/Tables'/folder/(table['name']+'.json')).write_text(json.dumps(table,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
assets=load('Map','MapAssetTable');lots=load('MapArea','MapAreaTownLotTable')
assert not any(r['name'].startswith('WalkTown_') for r in assets['rows']),'迁移已执行，后续请定向改表'
next_asset=max(r['id'] for r in assets['rows'])+1
def asset(name,color='#c7b69a'):
    global next_asset
    id=next_asset;next_asset+=1
    assets['rows'].append(dict(id=id,name=name,prefabPath='Assets/DynamicAsset/TownInteriorLowPoly/Models/'+name+'.fbx',
        previewShape='hall',previewColor=color,referenceHeight=1,footprintRadius=1,tintMaterial=''))
    return id
lots['fields'].append(dict(name='scaleMode',type='enum',values=['grid','meters'],description='grid 随格子缩放；meters 保持真实建筑与家具米制尺度'))
for lot in lots['rows']:lot['scaleMode']='grid'
fields=[dict(name='id',type='int',ref='MapAreaTownLotTable',description='对应完整建筑地块 ID'),
 dict(name='name',type='string',description='室内类型'),dict(name='coverAssetId',type='int',ref='MapAssetTable',description='进入后剖切隐藏的上墙和屋顶'),
 dict(name='navRadius',type='float',description='模型与导航制作时的地格半径，改变时需要同步重制占地'),
 dict(name='interiorQ',type='int[]',description='可走室内地格 q，不含墙和家具'),dict(name='interiorR',type='int[]',description='可走室内地格 r'),
 dict(name='serviceQ',type='int',description='室内介绍/服务点 q'),dict(name='serviceR',type='int',description='室内介绍/服务点 r'),
 dict(name='floorColor',type='string',description='室内地面纯色'),dict(name='doorWidth',type='float',description='门洞净宽，米'),
 dict(name='doorHeight',type='float',description='门洞净高，米'),dict(name='storeyHeight',type='float',description='首层层高，米')]
interiors=dict(version=1,name='MapAreaTownInteriorTable',description='与街道共用坐标的真实室内；建筑核心与可剖切上盖分离',key='id',fields=fields,rows=[])
kit=[]
for id,kind,title in [(1,'Tavern','酒馆公共厅'),(2,'Forge','铁匠工坊'),(3,'Shop','商店营业厅'),(4,'Guild','公会接待厅')]:
    shell=asset('WalkTown_'+kind+'_Structure');cover=asset('WalkTown_'+kind+'_Cover')
    # 墙格位于真实墙线上；中心只给家具占格，不能把整栋楼再次当实心方块。
    envelope=[(q,r) for r in range(-2,3) for q in range(-6,7) if abs(q+r/2)<=3.5]
    floor=[(q,r) for q,r in envelope if abs(r)<=1 and abs(q+r/2)<=2.5]
    fixtures={'Tavern':[(-2,-1),(2,-1),(-2,1),(1,1)],'Forge':[(-2,-1),(2,-1),(1,1)],
              'Shop':[(-2,-1),(2,-1),(-2,1)],'Guild':[(-2,-1),(2,-1),(-2,1)]}[kind]
    walk=[p for p in floor if p not in fixtures]
    solids=[p for p in envelope if p not in walk and p!=(-1,2)]
    lot=next(r for r in lots['rows'] if r['id']==id)
    lot.update(assetId=shell,scale=1,scaleMode='meters',footprintQ=[q for q,r in solids],footprintR=[r for q,r in solids],entryQ=-1,entryR=2)
    interiors['rows'].append(dict(id=id,name=title,coverAssetId=cover,navRadius=1.5,interiorQ=[q for q,r in walk],interiorR=[r for q,r in walk],
        serviceQ=0,serviceR=0,floorColor='#9b805f' if kind in ['Tavern','Shop'] else '#aa9e8b',doorWidth=3.0,doorHeight=2.4,storeyHeight=3.2))
    kit.append(dict(kind=kind,shell='WalkTown_'+kind+'_Structure',cover='WalkTown_'+kind+'_Cover',fixtures=fixtures,halfWidth=7.75,halfDepth=3.55))
# 王宫沿用原 43 米宽的上部轮廓；底层开真实门厅，双翼暂不开放。
shell=asset('WalkTown_Palace_Structure');cover=asset('WalkTown_Palace_Cover')
envelope=[(q,r) for r in range(-6,6) for q in range(-14,15) if abs(q+r/2)<=9]
floor=[(q,r) for q,r in envelope if -4<=r<=-1 and abs(q+r/2)<=7]
fixtures=[(-4,-2),(6,-2),(-3,-4),(7,-4),(2,-4)]
walk=[p for p in floor if p not in fixtures]
solids=[(q,r) for q,r in envelope if (r<0 or abs(q+r/2)>=4.5) and (q,r) not in walk]
lot=next(r for r in lots['rows'] if r['id']==17)
lot.update(assetId=shell,scale=1,scaleMode='meters',footprintQ=[q for q,r in solids],footprintR=[r for q,r in solids],entryQ=0,entryR=0)
interiors['rows'].append(dict(id=17,name='王宫接见门厅',coverAssetId=cover,navRadius=1.5,interiorQ=[q for q,r in walk],interiorR=[r for q,r in walk],
    serviceQ=2,serviceR=-2,floorColor='#c4b69c',doorWidth=3.6,doorHeight=4.1,storeyHeight=4.5))
kit.append(dict(kind='Palace',shell='WalkTown_Palace_Structure',cover='WalkTown_Palace_Cover',fixtures=fixtures,halfWidth=20.5,halfDepth=6))
# 新联排保持现实门窗层高，仍为不可进入的三栋完整组团。
for id,variant in [(14,'A'),(15,'B'),(16,'C')]:
    lot=next(r for r in lots['rows'] if r['id']==id);points=[(q,r) for r in [-1,0,1] for q in range(-3,4) if abs(q+r/2)<=2]
    lot.update(assetId=asset('WalkTown_Row'+variant),scale=1,scaleMode='meters',footprintQ=[q for q,r in points],footprintR=[r for q,r in points])
save('Map',assets);save('MapArea',lots);save('MapArea',interiors)
blocks=load('MapArea','MapAreaTownBlockTable')
for block in blocks['rows']:
    if block['id'] in [4,5,6]:block['facilityR']=-2
save('MapArea',blocks)
facilities=load('MapArea','MapAreaTownFacilityTable')
for row in facilities['rows']:
    if row['id'] in [1,2,3,4]:row['description']='可直接走入室内参观，在服务台附近查看介绍。交易、锻造、任务和住宿业务暂未接入。'
    if row['id']==6:row['name']='王宫接见厅';row['description']='王宫外苑和底层接见门厅开放，可直接步行进入；双翼、上层与宫廷玩法暂未开放。'
save('MapArea',facilities)
out=ROOT/'Art/TownInteriorLowPoly/Integration';out.mkdir(parents=True,exist_ok=True)
(out/'kit-design.json').write_text(json.dumps(kit,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('室内源表与 13 个米制模型资源已登记；待建模、导航与渲染接入后统一导出。')
