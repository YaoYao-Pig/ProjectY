"""Author source tables only; run the project exporter after this script."""
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TABLES = ROOT / 'Config/Tables'


def read(name):
    path = next(TABLES.rglob(name + '.json'))
    return path, json.loads(path.read_text(encoding='utf-8-sig'))


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def upsert(name, rows, fields=None):
    path, data = read(name)
    for row in rows:
        old = next((r for r in data['rows'] if r['id'] == row['id']), None)
        if old is None:
            data['rows'].append(row)
        else:
            old.update(row)
    if fields:
        fields(data['fields'])
    save(path, data)


def field(name, kind, description, **kwargs):
    return dict(name=name, type=kind, description=description, **kwargs)


def new(name, description, fields, rows):
    save(TABLES / 'Animals' / (name + '.json'), dict(version=1, name=name, description=description,
         key='id', fields=[field('id', 'int', '稳定配置 ID', min=1)] + fields, rows=rows))

upsert('GrowthAttributeTable',[dict(id=19,code='charisma',name='魅力',category='life',pointCost=1,amount=1,maximumInvestment=30,skillDirection=False)])


new('AnimalSpeciesTable', '动物物种、可骑乘性与固定轴向占地；每只动物沿用独立 CombatActorData。', [
    field('name','text','动物名称'),field('unitId','int','战斗模板',ref='CombatUnitTable'),
    field('rideable','bool','驯服后是否立即骑乘'),field('footprintQ','int[]','轴向 q 偏移，必须包含原点'),
    field('footprintR','int[]','配对的轴向 r 偏移，支持一到多格'),
    field('tameDifficulty','float','从成功率扣除的驯服难度'),field('tameRetryTurns','int','驯服失败后此动物再次接受尝试所需的回合数',min=1),field('riderSeat','float[]','Unity 骑手髋部坐标 x/y/z'),
    field('moveRange','int','骑乘移动距离',min=1),field('initialBond','int','初始亲密度',min=0),
    field('bondPerBattle','int','共同完成战斗增长的亲密度',min=0),field('maximumBond','int','亲密度上限',min=1)], [
    dict(id=1,name='马',unitId=201,rideable=True,footprintQ=[0],footprintR=[0],tameDifficulty=8,tameRetryTurns=3,riderSeat=[0,1.40,-.05],moveRange=5,initialBond=0,bondPerBattle=10,maximumBond=100),
    dict(id=2,name='鸡',unitId=202,rideable=True,footprintQ=[0],footprintR=[0],tameDifficulty=0,tameRetryTurns=2,riderSeat=[0,1.22,-.08],moveRange=3,initialBond=0,bondPerBattle=10,maximumBond=100),
    dict(id=3,name='兔子',unitId=203,rideable=True,footprintQ=[0],footprintR=[0],tameDifficulty=4,tameRetryTurns=3,riderSeat=[0,1.0,-.1],moveRange=4,initialBond=0,bondPerBattle=10,maximumBond=100)])
new('AnimalRuleTable','驯服成功率与技能入口。概率单位为百分数，满血中立动物不享受受伤加成。',[
    field('tameSkillId','int','驯服技能',ref='CombatSkillTable'),field('chance','formula','驯服概率；affinity/charisma/missingHealth/hostile/difficulty',variables=['affinity','charisma','missingHealth','hostile','difficulty']),
    field('minimumChance','float','最小概率',min=0,max=100),field('maximumChance','float','最大概率',min=0,max=100)],
    [dict(id=1,tameSkillId=201,chance='30 + affinity * 3 + charisma * 2 + missingHealth * hostile * 45 - difficulty',minimumChance=5,maximumChance=95)])
new('AnimalSkillTable','骑兵技能随当前坐骑亲密度自动解锁；更换物种时技能集合随之变化。',[
    field('speciesId','int','动物物种',ref='AnimalSpeciesTable'),field('skillId','int','授予技能',ref='CombatSkillTable'),
    field('minimumBond','int','所需亲密度',min=0),field('movement','enum','冲击直线移动、飞扑与跳跃',values=['charge','pounce','leap']),
    field('minimumDistance','int','目标最小格距',min=1),field('maximumDistance','int','目标最大格距',min=1)], [
    dict(id=1,speciesId=1,skillId=202,minimumBond=10,movement='charge',minimumDistance=2,maximumDistance=5),
    dict(id=2,speciesId=2,skillId=203,minimumBond=10,movement='pounce',minimumDistance=2,maximumDistance=2),
    dict(id=3,speciesId=3,skillId=204,minimumBond=10,movement='leap',minimumDistance=1,maximumDistance=3)])

_, units = read('CombatUnitTable')
animals=[]
for unit_id,name,vitality,strength,speed,defense,move in [(201,'马',9,6,6,2,5),(202,'鸡',4,4,5,0,3),(203,'兔子',5,3,7,1,4)]:
    animals.append(dict(id=unit_id,name=name,vitality=vitality,endurance=3,intellect=1,strength=strength,speed=speed,defense=defense,
                        attributeNames=['unarmed'],attributeValues=[4],maxHealth='12 + vitality * 4',actionPoints=4,moveRange=move,moveCost=1,skillIds=[205]))
upsert('CombatUnitTable',animals)

_, skills=read('CombatSkillTable')
base=skills['rows'][0]
rows=[]
for id,name,description,target,rng,effect in [
    (201,'驯服','以动物亲和与魅力尝试驯服。探索中可驯服中立动物，战斗中可驯服敌对动物；敌对动物伤势越重越容易成功。','enemy',1,201),
    (202,'冲击','骑马沿直线冲至目标前方并攻击；冲刺距离越长，伤害越高。','enemy',5,202),
    (203,'飞扑','骑鸡向前跃进一格并攻击相邻目标。','enemy',2,203),
    (204,'跳跃','骑兔子跃向最多三格内的空地，可以越过低矮阻挡；落点必须可站立。','cell',3,204),
    (205,'扑咬','动物的近身攻击。','enemy',1,203)]:
    row=copy.deepcopy(base);row.update(id=id,name=name,description=description,iconId=1,action='main',cost=2,range=rng,target=target,
       proficiency='animalAffinity' if id==201 else 'unarmed',effectIds=[effect],skillGroup='animal',cooldownTurns=0 if id in (201,205) else 1,
       hitChance=100,shots=1,ammoPerShot=0,damageScale=1,actionTemplate=0,contexts=['life','battle'] if id==201 else ['battle']);rows.append(row)
def skill_fields(fields):
    if not any(f['name']=='contexts' for f in fields):
        fields.append(field('contexts','enum[]','允许使用的场景；life 为探索生活技能，battle 为战斗技能，可同时选择',values=['life','battle'],default=['battle']))
    for f in fields:
        if f['name']=='target' and 'cell' not in f['values']:f['values'].append('cell')
        if f['name']=='skillGroup' and 'animal' not in f['values']:f['values'].append('animal')
upsert('CombatSkillTable',rows,skill_fields)
def effect_fields(fields):
    for f in fields:
        if f['name']=='amount' and 'distance' not in f['variables']:f['variables'].append('distance')
        if f['name']=='kind':
            for value in ('tame','relocate'):
                if value not in f['values']:f['values'].append(value)
upsert('CombatEffectTable',[dict(id=201,kind='tame',amount='0'),dict(id=202,kind='damage',amount='max(1,floor(5 + strength + distance * 4 - defense - guard))'),
       dict(id=203,kind='damage',amount='max(1,floor(4 + strength - defense - guard))'),dict(id=204,kind='relocate',amount='0')],effect_fields)
upsert('ActiveSkillPoolTable',[dict(id=201,attributeId=18,skillId=201,tier=1,minValue=5,maxValue=100000,weight=1)])
for id,name in [(201,'Horse'),(202,'Chicken'),(203,'Rabbit')]:
    upsert('PawnPartTable',[dict(id=id,name=name,slot='body',prefabPath='Assets/DynamicAsset/ForestAnimals/Models/'+name+'.fbx',equipmentItemId=0)])
    upsert('PawnTemplateTable',[dict(id=id,name=name,unitId=id,partIds=[id,2],appearancePoolId=1)])
encounters=[]
for id,name,enemyids in [(201,'林地野马',[201]),(202,'林地野鸡',[202]),(203,'林地野兔',[203]),(204,'森林哥布林',[4,5,4])]:
    encounters.append(dict(id=id,name=name,radius=5,obstacleChance=0,enemyIds=enemyids,maxRounds=30,rewardCoins=12 if id==204 else 0,
                           rewardTraitIds=[],experience=50 if id==204 else 20,appearancePoolId=3 if id==204 else 1))
upsert('CombatEncounterTable',encounters)

catalog_path=ROOT/'Config/Catalog.json';catalog=json.loads(catalog_path.read_text(encoding='utf-8-sig'))
module=next(m for m in catalog['modules'] if m['id']=='MapArea');enum=next(e for e in module['enums'] if e['name']=='E_MapAreaType')
if not any(m['name']=='Forest' for m in enum['members']):enum['members'].append(dict(name='Forest',value=3,description='森林空地与林间小径'))
if not any(m['id']=='Animals' for m in catalog['modules']):catalog['modules'].append(dict(id='Animals',folder='Animals',description='动物、驯服与骑兵技能',enums=[],constants=[]))
save(catalog_path,catalog)
new('MapAreaForestTable','森林生成参数；林间空地保留战斗空间，树木按噪声形成疏密变化。',[
    field('gladeCount','int','安全空地数量',min=4,max=16),field('gladeRadius','int','空地净空半径',min=2,max=5),
    field('treeChance','float','林木基础密度',min=0,max=.5),field('fernChance','float','非阻挡蕨类密度',min=0,max=.5),
    field('oakAssetId','int','阔叶树资源',ref='MapAssetTable'),field('pineAssetId','int','针叶树资源',ref='MapAssetTable'),
    field('fernAssetId','int','蕨类资源',ref='MapAssetTable'),field('groundSurfaceId','int','苔草地面材质',ref='MapAreaSurfaceTable'),
    field('trailSurfaceId','int','林间土路材质',ref='MapAreaSurfaceTable')],
    [dict(id=1,gladeCount=8,gladeRadius=3,treeChance=.26,fernChance=.10,oakAssetId=201,pineAssetId=202,fernAssetId=203,groundSurfaceId=201,trailSurfaceId=202)])
new('MapAreaForestSpawnTable','每行独立抽取是否刷新、数量和敌对概率；复进使用持久状态。',[
    field('areaId','int','森林地图',ref='MapAreaTable'),field('encounterId','int','遭遇模板',ref='CombatEncounterTable'),
    field('chance','int','本类刷新百分比',min=0,max=100),field('minCount','int','最少组数',min=0),field('maxCount','int','最多组数',min=0),
    field('neutralChance','int','中立百分比，仅动物可为中立',min=0,max=100)],
    [dict(id=i,areaId=20,encounterId=200+i,chance=100 if i<4 else 65,minCount=1,maxCount=2,neutralChance=65 if i<4 else 0) for i in range(1,5)])
new('MapAreaForestEntranceTable','按大地图 Region 类型创建森林小地图入口，每个真实森林 Region 一个入口。',[
    field('regionType','enum','大地图地貌类型',enumRef='Map.E_MapRegion'),field('areaId','int','森林地图',ref='MapAreaTable')],
    [dict(id=1,regionType=5,areaId=20)])
upsert('MapAreaTable',[dict(id=20,name='幽叶森林',areaType=3,profileId=1,width=48,height=48,hexRadius=1.5,visionRadius=9,moveStepSeconds=.18,seedSalt=87541,discovery='explore')])
upsert('MapAreaEncounterTable',[dict(id=20,encounterId=204,groupCount=1,alertRange=4,battleMargin=3,seedSalt=24737)])
_,themes=read('MapAreaThemeTable')
theme_rows=[]
for old in themes['rows']:
    row=copy.deepcopy(old);row.update(name='幽叶森林',floorColor='#567747',wallColor='#645842',wallHeight=.5,heightNoise=0,assetId=204);theme_rows.append(row)
new('MapAreaForestThemeTable','森林地面与边界主题。',themes['fields'][1:],theme_rows)
asset_rows=[]
for id,name,shape,color,height,material in [(201,'ForestOak','tree','#557c43',5.5966,'M_MapLP_ForestLeaf'),(202,'ForestPine','tree','#3f6b57',5.5,'M_MapLP_ForestPine'),
    (203,'ForestFern','rock','#71934e',.52,'M_MapLP_ForestLeaf'),(204,'ForestGround','hex','#567747',1,'M_MapLP_ForestGround')]:
    asset_rows.append(dict(id=id,name=name,prefabPath='Assets/DynamicAsset/ForestAnimals/Models/'+name+'.fbx',previewShape=shape,previewColor=color,referenceHeight=height,footprintRadius=0,tintMaterial=material))
upsert('MapAssetTable',asset_rows)
upsert('MapAreaSurfaceTable',[
    dict(id=201,name='森林苔草',pattern=4,baseColor='#567747',detailColor='#698354',tileMeters=1.9,contrast=.14,jointWidth=.02,smoothness=.02),
    dict(id=202,name='森林落叶土路',pattern=4,baseColor='#827454',detailColor='#6e674b',tileMeters=1.1,contrast=.16,jointWidth=.02,smoothness=.02)])
print('Forest and animal source tables authored.')
