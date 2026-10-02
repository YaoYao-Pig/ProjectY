"""Draw a debugging diagram from the real frozen-layout snapshot; no invented layout."""
from pathlib import Path
import json,math,html
from collections import deque
root=Path(__file__).parent
data=json.loads((root/'Integration/layout_snapshot.json').read_text(encoding='utf8'))
cells=data['cells'];start=data['rooms'][0]['centerIndex'];goal=data['rooms'][2]['centerIndex']
hull=next(p for p in data['props'] if p['assetId']==602);ox,oz=hull['x'],hull['z']
parents={start:None};queue=deque([start])
while queue:
    i=queue.popleft()
    if i==goal:break
    for d,j in enumerate(cells[i-1]['neighbors']):
        if j and j not in parents and not cells[j-1]['blocked'] and cells[i-1]['walkMask']&(1<<d):parents[j]=i;queue.append(j)
assert goal in parents
path=[];i=goal
while i is not None:path.append(i);i=parents[i]
path.reverse()
def point(x,z):return (440+22*(x-ox),520-22*(z-oz))
svg=['<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="1000" viewBox="0 0 1200 1000">',
'<rect width="1200" height="1000" fill="#192b31"/>',
'<g font-family="Microsoft YaHei,sans-serif" fill="#e4ddc7"><text x="45" y="48" font-size="26">暮潮号 · 真实生成导航检查</text><text x="45" y="80" font-size="14" fill="#9cb0ae">实际 LayoutSnapshot · 船形固定模板 · 六角半径 1 米</text></g>']
for idx,c in enumerate(cells,1):
    x,z=c['x']-ox,c['z']-oz
    if abs(x)>8.5 or z < -17 or z>20:continue
    points=[]
    for side in range(6):
        a=math.radians(30+60*side);px,pz=point(c['x']+math.cos(a)*data['hexRadius']*.93,c['z']+math.sin(a)*data['hexRadius']*.93);points.append(f'{px:.2f},{pz:.2f}')
    color='#776a56' if c['blocked'] and not c['renderGround'] else '#c1ab7d' if not c['blocked'] else '#274b56'
    svg.append(f'<polygon points="{" ".join(points)}" fill="{color}" stroke="#17282b" stroke-width=".8"/>')
coords=[point(cells[i-1]['x'],cells[i-1]['z']) for i in path]
svg.append('<polyline points="'+' '.join(f'{x:.2f},{y:.2f}' for x,y in coords)+'" fill="none" stroke="#6de4b4" stroke-width="5" stroke-linejoin="round"/>')
for i,label,color in [(start,'登船入口','#74e8c1'),(goal,'船艏目标','#eec66f')]:
    x,y=point(cells[i-1]['x'],cells[i-1]['z']);svg.append(f'<circle cx="{x}" cy="{y}" r="9" fill="{color}"/><text x="{x+18}" y="{y-12}" fill="{color}" font-family="Microsoft YaHei" font-size="16">{label}</text>')
walk=sum(not c['blocked'] for c in cells)
texts=[f'可走甲板：{walk} 格',f'入口到目标：{len(path)-1} 步',f'生成陈设：{len(data["props"])} 件','浅木色：可行走甲板','深木色：船舷 / 设施阻挡','蓝绿色：不可行走水域','绿色线：真实邻接路径','','左舷破口不进入导航','船长艉楼封闭','桅杆仅占用底部空间','四人往返另有原生状态检查']
for k,t in enumerate(texts):svg.append(f'<text x="760" y="{190+k*42}" fill="#c1cbc2" font-family="Microsoft YaHei" font-size="17">{html.escape(t)}</text>')
svg.append('</svg>');(root/'Previews/generated_navigation.svg').write_text('\n'.join(svg),encoding='utf8')
print(json.dumps({'walkable_cells':walk,'path_steps':len(path)-1,'props':len(data['props'])}))
