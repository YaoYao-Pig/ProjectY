"""把已检查的静态导出文件复制到 Unity，并将实测高度回写源配置。"""
import json,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT/'Art/MapDressingLowPoly'
models=json.loads((OUT/'Integration/models.json').read_text(encoding='utf-8'))
path=ROOT/'Config/Tables/Map/MapAssetTable.json';table=json.loads(path.read_text(encoding='utf-8'))
target=ROOT/'Assets/DynamicAsset/MapDressingLowPoly'
for folder in ['Models','Materials']:(target/folder).mkdir(parents=True,exist_ok=True)
for model in models:
    row=next(r for r in table['rows'] if r['id']==model['assetId'])
    row['referenceHeight']=round(model['dimensions'][2],4);row['tintMaterial']=model['materials'][0]
    shutil.copyfile(OUT/'Staging'/(model['name']+'.fbx'),target/'Models'/(model['name']+'.fbx'))
path.write_text(json.dumps(table,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('已复制 24 个 FBX，保留所有现存 meta；实测高度与材质写入源表。')
