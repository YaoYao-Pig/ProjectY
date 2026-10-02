"""Persist actual human-readable observations after inspecting the rendered review sheets."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parent
NOTES={
'Urn_TallKeeper':['长身、窄颈、封盖比例明确；修后铜箍连续，不再露出三角切口。','轮廓对称，底座接地，颈与盖衔接完整。','背面封闭完整，三道铜箍与前面一致。'],
'Amphora_TwinHandle':['双耳轮廓完整，手把两端接入肩颈，口沿厚度明确。','侧面可辨手把厚度，底部陶环已改为贴合斜腹。','双耳后侧无缺面，瓶身封闭且内口保留。'],
'Jar_SquatMoss':['矮腹青釉与长罐区别明确，小耳位置均衡。','短颈和腹部连接自然，修后底部装饰环无锯齿。','背面口沿及厚壁正常，材质安静。'],
'Pot_ThreeLegCook':['三足支撑与金属锅身可辨，两个锅耳没有漂浮。','侧面第三支脚可见，锅底离地符合烹煮功能。','后脚落地、环口和内壁完整；斜俯视能看见实心锅底。'],
'Urn_HexReliquary':['六棱石匣与陶器有明显剪影差，三道金属束带整齐。','侧棱硬边清楚，盖有厚度且与匣口重叠支撑。','背面构造闭合，未见缺面或错位。'],
'Urn_BrokenOpen':['破口不对称有意为之，底旁碎片全部接地。','断面保留壁厚，口沿无单面薄片。','背面保持完整腹部，俯视破口内壁可读。'],
'Barrel_Ironbound':['木板分片和桶腹弧度可辨，修后铁箍边缘连续。','上下收分对称，桶箍贴合木板而无穿出尖角。','背面铁箍同样完整，俯视木板封盖无漏底。'],
'Barrel_BurstCache':['缺失桶板露出内部，散落木条与小瓶形成明确破损状态。','修后桶箍不再穿出锯齿；缺口和内壁厚度正常。','背面桶壁保留，俯视敞口与碎物分离清楚。'],
'Crate_OpenSupplies':['横板与立柱有明确承重关系，板间可见物资。','短边封板和立柱接齐，底板接地。','背板完整，斜俯视看到敞口瓶及账册。'],
'Shelf_ScrollArchive':['书本、卷轴与横放账册分三层；修后卷轴落到架板。','架板厚度和侧板完整，无悬空卷轴。','背板闭合、四层架板均连接侧柱。'],
'Shelf_CandleSconce':['四根残烛高度错落，灯芯和滴蜡可辨。','斜铁托连接壁板与承台，壁挂结构完整。','背面壁板与铁托没有缺面；原点为包围盒底部，安装高度由使用方设定。'],
'Candles_OfferingCluster':['蜡烛高低错落并立于共同石托。','侧面前后蜡烛有层次，没有悬空根部。','背面保持完整石托和烛体，蜡滴有厚度。'],
'Post_Shackles':['柱、铁箍与两只拘束环容易识别。','侧面吊杆与腕环连通，底座承托木柱。','背面木柱和铁箍封闭；腕环为真实中空环体。'],
'Rack_MinerTools':['镐头与铲片有区别，木架留足空隙。','工具靠在架子前方，两侧地脚承托稳定。','横撑接上竖柱，镐柄与镐头相接。'],
'Bucket_RopeWell':['桶口和高提梁可辨，盘绳与桶分开但均接地。','提梁连接桶两侧，桶底有封闭厚度。','后部无缺面，斜俯视内壁与桶底完整。'],
'Debris_MossMasonry':['四块砌石构成有层次碎堆，苔在上表面。','低矮堆体适合墙边散布，根条跨在后方。','背侧根条有厚度，未见漏底；这是单件陈设，不负责通行判定。'],
'Marker_BrokenPilgrim':['断角墓板和日轮标记可辨，左右残烛有区别。','石板厚度与独立底座清楚，标记贴于正面。','背面保留素石面和小片苔色，未出现前后反贴。'],
'Lectern_ForgottenLedger':['打开的账册、斜面阅读台与中央柱组成完整讲台。','书页V形内脊贴近台面，抬起外沿保留厚度；台面接入支柱。','背面无缺面，中央柱与宽底座衔接。'],
'Stool_SackRest':['三脚凳支持布袋；修后收口增加布结两耳，避免误认陶罐。','侧面三脚支撑完整，布袋下端落在凳面。','背面布结可辨、底脚接地；无额外悬浮碎片。'],
'Grate_RubbleDrain':['铁栅落在厚石框内，碎石均在框边。','侧面厚度明确，栅格未穿出石框。','背面构造一致，俯视孔隙真实存在。'],
}
FIXED=['Urn_TallKeeper','Amphora_TwinHandle','Jar_SquatMoss','Barrel_Ironbound','Barrel_BurstCache','Shelf_ScrollArchive','Stool_SackRest']
rows=json.loads((ROOT/'manifest.json').read_text(encoding='utf8'))
reviews=[]
for row in rows:
    name=row['name'];kind=name.removeprefix('DG_')
    assert len(row['references'])>=2 and row['nonmanifold_edges']==0 and row['degenerate_faces']==0
    views={}
    for i,view in enumerate(['front','side','back']):
        p='Previews/'+name+'_'+view+'.png';assert (ROOT/p).is_file()
        views[view]=dict(path=p,observation=NOTES[kind][i])
    review=dict(name=name,result='pass_after_visual_review',reviewed_by='Codex dungeon asset agent',date='2026-10-01',
                views=views,hero='Previews/'+name+'_hero.png',
                geometry=dict(nonmanifold_edges=row['nonmanifold_edges'],degenerate_faces=row['degenerate_faces'],triangles=row['triangles']),
                style='项目低多边形硬边、共享哑光自然色；检查了轮廓、功能结构、正侧背厚度与接地。',
                limitations='Blender源几何和四向图已审；Unity导入、项目内放置、碰撞及随机池由主代理单独记录。')
    if kind in FIXED:
        review['repair_record']=dict(before='Previews/BeforeFix/'+name+'_hero.png',after=review['hero'],
          issue='环带与斜面相交形成锯齿' if kind not in ['Shelf_ScrollArchive','Stool_SackRest'] else ('卷轴离架板悬空约6cm' if kind=='Shelf_ScrollArchive' else '布袋收口过于像陶罐盖'),
          resolution='环带按主体纵剖面插值并匹配多边形分段' if kind not in ['Shelf_ScrollArchive','Stool_SackRest'] else ('卷轴底面下移至架板顶面' if kind=='Shelf_ScrollArchive' else '添加收束布结的两个折角'))
    row['review_status']='blender_three_views_and_hero_reviewed_pass'
    row['review_file']='review.json'
    row['previews']={v:'Previews/'+name+'_'+v+'.png' for v in ['front','side','back','hero']}
    reviews.append(review)
(ROOT/'manifest.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf8')
(ROOT/'review.json').write_text(json.dumps(reviews,ensure_ascii=False,indent=2),encoding='utf8')
print('reviewed models',len(reviews),'triangles',sum(r['triangles'] for r in rows))
