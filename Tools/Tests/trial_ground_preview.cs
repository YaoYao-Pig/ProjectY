// 供现有空闲 Editor 的 MCP execute_code 执行的方法体；不进入 Play，不保存场景。
// 仅渲染实际 TrialGround 布局与已有地图资源，输出 Docs/Previews/KnightTrial.png。
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling || UnityEditor.EditorApplication.isUpdating)
    throw new System.InvalidOperationException("Trial preview requires an idle Editor in Edit Mode.");
var root=System.IO.Directory.GetParent(UnityEngine.Application.dataPath).FullName;
var original=UnityEngine.SceneManagement.SceneManager.GetActiveScene();var wasDirty=original.isDirty;
ProjectY.Samples.AdventureRuntimeDemo demo=null;
for(var s=0;s<UnityEngine.SceneManagement.SceneManager.sceneCount;s++)
    foreach(var obj in UnityEngine.SceneManagement.SceneManager.GetSceneAt(s).GetRootGameObjects())
        foreach(var candidate in obj.GetComponentsInChildren<ProjectY.Samples.AdventureRuntimeDemo>(true))
            if(candidate.gameObject.scene.path=="Assets/GameFramework/Samples/Adventure/AdventureDemo.unity")demo=candidate;
if(demo==null)throw new System.InvalidOperationException("The existing AdventureDemo scene must be loaded for resource bindings.");
var models=new System.Collections.Generic.Dictionary<int,UnityEngine.GameObject>();
var pawnModels=new System.Collections.Generic.Dictionary<int,UnityEngine.GameObject>();ProjectY.Samples.PawnView pawnRig=null;
using(var serialized=new UnityEditor.SerializedObject(demo)){
    var bindings=serialized.FindProperty("assetBindings");
    for(var i=0;i<bindings.arraySize;i++){
        var row=bindings.GetArrayElementAtIndex(i);
        models.Add(row.FindPropertyRelative("id").intValue,(UnityEngine.GameObject)row.FindPropertyRelative("prefab").objectReferenceValue);
    }
    pawnRig=(ProjectY.Samples.PawnView)serialized.FindProperty("pawnPrefab").objectReferenceValue;
    var parts=serialized.FindProperty("pawnBindings");
    for(var i=0;i<parts.arraySize;i++){
        var row=parts.GetArrayElementAtIndex(i);
        pawnModels.Add(row.FindPropertyRelative("id").intValue,(UnityEngine.GameObject)row.FindPropertyRelative("prefab").objectReferenceValue);
    }
}
if(pawnRig==null)throw new System.InvalidOperationException("AdventureDemo pawn rig must be bound.");
ProjectY.Samples.MapAreaViewData layout;
using(var lua=new XLua.LuaEnv()){
    var services=new ProjectY.FrameworkServices(null);
    var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
    try{
        var source=@"
local config=require('Config.ConfigSystem')()
config:OnInit({services=Services})
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(config:GetEnum('MapArea','E_MapAreaType').TrialGround,
    require('Game.MapArea.TrialGroundGenerator'),'MapAreaTrialGroundTable','MapAreaTrialGroundThemeTable')
local area=generator:Generate(60,20261024,3060,{regionId=7,regionType=1,regionConfigId=1,q=0,r=0,height=0,biomeWeights={{regionType=1,weight=1}}})
return require('Game.MapArea.MapAreaSystem').LayoutSnapshot({config=config,appearance=require('Game.Adventure.PawnAppearance').New(config),ActiveLayout=function()return area end})
";
        using(var table=(XLua.LuaTable)lua.DoString(source,"TrialGroundPreview")[0])layout=ProjectY.Samples.MapAreaViewData.Read(table);
    }finally{lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();}
}
if(layout.AreaType!=7 || layout.Props.Length==0)throw new System.InvalidOperationException("Missing trial ground snapshot.");
if(!models.ContainsKey(layout.AssetId) || UnityEditor.AssetDatabase.GetAssetPath(models[layout.AssetId])!=layout.AssetPath)
    throw new System.InvalidOperationException("Stale trial ground binding: "+layout.AssetId);
foreach(var asset in layout.PropAssets)
    if(!models.ContainsKey(asset.Id) || UnityEditor.AssetDatabase.GetAssetPath(models[asset.Id])!=asset.Path)
        throw new System.InvalidOperationException("Stale trial prop binding: "+asset.Id);
var shader=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
if(shader==null || UnityEditor.ShaderUtil.ShaderHasError(shader))throw new System.InvalidOperationException("Map preview shader is unavailable.");
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
ProjectY.Samples.MapAreaRenderer renderer=null;ProjectY.Samples.TownNpcRenderer residents=null;
UnityEngine.RenderTexture target=null;UnityEngine.Texture2D pixels=null,image=null;
var previous=UnityEngine.RenderTexture.active;
try{
    var host=new UnityEngine.GameObject("TrialGroundPreview");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(host,scene);
    for(var i=0;i<2;i++){
        var light=new UnityEngine.GameObject("TrialLight"+i).AddComponent<UnityEngine.Light>();light.transform.SetParent(host.transform,false);
        light.type=UnityEngine.LightType.Directional;light.intensity=i==0?1.15f:.38f;light.color=i==0?new UnityEngine.Color(1,.94f,.82f):new UnityEngine.Color(.78f,.86f,1);
        light.transform.rotation=UnityEngine.Quaternion.Euler(i==0?new UnityEngine.Vector3(50,-35,0):new UnityEngine.Vector3(35,145,0));
        light.shadows=UnityEngine.LightShadows.None;
    }
    var camera=new UnityEngine.GameObject("TrialCamera").AddComponent<UnityEngine.Camera>();camera.transform.SetParent(host.transform,false);
    ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
    camera.scene=scene;camera.enabled=false;camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
    camera.orthographic=true;camera.orthographicSize=19;camera.aspect=1600f/1100;camera.nearClipPlane=.1f;camera.farClipPlane=300;
    camera.clearFlags=UnityEngine.CameraClearFlags.SolidColor;camera.backgroundColor=new UnityEngine.Color(.12f,.16f,.19f);
    var focus=layout.Cells[layout.Rooms[0].CenterIndex].Position+UnityEngine.Vector3.up*.8f;
    var rotation=UnityEngine.Quaternion.Euler(55,-25,0);camera.transform.SetPositionAndRotation(focus-rotation*UnityEngine.Vector3.forward*100,rotation);
    renderer=new ProjectY.Samples.MapAreaRenderer(shader,models[layout.AssetId],layout,asset=>models[asset.Id]);
    residents=new ProjectY.Samples.TownNpcRenderer(host.transform,pawnRig,layout,part=>{
        if(!pawnModels.ContainsKey(part.Id) || UnityEditor.AssetDatabase.GetAssetPath(pawnModels[part.Id])!=part.Path)
            throw new System.InvalidOperationException("Stale trial pawn binding: "+part.Id);
        return pawnModels[part.Id];
    });
    residents.Tick(0);residents.LateTick(camera);
    var all=new int[layout.Cells.Length];for(var i=0;i<all.Length;i++)all[i]=i;
    renderer.UpdateVisibility(new ProjectY.Samples.MapAreaViewData.State{Known=all,Visible=all,Members=new ProjectY.Samples.MapAreaViewData.Member[0],Revision=1},true);
    target=new UnityEngine.RenderTexture(1600,1100,24,UnityEngine.RenderTextureFormat.ARGBHalf,UnityEngine.RenderTextureReadWrite.Linear);target.Create();camera.targetTexture=target;
    pixels=new UnityEngine.Texture2D(1600,1100,UnityEngine.TextureFormat.RGBAFloat,false,true);
    image=new UnityEngine.Texture2D(1600,1100,UnityEngine.TextureFormat.RGB24,false);
    renderer.Draw(camera);ProjectY.Rendering.UrpCameraRendering.Render(camera);
    UnityEngine.RenderTexture.active=target;pixels.ReadPixels(new UnityEngine.Rect(0,0,1600,1100),0,0);pixels.Apply();
    var linear=pixels.GetPixels();var encoded=new UnityEngine.Color32[linear.Length];for(var i=0;i<linear.Length;i++)encoded[i]=linear[i].gamma;
    image.SetPixels32(encoded);image.Apply();
    var path=System.IO.Path.Combine(root,"Docs/Previews/KnightTrial.png");System.IO.Directory.CreateDirectory(System.IO.Path.GetDirectoryName(path));
    System.IO.File.WriteAllBytes(path,image.EncodeToPNG());camera.targetTexture=null;
    return new {image=path,areaType=layout.AreaType,cells=layout.Cells.Length,props=layout.Props.Length,npcs=layout.Npcs.Length,previewScene=true,playMode=false};
}finally{
    UnityEngine.RenderTexture.active=previous;
    if(residents!=null)residents.Dispose();
    if(renderer!=null)renderer.Dispose();
    if(target!=null){target.Release();UnityEngine.Object.DestroyImmediate(target);}
    if(pixels!=null)UnityEngine.Object.DestroyImmediate(pixels);if(image!=null)UnityEngine.Object.DestroyImmediate(image);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
    if(UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=original || original.isDirty!=wasDirty)
        throw new System.InvalidOperationException("Trial preview changed the active scene state.");
}
