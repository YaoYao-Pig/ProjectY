"""登记共用棋子部件和已确定的三种模板；表源由工程导出器统一导出。"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
folder = ROOT / 'Config/Tables/Adventure'
models = json.loads((ROOT / 'Art/PawnLowPoly/Integration/pawn-models.json').read_text(encoding='utf-8'))
names = ['人类身体', '圆形棋子底座', '板甲', '皮甲', '法袍', '头盔', '兜帽', '法师帽', '长剑', '法杖', '长弓', '盾牌', '披风', '箭袋']

def write(name, description, fields, rows):
    path = folder / (name + '.json')
    if path.exists():
        raise RuntimeError('拒绝覆盖已存在的表源：' + str(path))
    path.write_text(json.dumps(dict(version=1, name=name, description=description, key='id', fields=fields, rows=rows), ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

write('PawnPartTable', 'LowPoly 棋子的独立部件；资源原点对齐对应插槽，尺寸固定，不随地格放大。', [
    dict(name='id', type='int', description='稳定部件 ID', min=1),
    dict(name='name', type='text', description='部件名称'),
    dict(name='slot', type='enum', description='棋子挂点；同一外观每个挂点只能有一个部件', values=['body','base','mainHand','offHand','head','chest','back']),
    dict(name='prefabPath', type='string', description='Unity 部件资源路径；通过 Editor 绑定实际引用')
], [dict(id=i+1, name=names[i], slot=m['slot'], prefabPath='Assets/DynamicAsset/PawnLowPoly/Models/'+m['name']+'.fbx') for i,m in enumerate(models)])
write('PawnTemplateTable', '角色模板对应的初始棋子外观；装备与身体独立，为之后实际装备显示提供组合入口。', [
    dict(name='id', type='int', description='稳定外观模板 ID', min=1),
    dict(name='name', type='text', description='模板名称'),
    dict(name='unitId', type='int', description='角色模板 ID；每个角色模板只能对应一个初始外观', ref='CombatUnitTable'),
    dict(name='partIds', type='int[]', description='部件组合；必须包含身体和底座，其余插槽可不装备', ref='PawnPartTable')
], [
    dict(id=1,name='剑盾卫士',unitId=1,partIds=[1,2,3,6,9,12,13]),
    dict(id=2,name='游侠弓手',unitId=2,partIds=[1,2,4,7,11,14]),
    dict(id=3,name='法师',unitId=3,partIds=[1,2,5,8,10,13])
])
area = ROOT / 'Config/Tables/MapArea/MapAreaTable.json'
table = json.loads(area.read_text(encoding='utf-8'))
for row in table['rows']:
    row['hexRadius'] = 1.5
area.write_text(json.dumps(table, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print('已写入两张棋子表源，并将 MapArea 半径设为 1.5。')
