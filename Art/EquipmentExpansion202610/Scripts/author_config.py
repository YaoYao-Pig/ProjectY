"""Author the 30-attachment expansion from its reviewed Blender manifest. Does not export or touch Unity."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
manifest=json.loads((ROOT/'Art/EquipmentExpansion202610/manifest.json').read_text(encoding='utf-8'))
assets=manifest['assets']
assert len(assets)==30 and {r['id'] for r in assets}==set(range(501,531))
def table(name):
    p=next((ROOT/'Config/Tables').rglob(name+'.json'))
    return p,json.loads(p.read_text(encoding='utf-8'))
def append(name,rows):
    p,d=table(name);index={r['id']:r for r in d['rows']}
    for row in rows:
        if row['id'] in index:
            assert index[row['id']]==row, f"Content ID collision in {name}: {row['id']}"
        else:d['rows'].append(row)
    p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
items=[];models=[];runes=[];shop=[]
_,runeTable=table('EquipmentRuneTable');fields=[f['name'] for f in runeTable['fields']]
for a in assets:
    items.append(dict(id=a['id'],name=a['name'],kind='module' if a['slotKind']=='thruster' else 'rune',assetId=a['assetId'],
        iconPath=f"Assets/DynamicAsset/EquipmentExpansion202610/Icons/Item_{a['id']}.png",width=a['inventoryWidth'],height=a['inventoryHeight'],
        iconMode='model',iconRotation=[8,22,-10],iconPadding=1.18))
    models.append(dict(id=a['assetId'],name=a['model'],modelPath=a['unityFbx'],prefabPath=a['unityFbx']))
    runes.append({field:a[field] for field in fields})
    shop.append(dict(id=a['id'],templateId=1,itemId=a['id'],chance=18 if a['slotKind']=='catalyst' else 25,minCount=1,maxCount=1,price=a['value']))
append('EquipmentAssetTable',models);append('EquipmentItemTable',items);append('EquipmentRuneTable',runes);append('ShopEntryTable',shop)
p,d=table('EquipmentSocketTable')
for row in d['rows']:
    row['name']={'head':'杖头组件','shaft':'杖身组件','thruster':'剑脊 · 机械组件','catalyst':'剑脊 · 奥术触媒'}.get(row['kind'],row['name'])
p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Authored 30 items/models/attachments and 30 shop entries; existing source rows retained.')
