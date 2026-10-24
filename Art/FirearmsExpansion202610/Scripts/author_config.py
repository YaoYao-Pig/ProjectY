"""Author this firearm set using existing equipment, magazine, shop and loot contracts."""
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
ART = ROOT / 'Art/FirearmsExpansion202610'
ASSETS = 'Assets/DynamicAsset/FirearmsExpansion202610'
tables = {}
paths = {}

def table(name):
    if name not in tables:
        paths[name] = next((ROOT / 'Config/Tables').rglob(name + '.json'))
        tables[name] = json.loads(paths[name].read_text(encoding='utf-8'))
    return tables[name]

def row(name, id):
    return next(r for r in table(name)['rows'] if r['id'] == id)

def add(name, value):
    existing = next((r for r in table(name)['rows'] if r['id'] == value['id']), None)
    if existing is not None:
        assert existing == value, (name, value['id'], 'conflicting authored row')
    else:
        table(name)['rows'].append(value)

def field(name, value):
    existing = next((f for f in table(name)['fields'] if f['name'] == value['name']), None)
    if existing:
        assert existing == value
    else:
        table(name)['fields'].append(value)

field('CombatSkillTable', dict(name='criticalChance', type='float', description='每发命中后的独立暴击概率；只放大对他人的即时伤害', default=0, min=0, max=100))
field('CombatSkillTable', dict(name='criticalMultiplier', type='float', description='暴击伤害倍率；不放大治疗、护卫、状态或持续伤害', default=2, min=1, max=10))
field('EquipmentRuneTable', dict(name='criticalBonus', type='float', description='匹配技能的暴击率加成，单位为百分点', default=0, min=-100, max=100))

precise = row('CombatSkillTable', 7)
precise.update(name='精准射击', hitChance=95, criticalChance=35, criticalMultiplier=2,
               description='消耗1发弹药进行精准单发射击：基础命中95%，命中后35%概率造成2倍伤害。节省弹药，适合稳定点杀。')
burst = row('CombatSkillTable', 8)
burst.update(name='连续射击', hitChance=70, criticalChance=10, criticalMultiplier=2, damageScale=.8,
             description='消耗3发弹药连续射击3次：每发基础命中70%、暴击率10%、伤害80%。逐发独立判定命中、暴击与命中附加效果，以更多耗弹换取更高总伤害期望。')
for id in (7, 8):
    row('SkillDescriptionTable', id)['body'] = row('CombatSkillTable', id)['description']
for id in (604, 605, 606):
    skills = row('EquipmentWeaponTable', id)['skillIds']
    if 8 not in skills:
        skills.insert(skills.index(9), 8)

skills = [
    (1701, '狙击射击', '消耗1发狙击弹，在2—9格内进行单发狙击：基础命中95%、暴击率50%、伤害160%，暴击造成2倍伤害。', 9, 2, 3, 95, 50, 1.6, 1, 0, 1, [7]),
    (1702, '贯甲狙击', '消耗2发狙击弹进行一次贯甲射击，伤害只计入目标60%防御；基础命中90%、暴击率55%，命中施加2回合破甲。', 9, 2, 4, 90, 55, 1.6, 2, 2, 1, [1312, 1313]),
    (1703, '近距霰射', '消耗1发霰弹，攻击主目标及其1格内最多2名其他敌人。每个目标独立判定80%基础命中与10%暴击；每目标100%伤害，射程3格。', 3, 0, 2, 80, 10, 1.0, 1, 0, 3, [7]),
    (1704, '重霰双发', '消耗2发霰弹，连续进行两次近距散射。每次最多3名相邻敌人，每目标逐发独立判定75%命中与10%暴击，每发85%伤害。', 3, 0, 3, 75, 10, .85, 1, 1, 3, [7]),
]
for id, name, desc, reach, minimum, cost, hit, crit, scale, ammo, cooldown, targets, effects in skills:
    value = copy.deepcopy(precise)
    value.update(id=id, name=name, description=desc, range=reach, minRange=minimum, cost=cost, hitChance=hit,
                 criticalChance=crit, damageScale=scale, ammoPerShot=ammo, cooldownTurns=cooldown,
                 shots=2 if id == 1704 else 1, effectIds=effects, maxTargets=targets, splashRadius=1 if targets > 1 else 0,
                 iconId=12 if targets > 1 else 11, visualEffectId=8 if id == 1704 else 7,
                 contexts=['battle'], affectsContainers=False)
    add('CombatSkillTable', value)
    add('SkillDescriptionTable', dict(id=id, tagIds=['attack', 'physical'], body=desc, fragmentIds=[]))
    add('SkillAtlasTable', dict(id=id, categoryId=15, relatedCategoryIds=[], x=145+(id-1701)%2*220,
                              y=632+(id-1701)//2*180, prerequisiteIds=[], prerequisiteMode='all',
                              tags=['装备专属', '枪械', 'firearms'], glyphCode='firearms'))

add('EquipmentCategoryTable', dict(id=9, name='狙击枪'))
add('EquipmentCategoryTable', dict(id=10, name='霰弹枪'))
for id, name in [('assault_rifle', '突击步枪'), ('sniper_rifle', '狙击枪'), ('shotgun', '霰弹枪')]:
    add('EquipmentWeaponTagTable', dict(id=id, name=name, tool=False))

manifest = []
def item(id, name, kind, price, width=1, height=1):
    model = 'Firearm_' + str(id)
    prefab = ASSETS + '/Weapons/' + model + '.prefab' if kind == 'weapon' else ASSETS + '/Models/' + model + '.fbx'
    add('EquipmentAssetTable', dict(id=id, name=model, modelPath=ASSETS+'/Models/'+model+'.fbx', prefabPath=prefab))
    add('EquipmentItemTable', dict(id=id, name=name, kind=kind, assetId=id, iconPath=ASSETS+'/Icons/Item_'+str(id)+'.png',
                                  width=width, height=height, iconMode='model', iconRotation=[8,100,65] if kind=='weapon' else [8,25,0],
                                  iconPadding=1.18, visualEffectId=10021 if kind=='weapon' else 0))
    add('WorldTradePriceTable', dict(id=id, itemId=id, price=price))
    add('ShopEntryTable', dict(id=id, templateId=1, itemId=id, chance=100 if kind in ('ammo', 'magazine') else 65,
                              minCount=8 if kind=='ammo' else 2 if kind=='magazine' else 1,
                              maxCount=20 if kind=='ammo' else 3 if kind=='magazine' else 1, price=price))
    manifest.append(dict(id=id, name=name, kind=kind, model=model, price=price))

weapons = [
    (800, '风隼突击步枪', 2, 2, .95, 21, [7,8,9], 'assault_rifle', '轻型突击步枪，精准单发与三连射兼备。使用巡猎12发弹匣及巡猎弹药。'),
    (801, '铁雨突击步枪', 2, 3, 1.12, 810, [7,8,9], 'assault_rifle', '重型持续火力步枪，使用专属24发弹匣与巡猎弹药，可连续完成8轮三连射；不兼容巡猎12发弹匣。'),
    (802, '远望狙击枪', 9, 2, 1, 811, [1701,9], 'sniper_rifle', '远程高命中、高暴击的栓动狙击枪，相邻1格无法射击。使用5发狙击弹匣和狙击弹药。'),
    (803, '钟塔重型狙击枪', 9, 3, 1.15, 811, [1701,1702,9], 'sniper_rifle', '长枪管重型狙击枪，可使用贯甲射击对付重甲。使用5发狙击弹匣，贯甲一次消耗2发。'),
    (804, '破门霰弹枪', 10, 2, 1, 812, [1703,9], 'shotgun', '短管近战散射枪，1发霰弹最多命中3名相邻敌人。使用6发霰弹匣和霰弹弹药。'),
    (805, '碎礁战斗霰弹枪', 10, 3, 1.1, 812, [1703,1704,9], 'shotgun', '强化型战斗霰弹枪，可双发连续散射。使用6发霰弹匣；每轮重霰双发消耗2发。'),
]
for id, name, category, level, scale, magazine, granted, tag, desc in weapons:
    item(id, name, 'weapon', 160+(level-2)*70+(category>2)*40, 2, 5 if category==9 else 4)
    value = copy.deepcopy(row('EquipmentWeaponTable', 2))
    sockets = list(range(400+(id-800)*4, 404+(id-800)*4))
    value.update(id=id, socketIds=sockets, skillIds=granted, magazineItemId=magazine, categoryId=category,
                 level=level, damageMultiplier=scale, gripId=id, tagIds=[tag], description=desc, onHitEffectIds=[])
    # gunClass is a pose/motion family, not the displayed firearm category.
    add('EquipmentWeaponTable', value)
    grip = copy.deepcopy(row('EquipmentGripTable', 2));grip.update(id=id, name=name+'握点');add('EquipmentGripTable', grip)
    for old in list(table('EquipmentHoldAdjustmentTable')['rows']):
        if old['weaponId']==2:
            new=copy.deepcopy(old);new.update(id=80000+(id-800)*10+old['moduleId'], weaponId=id);add('EquipmentHoldAdjustmentTable',new)
    muzzle = {800: .78, 801: .86, 802: 1.02, 803: 1.14, 804: .60, 805: .70}[id]
    specs=[('magazine','弹匣接口',[0,.04,.22],'right'), ('rail','瞄具导轨',[0,.25,.12],'left'),
           ('muzzle','枪口接口',[0,.18,muzzle],'left'), ('stock','枪托组件',[.069,.11,-.35],'right')]
    for sid,(kind,label,position,side) in zip(sockets,specs):
        add('EquipmentSocketTable', dict(id=sid,name=label,weaponItemId=id,kind=kind,position=position,rotation=[0,0,0],calloutSide=side))
    manifest[-1].update(category=tag, magazine=magazine, description=desc, muzzle=muzzle)

for id,name,ammo,capacity,price in [(810,'铁雨弹匣 · 24发',31,24,28),(811,'狙击弹匣 · 5发',820,5,24),(812,'霰弹匣 · 6发',821,6,20)]:
    item(id,name,'magazine',price,1,2)
    add('EquipmentMagazineTable',dict(id=id,ammoItemId=ammo,capacity=capacity,spawnRounds=capacity))
    manifest[-1].update(capacity=capacity,ammo=ammo)

modules = [
    (813,'鹰眼准镜','rail',.95,0,8,10,0,[], '命中提高8个百分点，暴击率提高10个百分点；伤害降低5%。'),
    (814,'长视狙击镜','rail',1,2,5,15,1,[], '射程增加2格，命中提高5个百分点，暴击率提高15个百分点；技能冷却增加1回合。'),
    (815,'制退补偿器','muzzle',.9,0,10,0,0,[], '命中提高10个百分点；伤害降低10%，适合稳定连续射击。'),
    (816,'长膛枪口','muzzle',1.1,1,-5,0,0,[], '伤害提高10%，射程增加1格；命中降低5个百分点。'),
    (817,'裂甲枪口','muzzle',.9,0,0,0,0,[1356], '每次命中独立有35%概率施加2回合破甲（防御-2）；伤害降低10%。连续射击可多次尝试触发。'),
    (818,'贴腮稳定托','stock',.95,0,6,5,0,[], '命中提高6个百分点，暴击率提高5个百分点；伤害降低5%。'),
    (819,'复进缓冲托','stock',.9,0,0,0,-1,[], '技能冷却减少1回合，最低为0；伤害降低10%。适合贯甲狙击或重霰双发。'),
]
for id,name,slot,scale,reach,hit,crit,cd,effects,desc in modules:
    item(id,name,'module',90 if slot=='rail' else 75)
    add('EquipmentRuneTable',dict(id=id,slotKind=slot,skillGroup='physical',description=desc,damageMultiplier=scale,
                                 rangeBonus=reach,hitBonus=hit,criticalBonus=crit,cooldownBonus=cd,maxTargets=1,splashRadius=0,
                                 catalystKind='none',requiredTalentId=0,onHitEffectIds=effects,transferSelf=False,transferRange=0))
    add('SkillSynergyTable',dict(id=id,runeIds=[id],skillIds=[],name=name,body=desc))
    manifest[-1].update(slot=slot,description=desc)
item(820,'狙击弹药','ammo',3)
item(821,'霰弹弹药','ammo',2)
for id in [800,801,802,803,804,805,810,811,812,813,815,817,820,821]:
    add('LootEntryTable',dict(id=8000+id,poolId=5,itemId=id,chance=100,minCount=6 if id>=820 else 1,
                            maxCount=12 if id>=820 else 1,weight=2 if id<810 else 4))

for name,t in tables.items():
    paths[name].write_text(json.dumps(t,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
ART.mkdir(parents=True,exist_ok=True)
(ART/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Authored 6 firearms, 3 magazines, 7 modules, 2 ammunition types and 4 skills.')
