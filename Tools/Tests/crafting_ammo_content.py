"""Check real crafting/ammunition source content without exporting or starting Unity."""
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def table(relative):
    document = json.loads((ROOT / 'Config/Tables' / relative).read_text(encoding='utf-8'))
    rows = {row[document['key']]: row for row in document['rows']}
    assert len(rows) == len(document['rows']), f'Duplicate keys in {relative}'
    return document, rows


item_doc, items = table('Equipment/EquipmentItemTable.json')
ammo_doc, ammo = table('Equipment/EquipmentAmmoTable.json')
_, magazines = table('Equipment/EquipmentMagazineTable.json')
weapon_doc, weapons = table('Equipment/EquipmentWeaponTable.json')
_, recipes = table('Camp/CampRecipeTable.json')
_, facilities = table('Camp/CampFacilityTable.json')
_, upgrades = table('Camp/CampUpgradeTable.json')
_, entries = table('Loot/LootEntryTable.json')
_, pools = table('Loot/LootPoolTable.json')
_, containers = table('Equipment/EquipmentLootTable.json')
_, shops = table('Shop/ShopEntryTable.json')
_, trade_prices = table('Travel/WorldTradePriceTable.json')
skill_doc, skills = table('Adventure/CombatSkillTable.json')

assert next(field for field in item_doc['fields'] if field['name'] == 'name')['type'] == 'text'
for name in ('name', 'description'):
    assert next(field for field in ammo_doc['fields'] if field['name'] == name)['type'] == 'text'
assert not any(field['name'] in ('level', 'tier') for field in ammo_doc['fields']), 'Ammo categories must not introduce levels'

expected_calibers = {1: (31, 822, 823), 2: (820, 824, 825), 3: (821, 826, 827)}
assert set(ammo) == {item for group in expected_calibers.values() for item in group}
for caliber, ids in expected_calibers.items():
    balanced, piercing, flesh = (ammo[item] for item in ids)
    assert [row['ammoType'] for row in (balanced, piercing, flesh)] == ['balanced', 'armor_piercing', 'flesh']
    assert all(row['caliberId'] == caliber for row in (balanced, piercing, flesh))
    assert piercing['armorDamageMultiplier'] > balanced['armorDamageMultiplier'] > flesh['armorDamageMultiplier'] >= 0
    assert flesh['fleshDamageMultiplier'] > balanced['fleshDamageMultiplier'] > piercing['fleshDamageMultiplier'] >= 0
    assert piercing['armorPenetrationBonus'] > balanced['armorPenetrationBonus'] == 0 > flesh['armorPenetrationBonus']
    for row in (balanced, piercing, flesh):
        item = items[row['id']]
        assert item['kind'] == 'ammo' and item['name'] == row['name'] and row['description']
        assert -100 <= row['armorPenetrationBonus'] <= 100
        assert item['iconPath'] == items[ids[0]]['iconPath'], 'Ammo variants must reuse the existing caliber icon'
        assert (ROOT / item['iconPath']).is_file(), f'Missing ammunition icon: {item["iconPath"]}'
        assert (item['width'], item['height'], item['assetId']) == (items[ids[0]]['width'], items[ids[0]]['height'], items[ids[0]]['assetId'])
    assert any(ammo[row['ammoItemId']]['caliberId'] == caliber for row in magazines.values()), 'A caliber has no compatible magazine'
for row in magazines.values():
    assert row['ammoItemId'] in ammo and items[row['id']]['kind'] == 'magazine'
assert {key: row['ammoItemId'] for key, row in magazines.items()} == {21: 31, 810: 31, 811: 820, 812: 821}, 'Legacy default ammunition IDs changed'
priced_items = {row['itemId']: row['price'] for row in trade_prices.values()}
assert all(priced_items.get(item, 0) > 0 for item in ammo), 'Every ammunition item needs a world-trade price before adventure initialization'
print('PASS three calibers, three complementary ammo types, reused assets and stable magazine defaults')

stack_kinds = {'material', 'ammo', 'consumable', 'rune', 'module'}
outputs = set()
materials = set()
configured_levels = {(row['facilityId'], row['level']) for row in upgrades.values()}
for recipe in recipes.values():
    assert recipe['facilityId'] in facilities and (recipe['facilityId'], recipe['requiredLevel']) in configured_levels
    assert recipe['minutes'] > 0 and recipe['coins'] >= 0
    for id_key, count_key, allowed in (('itemIds', 'itemCounts', stack_kinds), ('outputIds', 'outputCounts', stack_kinds | {'weapon', 'wearable'})):
        assert len(recipe[id_key]) == len(recipe[count_key]) and len(set(recipe[id_key])) == len(recipe[id_key])
        assert all(count > 0 for count in recipe[count_key])
        assert all(item in items and items[item]['kind'] in allowed for item in recipe[id_key])
    assert recipe['outputIds']
    outputs.update(recipe['outputIds'])
    materials.update(recipe['itemIds'])
assert {1, 2, 3, 4}.issubset(recipes), 'Original recipe IDs must survive'
for recipe_id, output in ((1, 31), (2, 93), (3, 91), (4, 92)):
    assert recipes[recipe_id]['outputIds'] == [output]
assert set(ammo).issubset(outputs), 'Every ammo variant must be craftable'
assert {40, 52, 70, 72, 73, 74, 94, 190, 91, 92}.issubset(outputs), 'Crafting must cover weapons, armor, tools and medicine'

active_pools = {row['poolId'] for row in containers.values() if row['poolId'] > 0}
available_loot = set()
for row in entries.values():
    assert row['itemId'] in items and row['poolId'] in pools
    assert 0 <= row['chance'] <= 100 and 0 < row['minCount'] <= row['maxCount']
    pool = pools[row['poolId']]
    if row['poolId'] in active_pools and row['chance'] > 0 and (pool.get('mode', 'independent') != 'weighted' or row.get('weight', 1) > 0):
        available_loot.add(row['itemId'])
assert set(ammo).issubset(available_loot), 'Every ammo variant needs an active loot route'
sources = available_loot | {row['itemId'] for row in shops.values()}
assert materials.issubset(sources | outputs), 'A recipe consumes an unavailable resource'
assert {81, 82, 83}.issubset(available_loot), 'Basic production resources must remain searchable'
print('PASS recipe references, original recipe continuity, all ammunition craft/loot routes and material availability')

for row in weapons.values():
    assert items[row['id']]['kind'] == 'weapon'
    assert 0 <= row['armorPenetration'] <= 100 and row['armorDamageMultiplier'] >= 0
for item, penetration in {2: 25, 802: 35, 804: 15, 46: 15, 40: 20, 42: 20, 44: 25, 70: 25, 742: 35, 1: 10, 72: 15}.items():
    assert weapons[item]['armorPenetration'] == penetration, f'Unexpected first-pass penetration for {item}'
assert weapons[44]['armorDamageMultiplier'] == weapons[70]['armorDamageMultiplier'] == 1.2
assert weapons[40]['armorDamageMultiplier'] == 1
print('PASS explicit weapon armor fields and representative category defaults')

preserve = next(field for field in skill_doc['fields'] if field['name'] == 'preserveArmor')
assert preserve['type'] == 'bool' and preserve['default'] is False
assert skills[502]['preserveArmor'] is True
assert all(row.get('preserveArmor', False) is False for key, row in skills.items() if key != 502)
print('PASS precision thrust explicitly preserves armor and other skills default to ordinary armor resolution')
