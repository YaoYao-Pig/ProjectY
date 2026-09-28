// Edit Mode visual review of the actual playback at front/side angles.
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();var services=new ProjectY.FrameworkServices(null);
float minimumHeadGap=float.MaxValue,maximumGripError=0;
float maximumHelmetPenetration=0;
string penetrationFrame="";
string worstFrame="";
try {
 using(var lua=new XLua.LuaEnv()) {
  var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
  var fixture=lua.DoString(System.IO.File.ReadAllText("Tools/Tests/pawn_animation_preview.lua"));var actor=(ProjectY.Data.CombatActorData)fixture[0];((XLua.LuaTable)fixture[1]).Dispose();
  try {
   var lamp=new UnityEngine.GameObject("Sun").AddComponent<UnityEngine.Light>();UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(lamp.gameObject,scene);
   lamp.type=UnityEngine.LightType.Directional;lamp.intensity=1.4f;lamp.transform.rotation=UnityEngine.Quaternion.Euler(35,-30,0);
   var camera=new UnityEngine.GameObject("PreviewCamera").AddComponent<UnityEngine.Camera>();UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(camera.gameObject,scene);
   camera.scene=scene;camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);camera.enabled=false;camera.orthographic=true;
   camera.orthographicSize=1.55f;camera.nearClipPlane=.1f;camera.farClipPlane=30;camera.clearFlags=UnityEngine.CameraClearFlags.SolidColor;camera.backgroundColor=new UnityEngine.Color(.16f,.20f,.19f);
   var capture=typeof(ProjectY.Editor.PawnAnimationValidation).GetMethod("Capture",System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Static);
   foreach(var index in new[]{1,4,6}) {
    ProjectY.Samples.AdventureViewData.Actor state;
    using(var row=(XLua.LuaTable)lua.DoString("return PawnAnimationEquip("+index+")")[0])state=ProjectY.Samples.AdventureViewData.ReadActor(row);
    var pawn=UnityEngine.Object.Instantiate(UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>("Assets/DynamicAsset/PawnLowPoly/PawnRig.prefab")).GetComponent<ProjectY.Samples.PawnView>();
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(pawn.gameObject,scene);pawn.ApplyAppearance(state.Appearance,p=>UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(p.Path));
    UnityEngine.MeshCollider helmet=null;var weaponColliders=new System.Collections.Generic.List<UnityEngine.MeshCollider>();
    foreach(var mesh in pawn.GetComponentsInChildren<UnityEngine.MeshFilter>())if(mesh.name.Contains("Helmet")) {helmet=mesh.gameObject.AddComponent<UnityEngine.MeshCollider>();helmet.sharedMesh=mesh.sharedMesh;helmet.convex=true;}
    if(helmet==null)throw new System.InvalidOperationException("Clearance fixture must wear a helmet.");
    foreach(var weapon in pawn.GetComponentsInChildren<ProjectY.Samples.WeaponModelView>())foreach(var mesh in weapon.GetComponentsInChildren<UnityEngine.MeshFilter>())
    {var collider=mesh.gameObject.AddComponent<UnityEngine.MeshCollider>();collider.sharedMesh=mesh.sharedMesh;collider.convex=true;weaponColliders.Add(collider);}
    pawn.Capture(state,UnityEngine.Vector3.forward*3,0);for(int i=0;i<15;i++)pawn.TickPresentation(1f/30);
    foreach(int angle in new[]{0,90,270}) {
     camera.transform.position=UnityEngine.Quaternion.Euler(0,angle,0)*new UnityEngine.Vector3(0,1.7f,5);camera.transform.LookAt(UnityEngine.Vector3.up*1.15f);
     capture.Invoke(null,new object[]{camera,"clearance-"+index+"-idle-"+angle});
    }
    foreach(int actionId in index==1?new[]{2,3}:new[]{index==4?5:6}) {
    actor.RecordAction(actionId,1,0,3);
    using(var row=(XLua.LuaTable)lua.DoString("return PawnAnimationSnapshot()")[0])state=ProjectY.Samples.AdventureViewData.ReadActor(row);
    pawn.ApplyAppearance(state.Appearance,p=>UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(p.Path));
    pawn.Capture(state,UnityEngine.Vector3.forward*3,0);
    for(int frame=0;frame<45;frame++) {
     pawn.TickPresentation(1f/30);
     typeof(ProjectY.Samples.PawnEquipmentView).GetMethod("RenderPose",System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic).Invoke(pawn.GetComponent<ProjectY.Samples.PawnEquipmentView>(),null);
     var animation=pawn.GetComponentInChildren<ProjectY.Samples.PawnAnimationView>();var animator=pawn.GetComponentInChildren<UnityEngine.Animator>();
     float gap=animator.GetBoneTransform(UnityEngine.HumanBodyBones.Head).position.y-UnityEngine.Mathf.Max(animation.MainGrip.position.y,animation.OffGrip.position.y);
     if(gap<minimumHeadGap) {minimumHeadGap=gap;worstFrame="weapon="+index+",action="+actionId+",frame="+frame+",head="+animator.GetBoneTransform(UnityEngine.HumanBodyBones.Head).position+",main="+animation.MainGrip.position+",off="+animation.OffGrip.position;}
     var hold=state.Appearance.Equipment.Hold;var offset=UnityEngine.Quaternion.Inverse(UnityEngine.Quaternion.Euler(hold.WeaponRotation))*(hold.OffHand-hold.MainHand);
     if(animation.ReloadProgress>=0)offset+=animation.Settings.GetAction(3).OffGripOffset*UnityEngine.Mathf.Sin(animation.ReloadProgress*UnityEngine.Mathf.PI);
     maximumGripError=UnityEngine.Mathf.Max(maximumGripError,UnityEngine.Vector3.Distance(animation.OffGrip.position,animation.MainGrip.TransformPoint(offset)));
     foreach(var collider in weaponColliders) {
      UnityEngine.Vector3 direction;float depth;
      if(UnityEngine.Physics.ComputePenetration(helmet,helmet.transform.position,helmet.transform.rotation,collider,collider.transform.position,collider.transform.rotation,out direction,out depth) && depth>maximumHelmetPenetration) {
       maximumHelmetPenetration=depth;penetrationFrame="weapon="+index+",action="+actionId+",frame="+frame+",part="+collider.name;
       camera.transform.position=new UnityEngine.Vector3(5,1.7f,0);camera.transform.LookAt(UnityEngine.Vector3.up*1.15f);capture.Invoke(null,new object[]{camera,"clearance-worst-side"});
      }
     }
     if(frame==5||frame==12||frame==19) {
      camera.transform.position=new UnityEngine.Vector3(3,1.7f,5);camera.transform.LookAt(UnityEngine.Vector3.up*1.15f);
      capture.Invoke(null,new object[]{camera,"clearance-"+index+"-action-"+frame});
      foreach(int angle in new[]{0,90,270}) {
       camera.transform.position=UnityEngine.Quaternion.Euler(0,angle,0)*new UnityEngine.Vector3(0,1.7f,5);camera.transform.LookAt(UnityEngine.Vector3.up*1.15f);
       capture.Invoke(null,new object[]{camera,"clearance-"+index+"-action"+actionId+"-frame"+frame+"-view"+angle});
      }
     }
    }
    }
    UnityEngine.Object.DestroyImmediate(pawn.gameObject);
   }
  } finally {lua.DoString("ClosePawnAnimationFixture()");lua.Global.Set<string,object>("Services",null);}
 }
 if(minimumHeadGap<.18f || maximumGripError>.035f || maximumHelmetPenetration>.005f)throw new System.InvalidOperationException("Weapon clearance regression: head gap="+minimumHeadGap+", grip error="+maximumGripError+", weapon/helmet depth="+maximumHelmetPenetration+", "+penetrationFrame);
 var report=new {frames=180,minimumHeadGap=minimumHeadGap,maximumGripError=maximumGripError,maximumHelmetPenetration=maximumHelmetPenetration,worstFrame=worstFrame,playing=UnityEditor.EditorApplication.isPlaying,views="front, left, right"};
 System.IO.File.WriteAllText("Art/PawnAnimation/Integration/weapon-clearance.json",Newtonsoft.Json.JsonConvert.SerializeObject(report,Newtonsoft.Json.Formatting.Indented));
 return report;
} finally {services.Player.ClearListeners();UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);}
