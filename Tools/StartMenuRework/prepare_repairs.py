from pathlib import Path
import json,hashlib
root=Path(__file__).resolve().parents[2];stage=root/'Tools/StartMenuRework/Repairs';stage.mkdir(exist_ok=True)
paths=[r['path'] for r in json.loads((root/'Tools/StartMenuRework/Existing/manifest.json').read_text())]
paths+=['Assets/GameFramework/Editor/StartMenuSceneAssets.cs','Assets/GameFramework/Runtime/Data/WorldMenuPreview.cs']
records=[]
for relative in paths:
    file=root/relative;raw=file.read_bytes();text=raw.decode('utf-8-sig').replace('\r\r\n','\n').replace('\r\n','\n')
    if file.name=='StartMenuSceneAssets.cs':
        assert text.count('models+"House.fbx"')==1;text=text.replace('models+"House.fbx"','models+"Building_House.fbx"')
    if file.name=='WorldMenuPreview.cs':
        assert text.count('error is IOException||')==2;text=text.replace('error is IOException||','error is InvalidDataException||error is IOException||')
    if file.name=='CampaignMenu.cs':
        text=text.replace('error is System.IO.IOException ||','error is System.IO.InvalidDataException || error is System.IO.IOException ||')
    target=stage/file.name;target.write_bytes(text.encode('utf-8'))
    records.append({'path':relative,'staged':str(target.relative_to(root)),'before':hashlib.sha256(raw).hexdigest()})
(stage/'manifest.json').write_bytes(json.dumps(records,indent=2).encode())
print('Prepared bounded cache exception handling, corrected asset path and normalized line endings:',len(records),'files.')
