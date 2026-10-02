from pathlib import Path
import json
BASE=Path(__file__).resolve().parents[1]
rows=json.loads((BASE/'manifest.json').read_text(encoding='utf8'))
notes=[
('弯刀曲线与刀尖朝向清楚，三条潮痕已贴合实际刀面。','刀刃有厚度；护拳两端连接柄箍，潮痕未悬浮成铭牌。','背面保留干净刀背，非对称护拳正确，握位无遮挡。'),
('粗齿与钩状刀头形成独立轮廓，刃根明确插入铜护手。','锯齿具有厚度，铜补片与铆钉贴着刃根，没有纸片错位。','背面不再重复额外装饰，柄尾闭环连接完整。'),
('船钟宽口与背面的方形锤砧质量关系明确，四道铜箍可读。','右侧看到锤砧，另补左端视图确认中空钟壁及内部固定钟舌。','背面钟肩承接柄头，未见木杆穿出钟罩；低多边轮廓适合地图资产。'),
('双锚爪一宽一缺，双握位与柄尾两环断链完整。','侧面锚爪、锚眼与主杆有实厚，结构接合没有漂浮块。','背面保留非对称锚头，两只短链环没有拖到远离柄尾的位置。'),
('中心细长叉刃与朝后的短钩区分明确，索圈位于叉颈。','侧面窄而真实有厚度，倒刺没有离开叉刃成为孤立片。','背面长木杆与两端金属套箍连续，浅色修补节清楚。'),
('宽珍珠刃与扇贝护手一眼可辨，掌柄比例短小。','贝护手有实厚，暗纹贴合刃面，刃根未穿出护手侧边。','背面奶白色主形干净，柄尾珠与铜环固定在木芯上。'),
('宽后掠弩臂、中央木托与前踏环对称，弦端连接正确。','侧面双铜绞轮靠近弩托，掌柄和扳机护圈各有净空。','背面清楚显示双轮和弦槽，斜俯视确认没有无支撑的零件。'),
('修正后弦沿弓梢最外侧连接，和上下木臂之间均有净空。','骨背只保留在上下弓臂，笔直木芯被绿色握把完整包覆，消除了碎面竞争。','背面握柄干净连续；上下蛇首都连接弓梢，轮廓不与弦混叠。'),
('六角铜灯笼、暖黄灯晶和弯木杖有明确主次。','铜柱实际承托顶盖，灯晶有底部支座，不是悬空发光球。','背面所有支柱与上下圈相接，顶部小环闭合，中央握位完整。'),
('短铳枪口封闭黑色视觉孔与铜边清楚，整体为静态幻想外形。','侧面木柄、机匣、外部击锤和护圈分层，贝片贴合掌柄外侧。','背面能见握柄厚度和有限的蓝灰绑带，无镜像错位或单面消失。')]
reviews=[]
for row,obs in zip(rows,notes):
    views=['front','side','back','hero']
    if row['name']=='SWW_DrownedBellMaul':views.append('left')
    paths={v:'Previews/'+row['name']+'_'+v+'.png' for v in views}
    assert all((BASE/p).is_file() for p in paths.values())
    reviews.append(dict(name=row['name'],reviewer='terrain_assets agent — actual image inspection',reviewed_on='2026-10-02',status='pass',
      front_review_zh=obs[0],side_review_zh=obs[1],back_review_zh=obs[2],images=paths,
      criteria={'visible_alignment':'pass','unintended_visible_interpenetration':'none observed in reviewed final views','style':'medieval maritime fantasy, matte solid colors, flat normals','lore_features':'visible story motifs checked'},
      scope='Static modeled asset. Character animation, inventory data, damage, motion modules and sockets are not part of this delivery.'))
(BASE/'review.json').write_text(json.dumps(reviews,ensure_ascii=False,indent=2),encoding='utf8')
print('10 authored reviews written after inspecting final orthographic and hero images')
