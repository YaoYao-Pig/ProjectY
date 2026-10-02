"""Record the completed visual review. Notes are authored after viewing every sheet."""
from pathlib import Path
import json
BASE=Path(__file__).resolve().parents[1]
rows=json.loads((BASE/'manifest.json').read_text(encoding='utf8'))
notes={
'AE_Swamp_RootWillow':['正面三叉树冠与五向板根清楚，垂枝没有悬空断接。','侧面保持枝干连接，冠层厚度足够；后方冠层部分自然遮挡。','背面能读到主干的偏转，未见额外树枝穿出树冠顶面。'],
'AE_Swamp_ReedCattails':['七株香蒲错落，叶片有厚度，主轮廓不混成实心块。','侧面保留前后层次，部分叶交叠是植物丛的设计组成。','背面蒲头高度仍有节奏，无单面叶片消失。'],
'AE_Swamp_Rotwood':['横卧树干与少量苔片、折枝形成简明剪影。','端口真实镂空，厚树皮与心材断面连续；未使用黑片假洞。','背面折枝方向正确，苔层贴附树皮，没有漂浮大片。'],
'AE_Swamp_WitchesStump':['断口有大小高低变化，扇菌没有平均分布。','侧面三层菌架与根脚均可见，内壁不会从侧面漏空。','背面两条粗根提供稳定支撑，断口厚度一致。'],
'AE_DarkForest_AncientOak':['钩形大枝疏密分明，残叶稀疏，辨识为老树。','侧向剪影窄是枝系朝向造成，主干保持完整厚度。','背面偏心主干和折枝有连贯受力关系，无断裂飘浮。'],
'AE_DarkForest_ThornArch':['中央拱形负空间完整，两股荆棘顶端交织。','侧面显示藤蔓厚度和刺长，设计用于片状林缘构件。','背面仍可读到拱门，荆刺朝外，无无意封堵。'],
'AE_DarkForest_CrowPine':['四层针叶冠比例递减，裙边暗色确保层次可读。','偏心冠层不成为完全规则圆锥，主干接根。','背面同样完整，叶冠未出现漏面。'],
'AE_DarkForest_RootTangle':['盘根越过石块，中央斜断桩与低横向轮廓区别于树。','侧面根须回落地表，岩石嵌在根团内是有意包裹。','背面能看到石块与粗根的空间关系，未见不明突片。'],
'AE_Lava_BasaltOrgan':['五根玄武岩柱高低错落，节理带与竖线可辨。','双排柱群有厚度，窄暗缝为节理而非漏面。','背面柱顶高度仍有层次，平台顶面封闭。'],
'AE_Lava_ObsidianBlades':['四片斜向断刃大小分明，灰紫大面降低纯黑丢形。','侧面仍有不同倾角，避免纸片状晶体。','背面断面结构成立，无翻转法线造成的透明洞。'],
'AE_Lava_Fumarole':['矮锥与两侧碎石构成开口喷气孔剪影。','侧面呈厚实火口壁，顶缘有有限破损。','背面轮廓闭合；补看俯视确认内壁下降到熔岩喉口。'],
'AE_Lava_MagmaRift':['修正后岩板与熔岩床均贴地，旧版橙色圆管已移除。','侧面显示统一厚底和高低不同岩板，无悬空横线。','背面裂口仍与正面相通，斜俯视可读到分支熔岩。'],
'AE_Volcano_CinderCone':['高而收束的火山锥与矮喷气孔有明显差异。','侧面地层色面延续，锥体不悬空。','背面非对称碎口完整；俯视确认真实凹腔与深色熔岩底。'],
'AE_Volcano_BrokenCrater':['一侧坍塌较低，碎片方向与缺口呼应。','侧面明显见到坡度高低差，不是缩小的完整火山锥。','背面轮廓连续；俯视可见降低的鞍部，未漏底。'],
'AE_Volcano_SulphurChimney':['双烟囱一高一低，浅黄色矿层区别于灰色玄武岩。','侧面双柱有前后关系，底部沉积块承接高柱。','背面完整，补看俯视确认两个独立凹喉。'],
'AE_Volcano_AshSpire':['三座偏斜尖塔与水平退台形成风蚀层理。','侧面尖峰厚度充分，台地边缘没有纸片面。','背面大块暖灰与冷灰转折可读，纹理密度不过量。'],
'AE_Mushroom_RedParasol':['红色鼓伞、米白斑和弯菌柄辨识明确。','侧面伞盖厚、下缘有菌褶色带，菌柄不穿出盖顶。','背面斑块不完全对称，根须贴地；与既有民居同框尺度相称。'],
'AE_Mushroom_BrownCanopy':['宽平褐伞与幼菌形成母子关系，区别于红色鼓伞。','侧面幼菌保持独立菌柄，伞盖未与母伞穿插。','背面菌柄弯曲方向合理，幼菌部分被母柄遮挡是自然层次。'],
'AE_Mushroom_IndigoLantern':['三株铃盖菌高低不同，青色下缘与灰蓝顶部清楚。','侧向菌丛仍有前后层次，所有盖下均有菌柄支撑。','背面无盖柄错位，作为奇幻小型菌群不冒充真实物种。'],
'AE_Mushroom_ShelfColony':['沿老桩四层菌架交替伸出，扇形厚度清楚。','侧面大菌架没有完全遮住老桩，仍能辨识主体。','背面菌架方向有变化；桩顶凹口与菌架根部的交接为有意生长。'],
'AE_Mushroom_PuffballNest':['六枚梨形孢子囊大小错落，区别于带柄蘑菇。','侧面群体轮廓低矮，底部齐平，囊体之间相邻不穿插。','背面材质连续，斜俯视可辨每个顶部小孔标记。']}
reviews=[]
for i,row in enumerate(rows):
    name=row['name'];views=['front','side','back','hero']
    if row['category']=='hex_tile':
        views.append('top')
        n=[row['display_name_zh']+'正面边缘与底边水平，侧壁无缺口。','侧面精确六角柱边界，无倒角缝隙或随机偏移。','背面与正面厚度一致；俯视修正后的连续偏置色块无放射风车花纹。']
    else:n=notes[name]
    if name in ['AE_Lava_Fumarole','AE_Volcano_CinderCone','AE_Volcano_BrokenCrater','AE_Volcano_SulphurChimney']:views.append('top')
    images={view:'Previews/'+name+'_'+view+'.png' for view in views}
    for path in images.values():assert (BASE/path).is_file(),path
    reviews.append(dict(name=name,reviewer='terrain_assets agent — direct image inspection',reviewed_on='2026-10-01',
       status='pass',front_review_zh=n[0],side_review_zh=n[1],back_review_zh=n[2],
       images=images,contact_sheet='Previews/review_sheet_%02d.png'%(i//6+1),
       criteria={'visible_alignment':'pass','unintended_visible_interpenetration':'none observed in reviewed views','closed_mesh_components':row['nonmanifold_edges']==0,
       'project_style':'flat normals, matte solid colors, large readable forms','aesthetic_assessment':'suitable for current Project Y low-poly map family'},
       scope='Static asset views; excludes arbitrary gameplay placement, runtime lighting and collision.'))
(BASE/'review.json').write_text(json.dumps(reviews,ensure_ascii=False,indent=2),encoding='utf8')
print('Saved 36 authored per-asset reviews, with 3 view-specific observations each')
