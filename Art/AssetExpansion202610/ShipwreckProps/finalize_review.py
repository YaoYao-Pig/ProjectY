"""Record a completed human-visible four-view review and perform narrow artifact checks."""
import json, re
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).parent
rows=json.loads((ROOT/'manifest.json').read_text(encoding='utf8'))
assert len(rows)==20
notes=[
'铜盘、刻度、双色指针完整；正侧背无漏面，hero可辨导航用途。',
'三折纸片有厚度，地形色块贴合折面；侧面折线清晰。',
'封面、纸页、书脊与绑带完整，桌面落点正确。',
'四柱与收腰计时体连接，砂色分区不依赖透明材质。',
'套接管层次与握套清楚，宽镜口为放置接触面。',
'铁罩、四护条与提环完整连接，使用不透明哑光灯罩。',
'皮套扁壶与短塞有明确体积，绑带连续贴合。',
'修正分段把手缝隙为连续共享顶点管；内壁和杯底闭合。',
'碗口有壁厚，内腔与底部完整；青灰边线不抢主形。',
'宽浅餐盘边沿和内底闭合；浅沿区别粗瓷深碗。',
'卷布与铺开的布尾相连，两道束带形成主要识别点。',
'打开的盒盖和合页连接；线轴、针垫与针可辨；相机包围盒调整后四视图完整。',
'盘绳与松结表现为连续折线，实物保持细缆真实尺度。',
'修正吊眼悬空，以实体斜撑接至吊眼下缘；槽轮与双颊稳定连接。',
'浅盒内有独立方帽钉，不依赖贴图或颜色替代几何。',
'厚纸、折叠封口、绑绳及封蜡形成不同于海图的剪影。',
'袋口扎绳连续，散落铜钱随模型一并占地；相机留白完整。',
'木盖、陶罐和小标签有明确体积，所有细节实体闭合。',
'软包、绑带和备用卷布可辨；叶形标记为双面实体。',
'弯柄连续无接缝，钵口有内腔和封闭底部。',
]
for row,note in zip(rows,notes):
    assert row['nonmanifold_edges']==0,(row['name'],row['nonmanifold_edges'])
    assert row['degenerate_faces']==0 and row['uv_layers']==1
    assert len(row['references'])>=2
    assert abs(row['bounds_unity']['min'][1])<1e-6
    assert (ROOT/'Staging'/(row['name']+'.fbx')).stat().st_size>1000
    for ref in row['references']:
        assert all(ref.get(k) for k in ['work','page','image','local','study'])
        assert (ROOT/ref['local']).is_file()
    for view in ['front','side','back','hero']:
        with Image.open(ROOT/'Previews'/(row['name']+'_'+view+'.png')) as image:
            assert image.size==(512,512);image.verify()
    row['review_status']='front_side_back_hero_reviewed_after_corrections'
    row['review_zh']=note
    row['lore_han_characters']=len(re.findall(r'[\u4e00-\u9fff]',row['lore']))
    row['integration_status']='Source blend and staged FBX verified; Unity import and placement delegated to main agent.'
(ROOT/'manifest.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf8')
result=dict(assets=20,views=80,references_archived=len(list((ROOT/'References').glob('*.png'))),
    triangles=sum(r['triangles'] for r in rows),nonmanifold_edges=0,degenerate_faces=0,
    source=str(ROOT/'Source/ShipwreckProps.blend'),source_bytes=(ROOT/'Source/ShipwreckProps.blend').stat().st_size,
    checks=['20 nonempty FBX','80 actual Blender render PNGs','UVMap per mesh','0 nonmanifold edges','0 degenerate faces','bottom-origin bounds','2 attributed local visual references per item'],
    manual_review='All front, side, back, hero views viewed in 4 contact sheets, then corrected views rechecked.',
    corrections=['Continuous shared-ring cup handle and curves','Solid pulley eye support','Camera-space bounding-box framing'],
    unity_verification='Not performed by this subtask; main agent owns import and actual Unity checks.',
    no_editor_start=True,no_play_mode=True,no_project_compile=True)
(ROOT/'review.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf8')
lines=['# 沉船小物品：20件','',
'原创低多边形船舱物品，真实米制、底部原点、零位移与单位缩放。Unity 朝向 +Z，使用既有静态 FBX 轴向导出契约；`bounds_unity` 已包含非对称部分。',
'','- 可编辑来源：[ShipwreckProps.blend](Source/ShipwreckProps.blend)；独立 FBX：[Staging](Staging/)。',
'- 资源与放置契约：[manifest.json](manifest.json)；纯色哑光材质：[materials.json](materials.json)。',
'- 实际四视图：[Previews](Previews/)；总览：[collection_hero.jpg](Previews/collection_hero.jpg)；审核：[review.json](review.json)。',
'- 每件两份网络视觉参考及借鉴点随 manifest；原图仅用于研究，未作为模型贴图或几何挪用。参考档案：[References/references.json](References/references.json)。',
'- 风味文字为原创，文学意象参考《金银岛》的远航、船员补给与未完成归程：[Project Gutenberg](https://www.gutenberg.org/ebooks/120)。',
'',
'小物品按真实尺寸放在桌面；绳结和滑轮也可落地。不得跟随船体整体放大。表面位置取 `bounds_unity.min.y=0`，桌面可加 0.004 米避免接触闪烁；道具不承担导航阻挡。',
'','| ID | 模型 | 名称 | Unity 宽×高×深（米） | 表面 |','| --- | --- | --- | --- | --- |']
for row in rows:
    lines.append('| '+str(row['map_asset_id'])+' | '+row['name']+' | '+row['title']+' | '+' × '.join(f'{x:.3f}' for x in row['bounds_unity']['size'])+' | '+row['placement']+' |')
lines+=['','本子任务完成 Blender 制作、导出及四视图核验；Unity 导入、独立材质/Prefab 与实际船舱摆放由主任务完成。没有启动 Editor、进入 Play 或执行项目编译。']
(ROOT/'README.md').write_text('\n'.join(lines)+'\n',encoding='utf8')
print(json.dumps(result,ensure_ascii=False))
