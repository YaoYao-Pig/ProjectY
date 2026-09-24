"""首版视觉时钟与天气源表；运行一次建立配方，之后用配表工具维护。"""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[3]
def save(name,description,fields,rows):
    path=root/'Config/Tables/Rendering'/(name+'.json');path.parent.mkdir(parents=True,exist_ok=True)
    assert not path.exists(),'源表已存在，不能重放迁移'
    path.write_text(json.dumps(dict(version=1,name=name,description=description,key='id',fields=fields,rows=rows),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def f(name,kind,description,**kw):return dict(name=name,type=kind,description=description,**kw)
save('MapLightKeyTable','昼夜视觉关键帧，按小时循环插值，不推进玩法时间',[
    f('id','int','编号'),f('hour','float','小时',min=0,max=23.99),f('sunIntensity','float','主光强度',min=0),f('sunColor','string','主光颜色'),
    f('skyColor','string','天空环境光'),f('equatorColor','string','水平环境光'),f('groundColor','string','底部环境光'),f('fogColor','string','远景雾色'),
    f('lampWeight','float','室内暖灯权重',min=0,max=1)],
    [dict(zip(['id','hour','sunIntensity','sunColor','skyColor','equatorColor','groundColor','fogColor','lampWeight'],r)) for r in [
    (1,0,.22,'#91acdc','#526785','#414e67','#293747','#293e58',1),
    (2,5,.28,'#a0afd2','#61748f','#575c78','#393d50','#596d88',1),
    (3,7,.85,'#ffd4a0','#afc6d2','#aaaca1','#777869','#a7bcc9',.25),
    (4,12,1.1,'#fff1d8','#becddd','#b4b8ab','#888477','#c0d0d8',.05),
    (5,17,1.0,'#ffcc91','#b9becf','#b3a79b','#7e7169','#b9b8c3',.3),
    (6,19,.55,'#ed9562','#747f9e','#8c7880','#554d5b','#808ba5',.85),
    (7,21,.22,'#92abdb','#526785','#414e67','#293747','#354963',1)]])
save('MapWeatherTable','天气只控制显示，不修改地图水位或通行',[
    f('id','int','编号'),f('name','string','名称'),f('sunMultiplier','float','主光倍率',min=0),f('ambientMultiplier','float','环境光倍率',min=0),
    f('fogStart','float','从焦点起的雾起始距离，米',min=0),f('fogEnd','float','从焦点起的雾完全覆盖距离，米',min=1),
    f('tint','string','天气偏色'),f('shadowStrength','float','阴影强度',min=0,max=1)],
    [dict(id=1,name='晴天',sunMultiplier=1,ambientMultiplier=1,fogStart=120,fogEnd=550,tint='#ffffff',shadowStrength=.75),
     dict(id=2,name='阴天',sunMultiplier=.42,ambientMultiplier=.88,fogStart=55,fogEnd=320,tint='#d8e1e7',shadowStrength=.36)])
save('MapEnvironmentTable','地图表现层生命周期、视觉时钟与室内局部灯',[
    f('id','int','配方编号'),f('name','string','名称'),f('keyIds','int[]','按小时递增的关键帧',ref='MapLightKeyTable'),
    f('weatherIds','int[]','允许的天气',ref='MapWeatherTable'),f('defaultWeatherId','int','初始天气',ref='MapWeatherTable'),
    f('cycleSeconds','float','一个完整视觉日的真实秒数',min=60),f('startHour','float','初始小时',min=0,max=24),f('autoCycle','bool','自动推进视觉时间'),
    f('transitionSeconds','float','天气和室内外混合时间',min=.1),f('sunAzimuth','float','日照方位角'),
    f('indoorSunMultiplier','float','室内直射光倍率',min=0,max=1),f('indoorAmbientColor','string','室内环境色'),
    f('lampColor','string','室内灯色'),f('lampIntensity','float','灯光强度',min=0),f('lampRange','float','灯光范围，米',min=1),
    f('lampHeight','float','离地高度，米',min=1),f('maxLocalLights','int','同时启用的局部灯上限',min=1,max=8),
    f('shadowDistance','float','实时阴影距离，米',min=10)],
    [dict(id=1,name='低多边形城镇',keyIds=list(range(1,8)),weatherIds=[1,2],defaultWeatherId=1,cycleSeconds=600,startHour=10,autoCycle=True,
     transitionSeconds=.7,sunAzimuth=-35,indoorSunMultiplier=.45,indoorAmbientColor='#aaa090',lampColor='#ffc589',lampIntensity=2.1,
     lampRange=11,lampHeight=2.6,maxLocalLights=4,shadowDistance=180)])
# 追加功能标识枚举，保留原有稳定值。
p=root/'Config/Tables/MapArea/MapAreaTownFacilityTable.json';data=json.loads(p.read_text(encoding='utf-8'))
next(field for field in data['fields'] if field['name']=='kind')['values'] += ['bakery','herbalist','chapel','warehouse','stable','watchtower']
data['description']='城镇功能设施：可步入首层并在服务点查看介绍，业务按稳定 kind 接入。'
p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
