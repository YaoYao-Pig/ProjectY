if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.InvalidOperationException("Edit Mode required");
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var hostObj=new GameObject("EquipmentPreview");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(hostObj,scene);
var host=hostObj.AddComponent<ProjectY.UI.UIHost>();host.Initialize();
var prior=RenderTexture.active;var paths=new System.Collections.Generic.List<string>();
using(var lua=new XLua.LuaEnv()){
var services=new ProjectY.FrameworkServices(host);var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
try{
lua.DoString(System.IO.File.ReadAllText("Tools/Tests/equipment_preview.lua"));
lua.DoString("EquipmentPreviewModify();EquipmentPreviewRegistry:Get('UI'):Close('EquipmentWorkbench')");
var rig=UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/PawnLowPoly/PawnRig.prefab").GetComponent<ProjectY.Samples.PawnView>();
var pawns=new System.Collections.Generic.List<ProjectY.Samples.PawnView>();
for(int i=0;i<2;i++){
var pawn=UnityEngine.Object.Instantiate(rig,hostObj.transform,false);pawn.transform.localPosition=new Vector3(i*2.1f-1.05f,0,0);pawn.transform.localRotation=Quaternion.Euler(0,-20,0);
var values=lua.DoString("return EquipmentPreviewAppearance("+(i==0?3:2)+")");ProjectY.Samples.PawnAppearanceData appearance;
using(var row=(XLua.LuaTable)values[0]) appearance=ProjectY.Samples.PawnAppearanceData.Read(row);
System.Func<ProjectY.Samples.PawnAppearanceData.Part,GameObject> resolve=p=>UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(p.Path);
pawn.ApplyAppearance(appearance,resolve);var count=pawn.GetComponentsInChildren<Renderer>().Length;
for(int j=0;j<12;j++)pawn.ApplyAppearance(appearance,resolve);
if(count!=pawn.GetComponentsInChildren<Renderer>().Length)throw new System.Exception("Repeated pawn snapshot duplicates meshes");
var equipment=pawn.GetComponent<ProjectY.Samples.PawnEquipmentView>();
appearance.Equipment.Motion=new ProjectY.Samples.EquipmentVisualData.Action {Sequence=10,Kind=i==0?"cast":"reload",Duration=.9f,Shots=1,Pitch=i==0?14:-22,HandLift=i==0?.15f:-.12f,MagazineDrop=i==0?0:.35f};
pawn.ApplyAppearance(appearance,resolve);
var flags=System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Instance;
equipment.GetType().GetField("started",flags).SetValue(equipment,Time.unscaledTime-.45f);
equipment.GetType().GetMethod("RenderPose",flags).Invoke(equipment,null);
pawns.Add(pawn);
}
var light=new GameObject("PawnPreviewLight").AddComponent<Light>();UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(light.gameObject,scene);light.type=LightType.Directional;light.intensity=1.2f;light.transform.rotation=Quaternion.Euler(45,-35,0);
var camera=new GameObject("PawnCamera").AddComponent<Camera>();UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(camera.gameObject,scene);camera.scene=scene;camera.enabled=false;camera.orthographic=true;camera.orthographicSize=2.0f;camera.nearClipPlane=.1f;camera.farClipPlane=40;camera.backgroundColor=new Color(.13f,.16f,.17f);camera.clearFlags=CameraClearFlags.SolidColor;
camera.transform.position=new Vector3(3.8f,2.7f,6.5f);camera.transform.LookAt(new Vector3(0,.9f,0));
var target=new RenderTexture(1280,900,24,RenderTextureFormat.ARGB32);target.antiAliasing=4;target.Create();Texture2D picture=null;
try{
camera.targetTexture=target;camera.aspect=1280f/900;camera.Render();RenderTexture.active=target;picture=new Texture2D(1280,900,TextureFormat.RGB24,false);picture.ReadPixels(new Rect(0,0,1280,900),0,0);picture.Apply();
var path=System.IO.Path.GetFullPath("Art/EquipmentDemo/Previews/equipped-pawns-actions.png");System.IO.File.WriteAllBytes(path,picture.EncodeToPNG());paths.Add(path);
}finally{camera.targetTexture=null;RenderTexture.active=prior;if(picture!=null)UnityEngine.Object.DestroyImmediate(picture);target.Release();UnityEngine.Object.DestroyImmediate(target);}
return paths;
}finally{lua.DoString("EquipmentPreviewRegistry:Shutdown();EquipmentPreviewRegistry=nil;EquipmentPreviewPanel=nil;EquipmentPreviewAppearance=nil;EquipmentPreviewModify=nil;EquipmentPreviewGun=nil;Services=nil;collectgarbage('collect')");services.Player.ClearListeners();host.Shutdown();UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);}
}
