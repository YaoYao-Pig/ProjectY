// Run through Unity MCP execute_code in Edit Mode. BakeMesh snapshots bypass same-frame GPU skin caching.
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var services=new ProjectY.FrameworkServices(null);
var meshes=new System.Collections.Generic.List<UnityEngine.Mesh>();
try {
 using(var lua=new XLua.LuaEnv()) {
  var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
  lua.DoString(System.IO.File.ReadAllText("Tools/Tests/pawn_animation_preview.lua"));
  try {
   var lamp=new UnityEngine.GameObject("Sun").AddComponent<UnityEngine.Light>();UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(lamp.gameObject,scene);
   lamp.type=UnityEngine.LightType.Directional;lamp.intensity=1.2f;lamp.transform.rotation=UnityEngine.Quaternion.Euler(35,-30,0);
   var camera=new UnityEngine.GameObject("PreviewCamera").AddComponent<UnityEngine.Camera>();UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(camera.gameObject,scene);
   camera.scene=scene;camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);camera.enabled=false;camera.orthographic=true;
   camera.orthographicSize=1.5f;camera.nearClipPlane=.1f;camera.farClipPlane=30;camera.transform.position=new UnityEngine.Vector3(2.6f,2.1f,5);
   camera.transform.LookAt(UnityEngine.Vector3.up*.85f);camera.clearFlags=UnityEngine.CameraClearFlags.SolidColor;camera.backgroundColor=new UnityEngine.Color(.16f,.20f,.19f);
   var capture=typeof(ProjectY.Editor.PawnAnimationValidation).GetMethod("Capture",System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Static);
   foreach(var stateName in new[]{"IdleSword","Move","Attack","Hit","Death"}) {
    ProjectY.Samples.AdventureViewData.Actor state;
    using(var row=(XLua.LuaTable)lua.DoString("return PawnAnimationSnapshot()")[0])state=ProjectY.Samples.AdventureViewData.ReadActor(row);
    var pawn=UnityEngine.Object.Instantiate(UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>("Assets/DynamicAsset/PawnLowPoly/PawnRig.prefab")).GetComponent<ProjectY.Samples.PawnView>();
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(pawn.gameObject,scene);pawn.ApplyAppearance(state.Appearance,p=>UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(p.Path));
    var animator=pawn.GetComponentInChildren<UnityEngine.Animator>();animator.Play(stateName,0,stateName=="Death"?.9f:.45f);animator.SetFloat("PlaybackSpeed",1);animator.Update(.01f);
    foreach(var skin in pawn.GetComponentsInChildren<UnityEngine.SkinnedMeshRenderer>()) {
     var mesh=new UnityEngine.Mesh();skin.BakeMesh(mesh);meshes.Add(mesh);
     var obj=new UnityEngine.GameObject("BakedPreview");obj.transform.SetParent(skin.transform,false);
     obj.AddComponent<UnityEngine.MeshFilter>().sharedMesh=mesh;obj.AddComponent<UnityEngine.MeshRenderer>().sharedMaterials=skin.sharedMaterials;skin.enabled=false;
    }
    capture.Invoke(null,new object[]{camera,"baked-"+stateName});UnityEngine.Object.DestroyImmediate(pawn.gameObject);
   }
  } finally {lua.DoString("ClosePawnAnimationFixture()");lua.Global.Set<string,object>("Services",null);}
 }
 return "Captured actual deformed meshes in five poses";
} finally {services.Player.ClearListeners();UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);foreach(var mesh in meshes)UnityEngine.Object.DestroyImmediate(mesh);}
