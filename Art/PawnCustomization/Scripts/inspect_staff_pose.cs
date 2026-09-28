var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var services=new ProjectY.FrameworkServices(null);
try {
 using(var lua=new XLua.LuaEnv()) {
  var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
  var actor=(ProjectY.Data.CombatActorData)lua.DoString(System.IO.File.ReadAllText("Tools/CharacterPreview/export_equipment.lua"))[0];
  try {
   var catalog=AssetDatabase.LoadAssetAtPath<ProjectY.Samples.PawnCustomizationCatalog>(ProjectY.Editor.PawnCustomizationAssets.CatalogPath);
   var data=catalog.Rules.Randomize(412,"human","male");data.body="body_male_0";data.head="head_human_male_0";services.Appearances.Apply(actor,JsonUtility.ToJson(data));
   ProjectY.Samples.AdventureViewData.Actor state;
   using(var row=(XLua.LuaTable)lua.DoString("return CharacterEquipmentLoadout(0,true)")[0])state=ProjectY.Samples.AdventureViewData.ReadActor(row);
   var pawn=UnityEngine.Object.Instantiate(AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/PawnLowPoly/PawnRig.prefab")).GetComponent<ProjectY.Samples.PawnView>();UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(pawn.gameObject,scene);
   pawn.ApplyAppearance(state.Appearance,p=>AssetDatabase.LoadAssetAtPath<GameObject>(p.Path));pawn.Capture(state,Vector3.forward*3,0);
   var animation=pawn.GetComponentInChildren<ProjectY.Samples.PawnAnimationView>();
   for(int frame=0;frame<=16;frame++) {
    if(frame==15){actor.RecordAction(state.Appearance.Equipment.Hold.AttackActionId,1,0,3);using(var row=(XLua.LuaTable)lua.DoString("return CharacterEquipmentSnapshot()")[0])state=ProjectY.Samples.AdventureViewData.ReadActor(row);pawn.Capture(state,Vector3.forward*3,0);}
    pawn.TickPresentation(.12f/animation.Settings.PresentationSpeed,frame>0&&frame<15?2:0);
   }
   var camera=new GameObject("ProbeCamera").AddComponent<Camera>();UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(camera.gameObject,scene);
   camera.scene=scene;camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);camera.orthographic=true;camera.orthographicSize=1.1f;camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.14f,.18f,.17f);
   var lamp=new GameObject("ProbeLight").AddComponent<Light>();UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(lamp.gameObject,scene);lamp.type=LightType.Directional;lamp.intensity=1.3f;lamp.transform.rotation=Quaternion.Euler(30,-30,0);
   var capture=typeof(ProjectY.Editor.PawnCustomizationValidation).GetMethod("Capture",System.Reflection.BindingFlags.Static|System.Reflection.BindingFlags.NonPublic);
   foreach(int angle in new[]{0,90}) {
    camera.transform.position=Quaternion.Euler(0,angle,0)*new Vector3(0,1.8f,5);camera.transform.LookAt(new Vector3(0,1.15f,0));
    var image=(Texture2D)capture.Invoke(null,new object[]{camera,pawn.GetComponentInChildren<ProjectY.Samples.PawnCustomizationView>(),800,800});System.IO.File.WriteAllBytes("Art/PawnCustomization/Previews/staff-frame16-"+angle+".png",image.EncodeToPNG());UnityEngine.Object.DestroyImmediate(image);
   }
   var meshes=new System.Collections.Generic.List<object>();
   foreach(var weapon in pawn.GetComponentsInChildren<ProjectY.Samples.WeaponModelView>())foreach(var filter in weapon.GetComponentsInChildren<MeshFilter>())meshes.Add(new{name=filter.name,meshBounds=filter.sharedMesh.bounds.ToString(),world=filter.GetComponent<MeshRenderer>().bounds.ToString()});
   return new{main=animation.MainGrip.position.ToString(),off=animation.OffGrip.position.ToString(),rotation=animation.MainGrip.eulerAngles.ToString(),meshes=meshes};
  } finally {lua.DoString("CloseCharacterEquipmentFixture()");lua.Global.Set<string,object>("Services",null);}
 }
} finally {services.Player.ClearListeners();UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);}

