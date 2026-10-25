// Execute once in the existing Editor after compilation. No Play, live Data or player saves.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.InvalidOperationException("Edit Mode required");
var originalScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();var dirty=originalScene.isDirty;
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();var previousTarget=RenderTexture.active;
var areas=new System.Collections.Generic.List<ProjectY.Samples.MapAreaViewData>();
var names=new System.Collections.Generic.List<string>();var entries=new System.Collections.Generic.List<int>();
ProjectY.Samples.MapPreviewData world;
using(var lua=new XLua.LuaEnv())
{
    var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);
    using(var root=(XLua.LuaTable)lua.DoString(System.IO.File.ReadAllText("Tools/Tests/terrain_wonders_preview.lua"))[0])
    {
        using(var data=root.Get<XLua.LuaTable>("world")) world=ProjectY.Samples.MapPreviewData.Read(data);
        using(var rows=root.Get<XLua.LuaTable>("areas")) for(int i=1;i<=rows.Length;i++) using(var row=rows.Get<int,XLua.LuaTable>(i))
        using(var layout=row.Get<XLua.LuaTable>("layout"))
        { areas.Add(ProjectY.Samples.MapAreaViewData.Read(layout));names.Add(row.Get<string>("name"));entries.Add(row.Get<int>("entry")-1); }
    }
}
var folder="Docs/Previews/TerrainWonders";System.IO.Directory.CreateDirectory(folder);
if(world.GenerationVersion>=8 && System.Array.Exists(world.Cells,cell=>cell.SurfaceCorners!=null))
    throw new System.Exception("World mountain style must retain the flat hex-column tops");
for(int i=0;i<areas.Count;i++)if(names[i]=="HighMountain" && System.Array.Exists(areas[i].Cells,cell=>cell.UsesSurfaceMesh))
    throw new System.Exception("Ascent area must retain flat hex platforms");
Camera camera=null;RenderTexture target=null;Texture2D pixels=null;
var errors=new System.Collections.Generic.List<string>();
Application.LogCallback log=(message,trace,type)=>{if(type==LogType.Error||type==LogType.Exception)errors.Add(message);};
Application.logMessageReceived+=log;
var paths=new System.Collections.Generic.List<string>();
try
{
    var host=new GameObject("Terrain wonders preview");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(host,scene);
    var go=new GameObject("Preview camera",typeof(Camera));go.transform.SetParent(host.transform,false);camera=go.GetComponent<Camera>();
    camera.scene=scene;camera.enabled=false;camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
    camera.orthographic=true;camera.aspect=1.6f;camera.nearClipPlane=.1f;camera.farClipPlane=1000;
    camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.13f,.18f,.23f);
    ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
    var lamp=new GameObject("Preview sun",typeof(Light));lamp.transform.SetParent(host.transform,false);
    var sun=lamp.GetComponent<Light>();sun.type=LightType.Directional;sun.intensity=1.6f;sun.color=new Color(1,.95f,.87f);sun.transform.rotation=Quaternion.Euler(48,-35,0);
    target=new RenderTexture(1440,900,24,RenderTextureFormat.ARGB32,RenderTextureReadWrite.sRGB);target.Create();camera.targetTexture=target;
    pixels=new Texture2D(1440,900,TextureFormat.RGB24,false);
    var shader=UnityEditor.AssetDatabase.LoadAssetAtPath<Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
    System.Action<string> capture=name=>{
        ProjectY.Rendering.UrpCameraRendering.Render(camera);RenderTexture.active=target;pixels.ReadPixels(new Rect(0,0,1440,900),0,0);pixels.Apply();
        var colors=pixels.GetPixels32();int changed=0,pink=0;var background=colors[0];
        foreach(var c in colors){if(Mathf.Abs(c.r-background.r)+Mathf.Abs(c.g-background.g)+Mathf.Abs(c.b-background.b)>24)changed++;if(c.r>230&&c.b>230&&c.g<30)pink++;}
        if(changed<5000||pink>0)throw new System.Exception("Empty or missing material preview: "+name);
        var path=folder+"/"+name+".png";System.IO.File.WriteAllBytes(path,pixels.EncodeToPNG());paths.Add(path);
    };
    using(var renderer=new ProjectY.Samples.MapPreviewRenderer(shader,host.transform))
    {
        renderer.Build(world,asset=>UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(asset.Path));
        if(world.Clouds.Length==0)throw new System.Exception("Missing mountain cloud banks");
        foreach(var kind in new[]{12,13})
        {
            var cells=world.Cells.Where(cell=>cell.SurfaceA==kind).ToArray();
            var center=cells.Select(cell=>cell.Position).Aggregate(Vector3.zero,(a,b)=>a+b)/cells.Length;
            var bounds=new Bounds(center,Vector3.zero);foreach(var cell in cells)bounds.Encapsulate(cell.Position);
            center=bounds.center;
            camera.orthographicSize=kind==12?Mathf.Max(22,Mathf.Max(bounds.size.x/(2*camera.aspect)*1.15f,Mathf.Max(bounds.size.z*.5f,bounds.size.y*.9f))):Mathf.Max(23,bounds.size.x*.5f);
            camera.transform.position=center+(kind==12?new Vector3(100,100,-145):new Vector3(0,180,-30));camera.transform.LookAt(center);
            renderer.Draw(camera,true,true,true,true);capture(kind==12?"world-high-mountain":"world-canyon");
            if(kind==12) { renderer.Draw(camera,true,true,true,false);capture("world-high-mountain-terrain-only"); }
        }
        var tree=world.Decorations.FirstOrDefault(item=>item.Wonder);
        if(tree!=null)
        {
            var center=world.Cells[tree.Cell].Position+Vector3.up*18;
            camera.orthographicSize=26;camera.transform.position=center+new Vector3(55,42,85);camera.transform.LookAt(center);
            renderer.Draw(camera,true,true,true,true);capture("world-giant-tree");
        }
    }
    for(int i=0;i<areas.Count;i++)
    {
        var area=areas[i];
        using(var renderer=new ProjectY.Samples.MapAreaRenderer(shader,UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(area.AssetPath),area,
            asset=>UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(asset.Path)))
        {
            var indices=System.Linq.Enumerable.Range(0,area.Cells.Length).ToArray();
            renderer.UpdateVisibility(new ProjectY.Samples.MapAreaViewData.State {Revision=1,Known=indices,Visible=indices,Members=System.Array.Empty<ProjectY.Samples.MapAreaViewData.Member>()},true);
            var center=area.Cells[entries[i]].Position;
            if(i==0)center=renderer.Bounds.center;
            else if(i==1)center=area.Cells[entries[i]].Position+new Vector3(0,10,24);
            else center=area.Props.First(prop=>prop.AssetId==1108).Position+new Vector3(0,9,-16);
            camera.orthographicSize=i==0?65:i==1?28:24;
            camera.transform.position=center+(i==2?new Vector3(35,25,-60):new Vector3(40,65,-85));camera.transform.LookAt(center);
            renderer.Draw(camera);capture("area-"+names[i]);
        }
    }
    if(errors.Count>0)throw new System.Exception(string.Join("; ",errors));
    return new {worldCells=world.Cells.Length,clouds=world.Clouds.Length,wonders=world.Decorations.Count(item=>item.Wonder),areas=areas.Count,paths,playMode=false};
}
finally
{
    if(camera!=null)camera.targetTexture=null;RenderTexture.active=previousTarget;
    if(target!=null){target.Release();UnityEngine.Object.DestroyImmediate(target);}if(pixels!=null)UnityEngine.Object.DestroyImmediate(pixels);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);Application.logMessageReceived-=log;
    if(UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=originalScene||originalScene.isDirty!=dirty)throw new System.Exception("Preview changed active scene");
}
