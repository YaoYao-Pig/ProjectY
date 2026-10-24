// MCP execute_code body: actual generated map, saved scene bindings and renderer; no Play or player save writes.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.InvalidOperationException("Edit Mode required");
var originalScene = UnityEngine.SceneManagement.SceneManager.GetActiveScene();
var originalDirty = originalScene.isDirty;
var scene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var previousTarget = RenderTexture.active;
ProjectY.Samples.MapPreviewRenderer renderer = null;
Camera camera = null; RenderTexture target = null; Texture2D pixels = null;
var errors = new System.Collections.Generic.List<string>();
Application.LogCallback log = (message, trace, kind) => { if (kind == LogType.Error || kind == LogType.Exception) errors.Add(message); };
Application.logMessageReceived += log;
var folder = "Docs/Previews/MapEcology";
System.Action<bool,string> check = (ok,message) => { if (!ok) throw new System.Exception(message); };
var flags = System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic;
System.Func<object,string,object> field = (value,name) => value.GetType().GetField(name,flags).GetValue(value);
try
{
    ProjectY.Samples.MapPreviewData map;
    using (var lua = new XLua.LuaEnv())
    {
        var loader = new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot); lua.AddLoader(loader.Load);
        using (var data = (XLua.LuaTable)lua.DoString(System.IO.File.ReadAllText("Tools/Tests/map_ecology.lua"), "@map_ecology")[0])
            map = ProjectY.Samples.MapPreviewData.Read(data);
    }
    var demo = originalScene.GetRootGameObjects().SelectMany(root => root.GetComponentsInChildren<ProjectY.Samples.AdventureRuntimeDemo>(true)).Single();
    var bindingField = new UnityEditor.SerializedObject(demo).FindProperty("assetBindings");
    var bindings = new System.Collections.Generic.Dictionary<int,GameObject>();
    for (int i=0;i<bindingField.arraySize;i++)
    {
        var row=bindingField.GetArrayElementAtIndex(i);
        bindings.Add(row.FindPropertyRelative("id").intValue,(GameObject)row.FindPropertyRelative("prefab").objectReferenceValue);
    }
    foreach (var asset in map.Assets) check(bindings.ContainsKey(asset.Id) && bindings[asset.Id]!=null,"Missing saved scene binding: "+asset.Id);
    var host = new GameObject("Ecology preview"); UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(host,scene);
    var cameraObject = new GameObject("Camera"); cameraObject.transform.SetParent(host.transform,false);
    camera = cameraObject.AddComponent<Camera>(); camera.enabled=false; camera.scene=scene;
    camera.overrideSceneCullingMask = UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
    camera.orthographic=true; camera.aspect=1.6f; camera.nearClipPlane=.1f; camera.farClipPlane=600;
    camera.clearFlags=CameraClearFlags.SolidColor; camera.backgroundColor=new Color(.13f,.17f,.19f);
    ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
    var lightObject = new GameObject("Preview sun"); lightObject.transform.SetParent(host.transform,false);
    var sun = lightObject.AddComponent<Light>(); sun.type=LightType.Directional; sun.intensity=1.6f;
    sun.color=new Color(1,.95f,.87f); sun.transform.rotation=Quaternion.Euler(52,-30,0);
    var shader = UnityEditor.AssetDatabase.LoadAssetAtPath<Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
    renderer = new ProjectY.Samples.MapPreviewRenderer(shader,host.transform);
    renderer.Build(map,asset => bindings[asset.Id]);
    var models = (System.Collections.IDictionary)field(renderer,"models");
    int coloredSlots=0;
    foreach (var asset in map.Assets.Where(asset => asset.Id>=1000 && asset.Id<1015))
    {
        var prefab=bindings[asset.Id]; var mesh=prefab.GetComponent<MeshFilter>().sharedMesh;
        var materials=prefab.GetComponent<MeshRenderer>().sharedMaterials;
        foreach (var batch in ((System.Collections.IEnumerable)field(renderer,"batches")).Cast<object>().Where(batch => (Mesh)field(batch,"Mesh")==mesh))
        {
            var source=materials[(int)field(batch,"Submesh")].color;
            var expected=QualitySettings.activeColorSpace==ColorSpace.Linear?source.linear:source;
            var actual=((Vector4[])field(batch,"Colors"))[0];
            check(Vector4.Distance(actual,(Vector4)expected)<.0001f,"Authored material palette was flattened: "+asset.Id);
            coloredSlots++;
        }
    }
    check(coloredSlots>15,"Missing multi-material terrain batches");
    target = new RenderTexture(1440,900,24,RenderTextureFormat.ARGB32,RenderTextureReadWrite.sRGB); target.Create();
    camera.targetTexture=target; pixels=new Texture2D(1440,900,TextureFormat.RGB24,false);
    System.IO.Directory.CreateDirectory(folder);
    for (int kind=6;kind<=11;kind++)
    {
        var center=renderer.Bounds.center;
        var size=Mathf.Max(renderer.Bounds.size.x/(2*camera.aspect),renderer.Bounds.size.z*.55f)*1.12f;
        if (kind>6)
        {
            var cells=map.Cells.Where(cell=>cell.SurfaceA==kind && !cell.HasWater).ToArray();
            check(cells.Length>0,"New biome has no visible dry surface: "+kind);
            center=cells.Select(cell=>cell.Position).Aggregate(Vector3.zero,(a,b)=>a+b)/cells.Length;
            size=10;
        }
        camera.transform.position=center+new Vector3(0,150,-125);camera.transform.LookAt(center);camera.orthographicSize=size;
        renderer.Draw(camera,true,true,true,true);
        ProjectY.Rendering.UrpCameraRendering.Render(camera);
        RenderTexture.active=target;pixels.ReadPixels(new Rect(0,0,1440,900),0,0);pixels.Apply();
        var colors=pixels.GetPixels32();var corner=colors[0];int changed=0,pink=0;
        foreach(var color in colors)
        {
            if(Mathf.Abs(color.r-corner.r)+Mathf.Abs(color.g-corner.g)+Mathf.Abs(color.b-corner.b)>24)changed++;
            if(color.r>230 && color.b>230 && color.g<30)pink++;
        }
        check(changed>10000 && pink==0,"Blank or missing-material ecology preview: "+kind);
        System.IO.File.WriteAllBytes(folder+(kind==6?"/overview.png":"/biome-"+kind+".png"),pixels.EncodeToPNG());
    }
    check(errors.Count==0,"Renderer errors: "+string.Join("; ",errors));
    return new {cells=map.Cells.Length,biomes=map.Surfaces.Length,newAssets=map.Assets.Count(asset=>asset.Id>=1000 && asset.Id<=1035),coloredSlots,previews=folder,playMode=false};
}
finally
{
    renderer?.Dispose();if(camera!=null)camera.targetTexture=null;RenderTexture.active=previousTarget;
    if(target!=null){target.Release();UnityEngine.Object.DestroyImmediate(target);}if(pixels!=null)UnityEngine.Object.DestroyImmediate(pixels);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);Application.logMessageReceived-=log;
    check(UnityEngine.SceneManagement.SceneManager.GetActiveScene()==originalScene && originalScene.isDirty==originalDirty,"Preview changed the active scene");
}
