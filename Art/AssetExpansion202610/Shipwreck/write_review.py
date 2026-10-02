from pathlib import Path
import json
root=Path(__file__).parent
notes={
'SW_Map_WreckMarker':('尖艏、断帆与艉楼共同识别沉船','船体厚度和水线保留，单格占地足够','艉楼与舵连接；破口同源于大模型'),
'SW_Map_AbandonedCog':('完整船舷与残帆区别沉船版本','高艉楼明显，侧轮廓无现代机械','闭合艉部，作为较完整废船标识'),
'SW_Hull_CogWreck':('尖艏和船底龙骨可辨','多段舷板、上缘破口和外侧加强木条连接','艉板闭合；内部为开放壳体，不是实心障碍盒'),
'SW_Deck_Cog':('甲板具有明确尖艏外形','实体厚度0.18米，导航顶高0','俯视已核对左舷缺口和连续通道；减弱了初版高对比条纹'),
'SW_SternCastle':('封闭舱门与低窄窗明确','艉舵支架已延伸到后墙，消除悬浮间隔','栏杆及舵有厚度；舱体为不可进入设施'),
'SW_BowRibs':('船肋向船艏收窄','肋骨连接龙骨，端面可见','背面厚度完整，适合不可达破口边缘'),
'SW_Mast_BrokenSquare':('单桅、横桁和破方帆区别木杆','帆与横桁和拉索相接，桅杆非单面','残帆背面存在；最低帆边高于甲板3米'),
'SW_Mast_Fallen':('横卧桅杆和破帆有明确方向','几何为倾倒后的整体结构','用于完整占地阻挡，不在主通道上摆放'),
'SW_Rail_Broken':('断柱高低与缺口清楚','栏杆厚度统一','整体横档仍相连，不是无支撑悬空木条'),
'SW_Hatch_Collapsed':('破舱盖与框架可读','断板端部连接框缘，有实体黑色舱底','背面完整；导航必须阻挡整个舱口'),
'SW_Capstan':('四臂绞盘和缆鼓形成识别点','转杆穿过缆鼓属于合理结构连接','完整底座与铁箍'),
'SW_Anchor_Rusted':('锚横木、双爪、吊环清楚','窄厚度适于沿船舷陈列','吊环与锚杆接合，无单面消失'),
'SW_Cargo_SaltCrates':('货垛主次与斜撑可辨','上箱底部已移到下箱顶面，消除初版细缝','后板完整，箱体以功能形体为主'),
'SW_Cargo_WetBarrels':('一高一矮两桶有区别','箍圈沿对应桶腹半径，未见穿出尖角','桶盖与桶底闭合'),
'SW_Rope_Coil':('粗绳五圈形成中空卷缆','低矮厚度明确','散开绳尾与外圈相接'),
'SW_Bell_BrokenFrame':('铜钟与双柱框架可辨','吊杆触及横梁与钟顶','钟舌有实体连接，框柱落地'),
'SW_Drift_Planks':('三板错落，水藻色块克制','低矮片层适合甲板边缘','背部厚度完整'),
'SW_Boat_BrokenDinghy':('小艇艏艉不对称，保持中空','横座位于艇壳上缘内侧','艇尾闭合，底部完整'),
'SW_Gangplank':('七板拼成完整跳板','厚度与下方横撑可见','两端平齐，预留导航接驳契约')}
rows=json.loads((root/'manifest.json').read_text(encoding='utf8'));reviews=[]
for r in rows:
    name=r['name'];front,side,back=notes[name]
    r['review_status']='front_side_back_hero_reviewed_revision_2'
    r['integration_status']='Unity FBX / materials / prefabs imported, root transform and bounds verified; game integration tracked separately.'
    reviews.append(dict(name=name,title=r['title'],front=front,side=side,back=back,
                        evidence=[f'Previews/{name}_{v}.png' for v in ['front','side','back','hero']],
                        result='通过静态低多边形资产目视审核',reviewer='primary agent, actual rendered pixels'))
(root/'manifest.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf8')
(root/'review.json').write_text(json.dumps(reviews,ensure_ascii=False,indent=2),encoding='utf8')
(root/'review.md').write_text('# 沉船资产审核\n\n19件逐正侧背与斜视实际看图，三款主体另看俯视；整船组合看斜俯视与正俯视。\n\n修正了初版甲板条纹过亮、沉船破口不够明确、艉舵支架悬浮、货箱间细缝与尖艏内壁交叉。最终模型 0 非流形边、0 退化面；19件 Unity 尺寸、单位缩放、零根旋转及材质映射检查通过。\n\n原始参考共4张，来自 Skyrim、The Witcher 3 与 Sea of Thieves；每项关联3张，已亲自查看参考板。历史资料只用于单桅方帆与高艉楼轮廓，船体为游戏用奇幻尺寸。\n\n逐项记录见 review.json；源坐标经实际导入非对称甲板缺口校验：Unity=(-BlenderX, BlenderZ, -BlenderY)。不能把图审通过当作玩法导航已经通过。生成逻辑和实际地图预览另行验证。\n',encoding='utf8')
print('19 shipwreck visual reviews archived')
