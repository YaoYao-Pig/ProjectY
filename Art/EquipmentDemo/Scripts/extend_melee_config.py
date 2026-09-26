"""Author the melee demo rows; export through the existing ConfigEditor afterward."""
import json,copy
from pathlib import Path
root=Path('D:/Program/Unity/Project Y/Config/Tables')
def read(name,folder='Equipment'):return json.loads((root/folder/(name+'.json')).read_text(encoding='utf-8'))
def save(t,folder='Equipment'):(root/folder/(t['name']+'.json')).write_text(json.dumps(t,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def field(name,type,description,**kw):return dict(name=name,type=type,description=description,**kw)
def addfield(t,f,default):
    assert not any(x['name']==f['name'] for x in t['fields']);t['fields'].append(f)
    for r in t['rows']:r[f['name']]=copy.deepcopy(default)
def table(name,description,fields,rows):return dict(version=1,name=name,description=description,key='id',fields=fields,rows=rows)
save(table('EquipmentCategoryTable','武器种类；每类包含独立武器和装备等级。',[field('id','int','种类 ID',min=1),field('name','text','种类名称')],[dict(id=i,name=n) for i,n in enumerate(['法杖','步枪','单手剑','双手大剑','双手巨剑'],1)]))
save(table('EquipmentAttributeTable','装备要求引用战斗真实属性；显示名在表中定义。',[field('id','int','属性 ID',min=1),field('code','string','CombatStats 属性名'),field('name','text','属性名称')],[dict(id=i,code=k,name=n) for i,(k,n) in enumerate([('strength','力量'),('endurance','耐力'),('intellect','智力'),('speed','速度')],1)]))
req_fields=[field('id','int','需求规则 ID',min=1),field('attributeIds','int[]','需要的属性',ref='EquipmentAttributeTable'),field('values','int[]','对应最低属性值'),field('damageLossPerPoint','float','每个不足点的伤害倍率扣减',min=0,max=1),field('minimumDamageScale','float','最低伤害比例',min=.01,max=1),field('hitLossPerPoint','int','每个不足点扣减命中百分点',min=0),field('maximumHitLoss','int','最高命中惩罚',min=0,max=100)]
requirements=[]
def req(id,ids,values):requirements.append(dict(id=id,attributeIds=ids,values=values,damageLossPerPoint=.08,minimumDamageScale=.35,hitLossPerPoint=3,maximumHitLoss=40))
req(1,[3],[2]);req(2,[1,4],[4,4])
items=read('EquipmentItemTable');weapons=read('EquipmentWeaponTable');assets=read('EquipmentAssetTable');sockets=read('EquipmentSocketTable');runes=read('EquipmentRuneTable')
next(f for f in weapons['fields'] if f['name']=='kind')['values'].append('melee')
addfield(weapons,field('categoryId','int','武器种类',ref='EquipmentCategoryTable'),1)
addfield(weapons,field('level','int','装备等级（不是角色等级门槛）',min=1),1)
addfield(weapons,field('damageMultiplier','float','此武器授予攻击的伤害倍率',min=.01,max=10),1)
addfield(weapons,field('requirementId','int','不足仍可装备，按规则削弱授予技能',ref='EquipmentRequirementTable'),1)
weapons['rows'][1]['categoryId']=2;weapons['rows'][1]['requirementId']=2
addfield(sockets,field('calloutSide','enum','3D 工坊标签的外侧停靠列',values=['left','right']),'right')
sockets['rows'][1]['calloutSide']='left'
next(f for f in sockets['fields'] if f['name']=='kind')['values'].append('thruster')
next(f for f in items['fields'] if f['name']=='kind')['values'].append('module')
next(f for f in runes['fields'] if f['name']=='slotKind')['values'].append('thruster')
next(f for f in runes['fields'] if f['name']=='skillGroup')['values'].append('slash')
runes['description']='可拆改装组件：符文与机械组件通过挂点和技能组限定效果。'
definitions=[
 (40,'民兵铁剑','SwordIron',3,1,1.0,[1],[4],3,10,[]),
 (41,'骑士精钢剑','SwordKnight',3,2,1.3,[1],[6],3,10,[]),
 (42,'佣兵大剑','GreatswordMercenary',4,1,1.2,[1,2],[6,4],4,11,[]),
 (43,'王卫大剑','GreatswordRoyal',4,2,1.55,[1,2],[9,6],4,11,[]),
 (44,'破城巨剑','ColossalSiege',5,1,1.65,[1,2],[10,6],5,12,[4]),
 (45,'黑曜重型巨剑','ColossalObsidian',5,2,2.1,[1,2],[14,8],5,12,[5])]
for index,(id,name,model,category,level,mult,attrs,values,pose,skill,slots) in enumerate(definitions,13):
    items['rows'].append(dict(id=id,name=name,kind='weapon',assetId=index,iconPath=''))
    modelPath='Assets/DynamicAsset/EquipmentDemo/Models/Equip_'+model+'.fbx'
    assets['rows'].append(dict(id=index,name=model,modelPath=modelPath,prefabPath='Assets/DynamicAsset/EquipmentDemo/Weapons/'+model+'.prefab'))
    weapons['rows'].append(dict(id=id,kind='melee',socketIds=slots,skillIds=[skill],replacesSkillIds=[1,2,3],poseId=pose,magazineItemId=0,previewRotation=[4,-12,-20],previewZoom=1.45 if category==5 else 1.15,categoryId=category,level=level,damageMultiplier=mult,requirementId=id))
    req(id,attrs,values)
    if slots:sockets['rows'].append(dict(id=slots[0],name='剑脊 · 推进器',weaponItemId=id,kind='thruster',position=[0,.50,-.09],rotation=[0,0,0],calloutSide='right'))
items['rows'].append(dict(id=13,name='劈砍助推器',kind='module',assetId=19,iconPath=''))
assets['rows'].append(dict(id=19,name='Thruster',modelPath='Assets/DynamicAsset/EquipmentDemo/Models/Equip_Thruster.fbx',prefabPath='Assets/DynamicAsset/EquipmentDemo/Models/Equip_Thruster.fbx'))
runes['rows'].append(dict(id=13,slotKind='thruster',skillGroup='slash',description='双手巨剑专用机械组件：劈砍伤害提高 35%，不额外消耗 AP；属性不足惩罚仍然生效。',damageMultiplier=1.35,rangeBonus=0,hitBonus=0,cooldownBonus=0,maxTargets=1,splashRadius=0))
save(table('EquipmentRequirementTable','软门槛：对该武器授予的技能生效，缺口加总；装备命令不拒绝不足属性。',req_fields,requirements))
for t in [items,weapons,assets,sockets,runes]:save(t)
poses=read('EquipmentPoseTable');addfield(poses,field('offHandFollowsWeapon','bool','副手是否跟随武器旋转，适用于双手持握'),False);poses['rows'][1]['offHandFollowsWeapon']=True
for id,name,main,off,rot,elbowA,elbowB in [
 (3,'单手持 · 剑',[-.46,.94,.30],[.47,.98,.18],[10,0,-18],[-.48,1.12,.12],[.44,1.09,.02]),
 (4,'双手持 · 大剑',[-.07,1.07,.42],[.01,.92,.43],[5,0,-6],[-.35,1.08,.19],[.34,.98,.19]),
 (5,'双手持 · 巨剑',[-.06,1.03,.47],[.015,.84,.49],[9,0,-12],[-.38,1.09,.19],[.37,.94,.23])]:
    p=copy.deepcopy(poses['rows'][0]);p.update(id=id,name=name,mainHand=main,offHand=off,mainElbow=elbowA,offElbow=elbowB,weaponRotation=rot,offHandFollowsWeapon=id!=3);poses['rows'].append(p)
save(poses)
actions=read('EquipmentActionTable');next(f for f in actions['fields'] if f['name']=='kind')['values'].append('slash')
addfield(actions,field('yaw','float','动作水平旋转幅度'),0);addfield(actions,field('roll','float','动作侧倾幅度'),0)
for id,name,duration,pitch,yaw,roll in [(4,'单手斜斩',.5,85,18,-30),(5,'双手重劈',.75,105,0,-8),(6,'巨剑劈砍',.95,115,-5,-5)]:
    actions['rows'].append(dict(id=id,name=name,kind='slash',duration=duration,recoil=0,pitch=pitch,handLift=.12,magazineDrop=0,yaw=yaw,roll=roll))
save(actions)
skills=read('CombatSkillTable','Adventure');next(f for f in skills['fields'] if f['name']=='skillGroup')['values'].append('slash')
effects=read('CombatEffectTable','Adventure');icons=read('BattleIconTable','Adventure')
for id,name,cost,hit,cd,proficiency,action,effectId,formula in [
 (10,'单手斩击',2,95,0,'sword',4,9,'max(1,floor(5+strength+proficiency/2-defense-guard))'),
 (11,'大剑重劈',3,90,0,'greatsword',5,10,'max(1,floor(8+strength*1.2+proficiency/2-defense-guard))'),
 (12,'巨刃劈砍',3,85,1,'greatsword',6,11,'max(1,floor(10+strength*1.5+proficiency/2-defense-guard))')]:
    s=copy.deepcopy(next(r for r in skills['rows'] if r['id']==6));s.update(id=id,name=name,description='使用当前装备的近战武器劈砍相邻敌人；装备等级、属性需求和组件共同决定实际效果。',cost=cost,range=1,proficiency=proficiency,effectIds=[effectId],iconId=id+4,skillGroup='slash',cooldownTurns=cd,hitChance=hit,actionTemplate=action);skills['rows'].append(s)
    e=copy.deepcopy(next(r for r in effects['rows'] if r['id']==7));e.update(id=effectId,amount=formula);effects['rows'].append(e)
    icon=copy.deepcopy(icons['rows'][0]);icon.update(id=id+4,name=name,spritePath='');icons['rows'].append(icon)
for t in [skills,effects,icons]:save(t,'Adventure')
demo=read('EquipmentDemoTable');demo['rows'][0]['starterItemIds']+=list(range(40,46));demo['rows'][0]['starterCounts']+=[1]*6;save(demo)
loot=read('EquipmentLootTable');loot['rows'][0]['itemIds'].append(13);loot['rows'][0]['counts'].append(1);save(loot)
print('Authored six melee weapons, three categories, attribute requirements, a thruster and slash skills.')
