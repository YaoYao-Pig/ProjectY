"""Author loot source tables. Export through Tools/ConfigEditor/exporter.mjs."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
TABLES=ROOT/'Config/Tables'
def load(name):
    path=next(TABLES.rglob(name+'.json'));return path,json.loads(path.read_text(encoding='utf-8-sig'))
def save(path,value):
    path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def field(name,type,description,**kwargs):return dict(name=name,type=type,description=description,**kwargs)
def table(name,description,fields,rows):
    save(TABLES/'Loot'/(name+'.json'),dict(version=1,name=name,description=description,key='id',fields=[field('id','int','稳定配置 ID',min=1)]+fields,rows=rows))
def addrows(name,rows):
    path,data=load(name)
    for row in rows:
        old=next((r for r in data['rows'] if r['id']==row['id']),None)
        if old is None:data['rows'].append(row)
        else:old.update(row)
    save(path,data)
table('LootPoolTable','每个条目独立判定的掉落池；可能同时命中多项，也可能为空。',[
    field('name','text','掉落池名'),field('seedSalt','int','独立随机通道',min=0)],
    [dict(id=i,name=n,seedSalt=s) for i,n,s in [(1,'地牢宝箱',137),(2,'森林宝箱',271),(3,'近战敌人遗物',419),(4,'弓手遗物',563)]])
entries=[]
for pool,rows in [(1,[(31,80,12,24),(11,30,1,1),(12,25,1,1),(13,20,1,1),(40,15,1,1),(51,20,1,1)]),
                  (2,[(31,55,6,18),(46,20,1,1),(56,30,1,1),(53,8,1,1)]),
                  (3,[(40,35,1,1),(57,20,1,1),(13,10,1,1)]),
                  (4,[(46,35,1,1),(51,20,1,1),(56,25,1,1),(12,10,1,1)])]:
    for item,chance,low,high in rows:entries.append(dict(id=len(entries)+1,poolId=pool,itemId=item,chance=chance,minCount=low,maxCount=high))
table('LootEntryTable','掉落概率为百分比，数量为命中后的闭区间随机整数。',[
    field('poolId','int','所属掉落池',ref='LootPoolTable'),field('itemId','int','物品',ref='EquipmentItemTable'),
    field('chance','float','独立命中概率（百分比）',min=0,max=100),field('minCount','int','最小数量',min=1),field('maxCount','int','最大数量',min=1)],entries)
table('MapAreaChestRuleTable','小地图宝箱独立生成策略；只选入口可达、无角色/NPC占用的地格。',[
    field('areaId','int','小地图配置',ref='MapAreaTable'),field('lootTableId','int','宝箱与内容定义',ref='EquipmentLootTable'),
    field('strategy','enum','候选位置策略',values=['reachable','rooms']),field('minCount','int','最少宝箱数',min=0,max=100),
    field('maxCount','int','最多宝箱数',min=0,max=100),field('minDistance','int','距入口最小寻路距离',min=0),
    field('maxDistance','int','距入口最大寻路距离',min=0),field('spacing','int','宝箱间最小六边形格距',min=1),
    field('seedSalt','int','独立随机通道',min=0)],
    [dict(id=1,areaId=1,lootTableId=10,strategy='rooms',minCount=2,maxCount=4,minDistance=12,maxDistance=500,spacing=6,seedSalt=51073),
     dict(id=2,areaId=20,lootTableId=11,strategy='reachable',minCount=2,maxCount=4,minDistance=10,maxDistance=140,spacing=5,seedSalt=52711)])
table('EnemyDropTable','按敌人战斗模板配置死亡掉落；未配置模板无掉落，驯服不触发。',[
    field('unitId','int','敌人模板',ref='CombatUnitTable'),field('lootTableId','int','地面战利品及掉落池',ref='EquipmentLootTable'),
    field('seedSalt','int','独立随机通道',min=0)],
    [dict(id=1,unitId=4,lootTableId=100,seedSalt=731),dict(id=2,unitId=5,lootTableId=101,seedSalt=997)])
p,d=load('EquipmentLootTable')
if not any(f['name']=='poolId' for f in d['fields']):d['fields'].append(field('poolId','int','随机池 ID；0 使用固定 itemIds/counts',min=0,default=0))
for row in d['rows']:row.setdefault('poolId',0)
save(p,d)
addrows('EquipmentLootTable',[
    dict(id=10,name='地牢藏宝箱',kind='chest',assetId=7,openedAssetId=8,itemIds=[],counts=[],poolId=1),
    dict(id=11,name='林间藏宝箱',kind='chest',assetId=7,openedAssetId=8,itemIds=[],counts=[],poolId=2),
    dict(id=100,name='近战敌人的战利品',kind='ground',assetId=8,openedAssetId=8,itemIds=[],counts=[],poolId=3),
    dict(id=101,name='弓手的战利品',kind='ground',assetId=8,openedAssetId=8,itemIds=[],counts=[],poolId=4)])
catalogPath=ROOT/'Config/Catalog.json';catalog=json.loads(catalogPath.read_text(encoding='utf-8-sig'))
if not any(m['id']=='Loot' for m in catalog['modules']):catalog['modules'].append(dict(id='Loot',folder='Loot',description='宝箱生成与敌人掉落',enums=[],constants=[]))
lootModule=next(m for m in catalog['modules'] if m['id']=='Loot')
if not any(c['name']=='EventBattlefieldAreaId' for c in lootModule['constants']):lootModule['constants'].append(dict(name='EventBattlefieldAreaId',type='int',value=30,description='旧事件战斗转入并保留的局部战场定义'))
module=next(m for m in catalog['modules'] if m['id']=='MapArea');enum=next(e for e in module['enums'] if e['name']=='E_MapAreaType')
if not any(m['name']=='Battlefield' for m in enum['members']):enum['members'].append(dict(name='Battlefield',value=4,description='事件战场与战后探索'))
save(catalogPath,catalog)
table('MapAreaBattlefieldTable','旧事件使用的小型战场；几何沿用战斗模板半径和障碍概率。',[
    field('surfaceId','int','地面材质',ref='MapAreaSurfaceTable')],[dict(id=1,surfaceId=1)])
addrows('MapAreaTable',[dict(id=30,name='事件战场',areaType=4,profileId=1,width=32,height=32,hexRadius=1.5,visionRadius=9,moveStepSeconds=.18,seedSalt=54713,discovery='open')])
addrows('MapAreaEncounterTable',[dict(id=30,encounterId=1,groupCount=1,alertRange=4,battleMargin=3,seedSalt=4171)])
_,themes=load('MapAreaForestThemeTable')
for row in themes['rows']:row.update(name='野外战场',floorColor='#759754',wallColor='#898379',wallHeight=.8,assetId=1)
table('MapAreaBattlefieldThemeTable','事件战场的地面与障碍主题。',themes['fields'][1:],themes['rows'])
print('Loot pools, chest strategies, enemy drops and battlefield source tables authored.')
