"""Add physical container definitions without replacing existing loot/config rows."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(name):
    path = ROOT / 'Config/Tables' / (name + '.json')
    return path, json.loads(path.read_text(encoding='utf-8-sig'))


def save(path, table):
    path.write_text(json.dumps(table, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def fields(table, additions):
    for field in additions:
        old = next((row for row in table['fields'] if row['name'] == field['name']), None)
        if old is None:
            table['fields'].append(field)


def field(name, kind, description, default, **extra):
    return dict(name=name, type=kind, description=description, default=default, **extra)


def upsert(table, row):
    old = next((value for value in table['rows'] if value['id'] == row['id']), None)
    if old is None:
        table['rows'].append(row)
    else:
        assert old['name'] == row['name'], ('Container config ID collision', row['id'])
        old.update(row)


def main():
    path, table = read('Equipment/EquipmentLootTable')
    table['description'] = '容器表现、交互、耐久与默认掉落池；打开、破坏和取空独立记录。'
    fields(table, [
        field('interaction', 'enum', '打开、搜刮、必须打碎或装备工具后开启', 'open', values=['open', 'search', 'break', 'tool']),
        field('toolTag', 'string', 'tool 交互所需的已装备工具标签，其他方式为空', ''),
        field('interactionRounds', 'int', '首次工具开启消耗的探索回合', 0, min=0),
        field('maxDurability', 'int', '最大耐久；0 为不可破坏', 0, min=0),
        field('structuralDefense', 'int', '结构防御，代入技能伤害公式的 defense', 0, min=0),
        field('blocksMovement', 'bool', '完整/开启容器占地阻挡；破坏后清除', False),
        field('blocksSight', 'bool', '完整容器是否阻挡视线', False),
        field('brokenAssetId', 'int', '破坏后残骸模型，0 为不保留残骸', 0, min=0),
        field('emptyAssetId', 'int', '取空后模型，0 沿用开启模型', 0, min=0),
        field('modelScale', 'float', '模型等比缩放', 1, min=0.01),
        field('displayContents', 'enum', '开放式容器上显示剩余真实物品', 'none', values=['none','rack','surface']),
        field('displayHeight', 'float', '开放式容器物品显示高度（模型局部米）', 0.9, min=0),
        field('displayItemScale', 'float', '开放式容器展示物品的模型缩放', 0.6, min=0.01),
        field('footprintQ', 'int[]', '占地轴向 q，首项为锚点 0', [0]),
        field('footprintR', 'int[]', '占地轴向 r，与 q 成对', [0]),
    ])
    # Existing chest definitions retain their model/contents; become valid attack targets.
    for row in table['rows']:
        if row['kind'] == 'chest':
            row.setdefault('maxDurability', 45)
    definitions = [
        (200, '陶罐', 200, 'break', 12, 2, ''),
        (201, '木箱', 201, 'open', 30, 1, ''),
        (202, '板条箱', 202, 'tool', 40, 1, 'crowbar'),
        (203, '宝箱', 7, 'open', 60, 1, ''),
        (204, '首领奖励宝箱', 7, 'open', 100, 5, ''),
        (205, '中世纪武器架', 205, 'search', 45, 6, ''),
        (206, '补给桌', 206, 'search', 40, 2, ''),
        (207, '上锁宝箱', 7, 'tool', 65, 1, 'crowbar'),
    ]
    for ident, name, asset, interaction, hp, pool, tag in definitions:
        upsert(table, dict(id=ident, name=name, kind='chest', assetId=asset,
                          openedAssetId=8 if asset == 7 else asset,
                          itemIds=[], counts=[], poolId=pool, interaction=interaction,
                          toolTag=tag, interactionRounds=1 if interaction=='tool' else 0, maxDurability=hp, structuralDefense=0,
                          blocksMovement=True, blocksSight=False,
                          brokenAssetId=0, emptyAssetId=0, modelScale=3 if ident==200 else 1,
                          displayContents='rack' if ident==205 else 'surface' if ident==206 else 'none',
                          displayHeight=0.9, displayItemScale=0.6,
                          footprintQ=[0, 1] if ident==206 else [0],
                          footprintR=[0, 0] if ident==206 else [0]))
    save(path, table)

    path, table = read('Equipment/EquipmentAssetTable')
    assets = [
        (200, '容器陶罐', 'Assets/DynamicAsset/AssetExpansion202610/ShipwreckProps/Prefabs/SWP_SpiceJar.prefab'),
        (201, '容器木箱', 'Assets/DynamicAsset/MapLowPoly/Models/Dungeon_CrateStack.fbx'),
        (202, '容器板条箱', 'Assets/DynamicAsset/AssetExpansion202610/Shipwreck/Prefabs/SW_Cargo_SaltCrates.prefab'),
        (205, '容器武器架', 'Assets/DynamicAsset/AssetExpansion202610/ShipwreckV2/Prefabs/S2_WeaponRack.prefab'),
        (206, '容器补给桌', 'Assets/DynamicAsset/AssetExpansion202610/ShipwreckV2/Prefabs/S2_MessTable.prefab'),
    ]
    for ident, name, asset in assets:
        assert (ROOT / asset).exists(), asset
        upsert(table, dict(id=ident, name=name, modelPath=asset, prefabPath=asset))
    save(path, table)

    path, table = read('Loot/LootPoolTable')
    fields(table, [field('mode', 'enum', '逐项独立概率，或按权重抽取固定次数', 'independent', values=['independent', 'weighted']),
                   field('drawCount', 'int', 'weighted 模式抽取次数；允许重复，同物品合并', 1, min=1)])
    upsert(table, dict(id=5, name='首领奖励武器', seedSalt=719, mode='weighted', drawCount=2))
    upsert(table, dict(id=6, name='武器架', seedSalt=811, mode='weighted', drawCount=1))
    save(path, table)
    path, table = read('Loot/LootEntryTable')
    fields(table, [field('weight', 'int', 'weighted 池中的相对权重；0 不参与抽取', 1, min=0)])
    for ident, pool, item, weight in [(200, 5, 40, 3), (201, 5, 46, 2), (202, 6, 40, 3), (203, 6, 46, 2)]:
        if not any(row['id']==ident for row in table['rows']):
            table['rows'].append(dict(id=ident, poolId=pool, itemId=item, chance=100, minCount=1, maxCount=1, weight=weight))
    save(path, table)

    path, table = read('Loot/MapAreaChestRuleTable')
    table['description'] = '地图生成期容器计划；生成概率按每条规则判定，数量在命中后抽取。'
    next(f for f in table['fields'] if f['name']=='strategy')['values'] = ['reachable', 'rooms', 'wall', 'goal', 'fixed', 'props']
    fields(table, [
        field('spawnChance', 'float', '整张小地图每条规则独立出现概率（百分比）', 100, min=0, max=100),
        field('poolOverrideId', 'int', '覆盖容器默认掉落池；0 使用默认', 0, min=0),
        field('roomStyleId', 'int', '限定房间样式；0 不限', 0, min=0),
        field('districtId', 'int', '限定功能分区；0 不限', 0, min=0),
        field('presetId', 'int', '限定预设房间；0 不限', 0, min=0),
        field('propId', 'int', 'props 策略匹配 MapAreaPropTable，将陈设关联为同一容器', 0, min=0),
        field('q', 'int', 'fixed 策略锚点 q', 0), field('r', 'int', 'fixed 策略锚点 r', 0),
        field('rotation', 'int', '六向旋转；-1 随机', -1, min=-1, max=5),
        field('unlockEncounterId', 'int', '本地点敌群实例 ID；清除后允许打开和破坏，0 无条件', 0, min=0),
    ])
    rules = [(200,1,200,'wall',3,5,100), (201,1,201,'rooms',1,2,100),
             (202,1,202,'wall',1,2,80), (204,1,204,'goal',1,1,100),
             (205,1,205,'wall',1,1,100), (206,1,206,'rooms',1,1,100),
             (220,20,200,'rooms',2,3,80), (221,20,201,'rooms',1,2,80),
             (240,40,202,'rooms',1,2,100)]
    for ident, area, container, strategy, minimum, maximum, chance in rules:
        if not any(row['id']==ident for row in table['rows']):
            table['rows'].append(dict(id=ident, areaId=area, lootTableId=container, strategy=strategy,
                                     minCount=minimum, maxCount=maximum, minDistance=8, maxDistance=1000,
                                     spacing=2, seedSalt=ident*719, layer=-1, spawnChance=chance,
                                     unlockEncounterId=1 if ident==204 else 0))
    obstacle_path, obstacles = read('MapArea/MapAreaObstacleTable')
    for obstacle in obstacles['rows']:
        if obstacle['toolTag'] in ('axe', 'crowbar') and obstacle['count']>0:
            ident=800+obstacle['id']
            if not any(row['id']==ident for row in table['rows']):
                table['rows'].append(dict(id=ident, areaId=obstacle['areaId'], lootTableId=201 if obstacle['toolTag']=='axe' else 207,
                                         strategy='rooms', minCount=obstacle['count'], maxCount=obstacle['count'],
                                         minDistance=obstacle['minDistance'], maxDistance=1000, spacing=obstacle['spacing'],
                                         seedSalt=obstacle['seedSalt'], layer=-1, spawnChance=100))
            obstacle['count']=0
    save(obstacle_path, obstacles)
    save(path, table)

    path, table = read('Adventure/CombatSkillTable')
    fields(table, [field('affectsContainers', 'bool', '允许即时伤害作用于可破坏容器，含范围技能波及', False)])
    # Movement/riding abilities keep their own actor/landing contract.
    for row in table['rows']:
        if row['target']=='enemy' and row['id']<200:
            row['affectsContainers']=True
            if 'life' not in row['contexts']:
                row['contexts'].append('life')
    save(path, table)


if __name__ == '__main__':
    main()
