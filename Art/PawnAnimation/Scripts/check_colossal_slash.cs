// Run with Unity MCP execute_code in Edit Mode; samples production playback in a detached PreviewScene.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode)throw new System.InvalidOperationException("Edit Mode required.");
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var services=new ProjectY.FrameworkServices(null);
var results=new System.Collections.Generic.List<object>();
try {
 var light=new UnityEngine.GameObject("SlashPreviewLight").AddComponent<UnityEngine.Light>();
 UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(light.gameObject,scene);
 light.type=UnityEngine.LightType.Directional;light.intensity=1.4f;light.transform.rotation=UnityEngine.Quaternion.Euler(35,-30,0);
 var camera=new UnityEngine.GameObject("SlashPreviewCamera").AddComponent<UnityEngine.Camera>();
 UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(camera.gameObject,scene);
 camera.scene=scene;camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
 camera.enabled=false;camera.orthographic=true;camera.orthographicSize=2.2f;camera.nearClipPlane=.1f;camera.farClipPlane=30;
 camera.clearFlags=UnityEngine.CameraClearFlags.SolidColor;camera.backgroundColor=new UnityEngine.Color(.16f,.20f,.19f);
 var capture=typeof(ProjectY.Editor.PawnAnimationValidation).GetMethod("Capture",System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Static);
 using(var lua=new XLua.LuaEnv()) {
  var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
  var actor=(ProjectY.Data.CombatActorData)lua.DoString(System.IO.File.ReadAllText("Tools/CharacterPreview/export_equipment.lua"))[0];
  try {
   foreach(int index in new[]{6,7,4,1}) {
    ProjectY.Samples.AdventureViewData.Actor state;
    using(var row=(XLua.LuaTable)lua.DoString("return CharacterEquipmentLoadout("+index+",true)")[0])state=ProjectY.Samples.AdventureViewData.ReadActor(row);
    var pawn=UnityEngine.Object.Instantiate(UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>("Assets/DynamicAsset/PawnLowPoly/PawnRig.prefab")).GetComponent<ProjectY.Samples.PawnView>();
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(pawn.gameObject,scene);
    var headMesh=new UnityEngine.Mesh();
    try {
     pawn.ApplyAppearance(state.Appearance,p=>UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(p.Path));
     var animation=pawn.GetComponentInChildren<ProjectY.Samples.PawnAnimationView>();
     var custom=pawn.GetComponentInChildren<ProjectY.Samples.PawnCustomizationView>();
     var weapons=pawn.GetComponentsInChildren<ProjectY.Samples.WeaponModelView>();
     var weapon=System.Array.Find(weapons,w=>w.transform.IsChildOf(animation.MainGrip));
     var headColliders=new System.Collections.Generic.List<UnityEngine.MeshCollider>();
     var weaponColliders=new System.Collections.Generic.List<UnityEngine.MeshCollider>();
     UnityEngine.MeshCollider headCollider=null;
     if(custom!=null) {headCollider=custom.Modules[1].gameObject.AddComponent<UnityEngine.MeshCollider>();headCollider.convex=true;headColliders.Add(headCollider);}
     foreach(var filter in pawn.GetComponentsInChildren<UnityEngine.MeshFilter>())if(filter.name.Contains("Helmet")) {
      var collider=filter.gameObject.AddComponent<UnityEngine.MeshCollider>();collider.sharedMesh=filter.sharedMesh;collider.convex=true;headColliders.Add(collider);
     }
     if(headColliders.Count==0)throw new System.InvalidOperationException("Missing head/helmet clearance fixture.");
     foreach(var model in weapons)foreach(var filter in model.GetComponentsInChildren<UnityEngine.MeshFilter>()) {
      var collider=filter.gameObject.AddComponent<UnityEngine.MeshCollider>();collider.sharedMesh=filter.sharedMesh;collider.convex=true;weaponColliders.Add(collider);
     }
     pawn.Capture(state,UnityEngine.Vector3.forward*3,0);for(int i=0;i<15;i++)pawn.TickPresentation(1f/30);
     int actionId=state.Appearance.Equipment.Hold.AttackActionId;
     if(index>=6 && actionId!=6)throw new System.InvalidOperationException("Colossal fixture selected the wrong action.");
     int oldSequence=state.ActionSequence;actor.RecordAction(actionId,1,0,3);
     using(var row=(XLua.LuaTable)lua.DoString("return CharacterEquipmentSnapshot()")[0])state=ProjectY.Samples.AdventureViewData.ReadActor(row);
     pawn.Capture(state,UnityEngine.Vector3.forward*3,0);
     float duration=animation.Settings.GetAction(actionId).Duration,impact=pawn.ImpactTime(state,oldSequence);
     float gripError=0,headPenetration=0,minY=float.MaxValue,maxY=float.MinValue,idleY=animation.MainGrip.position.y;
     float maxDownwardAngle=0,finishedAt=-1,maxFaceMotion=0;string worst="";var previousBlade=weapon.transform.up;
     int steps=UnityEngine.Mathf.CeilToInt(duration*120)+12;
     for(int frame=0;frame<=steps;frame++) {
      pawn.TickPresentation(1f/120);
      if(!pawn.PresentationBusy && finishedAt<0)finishedAt=frame/120f;
      var equipment=state.Appearance.Equipment;
      gripError=UnityEngine.Mathf.Max(gripError,UnityEngine.Vector3.Distance(animation.MainGrip.position,weapon.transform.TransformPoint(equipment.WeaponView.PrimaryGrip.Position)));
      if(equipment.Hold.OffHandFollowsWeapon)gripError=UnityEngine.Mathf.Max(gripError,UnityEngine.Vector3.Distance(animation.OffGrip.position,weapon.transform.TransformPoint(equipment.WeaponView.SecondaryGrip.Position)));
      minY=UnityEngine.Mathf.Min(minY,animation.MainGrip.position.y);maxY=UnityEngine.Mathf.Max(maxY,animation.MainGrip.position.y);
      maxDownwardAngle=UnityEngine.Mathf.Max(maxDownwardAngle,UnityEngine.Vector3.Angle(UnityEngine.Vector3.up,weapon.transform.up));
      if(index>=6 && frame/120f>=duration*.34f && frame/120f<=duration*.56f)
       maxFaceMotion=UnityEngine.Mathf.Max(maxFaceMotion,UnityEngine.Mathf.Abs(UnityEngine.Vector3.Dot(weapon.transform.forward,(weapon.transform.up-previousBlade).normalized)));
      previousBlade=weapon.transform.up;
      if(headCollider!=null){custom.Modules[1].BakeMesh(headMesh);headCollider.sharedMesh=null;headCollider.sharedMesh=headMesh;}
      foreach(var head in headColliders)foreach(var blade in weaponColliders) {
       UnityEngine.Vector3 direction;float depth;
       if(UnityEngine.Physics.ComputePenetration(head,head.transform.position,head.transform.rotation,blade,blade.transform.position,blade.transform.rotation,out direction,out depth) && depth>headPenetration) {
        headPenetration=depth;worst="frame="+frame+", part="+blade.name;
       }
      }
      if(index>=6 && (frame==0 || frame==19 || frame==35 || frame==41 || frame==72)) {
       foreach(int angle in new[]{25,90}) {
        camera.transform.position=UnityEngine.Quaternion.Euler(0,angle,0)*new UnityEngine.Vector3(0,1.8f,5)+UnityEngine.Vector3.forward*.3f;
        camera.transform.LookAt(new UnityEngine.Vector3(0,1.35f,.3f));
        capture.Invoke(null,new object[]{camera,"colossal-"+index+"-frame"+frame+"-view"+angle});
       }
      }
     }
     var result=new {weapon=index,action=actionId,duration,impact,finishedAt,frames=steps+1,gripError,headPenetration,handRise=maxY-idleY,handTravel=maxY-minY,maxDownwardAngle,maxFaceMotion,worst};results.Add(result);
     if(gripError>.035f || headPenetration>.008f || finishedAt<0 || finishedAt>duration+.025f)throw new System.InvalidOperationException(Newtonsoft.Json.JsonConvert.SerializeObject(result));
     if(index>=6 && (maxDownwardAngle<110 || maxFaceMotion>.01f))throw new System.InvalidOperationException("Slash must cut along the blade plane with a downward follow-through.");
    } finally {UnityEngine.Object.DestroyImmediate(pawn.gameObject);UnityEngine.Object.DestroyImmediate(headMesh);}
   }
  } finally {lua.DoString("CloseCharacterEquipmentFixture()");lua.Global.Set<string,object>("Services",null);}
 }
 var report=new {playing=UnityEditor.EditorApplication.isPlaying,results};
 System.IO.File.WriteAllText("Art/PawnAnimation/Integration/colossal-slash.json",Newtonsoft.Json.JsonConvert.SerializeObject(report,Newtonsoft.Json.Formatting.Indented));
 return report;
} finally {services.Player.ClearListeners();UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);}
