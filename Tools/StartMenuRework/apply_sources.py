from pathlib import Path
import hashlib,json,shutil
root=Path(__file__).resolve().parents[2];stage=root/'Tools/StartMenuRework'
records=json.loads((stage/'Existing/manifest.json').read_text(encoding='utf-8'))
for row in records:
    assert hashlib.sha256((root/row['path']).read_bytes()).hexdigest()==row['before'],'Concurrent edit: '+row['path']
targets={
    'WorldMenuPreview.cs':'Assets/GameFramework/Runtime/Data/WorldMenuPreview.cs',
    'CampaignPreviewCapture.cs':'Assets/GameFramework/Samples/Adventure/CampaignPreviewCapture.cs',
    'StartMenuStage.cs':'Assets/GameFramework/Runtime/UI/StartMenuStage.cs',
    'StartMenuView.cs':'Assets/GameFramework/Runtime/UI/StartMenuView.cs',
    'StartMenuSceneAssets.cs':'Assets/GameFramework/Editor/StartMenuSceneAssets.cs',
    'MenuTerrain.shader':'Assets/GameFramework/Resources/MenuTerrain.shader',
    'MenuTransition.shader':'Assets/GameFramework/Resources/MenuTransition.shader'}
for relative in targets.values():assert not (root/relative).exists(),relative
for row in records:shutil.copyfile(root/row['staged'],root/row['path'])
for name,target in targets.items():shutil.move(str(stage/name),str(root/target))
folder=root/'Assets/DynamicAsset/MainMenu';(folder/'Models').mkdir(parents=True,exist_ok=True);(folder/'Materials').mkdir(exist_ok=True)
shutil.copyfile(root/'Art/MainMenu/Export/Signpost_Menu.fbx',folder/'Models/Signpost_Menu.fbx')
print('Applied',len(records),'existing files and',len(targets),'new sources; copied sign FBX.')
