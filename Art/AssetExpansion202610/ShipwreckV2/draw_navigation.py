from pathlib import Path
import json,math,html
root=Path(__file__).parent
layout=json.loads((root/'Integration/layout_snapshot.json').read_text(encoding='utf8'))
nav=json.loads((root/'Integration/navigation.json').read_text(encoding='utf8'))
hull=next(p for p in layout['props'] if p['assetId']==800);ox,oz=hull['x'],hull['z']
svg=['<svg xmlns="http://www.w3.org/2000/svg" width="1440" height="1000" viewBox="0 0 1440 1000">','<rect width="1440" height="1000" fill="#172b31"/>',
'<g fill="#e5d9bd" font-family="Microsoft YaHei,sans-serif"><text x="40" y="46" font-size="27">暮潮号 · 三层真实导航</text><text x="42" y="80" font-size="16">99 × 36.6 米 / 1595 连通可走格 / 9 功能区 / 4 条双向梯道</text></g>']
def point(layer,x,z):return (240+layer*475+7.2*(x-ox),550-7.2*(z-oz))
colors=['#b9a888','#c6ae7b','#d3b377']
for layer,title in enumerate(['下层货舱 · 0 m','主甲板 · 4 m','船艏与艉楼平台 · 7.2 m']):
    svg.append(f'<text x="{65+layer*475}" y="126" fill="#d8d6ba" font-size="19" font-family="Microsoft YaHei">{title}</text>')
    for c in layout['cells']:
        if c['layer']!=layer or c['kind']=='water':continue
        pts=[]
        for j in range(6):
            a=math.radians(30+60*j);x,y=point(layer,c['x']+.94*math.cos(a),c['z']+.94*math.sin(a));pts.append(f'{x:.2f},{y:.2f}')
        color='#edc75a' if c['kind']=='stairs' else '#645d50' if c['blocked'] else colors[layer]
        svg.append(f'<polygon points="{" ".join(pts)}" fill="{color}" stroke="#263633" stroke-width=".25"/>')
    for room in nav['rooms']:
        if room['layer']!=layer:continue
        c=layout['cells'][room['centerIndex']-1];x,y=point(layer,c['x'],c['z'])
        svg.append(f'<circle cx="{x}" cy="{y}" r="4" fill="#70d5bc"/><text x="{x+8}" y="{y-8}" font-size="13" fill="#edf0df" stroke="#213631" stroke-width=".5" paint-order="stroke" font-family="Microsoft YaHei">{html.escape(room["name"])}</text>')
    for stair in nav['stairs']:
        index=stair['bottom'] if stair['fromLayer']==layer else stair['top'] if stair['toLayer']==layer else None
        if index:
            c=layout['cells'][index-1];x,y=point(layer,c['x'],c['z']);svg.append(f'<circle cx="{x}" cy="{y}" r="10" fill="#d69d40"/><text x="{x-4}" y="{y+4}" fill="#172b31" font-size="12">{stair["id"]}</text>')
svg.append('<text x="45" y="965" fill="#adbdad" font-family="Microsoft YaHei" font-size="15">金色编号在相邻层对应同一梯道；深色为真实阻挡区域。图形来自实际生成快照，不另造导航。</text></svg>')
(root/'Previews/navigation_layers.svg').write_text('\n'.join(svg),encoding='utf8')
print('navigation_layers.svg')
