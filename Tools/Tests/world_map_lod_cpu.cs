// CPU-only verification for an existing idle Editor after the coordinated compilation.
// Owns an isolated PreviewScene; does not render, enter Play, change user scenes, or import assets.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.Exception("Idle Editor required for world-map LOD CPU checks.");
var scene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var settings = new ProjectY.Samples.MapRenderLod.Settings();
var messages = new System.Collections.Generic.List<string>();
System.Action<bool,string> expect = (value,message) => { if (!value) throw new System.Exception(message); };
var type = typeof(ProjectY.Samples.AdventureViewData).Assembly.GetType("ProjectY.Samples.WorldPartyView",true);
var flags = System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance;
object partyView = null;
UnityEngine.Material sourceMaterial = null;
UnityEngine.Mesh sourceMesh = null;
try
{
    expect(ProjectY.Samples.MapRenderLod.ClassifyDistance(39,40,100,4,ProjectY.Samples.MapRenderLod.Tier.Hidden)==ProjectY.Samples.MapRenderLod.Tier.Near,"Near detail classification");
    expect(ProjectY.Samples.MapRenderLod.ClassifyDistance(43,40,100,4,ProjectY.Samples.MapRenderLod.Tier.Near)==ProjectY.Samples.MapRenderLod.Tier.Near,"Near detail hysteresis");
    expect(ProjectY.Samples.MapRenderLod.ClassifyDistance(41,40,100,4,ProjectY.Samples.MapRenderLod.Tier.Medium)==ProjectY.Samples.MapRenderLod.Tier.Medium,"No distance-boundary flicker");
    expect(ProjectY.Samples.MapRenderLod.ClassifyDistance(105,40,100,4,ProjectY.Samples.MapRenderLod.Tier.Medium)==ProjectY.Samples.MapRenderLod.Tier.Far,"Far detail omission");
    messages.Add("near/mid/far classification and hysteresis");

    var cameraObject = new UnityEngine.GameObject("LOD_CPU_Camera");
    cameraObject.hideFlags = UnityEngine.HideFlags.HideAndDontSave;
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);
    var camera = cameraObject.AddComponent<UnityEngine.Camera>(); camera.enabled=false;
    camera.orthographic=true;camera.orthographicSize=10;camera.aspect=1;camera.nearClipPlane=.1f;camera.farClipPlane=2000;
    camera.transform.SetPositionAndRotation(new UnityEngine.Vector3(0,1000,0),UnityEngine.Quaternion.Euler(90,0,0));
    var lod = new ProjectY.Samples.MapRenderLod.View();lod.Update(camera,0,1,settings);
    var center = new UnityEngine.Bounds(UnityEngine.Vector3.zero,UnityEngine.Vector3.one);
    expect(lod.Classify(center)==ProjectY.Samples.MapRenderLod.Tier.Near,"Orthographic artificial camera offset must not lower detail");
    expect(lod.Visible(new UnityEngine.Bounds(new UnityEngine.Vector3(12,0,0),UnityEngine.Vector3.one)),"Frustum edge margin");
    expect(!lod.Visible(new UnityEngine.Bounds(new UnityEngine.Vector3(100,0,0),UnityEngine.Vector3.one)),"Outside frustum is culled");
    var broadModel=new UnityEngine.Bounds(new UnityEngine.Vector3(150,50,0),new UnityEngine.Vector3(300,100,4));
    expect(lod.Visible(broadModel) && lod.Classify(broadModel)==ProjectY.Samples.MapRenderLod.Tier.Near,"Large/high model uses its full footprint, not its offscreen center");
    camera.orthographicSize=60;lod.Update(camera,0,1,settings);
    expect(lod.Classify(center)==ProjectY.Samples.MapRenderLod.Tier.Medium,"Zoom changes detail without moving entities");
    camera.orthographicSize=150;lod.Update(camera,0,1,settings);
    expect(lod.Classify(center)==ProjectY.Samples.MapRenderLod.Tier.Far,"Wide view retains terrain/markers only");
    messages.Add("orthographic zoom, camera movement and frustum margin");

    var owner = new UnityEngine.GameObject("LOD_CPU_Owner");owner.hideFlags=UnityEngine.HideFlags.HideAndDontSave;
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(owner,scene);
    var prefab = new UnityEngine.GameObject("LOD_CPU_Model",typeof(UnityEngine.MeshFilter),typeof(UnityEngine.MeshRenderer));
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(prefab,scene);prefab.SetActive(false);
    var shader = UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
    expect(shader!=null,"Existing map shader");
    sourceMaterial=new UnityEngine.Material(shader);
    sourceMesh=new UnityEngine.Mesh {vertices=new[]{UnityEngine.Vector3.zero,UnityEngine.Vector3.right,UnityEngine.Vector3.up},triangles=new[]{0,1,2}};
    sourceMesh.RecalculateBounds();sourceMesh.RecalculateNormals();
    prefab.GetComponent<UnityEngine.MeshFilter>().sharedMesh=sourceMesh;prefab.GetComponent<UnityEngine.MeshRenderer>().sharedMaterial=sourceMaterial;
    var bindingType=type.GetNestedType("Binding",System.Reflection.BindingFlags.Public|System.Reflection.BindingFlags.NonPublic);
    var bindings=System.Array.CreateInstance(bindingType,2);var binding=System.Activator.CreateInstance(bindingType);
    bindingType.GetField("path").SetValue(binding,"test");bindingType.GetField("prefab").SetValue(binding,prefab);bindings.SetValue(binding,0);
    var otherPrefab=UnityEngine.Object.Instantiate(prefab);otherPrefab.name="LOD_CPU_OtherModel";
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(otherPrefab,scene);
    var otherBinding=System.Activator.CreateInstance(bindingType);
    bindingType.GetField("path").SetValue(otherBinding,"other");bindingType.GetField("prefab").SetValue(otherBinding,otherPrefab);bindings.SetValue(otherBinding,1);
    partyView=System.Activator.CreateInstance(type,flags,null,new object[]{owner.transform,bindings,1f,shader,settings},null);
    var parties=new ProjectY.Samples.AdventureViewData.WorldParty[6];
    for(int i=0;i<parties.Length;i++)parties[i]=new ProjectY.Samples.AdventureViewData.WorldParty {Id=i+1,Name="test",Kind=i==0?"stronghold":"hostile",ModelPath="test",Status="",Position=new UnityEngine.Vector3(i-3,0,0)};
    var view=new ProjectY.Samples.AdventureViewData {Phase="map",Travel=new ProjectY.Samples.AdventureViewData.TravelState {Position=UnityEngine.Vector3.zero},
        WorldParties=new ProjectY.Samples.AdventureViewData.WorldPartyState {PlayerModelPath="test",Rows=parties}};
    type.GetMethod("Sync",flags).Invoke(partyView,new object[]{view});
    var update=type.GetMethod("UpdateVisibility",flags);
    System.Func<string,int> metric=name=>(int)type.GetProperty(name,flags).GetValue(partyView);
    expect(metric("CreatedModelCount")==0,"Snapshot synchronization does not instantiate models");
    camera.orthographicSize=10;camera.transform.position=new UnityEngine.Vector3(500,1000,0);
    update.Invoke(partyView,new object[]{camera});
    expect(metric("CreatedModelCount")==0 && metric("ActiveModelCount")==0,"Initially offscreen models are not instantiated");
    camera.transform.position=new UnityEngine.Vector3(0,1000,0);
    camera.orthographicSize=10;update.Invoke(partyView,new object[]{camera});
    expect(metric("CreatedThisFrame")==2 && metric("CreatedModelCount")==2 && metric("ActiveModelCount")==2,"Creation budget limits a newly visible crowd");
    update.Invoke(partyView,new object[]{camera});
    expect(metric("CreatedThisFrame")==2,"Multiple visibility calls in one frame share the budget");
    camera.transform.position=new UnityEngine.Vector3(500,1000,0);update.Invoke(partyView,new object[]{camera});
    expect(metric("ActiveModelCount")==0 && metric("OutsideDetailCount")==0 && metric("PooledModelCount")==2,"No detailed objects active outside the expanded frustum");
    camera.transform.position=new UnityEngine.Vector3(0,1000,0);update.Invoke(partyView,new object[]{camera});
    expect(metric("ActiveModelCount")==2 && metric("CreatedModelCount")==2,"Returning camera reuses pooled models");
    expect(metric("ActivatedThisFrame")<=settings.activationsPerFrame,"Activation budget");
    camera.orthographicSize=150;update.Invoke(partyView,new object[]{camera});
    expect(metric("ActiveModelCount")==0 && metric("MarkerCount")==2,"Far view keeps only the player and settlement markers");
    messages.Add("2 creations/frame, pooled reuse, 0 outside details and far markers");
    settings.maximumDetailedObjects=2;settings.creationsPerFrame=4;
    parties[0].ModelPath="other";parties[0].Position=new UnityEngine.Vector3(200,0,0);
    type.GetMethod("Sync",flags).Invoke(partyView,new object[]{view});
    camera.orthographicSize=10;camera.transform.position=new UnityEngine.Vector3(200,1000,0);
    update.Invoke(partyView,new object[]{camera});
    expect(metric("ActiveModelCount")==1 && metric("CreatedModelCount")==2 && metric("EvictedThisFrame")==1,"Full pool evicts an idle different prefab for the newly visible model");
    expect(metric("CreatedThisFrame")<=settings.creationsPerFrame && metric("OutsideDetailCount")==0,"Replacement still respects creation budget and frustum");
    messages.Add("full-pool cross-prefab replacement within budget");
}
finally
{
    if(partyView!=null)((System.IDisposable)partyView).Dispose();
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
    if(sourceMesh!=null)UnityEngine.Object.DestroyImmediate(sourceMesh);
    if(sourceMaterial!=null)UnityEngine.Object.DestroyImmediate(sourceMaterial);
}
return "PASS world-map LOD CPU: "+string.Join("; ",messages.ToArray());
