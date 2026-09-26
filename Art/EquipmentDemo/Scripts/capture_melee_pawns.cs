if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode)throw new System.Exception("Edit Mode required");
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var hostObj=new GameObject("MeleePawnPreview");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(hostObj,scene);
var host=hostObj.AddComponent<ProjectY.UI.UIHost>();host.Initialize();
var prior=RenderTexture.active;
using(var lua=new XLua.LuaEnv()){
var services=new ProjectY.FrameworkServices(host);var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
try{
lua.DoString(System.IO.File.ReadAllText("Tools/Tests/equipment_preview.lua"));
var rig=UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/PawnLowPoly/PawnRig.prefab").GetComponent<ProjectY.Samples.PawnView>();
var equipped=new System.Collections.Generic.List<ProjectY.Samples.PawnEquipmentView>();
var flags=System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Instance;
var motionTimes=new float[3];
for(int i=0;i<3;i++){
lua.DoString("EquipmentPreviewMelee("+(41+i*2)+","+(i==2?"true":"false")+",4)");
var pawn=UnityEngine.Object.Instantiate(rig,hostObj.transform,false);pawn.transform.localPosition=new Vector3(i*2.0f-2,0,0);pawn.transform.localRotation=Quaternion.Euler(0,-10,0);
var values=lua.DoString("return EquipmentPreviewAppearance(4)");ProjectY.Samples.PawnAppearanceData appearance;
using(var row=(XLua.LuaTable)values[0])appearance=ProjectY.Samples.PawnAppearanceData.Read(row);
System.Func<ProjectY.Samples.PawnAppearanceData.Part,GameObject> resolve=p=>UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(p.Path);
pawn.ApplyAppearance(appearance,resolve);var count=pawn.GetComponentsInChildren<Renderer>().Length;
for(int j=0;j<8;j++)pawn.ApplyAppearance(appearance,resolve);
if(count!=pawn.GetComponentsInChildren<Renderer>().Length)throw new System.Exception("Repeated snapshots duplicated weapon meshes");
var equipment=pawn.GetComponent<ProjectY.Samples.PawnEquipmentView>();equipped.Add(equipment);
var action=lua.DoString("local b=EquipmentPreviewRegistry:Get('Battle');local e=EquipmentPreviewRegistry:Get('Equipment');local a=e:Actor(4);local s=b:Skill(a,"+(10+i)+");a:RecordAction(s.actionTemplate,1,1,0);return EquipmentPreviewAppearance(4)");
using(var row=(XLua.LuaTable)action[0])appearance=ProjectY.Samples.PawnAppearanceData.Read(row);
// Read the actual configured action, but position its timeline explicitly in this isolated static capture.
equipment.Apply(appearance.Equipment);motionTimes[i]=appearance.Equipment.Motion.Duration*.45f;
equipment.GetType().GetField("started",flags).SetValue(equipment,-100f);equipment.GetType().GetMethod("RenderPose",flags).Invoke(equipment,null);
}
lua.DoString("EquipmentPreviewRegistry:Get('UI'):Close('EquipmentWorkbench')");
var light=new GameObject("PawnPreviewLight").AddComponent<Light>();UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(light.gameObject,scene);light.type=LightType.Directional;light.intensity=1.2f;light.transform.rotation=Quaternion.Euler(45,-35,0);
var fill=new GameObject("PawnFill").AddComponent<Light>();UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(fill.gameObject,scene);fill.type=LightType.Directional;fill.intensity=.6f;fill.transform.rotation=Quaternion.Euler(20,145,0);
var camera=new GameObject("PawnCamera").AddComponent<Camera>();UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(camera.gameObject,scene);camera.scene=scene;camera.enabled=false;camera.orthographic=true;camera.orthographicSize=2.5f;camera.nearClipPlane=.1f;camera.farClipPlane=40;camera.backgroundColor=new Color(.13f,.16f,.17f);camera.clearFlags=CameraClearFlags.SolidColor;
camera.transform.position=new Vector3(2.7f,3.1f,8.5f);camera.transform.LookAt(new Vector3(0,1.25f,0));
var paths=new System.Collections.Generic.List<string>();
for(int frame=0;frame<2;frame++){
if(frame==1)for(int i=0;i<3;i++){
 var eq=equipped[i];eq.GetType().GetField("started",flags).SetValue(eq,Time.unscaledTime-motionTimes[i]);eq.GetType().GetMethod("RenderPose",flags).Invoke(eq,null);
}
var target=new RenderTexture(1600,1000,24,RenderTextureFormat.ARGB32);target.antiAliasing=4;target.Create();Texture2D picture=null;
try{
camera.targetTexture=target;camera.aspect=1.6f;camera.Render();RenderTexture.active=target;picture=new Texture2D(1600,1000,TextureFormat.RGB24,false);picture.ReadPixels(new Rect(0,0,1600,1000),0,0);picture.Apply();
var path=System.IO.Path.GetFullPath("Art/EquipmentDemo/Previews/melee-pawns-"+(frame==0?"hold":"slash")+".png");System.IO.File.WriteAllBytes(path,picture.EncodeToPNG());paths.Add(path);
}finally{camera.targetTexture=null;RenderTexture.active=prior;if(picture!=null)UnityEngine.Object.DestroyImmediate(picture);target.Release();UnityEngine.Object.DestroyImmediate(target);}
}
return paths;
}finally{lua.DoString("EquipmentPreviewRegistry:Shutdown();EquipmentPreviewRegistry=nil;EquipmentPreviewPanel=nil;EquipmentPreviewAppearance=nil;EquipmentPreviewModify=nil;EquipmentPreviewGun=nil;EquipmentPreviewMelee=nil;Services=nil;collectgarbage('collect')");services.Player.ClearListeners();host.Shutdown();UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);}
}
