"""王城体量、街道尺度与山坡街区的本次定向重做；只执行一次。"""
import json
from pathlib import Path
root=Path('D:/Program/Unity/Project Y/Config/Tables/MapArea')
def load(name):return json.loads((root/(name+'.json')).read_text(encoding='utf-8-sig'))
def save(data):(root/(data['name']+'.json')).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
recipe=load('MapAreaRoyalTable');row=recipe['rows'][0]
for name,kind,value,description in [
 ('outlineR','int[]',[-34,-24,-10,8,24,34],'城市外轮廓纵向控制点'),
 ('outlineLeft','float[]',[-27,-31,-26,-32,-26,-22],'各控制点左侧城界'),
 ('outlineRight','float[]',[28,31,28,29,23,18],'各控制点右侧城界'),
 ('boundarySlope','float[]',[.18,-.10,.24],'各层台地等高线的主方向斜率')]:
    assert name not in row,'重做已执行，请定向调表'
    recipe['fields'].append(dict(name=name,type=kind,description=description));row[name]=value
row.update(minR=-34,maxR=34,outlineInset=2.5,boundaryAmplitude=[3,4,4],mainRoadRadius=1,laneRadius=0,
    frontageDistance=5,frontageWeight=6,anchorWeight=.6,clusterWeight=1.3,plotNoiseWeight=1.1,candidateLimit=48,
    stairU=[-20,21,-15,18,-11,13],districtIds=[1,2,3,4,5,6,7])
districts=load('MapAreaRoyalDistrictTable')
gate=next(r for r in districts['rows'] if r['role']=='gate');gate.update(centerQ=-24,centerR=24,shiftQ=2)
districts['rows'].append(dict(id=7,name='坡心旧街',centerQ=1,centerR=-2,shiftQ=3,shiftR=1,searchRadius=14,role='residential',roadRadius=1))
plots=load('MapAreaRoyalPlacementTable');next_id=max(r['id'] for r in plots['rows'])+1
for district,u,r in [(7,-3,0),(7,3,0),(7,0,-6),(7,1,6),(3,-5,4),(4,-3,2)]:
    assert (2*u-r)%2==0
    plots['rows'].append(dict(id=next_id,name='旧街连续联排',districtId=district,localQ=int(u-r/2),localR=r,
        lotIds=[14,15,16],facilityId=0,role='house',searchRadius=14,rotations=[0,1,2,3,4,5],required=True))
    row['placementIds'].append(next_id);next_id+=1
lots=load('MapAreaTownLotTable')
points=[(0,0),(1,0),(0,1),(-1,1),(-1,0),(0,-1),(1,-1)]
lots['rows'].append(dict(id=24,name='街巷阔叶树组',assetId=13,scale=2,scaleMode='meters',footprintQ=[q for q,r in points],footprintR=[r for q,r in points],entryQ=0,entryR=2,kind='street',houseUnits=0))
# 城门也回到模型米制大小，并同步它的实体双塔占地。
gate_lot=next(r for r in lots['rows'] if r['id']==18)
points=[(q,r) for r in range(-1,2) for q in range(-6,7) if 2<=abs(q+r/2)<=4.5]
gate_lot.update(scaleMode='meters',footprintQ=[q for q,r in points],footprintR=[r for q,r in points])
parterres=0
for plot in plots['rows']:
    if plot['lotIds']==[22]:
        parterres+=1
        if parterres>3:plot.update(lotIds=[24],role='detail',rotations=[0])
for district in [3,4,7]:
    for u,r in [(-5,-2),(4,4),(-2,6)]:
        plots['rows'].append(dict(id=next_id,name='院落绿荫',districtId=district,localQ=int(u-r/2),localR=r,
            lotIds=[24],facilityId=0,role='detail',searchRadius=8,rotations=[0],required=False))
        row['placementIds'].append(next_id);next_id+=1
towns=load('MapAreaTownTable');next(r for r in towns['rows'] if r['id']==5)['houseCount']=42
for table in [recipe,districts,plots,lots,towns]:save(table)
print('王城：42 栋米制住宅、坡心旧街、收紧的街道、变化的城界和错位台地。')
