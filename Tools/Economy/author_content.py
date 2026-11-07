"""Idempotent source-table authoring for town economy. Run exporter afterwards."""
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TABLES = ROOT / 'Config/Tables'


def read(name):
    return json.loads((TABLES / f'{name}.json').read_text(encoding='utf-8-sig'))


def write(name, table):
    path = TABLES / f'{name}.json'
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(table, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def upsert(table, row):
    index = next((i for i, old in enumerate(table['rows']) if old['id'] == row['id']), None)
    if index is None:
        table['rows'].append(row)
    else:
        table['rows'][index] = row


def field(name, kind, description, **extra):
    return dict(name=name, type=kind, description=description, **extra)


def new(name, description, fields, rows):
    return dict(version=1, name=name, description=description, key='id', fields=fields, rows=rows)


settings = dict(id=1, radius=12, foodBase=2, foodLevelStep=5, wageBase=2, wagePerLevel=2,
                animalFoodBase=3, termDays=7, investmentLimit=1000, maximumLossPercent=30,
                maximumGainPercent=15, historyDays=60, marketTarget=80, marketCapacity=320,
                sellMultiplier=.8, hungerPenalty=.05, debtPenalty=.03, maximumPenalty=.4,
                starterFood=60, bankFacilityId=14, bankRoyalPlacementId=9001)
descriptions = dict(radius='城镇可达资源搜索半径', foodBase='每名人形队员每日基础食物',
                    foodLevelStep='每提升多少级增加一份食物', wageBase='队员基础日薪', wagePerLevel='每级增加日薪',
                    animalFoodBase='动物每个占地格的基础食物', termDays='投资期限，游戏日',
                    investmentLimit='每城同时可投入的本金上限', maximumLossPercent='投资最大本金损失百分比',
                    maximumGainPercent='单期最大盈利百分比', historyDays='保留真实日K线数量',
                    marketTarget='常态参考库存', marketCapacity='市场单商品容量', sellMultiplier='收购折扣',
                    hungerPenalty='每个饥饿日的状态减益比例', debtPenalty='每欠一天日薪的状态减益比例',
                    maximumPenalty='状态减益上限', starterFood='新远征初始口粮', bankFacilityId='银行设施配置', bankRoyalPlacementId='王城银行地块预设')
write('Economy/EconomyRuleTable', new('EconomyRuleTable', '城镇贸易、银行与队伍每日运营规则。',
      [field(k, 'float' if isinstance(v, float) else 'int', descriptions.get(k, '规则编号'), min=0) for k, v in settings.items()], [settings]))

goods = [
    dict(id=1, itemId=9100, name='粮食', richTag='粮食充足', poorTag='农业薄弱', basePrice=4, food=True, regionTypes=[1], regionWeights=[1.0], waterWeight=0),
    dict(id=2, itemId=9101, name='渔获', richTag='渔业兴盛', poorTag='渔获依赖进口', basePrice=5, food=True, regionTypes=[], regionWeights=[], waterWeight=1.0),
    dict(id=3, itemId=81, name='木材', richTag='森林资源丰富', poorTag='木材依赖进口', basePrice=3, food=False, regionTypes=[5,8], regionWeights=[1.0,.7], waterWeight=0),
    dict(id=4, itemId=9102, name='矿石', richTag='矿业资源丰富', poorTag='矿石依赖进口', basePrice=9, food=False, regionTypes=[2,6,12,13,10], regionWeights=[1.0,.5,.8,.7,.5], waterWeight=0),
    dict(id=5, itemId=9103, name='纺织品', richTag='纤维原料丰富', poorTag='纺织原料不足', basePrice=8, food=False, regionTypes=[1,5,7], regionWeights=[.8,.3,.5], waterWeight=0),
    dict(id=6, itemId=9104, name='药草', richTag='药草资源丰富', poorTag='药草依赖进口', basePrice=7, food=False, regionTypes=[5,7,11,8], regionWeights=[.8,1.0,.7,.6], waterWeight=0)]
fields = [field('id','int','商品分类编号',min=1),field('itemId','int','实际背包物品',ref='EquipmentItemTable'),
          field('name','text','分类名称'),field('richTag','text','高资源强度标签'),field('poorTag','text','低资源强度标签'),
          field('basePrice','int','基础价格',min=1),field('food','bool','是否可作为每日食物消耗'),
          field('regionTypes','int[]','产地地貌类型'),field('regionWeights','float[]','对应地貌生产潜力'),
          field('waterWeight','float','可接近水域的渔业潜力',min=0,max=1)]
write('Economy/EconomyCommodityTable', new('EconomyCommodityTable','六类地区商品；地貌表示首版生产潜力。',fields,goods))

items=read('Equipment/EquipmentItemTable')
wood=next(r for r in items['rows'] if r['id']==81)
for item_id,name,asset,icon in [(9100,'旅行口粮',301,wood['iconPath']),(9101,'风干渔获',301,wood['iconPath']),
                               (9102,'铁矿石',303,'Assets/DynamicAsset/EquipmentDemo/Icons/Item_83.png'),
                               (9103,'粗纺布匹',302,'Assets/DynamicAsset/EquipmentDemo/Icons/Item_82.png'),
                               (9104,'干燥药草',301,wood['iconPath'])]:
    row=copy.deepcopy(wood);row.update(id=item_id,name=name,assetId=asset,iconPath=icon,visualEffectId=0)
    upsert(items,row)
write('Equipment/EquipmentItemTable',items)
prices=read('Travel/WorldTradePriceTable')
for good in goods:
    if good['itemId']!=81:upsert(prices,dict(id=good['itemId'],itemId=good['itemId'],price=good['basePrice']))
write('Travel/WorldTradePriceTable',prices)
entries=read('Shop/ShopEntryTable')
for good in goods:
    if good['itemId']!=81:upsert(entries,dict(id=good['itemId'],templateId=1,itemId=good['itemId'],chance=100,minCount=12,maxCount=30,price=good['basePrice']))
write('Shop/ShopEntryTable',entries)

facilities=read('MapArea/MapAreaTownFacilityTable')
kind=next(f for f in facilities['fields'] if f['name']=='kind')
if 'values' in kind and 'bank' not in kind['values']:kind['values'].append('bank')
upsert(facilities,dict(id=14,name='城镇银行',kind='bank',description='在柜台查看当地商贸投资的日K线、风险和到期结算。本金可能部分亏损。',lotIds=[33],npcTemplateId=5,interactionRadius=1))
write('MapArea/MapAreaTownFacilityTable',facilities)
npcs=read('MapArea/MapAreaTownNpcTable');row=copy.deepcopy(next(r for r in npcs['rows'] if r['id']==3));row.update(id=5,name='银行柜员',description='办理本地商贸投资，展示历史行情并说明本金风险。');upsert(npcs,row);write('MapArea/MapAreaTownNpcTable',npcs)
lots=read('MapArea/MapAreaTownLotTable');row=copy.deepcopy(next(r for r in lots['rows'] if r['id']==3));row.update(id=33,name='银行营业厅');upsert(lots,row);write('MapArea/MapAreaTownLotTable',lots)
interiors=read('MapArea/MapAreaTownInteriorTable');row=copy.deepcopy(next(r for r in interiors['rows'] if r['id']==3));row.update(id=33,name='银行柜台与营业厅',floorColor='#82714e');upsert(interiors,row);write('MapArea/MapAreaTownInteriorTable',interiors)
placements=read('MapArea/MapAreaRoyalPlacementTable');row=copy.deepcopy(next(r for r in placements['rows'] if r['facilityId']==3));row.update(id=9001,name='商贸银行',facilityId=14,localQ=-7,localR=-4,searchRadius=14);upsert(placements,row);write('MapArea/MapAreaRoyalPlacementTable',placements)
print('Economy source tables authored. Existing building meshes are reused for the bank branch.')
