import json,re
from pathlib import Path
root=Path(__file__).parent
rows=json.loads((root/'manifest.json').read_text(encoding='utf8'))
notes={
'HearthLoaf':'宽拱面包与三道切口清楚|侧面厚度收束、落地底部完整|背面保持连贯硬壳',
'RedOrchardApple':'果梗叶片区别于球形石块|叶片有厚度、果梗连接果面|叶梗连接正常，无漏面',
'WaxCheese':'蜡皮厚度与轮形明确|缺角露出浅色切面|背面完整，无破洞',
'SmokedTrout':'头尾、鱼鳍和眼点可分辨|鱼身扁厚、鳍有实体厚度|两侧眼与尾部对应，无单面消失',
'RoastLeg':'肉块和骨柄比例可读|骨节连接肉端，未悬浮|骨头从肉体自然伸出',
'MooncapSkewer':'菌帽与烤肉交替排列|木签穿过食材是合理装配|背面维持完整菌柄与肉块',
'RootHarvest':'根尖高低不同|长锥根形与叶束可辨|叶片有背面厚度',
'HoneyTart':'卷边壳围住馅料|饼底厚度完整|莓果排列清楚，底边闭合',
'WayfarerRation':'双束带和浅色布面可辨|面饼部分收在包口|背面布块为粗块面风格，无洞',
'ClayStew':'双耳厚口碗剪影明确|把手和碗壁相接|耳柄两侧一致，汤面在碗内',
'LinenBandage':'外沿线密度克制|松布尾接触卷底|背面闭合；斜视卷芯孔已修出',
'MossPoultice':'扁布包带叶标|修后布带随包体弯曲，去除两块硬板|束带包住物体，有合理厚度',
'BoneSplint':'双木片与三布带区分|窄长木片厚度正常|横带连贯，保留夹板开放结构',
'LeechJar':'通气盖与双蛭纹可见|颈圈贴合罐体|完整低腹轮廓，盖面无错位',
'SurgeonSatchel':'铜扣与皮包开口清楚|后盖厚度明确|骨针和小瓶已有实体模型，不再只用方杆表示',
'EmberHeart':'铜火印贴于瓶腹|修后印片不悬空|背面瓶肩收颈完整',
'TideMemory':'双铜耳与细瓶颈区分|瓶耳连接宽腹|背面保留简单瓶形',
'SporeMercy':'六角瓶和菌盖突出|标签厚度与瓶面贴合|菌盖与木塞连续',
'VioletVigil':'细高瓶与晶印清楚|两道瓶箍不刺穿外形|瓶肩收束、背面无多余细节',
'AshAntidote':'三足和斜带区别瓶型|末次修正将断续带改为沿表面的连续曲线|脚点分布稳定，后面瓶体完整',
'VeteranCuirass':'补片、刻痕与三甲叶体现老兵背景|改为弧面壳，甲叶分段贴合，头臂腰开口保留|背板和两道腰带有厚度',
'DrakeScaleVest':'五枚重叠龙鳞可辨|鳞片沿胸壳弯折，短宽比例有别于其他甲|皮质背板简洁，颈臂开口保留',
'MarshWarden':'窄长甲、铜条和领圈区分|领圈连至肩带，活动空间保留|末次修正后三枚背环完整露出，不再被背板吞没',
'AbbeyReliquary':'宽肩、象牙护板和中央圣匣可辨|肩甲有厚度，与主体肩部连接|完整护背和肩廓，未见翻面',
'BlackBriarHarness':'深色肋板与短荆棘符合背景|短刺向后而非横向刺入邻位|深铁背壳有体积，仍需角色实装验证',
'DrakeOath':'双首围住红石，指孔清晰|冠部接在指圈顶部|左右头部虽简化但不与指孔相交',
'CrescentPilgrim':'月牙式镂空清晰|修后加内收镶爪，宝石有真实支撑|指圈和两侧支臂连续',
'WaxSealSignet':'方形印面与红蜡色区可辨|宽肩连接戒台|环带孔洞完整，未封成圆盘',
'SunkenSun':'六道日芒与圆主石不同于其他戒|日盘接触指圈上沿|短芒不伸入主要指孔空间',
'ThornWidow':'黑枝和紫石形成尖形冠部|修后两枝镶爪触及宝石|枝隙与指孔均保持开放',
'HearthSigil':'六角底与火纹有对比|刻符是有厚度的嵌条|背面为完整石块',
'TideKnot':'椭圆轮廓与交错纹区别其他符石|银条贴在石面|背面完整、硬边一致',
'RootPact':'木印不规则外缘与分叉根纹|纹线附着表面|木片厚度可读',
'FrostTooth':'弯牙轮廓与冰纹可辨|牙片保留厚度|背面弯折轮廓连续',
'StarAsh':'厚星形与菱纹区别其余符石|晶点连接面板|背面星角有厚度，暗色对比偏低但可辨'
}
review=[]
for r in rows:
    front,side,back=notes[r['slug']].split('|')
    evidence=[str(Path('Previews')/(r['name']+'_'+v+'.png')) for v in ['front','side','back','hero']]
    assert all((root/p).exists() for p in evidence)
    review.append(dict(name=r['name'],title=r['title'],front=front,side=side,back=back,
                       result='通过本批静态低多边形资产目视审核；穿戴/插槽未接入',reviewer='primary agent; viewed actual images',evidence=evidence))
    r['review_status']='front_side_back_hero_reviewed_after_corrections'
    r['lore_han_characters']=len(re.findall('[\u4e00-\u9fff]',r['lore']))
(root/'manifest.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf8')
(root/'review.json').write_text(json.dumps(review,ensure_ascii=False,indent=2),encoding='utf8')
print('35 item visual reviews archived')
