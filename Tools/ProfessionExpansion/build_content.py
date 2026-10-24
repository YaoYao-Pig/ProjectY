"""Apply the profession expansion's owned source rows; never exports generated files."""
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
paths = {p.stem: p for p in (ROOT / 'Config/Tables').rglob('*.json')}
tables = {}


def table(name):
    if name not in tables:
        tables[name] = json.loads(paths[name].read_text(encoding='utf-8-sig'))
    return tables[name]


def row(name, key):
    return next(r for r in table(name)['rows'] if r['id'] == key)


def put(name, value):
    rows = table(name)['rows']
    previous = next((r for r in rows if r['id'] == value['id']), None)
    if previous is None:
        rows.append(value)
    else:
        previous.update(value)


def field(name, kind, description, **extra):
    return dict(name=name, type=kind, description=description, **extra)


def add_field(name, value):
    fields = table(name)['fields']
    if not any(f['name'] == value['name'] for f in fields):
        fields.append(value)


def create(name, description, fields, folder='Progression'):
    if name not in paths:
        paths[name] = ROOT / 'Config/Tables' / folder / (name + '.json')
        tables[name] = dict(version=1, name=name, description=description, key='id', fields=fields, rows=[])


create('ProfessionCombatTable', '职业战斗技能机制、选项与实际材料契约', [
    field('id', 'int', '技能 ID', ref='CombatSkillTable'),
    field('mechanic', 'string', '战斗机制代码'),
    field('family', 'string', '药剂或咒术分组', default=''),
    field('materialId', 'int', '消耗物品；0 表示无', default=0, min=0),
    field('materialCount', 'int', '每次合法施放消耗份数', default=0, min=0),
    field('statusTag', 'string', '选择或消费的状态标签', default=''),
    field('applyEffectId', 'int', '机制施加的 CombatEffect；0 表示无', default=0, min=0),
    field('bonusDamage', 'int', '条件附伤；受共享附伤上限约束', default=0, min=0),
    field('baseSkillId', 'int', '共享课程的基础技能；0 表示本人', default=0, min=0),
    field('requiredEquipment', 'string', '额外要求的实际装备类型；shield/bow/melee，空为无', default=''),
    field('refundItemId', 'int', '拆料返还的实际原投入物品；0 表示无', default=0, min=0),
])
add_field('ProfessionCombatTable', field('requiredEquipment', 'string', '额外要求的实际装备类型；shield/bow/melee，空为无', default=''))
add_field('ProfessionCombatTable', field('refundItemId', 'int', '拆料返还的实际原投入物品；0 表示无', default=0, min=0))
create('ProfessionStatusTable', '一次性职业状态的消费机制', [
    field('id', 'int', '状态 ID', ref='BuffTable'),
    field('mechanic', 'string', '状态消费机制'),
    field('amount', 'int', '机制数值；涂层与附刃为施加效果 ID'),
    field('applyEffectId', 'int', '施加此状态的效果 ID', ref='CombatEffectTable'),
])
create('ProfessionExplorationTable', '职业探索能力的耗时、材料和实体交互规则', [
    field('id', 'int', '探索技能 ID', ref='CombatSkillTable'),
    field('kind', 'enum', '探索交互类型', values=['extract', 'rumor', 'care', 'curse', 'duel', 'track', 'companion']),
    field('minutes', 'float', '成功推进游戏分钟', min=0),
    field('range', 'int', '有效实体距离', min=0),
    field('itemId', 'int', '消耗物品；0 表示无', default=0, min=0),
    field('itemCount', 'int', '消耗份数', default=0, min=0),
    field('rewardItemId', 'int', '采集获得物品；0 表示无', default=0, min=0),
    field('rewardCount', 'int', '采集获得份数', default=0, min=0),
    field('daily', 'bool', '按实体或城镇每日限一次', default=False),
    field('amount', 'int', '该能力配置数值', default=0, min=0),
    field('description', 'text', '探索用途与限制'),
])
create('ProfessionCurseTable', '可识别、触发和净化的真实物品诅咒', [
    field('id', 'int', '诅咒物品 ID', ref='EquipmentItemTable'),
    field('itemId', 'int', '诅咒物品 ID', ref='EquipmentItemTable'),
    field('triggerBuffId', 'int', '首次装备触发状态', ref='BuffTable'),
    field('applyEffectId', 'int', '首次装备触发效果', ref='CombatEffectTable'),
    field('cleanseItemId', 'int', '再次识咒时净化消耗的物品', ref='EquipmentItemTable'),
    field('description', 'text', '真实触发条件'),
    field('clue', 'text', '真实解除方法'),
])
create('ProfessionDuelTable', '公会礼式决斗的单挑契约', [
    field('id', 'int', '规则 ID'),
    field('facilityKind', 'enum', '允许发起的设施', values=['guild']),
    field('encounterId', 'int', '实际单挑遭遇', ref='CombatEncounterTable'),
    field('minimumHealthPercent', 'int', '认输生命百分比', min=1, max=99),
    field('rewardCoins', 'int', '胜利奖励', min=0),
    field('lossCoins', 'int', '失败代价', min=0),
    field('description', 'text', '单挑的明确规则'),
])
create('ProfessionBeastTable', '绑定动物的付费指令与共享结算参数', [
    field('id', 'int', '技能 ID', ref='CombatSkillTable'),
    field('kind', 'enum', '指令机制', values=['scent','move','attack','rescue','mode']),
    field('commandRange', 'int', '主人至动物的指令距离', default=3, min=0),
    field('biteSkillId', 'int', '真实动物扑咬技能', ref='CombatSkillTable'),
    field('bleedEffectId', 'int', '实际流血效果', ref='CombatEffectTable'),
    field('passiveNodeId', 'int', '嗅血被动节点', ref='TalentNodeTable'),
    field('bonusDamage', 'int', '嗅血基础附伤', default=3, min=0),
    field('bonusEffectId', 'int', '嗅血附伤效果，正常防御结算', ref='CombatEffectTable'),
    field('description', 'text', '指令说明'),
])
add_field('PassiveSkillTable', field('triggerKind', 'string', '已学被动的规则触发代码；空表示无触发', default=''))
add_field('CombatEffectTable', field('damageType', 'string', '直接伤害类型及免疫匹配；附刃可覆盖', default='physical'))
for name in ['sourceRequiredTags', 'sourceForbiddenTags']:
    add_field('CombatEffectTable', field(name, 'string[]', '施法者状态标签条件；required 任一存在才执行，forbidden 任一存在时拒绝', default=[]))
groups = next(f for f in table('CombatSkillTable')['fields'] if f['name'] == 'skillGroup')['values']
for code in ['extract', 'rumor', 'care', 'curse', 'duel', 'track', 'companion']:
    group = 'profession_life_' + code
    if group not in groups:
        groups.append(group)

# Status definitions have real GameEffect tags and durations; custom consumption is separately declared.
states = [
    (12001, '破绽', '下一次直接武器命中按少 2 点防御结算，随后清除。', 'exposed', 'debuff', 2, 'exposed', 2),
    (12002, '咒印', '下一次直接伤害增加 30%，上限为目标最大生命的 10%，随后清除。', 'curse_mark', 'debuff', 2, 'curse_mark', 30),
    (12003, '余音', '最多一层，可由破音或安可消费，不额外授予主要行动。', 'resonance', 'buff', 2, 'resonance', 1),
    (12004, '水剂涂层', '下一次直接武器命中施加潮湿；首个正式回合结束失效。', 'coating_water', 'buff', 1, 'coating_water', 20019),
    (12005, '毒剂涂层', '下一次直接武器命中施加一层中毒；首个正式回合结束失效。', 'coating_poison', 'buff', 1, 'coating_poison', 803),
    (12006, '审势', '下一次直接武器命中先制造破绽再结算本击。', 'opening_edge', 'buff', 1, 'opening', 0),
    (12007, '火焰附刃', '下一次直接近战命中改为火焰伤害并施加燃烧。', 'spell_edge_fire', 'buff', 2, 'enchant_fire', 20021),
    (12008, '流水附刃', '下一次直接近战命中改为水系伤害并施加潮湿。', 'spell_edge_water', 'buff', 2, 'enchant_water', 20019),
    (12009, '守命护符', '下次直接伤害减免 4 点后消失；不减免周期伤害。', 'ward', 'buff', 2, 'ward', 4),
    (12010, '安可', '下一次技能 AP 减少 2，最低 1；不影响道具或行动额度。', 'encore_discount', 'buff', 2, 'encore_discount', 2),
    (12011, '描印', '下一次咒术技能 AP 减少 1，最低 1；首个正式回合结束失效。', 'drawing_mark', 'buff', 1, 'draw_discount', 1),
    (12012, '残液回收', '下一次药剂技能 AP 减少 1，最低 1；本场战斗有效。', 'recycle_discount', 'buff', 100000, 'recycle_discount', 1),
    (12013, '虚弱', '力量降低 2，持续 2 回合。', 'weakness', 'debuff', 2, '', 0),
    (12014, '腐蚀', '防御降低 2，持续 2 回合，不磨损护甲耐久。', 'corrosion', 'debuff', 2, '', 0),
    (12015, '并肩节奏', '速度提高 2，持续 2 回合；仅影响下一轮排序。', 'haste', 'buff', 2, '', 0),
    (12016, '绊索迟缓', '速度降低 2，持续 2 回合。', 'slow', 'debuff', 2, '', 0),
    (12017, '苦难研习', '保留负面状态时，本回合智力提高 2。', 'suffering', 'buff', 1, 'suffering', 2),
    (12018, '承誓', '相邻守护者承受下一次单目标直接攻击；不能连锁转交。', 'interpose', 'buff', 1, 'interpose', 0),
    (12019, '潮湿', '熄灭燃烧并阻止点燃，持续 2 回合。', 'wet', 'debuff', 2, '', 0),
    (12020, '血契诅咒', '首次装备未净化的血契仪刀时力量降低 2；识咒后消耗净咒药剂解除。', 'blood_curse', 'debuff', 0, '', 0),
    (12021, '附刃燃烧', '每回合承受火焰伤害；潮湿期间不能点燃，持续 2 回合。', 'burning', 'debuff', 2, '', 0),
    (12022, '净身护卫', '护卫至少为 3，持续至首个正式回合结束。', 'preparation_guard', 'buff', 1, 'guard_floor', 3),
]
for sid, name, description, tag, category, turns, mechanic, amount in states:
    buff = dict(id=sid, name=name, description=description, iconId=10004 if category == 'buff' else 10001,
                color='#A1D8C8' if category == 'buff' else '#CA83A7', category=category, scope='battle',
                clock='turns', durationTurns=turns, durationMinutes=0, tickPhase='turn_end', periodTurns=0,
                periodMinutes=0, stacking='refresh', maxStacks=1, removeOnDeath=True, periodicEffectIds=[],
                modifierEffectIds=[], onApplyEffectIds=[], tags=[tag], blockedByTags=[], removeTags=[], skipTurn=False)
    if sid in [12013, 12014, 12015, 12016, 12017, 12020]:
        attr, value = {12013:('strength',-2),12014:('defense',-2),12015:('speed',2),12016:('speed',-2),12017:('intellect',2),12020:('strength',-2)}[sid]
        modifier_id = 20100 + sid - 12000
        buff['modifierEffectIds'] = [modifier_id]
        put('CombatEffectTable', dict(id=modifier_id, kind='modifier', amount=str(value), name=name, description=description, attribute=attr, duration='infinite', removeOnBattleEnd=sid != 12020))
    if sid == 12019:
        buff['removeTags'] = ['burning']
    if sid == 12021:
        buff.update(periodTurns=1, periodicEffectIds=[904], blockedByTags=['wet'])
    if sid == 12020:
        buff.update(scope='persistent', clock='infinite', removeOnDeath=False, tags=['curse','persistent_curse'], stacking='independent')
    if sid in [12012,12018]: buff.update(clock='infinite', durationTurns=0)
    if sid in [12004,12005]: buff['tags'].append('coating')
    if sid in [12007,12008]: buff['tags'].append('enchantment')
    put('BuffTable', buff)
    put('CombatEffectTable', dict(id=sid + 8000, kind='apply_buff', amount='0', name=name, description=description, buffId=sid, chance=100))
    if mechanic:
        put('ProfessionStatusTable', dict(id=sid, mechanic=mechanic, amount=amount, applyEffectId=sid+8000))

# Common direct damage/healing instructions. Conditional bonuses are resolved from pre-hit state snapshots.
for eid, template, scale in [(20201,1,1),(20202,8,1),(20203,2,1)]:
    effect = copy.deepcopy(row('CombatEffectTable', template)); effect['id'] = eid
    effect.update(damageType='arcane' if eid==20202 else 'physical')
    put('CombatEffectTable', effect)
put('CombatEffectTable', dict(id=20204,kind='heal',amount='6 + intellect',name='代罪疗伤',description='治疗存活友军。'))
put('CombatEffectTable', dict(id=20205,kind='remove_buffs',amount='0',name='净化伤毒',description='清除中毒与流血。',removeTags=['poison','bleeding']))
put('CombatEffectTable', dict(id=20206,kind='apply_buff',amount='0',name='承担虚弱',description='施法者力量降低 2，持续 2 回合。',buffId=12013,recipient='source',chance=100))
lightning=copy.deepcopy(row('CombatEffectTable',20202));lightning.update(id=20207,damageType='lightning');put('CombatEffectTable',lightning)
put('CombatEffectTable',dict(id=20209,kind='damage',amount='max(0, 3 - defense - guard)',name='嗅血',description='指令命中流血敌人时追加 3 点基础物理伤害，正常计算防御。',requiredTags=['bleeding'],damageType='physical',equipmentDamage=0,killEquipmentDamage=0))

professions = [
    (6,'炼金师','alchemist','intellect','残液回收','recycle','每场首次蒸馏爆破成功消费敌方状态后，下次本人药剂技能 AP 减少 1，最低 1。',1800,71,7),
    (7,'吟游诗人','bard','charisma','接句','reply','主要技能成功作用于施放前已有减益的敌人后获得余音，每轮一次。',1810,81,8),
    (8,'神官','cleric','intellect','余恩','grace','正式战斗每轮首次由自己技能清除自身减益后，护卫至少为 4，持续至下回合开始。',1820,23,2),
    (9,'咒术师','warlock','intellect','苦难研习','suffering','回合开始有中毒、流血或虚弱时，本回合智力提高 2，多种状态不叠加。',1830,24,2),
    (10,'决斗家','duelist','speed','留手','mercy','直接武器命中施放前已有破绽的目标时，不磨损目标装备，自身武器仍磨损。',1840,17,1),
    (11,'驯兽师','beastmaster','animalAffinity','嗅血','scent_blood','绑定动物通过指令命中流血敌人时追加 3 点基础物理伤害，每条指令一次，正常计算防御。',1850,54,5),
]
for did,name,desc in [(7,'炼金','药剂与野外萃取'),(8,'战歌','节奏、余音与旅行传闻')]:
    put('SkillDisciplineTable',dict(id=did,name=name,description=desc,order=did))
for pid,name,code,attribute,passive,trigger,passive_desc,base,category,discipline in professions:
    put('ProfessionTable',dict(id=pid,name=name,description={'alchemist':'消耗真实试剂控制状态，并选择持续伤害或提炼爆发。','bard':'运用节奏和余音安排先手与队友行动资源。','cleric':'以触媒祷言保护队友，承担虚弱后化为反击。','warlock':'用咒印、伤口与负面状态完成有代价的交换。','duelist':'制造破绽，控制距离，完整留下目标装备。','beastmaster':'以自己的行动指挥真实动物伙伴，兼顾骑乘与探索。'}[code],treeIds=[1,pid],initialSkillIds=[base+1]))
    put('PassiveSkillTable',dict(id=base+5,name=passive,description=passive_desc,attributeNames=[],attributeValues=[],immunityTags=[],iconAttribute=attribute,triggerKind=trigger))
    put('TalentTreeTable',dict(id=pid,name=name+'研习',description='加入职业后开放，已学被动在转职后保留。',unlockRule='adjacent_any',rootIds=[base+5]))
    put('TalentNodeTable',dict(id=base+5,treeId=pid,passiveId=base+5,pointCost=1,maxRank=1,minLevel=3,x=280,y=145))
    put('SkillCategoryTable',dict(id=category,disciplineId=discipline,name=name,order=category))

def skill_visual(sid):
    # Particle art is authored in the source table; never inherit another skill's profile.
    profile = next((entry for entry in table('VisualEffectTable')['rows'] if entry['id'] == sid), None)
    assert profile is not None, f'Author an independent VisualEffectTable profile for skill {sid} before generating content'
    return sid


def skill(sid,name,description,*,action='main',cost=2,range=3,target='enemy',proficiency='',effects=None,group='support',cd=2,hit=90,scale=1,trajectory='sight',contexts=None,catalyst='none',wear=0,icon=10004,mechanic='',family='',material=0,status='',apply=0,bonus=0,base=0):
    contexts = contexts or ['battle']
    put('CombatSkillTable',dict(id=sid,name=name,description=description,iconId=icon,visualEffectId=skill_visual(sid),
        action=action,cost=cost,range=range,target=target,proficiency=proficiency,effectIds=effects or [],skillGroup=group,
        cooldownTurns=cd,hitChance=hit,shots=1,ammoPerShot=0,damageScale=scale,actionTemplate=1 if catalyst=='arcane' else 4 if group=='weapon' else 0,
        trajectory=trajectory,contexts=contexts,affectsContainers=False,skillKind='preparation' if contexts==['preparation'] else 'active',catalystKind=catalyst,weaponWear=wear))
    if mechanic:
        put('ProfessionCombatTable',dict(id=sid,mechanic=mechanic,family=family,materialId=material,materialCount=1 if material else 0,statusTag=status,applyEffectId=apply,bonusDamage=bonus,baseSkillId=base))

prep=dict(contexts=['preparation'],target='self',range=0,hit=100,cd=0)
spell=dict(group='spell',proficiency='staff',catalyst='arcane',icon=10003)
weapon=dict(group='weapon',proficiency='sword',range=1,hit=95,wear=1,icon=10001)
skill(1801,'分装试剂·水剂','消耗 1 份水剂，为下一次直接武器命中涂上水剂，施加潮湿 2 回合。首个正式回合结束失效；学习后同时可选毒剂。',mechanic='coat',family='potion',material=8013,status='wet',apply=20004,**prep)
skill(1802,'泼水瓶','消耗 1 份水剂，使单个角色潮湿 2 回合并灭火；友方必定成功，敌方正常判命中。',action='secondary',cost=1,range=2,target='any',mechanic='splash',family='potion',material=8013,apply=20019)
skill(1803,'腐蚀剂','消耗 1 份腐蚀剂。命中施加一层中毒，并使防御降低 2、持续 2 回合；不直接扣血或磨损护甲。',effects=[803,20014],trajectory='lobbed',mechanic='splash',family='potion',material=8015)
skill(1804,'蒸馏爆破·燃烧','消耗 1 份爆破剂，造成 70% 基础伤害；命中燃烧目标时消费全部燃烧并追加 6 点伤害。学习后同时可选提炼中毒。',cost=3,effects=[20202],scale=.7,trajectory='direct',proficiency='staff',mechanic='distill',family='potion',material=8016,status='burning',bonus=6,icon=10003,cd=3)
skill(1811,'起拍','给自己或一名友军一层余音，持续至其首个正式回合结束。',contexts=['preparation'],target='ally',range=3,hit=100,cd=0,mechanic='beat',apply=20003)
skill(1812,'并肩曲','自己或一名友军速度提高 2，持续 2 回合；按下一轮排序生效，不插队。',action='secondary',cost=1,target='ally',hit=100,effects=[20015])
skill(1813,'破音','使敌人力量降低 2，持续 2 回合；若自身有余音，命中后消费余音并额外制造破绽。',effects=[20013],mechanic='beat',status='resonance',apply=20001)
skill(1814,'安可','消费自己或一名友军的余音，使其下一技能 AP 减少 2，最低 1，至下个回合结束有效；每人每轮至多受益一次，不刷新行动。',action='secondary',target='ally',hit=100,mechanic='encore',status='resonance',apply=20010,cd=3)
skill(1821,'净身祷文','清除自身中毒与流血，使护卫至少为 3，持续至首个正式回合结束；需要触媒，不治疗身体创伤。',mechanic='cleanse_guard',apply=20022,**prep,**spell)
skill(1822,'守命祷言','给自己或友军护符，下次直接伤害减免 4 点后消失，最迟在接收者下个回合结束失效；同类不叠加。',action='secondary',cost=1,range=2,target='ally',hit=100,mechanic='ward',apply=20009,**spell)
skill(1823,'代罪疗伤','清除一名存活友军的中毒与流血并治疗 6＋智力；施法者力量降低 2，持续 2 回合。',range=2,target='ally',hit=100,effects=[20205,20204,20206],mechanic='atonement',**spell)
skill(1824,'赎罪裁决','造成 90% 奥术伤害；自身施放前有虚弱时，命中后消费全部虚弱并追加 6 点伤害。',cost=3,effects=[20202],scale=.9,trajectory='direct',cd=3,mechanic='judgement',status='weakness',bonus=6,**spell)
skill(1831,'描印','下一次咒术技能 AP 减少 1，最低 1；首个正式回合结束前有效。',mechanic='draw_mark',family='curse',apply=20011,**prep,**spell)
skill(1832,'烙咒','对敌人施加咒印：下一次直接伤害增加 30%，上限为目标最大生命的 10%，随后清除。',action='secondary',cost=1,mechanic='curse_mark',family='curse',apply=20002,**spell)
skill(1833,'蚀命','造成 80% 奥术伤害；命中流血目标追加 6 点，并消费其全部流血。',effects=[20202],scale=.8,trajectory='direct',mechanic='consume_damage',family='curse',status='bleeding',bonus=6,**spell)
skill(1834,'转祸·中毒','把自己一项中毒尝试移交给敌人，保留剩余时长与层数；成功施加后才移除自身状态，免疫目标不能接收。学习后也可选择流血或虚弱。',cost=3,cd=3,mechanic='transfer',family='curse',status='poison',**spell)
skill(1841,'审势','下一次直接武器命中先施加破绽，再结算本击；首个正式回合结束失效。',mechanic='opening',apply=20006,**prep)
skill(1842,'佯攻','使用可用近战武器对相邻敌人制造破绽，无直接伤害；下一次直接武器命中按少 2 点防御结算并消费破绽。',action='secondary',cost=1,mechanic='feint',apply=20001,**weapon)
skill(1843,'牵步刺','造成 80% 武器伤害，随后退至事先选定且更远离目标的相邻空格；不会重新开放普通移动。该技能位移不触发借机攻击。',effects=[20201],scale=.8,mechanic='retreat',**weapon)
skill(1844,'见隙封喉','造成 110% 武器伤害；目标命中前已有破绽时追加 6 点伤害，破绽只消费一次；自身武器本次额外磨损 1。',cost=3,effects=[20201],scale=1.1,cd=3,mechanic='finisher',status='exposed',bonus=6,**{**weapon,'wear':2})
skill(1851,'熟悉气味','指定一名可见敌人为猎物，本人绑定动物首次成功攻击该目标时施加流血，本场一次。',contexts=['preparation'],target='enemy',range=3,hit=100,cd=0,group='animal',proficiency='animalAffinity')
skill(1852,'驱赶口令','令 3 格内本人绑定的可行动动物移动至选定相邻格，不攻击；每只动物每轮只能接受一次额外位移口令，并正常承担借机风险。',action='secondary',cost=1,target='cell',group='animal',proficiency='animalAffinity',hit=100)
skill(1853,'夹击口令','用本人的主要行动指挥 3 格内绑定动物扑咬其相邻敌人；主人也相邻时命中施加流血。骑乘不能算双人夹击。',group='animal',proficiency='animalAffinity',hit=95)
skill(1854,'救援衔拖','令 3 格内绑定动物将其相邻存活友军拖至选定合法相邻空格，最多 1 格；大型或重载目标拒绝，动物本轮不再接受攻击口令。',cost=3,target='ally',group='animal',proficiency='animalAffinity',hit=100,cd=3)

skill(1901,'盾推','需要盾，造成 60% 武器伤害；命中沿远离自己的方向推动目标 1 格，无合法落点时只有伤害。',effects=[20201],scale=.6,mechanic='push',**weapon)
skill(1902,'压制打击','造成 90% 武器伤害，命中使目标力量降低 2，持续 2 回合。',effects=[20201,20013],scale=.9,mechanic='strike',**weapon)
bow=dict(group='weapon',proficiency='bow',range=3,trajectory='lobbed',hit=90,wear=1,icon=10002)
skill(1903,'牵索箭','需要弓及 1 份绳索，造成 60% 伤害，命中向自己拉动目标 1 格；无法拉动的体型仍受伤但不位移。',effects=[20203],scale=.6,mechanic='pull',material=82,**bow)
skill(1904,'退身射击','需要弓，造成 80% 伤害，随后退至事先选定且更远离目标的相邻合法空格；不追加普通移动额度。该技能位移不触发借机攻击。',cost=3,effects=[20203],scale=.8,mechanic='retreat',**bow)
skill(1905,'术式附刃·火焰','需触媒及可用近战武器；下一次直接近战命中改为火焰伤害并施加燃烧 2 回合，至下个回合结束有效。学习后也可选择水系。',action='secondary',target='self',range=0,hit=100,mechanic='enchant',status='burning',apply=20007,**spell)
skill(1906,'导流术','造成 80% 奥术基础的闪电伤害；命中潮湿目标追加 6 点伤害并消费潮湿，不附带眩晕。',effects=[20207],scale=.8,trajectory='direct',mechanic='consume_damage',status='wet',bonus=6,**spell)
skill(1907,'绊索','消耗 1 份绳索在相邻空格放置公开的一次性绊索；首个地面单位进入时中止移动并速度降低 2、持续 2 回合，双方均可触发。',range=1,target='cell',contexts=['preparation','battle'],hit=100,group='construction',mechanic='trap',material=82,apply=20016)
skill(1908,'应急拆料','拆除相邻己方且无人承载的工事，返还其实际木料投入的一半、向下取整；不返还绳索，不拆任务设施。',range=1,target='cell',hit=100,group='construction',mechanic='salvage')
row('ProfessionCombatTable',1908)['refundItemId']=81
skill(1909,'护卫换位','与相邻同意且可移动的存活友军换位；双方完整占位均合法才成功，不重开普通移动。该技能位移不触发借机攻击。',action='secondary',range=1,target='ally',hit=100,mechanic='swap')
skill(1910,'承誓','需要盾，守护相邻友军至自己下回合开始；若仍相邻，其下一次单目标直接攻击改由自己承受；不挡周期或范围伤害，不连锁转交。',range=1,target='ally',hit=100,mechanic='interpose',apply=20018)

variants=[(1861,1801,'分装试剂·毒剂','消耗 1 份毒剂，下一次直接武器命中施加一层中毒；首个正式回合结束失效。',8014,'poison',20005),
          (1862,1804,'蒸馏爆破·中毒','消耗 1 份爆破剂，造成 70% 基础伤害；命中后消费全部中毒，每层追加 3 点、最多 9 点伤害。',8016,'poison',0),
          (1863,1834,'转祸·流血','把自己一项流血移交给敌人，保留剩余时长与层数；成功施加后才移除自己对应状态。',0,'bleeding',0),
          (1864,1834,'转祸·虚弱','把自己一项虚弱移交给敌人，保留剩余时长与层数；成功施加后才移除自己对应状态。',0,'weakness',0),
          (1865,1905,'术式附刃·流水','需触媒及可用近战武器；下一次直接近战命中改为水系伤害并施加潮湿 2 回合，至下个回合结束有效。',0,'wet',20008)]
for sid,parent,name,description,material,status,apply in variants:
    s=copy.deepcopy(row('CombatSkillTable',parent)); s.update(id=sid,name=name,description=description,visualEffectId=skill_visual(sid));put('CombatSkillTable',s)
    r=copy.deepcopy(row('ProfessionCombatTable',parent));r.update(id=sid,baseSkillId=parent,materialId=material,materialCount=1 if material else 0,statusTag=status,applyEffectId=apply)
    if sid==1862:r['bonusDamage']=3
    put('ProfessionCombatTable',r)
for sid,equipment in [(1901,'shield'),(1902,'melee'),(1910,'shield'),(1903,'bow'),(1904,'bow'),(1842,'melee'),(1843,'melee'),(1844,'melee'),(1905,'melee'),(1865,'melee')]:
    row('ProfessionCombatTable',sid)['requiredEquipment']=equipment

life=[(1806,'野外萃取','extract',5,2,0,0,8014,1,False,0,'采集一处相邻范围内尚未采过的有效蕨类植物，得到 1 份毒剂；同一真实实体只能采一次。'),
      (1816,'酒馆采风','rumor',30,3,0,0,0,0,True,12,'在当地酒馆听取有来源、12 格以内的真实附近地点消息；每城镇每日一次，已知线索不重复授予。'),
      (1826,'随军诊护','care',10,3,91,1,0,0,True,360,'消耗 1 份急救包，为有可恢复伤势的队员缩短 6 小时恢复时间；每队员每日一次，不能再生永久缺失部位。'),
      (1836,'识咒','curse',5,0,0,0,0,0,False,0,'识别持有诅咒物的真实触发条件与解除线索；已识别后再次使用，若携带净咒药剂则消耗 1 份净化该武器实例。'),
      (1846,'礼式决斗','duel',0,3,0,0,0,0,True,0,'在公会按约定请求一次单挑，每城镇每日一次；任一方生命低至 25% 时认输，保留真实伤势，胜利得 30 金币、失败付 15 金币。'),
      (1856,'循迹','track',5,4,0,0,0,0,False,120,'从附近真实动物足迹提取行动方向，记录带时间、有效 120 分钟的线索；不能定位世界上全部动物。'),
      (1867,'伙伴随行／骑乘切换','companion',0,1,0,0,0,0,False,0,'将本人绑定的同一只真实动物切换为独立随行或骑乘；两个模式互斥，保留生命、伤势与死亡状态。')]
for sid,name,kind,minutes,distance,item,count,reward,reward_count,daily,amount,description in life:
    skill(sid,name,description,target='ally' if kind=='care' else 'self',range=distance if kind=='care' else 0,cost=0,hit=100,cd=0,contexts=['life'],group='profession_life_'+kind)
    put('ProfessionExplorationTable',dict(id=sid,kind=kind,minutes=minutes,range=distance,itemId=item,itemCount=count,rewardItemId=reward,rewardCount=reward_count,daily=daily,amount=amount,description=description))
for sid,kind in [(1851,'scent'),(1852,'move'),(1853,'attack'),(1854,'rescue'),(1867,'mode')]:
    put('ProfessionBeastTable',dict(id=sid,kind=kind,commandRange=3,biteSkillId=205,bleedEffectId=802,passiveNodeId=1855,bonusDamage=3,bonusEffectId=20209,description=row('CombatSkillTable',sid)['description']))

# Courses retain all existing rows. A learned basic course grants its explicit option rows through runtime lookup.
for pid,name,code,attribute,passive,trigger,pdesc,base,category,discipline in professions:
    for offset in [1,2,3,4,6]:
        sid=base+offset
        put('ProfessionSkillTable',dict(id=pid*10000+sid,professionId=pid,skillId=sid,minLevel=5 if offset==4 else 3 if offset==3 else 1,attributeNames=[attribute],attributeValues=[6 if offset==4 else 4 if offset==3 else 2]))
put('ProfessionSkillTable',dict(id=110201,professionId=11,skillId=201,minLevel=1,attributeNames=['animalAffinity'],attributeValues=[2]))
for sid,pid in [(1901,1),(1902,1),(1903,2),(1904,2),(1905,3),(1906,3),(1907,4),(1908,4),(1909,5),(1910,5)]:
    attr={1:'strength',2:'bow',3:'intellect',4:'crafting',5:'endurance'}[pid]
    # Construction's existing attribute code is engineering, resolved below from current courses.
    if pid==4: attr=next(r['attributeNames'][0] for r in table('ProfessionSkillTable')['rows'] if r['professionId']==4 and r['attributeNames'])
    put('ProfessionSkillTable',dict(id=pid*10000+sid,professionId=pid,skillId=sid,minLevel=3,attributeNames=[attr],attributeValues=[4]))

put('SkillTagTable',dict(id='exploration',name='探索',textColor='#CFDFB4',backgroundColor='#3E5038E6'))
new_skills=[r for r in table('CombatSkillTable')['rows'] if 1800<r['id']<1920]
for index,s in enumerate(new_skills):
    sid=s['id']; parent=next((r['baseSkillId'] for r in table('ProfessionCombatTable')['rows'] if r['id']==sid),0) or sid
    p=next((p for p in professions if p[7]<parent<p[7]+10),None)
    cat=p[8] if p else {1901:13,1902:16,1903:14,1904:14,1905:21,1906:21,1907:41,1908:34,1909:13,1910:13,1867:54}[parent]
    glyph=p[3] if p else ('animalAffinity' if parent==1867 else 'intellect' if parent in [1905,1906] else 'sword')
    offset=parent%10; prerequisites=[parent] if sid!=parent else [parent-1] if p and offset in [3,4] else []
    if 'life' in s['contexts']: prerequisites=[]
    put('SkillAtlasTable',dict(id=sid,categoryId=cat,glyphCode=glyph,relatedCategoryIds=[],x=145+220*(index%2),y=160+180*(index//2),prerequisiteIds=prerequisites,prerequisiteMode='all',tags=[p[2] if p else 'profession_expansion',s['skillGroup']]))
    tags=['exploration'] if s['contexts']==['life'] else ['preparation'] if s['skillKind']=='preparation' else ['spell'] if s['catalystKind']=='arcane' else ['animal'] if s['skillGroup']=='animal' else ['attack','physical'] if s['skillGroup']=='weapon' else ['support']
    put('SkillDescriptionTable',dict(id=sid,tagIds=tags,body=s['description'],fragmentIds=[]))
    subject=('A single corked potion bottle with one bold droplet.' if p and p[0]==6 else 'A simple lute with one broad musical note.' if p and p[0]==7 else 'A plain golden shield with one pale healing cross.' if p and p[0]==8 else 'A violet wax seal with one broken circle.' if p and p[0]==9 else 'A slender rapier with one bold opening in a shield.' if p and p[0]==10 else 'A single wolf paw print and one clear command mark.' if p and p[0]==11 else 'A single medieval weapon with one clear directional motion mark.')
    put('SkillIconRecipeTable',dict(id=10000+sid,skillId=sid,slug='profession-skill-'+str(sid),styleId='pixel-simple-v1',subject=subject))

# Twelve genuinely different equipment forms, all attribute gated and usable across professions.
weapons=[
    ('AlembicStaff','炼金蒸馏杖',1,'arcane',1.05,[3],[4],[20019],'奥术触媒；直接命中使目标潮湿 2 回合，可为导流术铺垫。',120),
    ('CausticInjector','腐蚀注射剑',40,'arcane',.9,[1,3],[3,3],[803],'单手奥术触媒，直接命中施加一层中毒；可与盾牌共持。',125),
    ('ResonanceLute','共鸣鲁特琴',1,'arcane',1,[3],[3],[],'以琴颈引导奥术飞矢的双手乐器触媒；职业演奏本身不强制装备乐器。',110),
    ('MarchingLyre','行军七弦琴',1,'arcane',.95,[3],[2],[],'轻巧的双手乐器触媒，较低智力门槛；职业演奏本身不强制装备乐器。',85),
    ('MercyCenser','慈悲香炉杖',1,'arcane',1.1,[3],[4],[],'双手奥术触媒，可施放已掌握的神官、咒术与其他奥术技能。',130),
    ('VigilMace','守夜祷锤',40,'arcane',1,[1,3],[4,3],[],'可与盾牌共持的单手奥术触媒，为护卫与祷言保留同一套装备。',145),
    ('HexSpindle','缚咒纺锤杖',1,'arcane',1.2,[3],[5],[],'较高智力要求的双手触媒，强化通过本杖结算的直接伤害。',160),
    ('BloodCovenKnife','血契仪刀',40,'arcane',1.15,[1,3],[3,4],[802],'直接命中施加流血的单手触媒；首次装备未净化实例会触发血契诅咒，可由识咒揭示并解除。',150),
    ('SilverRapier','银线刺剑',40,'none',1.15,[1,4],[3,5],[],'轻量单手刺剑，速度要求较高；可配合佯攻、牵步刺与留手。',135),
    ('ParryingDagger','捕刃左手匕',40,'none',.85,[4],[4],[],'可作主手或副手的短匕；副手斩击沿用独立费用和 70% 基础伤害。',90),
    ('PackmasterCrook','驯群钩杖',1,'arcane',1,[3],[3],[],'带钩的双手奥术触媒，可同时研习兽群指令与咒术，指令仍消耗主人行动。',105),
    ('FangBow','狼牙猎弓',46,'none',1.1,[1,4],[3,4],[802],'直接命中施加流血的双手猎弓，为动物嗅血与蚀命提供伤口。',125),
]
for index,(model,name,template,catalyst,mult,attrs,values,on_hit,description,price) in enumerate(weapons,8001):
    asset=f'Assets/DynamicAsset/ProfessionArsenal20261025/Models/Profession_{model}.fbx'
    put('EquipmentAssetTable',dict(id=index,name='Profession_'+model,modelPath=asset,prefabPath=f'Assets/DynamicAsset/ProfessionArsenal20261025/Weapons/Weapon_{index}.prefab'))
    item=copy.deepcopy(row('EquipmentItemTable',template));item.update(id=index,name=name,assetId=index,iconPath=f'Assets/DynamicAsset/ProfessionArsenal20261025/Icons/Item_{index}.png',iconMode='model')
    if index in [8003,8004]:item.update(width=2,height=3)
    if index in [8008,8010]:item.update(width=1,height=2)
    put('EquipmentItemTable',item)
    w=copy.deepcopy(row('EquipmentWeaponTable',template));w.update(id=index,socketIds=[],skillIds=[6] if template==1 else [10] if template==40 else [2],level=2,damageMultiplier=mult,requirementId=index,gripId=index,catalystKind=catalyst,onHitEffectIds=on_hit,description=description)
    put('EquipmentWeaponTable',w)
    requirement=copy.deepcopy(row('EquipmentRequirementTable',46));requirement.update(id=index,attributeIds=attrs,values=values);put('EquipmentRequirementTable',requirement)
    grip=copy.deepcopy(row('EquipmentGripTable',row('EquipmentWeaponTable',template)['gripId']));grip.update(id=index,name=name+'握点')
    if template==40:grip.update(mainPosition=[0,0,0],offPosition=[0,0,0])
    put('EquipmentGripTable',grip)
    for adjustment in list(table('EquipmentHoldAdjustmentTable')['rows']):
        if adjustment['weaponId']==template:
            a=copy.deepcopy(adjustment);a.update(id=index*10+adjustment['moduleId'],weaponId=index);put('EquipmentHoldAdjustmentTable',a)
    put('ShopEntryTable',dict(id=index,templateId=1,itemId=index,chance=100,minCount=1,maxCount=1,price=price))
    put('WorldTradePriceTable',dict(id=index,itemId=index,price=price))

for iid,name,price in [(8013,'水剂',3),(8014,'毒剂',6),(8015,'腐蚀剂',8),(8016,'爆破剂',10),(8017,'净咒药剂',20)]:
    item=copy.deepcopy(row('EquipmentItemTable',92));item.update(id=iid,name=name,kind='material');put('EquipmentItemTable',item)
    put('WorldTradePriceTable',dict(id=iid,itemId=iid,price=price))
    put('ShopEntryTable',dict(id=iid,templateId=1,itemId=iid,chance=100,minCount=3,maxCount=6,price=price))

put('ProfessionCurseTable',dict(id=8008,itemId=8008,triggerBuffId=12020,applyEffectId=20020,cleanseItemId=8017,description='未净化的血契仪刀首次装备时，持有者获得持久血契诅咒，力量降低 2。',clue='先用识咒识别该武器，再携带一份净咒药剂使用识咒净化；净化记录属于该武器实例。'))
put('CombatEncounterTable',dict(id=1801,name='公会礼式决斗',radius=4,obstacleChance=0,enemyIds=[4],maxRounds=20,rewardCoins=0,rewardTraitIds=[],experience=0,appearancePoolId=1))
put('ProfessionDuelTable',dict(id=1,facilityKind='guild',encounterId=1801,minimumHealthPercent=25,rewardCoins=30,lossCoins=15,description='双方自愿单挑，任一方生命降至四分之一时认输；保留伤势，每城每日一次，不生成战利品。'))

for name,t in tables.items():
    paths[name].parent.mkdir(parents=True,exist_ok=True)
    paths[name].write_text(json.dumps(t,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
manifest_path=Path(__file__).with_name('content_manifest.json')
manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
manifest.update(configurationStatus='source rows written; awaiting runtime and root export', combatRows=table('ProfessionCombatTable')['rows'], statusRows=table('ProfessionStatusTable')['rows'], sourceTableNames=sorted(tables), activeSkillIds=[s['id'] for s in new_skills])
manifest['buffs']['preparation_guard']=12022
manifest['passiveTriggers']['1855']='scent_blood'
manifest['beastRows']=table('ProfessionBeastTable')['rows']
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(dict(sourceTables=len(tables),activeSkills=len(new_skills),newProfessions=6,passives=6,weapons=12,materials=5),ensure_ascii=False))
