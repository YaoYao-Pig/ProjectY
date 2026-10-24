"""Copy this batch's validated FBX files only; preserve every Unity .meta GUID."""
import hashlib,json,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
ART=ROOT/'Art/ProfessionArsenal20261025'
DEST=ROOT/'Assets/DynamicAsset/ProfessionArsenal20261025'
models=json.loads((ART/'Integration/models.json').read_text(encoding='utf-8'))
assert len(models)==12 and [r['id'] for r in models]==list(range(8001,8013))
report=[]
for row in models:
    source=(ART/'Staging'/(row['modelKey']+'.fbx')).resolve()
    target=(ROOT/row['modelPath']).resolve()
    assert target.is_relative_to(DEST.resolve()) and source.is_relative_to(ART.resolve())
    assert source.is_file() and source.stat().st_size>0
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(source,target)
    digest=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
    assert digest(source)==digest(target)
    report.append({'id':row['id'],'modelPath':row['modelPath'],'bytes':target.stat().st_size,'sha256':digest(target)})
for folder in ('Weapons','Icons'):(DEST/folder).mkdir(parents=True,exist_ok=True)
(ART/'Integration/staging.json').write_text(json.dumps({'status':'copied_pending_native_validation','files':report},indent=2),encoding='utf-8')
print(json.dumps({'copied':len(report),'bytes':sum(r['bytes'] for r in report),'native_import':'pending'}))
