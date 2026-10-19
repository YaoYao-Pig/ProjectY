// Unity MCP execute_code body. Run after import_map_ground.cs; no Play session or scene save.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.InvalidOperationException("Edit Mode required");
var originalScene = UnityEngine.SceneManagement.SceneManager.GetActiveScene();
bool originalDirty = originalScene.isDirty;
var oldTarget = RenderTexture.active;
var scene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var logErrors = new System.Collections.Generic.List<string>();
Application.LogCallback log = (message, trace, type) => { if (type == LogType.Error || type == LogType.Exception) logErrors.Add(message); };
Application.logMessageReceived += log;
ProjectY.Samples.MapPreviewRenderer renderer = null;
Camera camera = null; RenderTexture target = null; Texture2D image = null;
int covers = 0, changedPixels = 0; string folder = "Docs/Previews/Rendering";
System.Action<bool,string> check = (valid,message) => { if (!valid) throw new System.Exception(message); };
System.Func<object,string,object> field = (value,name) => value.GetType().GetField(name,
    System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic).GetValue(value);
System.Func<string,Color> parseColor = value => { Color result; if (!ColorUtility.TryParseHtmlString(value,out result)) throw new System.Exception("Invalid color"); return result; };
try
{
    var source = Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText(folder + "/map-ground-layout.json"));
    var map = new ProjectY.Samples.MapPreviewData {
        Radius = (float)source["hexRadius"], Seed = (uint)source["seed"],
        Cells = source["cells"].Select(row => new ProjectY.Samples.MapPreviewData.Cell {
            Position = new Vector3((float)row["x"],(float)row["y"],(float)row["z"]),
            Color = new Color((float)row["groundColor"][0],(float)row["groundColor"][1],(float)row["groundColor"][2]),
            HasWater = (bool)row["hasWater"], IsRiver = (bool)row["isRiver"], WaterLevel = (float)row["waterLevel"],
            WaterDepth = (float)row["waterDepth"], FlowTo = (int)row["flowTo"] - 1, RiverId = (int)row["riverId"],
            TerrainAssetId = (int)row["terrainAssetId"], WaterAssetId = (int)row["waterAssetId"],
            SurfaceA = (int)row["surfaceA"], SurfaceB = (int)row["surfaceB"], SurfaceBlend = (float)row["surfaceBlend"],
            Neighbors = row["neighbors"].Select(n => (int)n - 1).ToArray() }).ToArray(),
        Assets = source["assets"].Select(row => new ProjectY.Samples.MapPreviewData.Asset {
            Id=(int)row["id"], Path=(string)row["prefabPath"], TintMaterial=(string)row["tintMaterial"], ReferenceHeight=(float)row["referenceHeight"] }).ToArray(),
        Surfaces = source["surfaces"].Select(row => new ProjectY.Samples.MapPreviewData.Surface {
            Id=(int)row["id"], GroundTexture=(string)row["groundTexture"], Color=parseColor((string)row["groundColor"]),
            TextureWorldSize=(float)row["textureWorldSize"], TextureStrength=(float)row["textureStrength"], WindStrength=(float)row["windStrength"] }).ToArray(),
        Groundcover = source["groundcover"].Select(row => new ProjectY.Samples.MapPreviewData.Cover {
            Cell=(int)row["cell"]-1, Kind=(int)row["kind"], OffsetX=(float)row["offsetX"], OffsetZ=(float)row["offsetZ"],
            Scale=(float)row["scale"], Yaw=(float)row["yaw"], Phase=(float)row["phase"] }).ToArray(),
        Decorations = source["decorations"].Select(row => new ProjectY.Samples.MapPreviewData.Decoration {
            Cell=(int)row["cell"]-1, AssetId=(int)row["assetId"], Scale=(float)row["scale"], Yaw=(float)row["yaw"], Height=(float)row["height"] }).ToArray(),
        Roads = source["roads"].Select(row => new ProjectY.Samples.MapPreviewData.Road {
            Kind=(string)row["kind"], Cells=row["cells"].Select(n=>(int)n-1).ToArray() }).ToArray(),
        Towns=System.Array.Empty<ProjectY.Samples.MapPreviewData.Town>(), Buildings=System.Array.Empty<ProjectY.Samples.MapPreviewData.Building>(),
        Waterfalls=System.Array.Empty<ProjectY.Samples.MapPreviewData.Waterfall>()
    };
    var host = new GameObject("Ground Presentation Preview"); UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(host, scene);
    var cameraObject = new GameObject("Camera"); cameraObject.transform.SetParent(host.transform,false);
    camera = cameraObject.AddComponent<Camera>(); camera.enabled=false; camera.scene=scene;
    camera.overrideSceneCullingMask = UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
    camera.orthographic=true; camera.aspect=1.6f; camera.nearClipPlane=.1f; camera.farClipPlane=150;
    camera.clearFlags=CameraClearFlags.SolidColor; camera.backgroundColor=new Color(.13f,.18f,.21f);
    ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
    var lightObject=new GameObject("Warm Sun"); lightObject.transform.SetParent(host.transform,false);
    var sun=lightObject.AddComponent<Light>(); sun.type=LightType.Directional; sun.intensity=1.6f;
    sun.color=new Color(1,.95f,.87f); sun.transform.rotation=Quaternion.Euler(52,-30,0);
    var shader=UnityEditor.AssetDatabase.LoadAssetAtPath<Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
    renderer=new ProjectY.Samples.MapPreviewRenderer(shader,host.transform);
    System.Func<ProjectY.Samples.MapPreviewData.Asset,GameObject> resolve=asset=>UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(asset.Path);
    renderer.Build(map,resolve);
    var ground=(ProjectY.Samples.MapGroundPresentation)field(renderer,"groundPresentation");
    var nature=(ProjectY.Samples.MapNatureRenderer)field(renderer,"natureRenderer");
    var water=(ProjectY.Samples.MapWaterEffects)field(renderer,"waterEffects");
    var oldArray=(Texture2DArray)field(ground,"textures");
    renderer.Build(map,resolve); check(oldArray==null,"Rebuild leaked the previous ground array");
    var textureArray=(Texture2DArray)field(ground,"textures");
    check(textureArray.depth==map.Surfaces.Length+1,"Ground array layer contract mismatch");
    var meshes=(Mesh[])field(nature,"meshes");
    check(meshes.Length==15,"Missing shared nature mesh variants");
    var proxies=new GameObject("Batch Preview Proxies"); proxies.transform.SetParent(host.transform,false);
    var batches=((System.Collections.IEnumerable)field(renderer,"batches")).Cast<object>().ToArray();
    foreach(var batch in batches)
    {
        if((int)field(batch,"Submesh")!=0)continue;
        var mesh=(Mesh)field(batch,"Mesh"); var kind=(ProjectY.Samples.MapPreviewRenderer.Kind)field(batch,"Kind");
        var slots=Enumerable.Range(0,mesh.subMeshCount).Select(slot=>batches.Single(b=>(Mesh)field(b,"Mesh")==mesh
            && (ProjectY.Samples.MapPreviewRenderer.Kind)field(b,"Kind")==kind && (int)field(b,"Submesh")==slot)).ToArray();
        var material=kind==ProjectY.Samples.MapPreviewRenderer.Kind.Terrain?ground.Material:
            kind==ProjectY.Samples.MapPreviewRenderer.Kind.Water?water.SurfaceMaterial:(Material)field(renderer,"material");
        var matrices=(Matrix4x4[])field(batch,"Matrices");
        for(int i=0;i<(int)field(batch,"Count");i++)
        {
            var proxy=new GameObject("Terrain/model",typeof(MeshFilter),typeof(MeshRenderer)); proxy.transform.SetParent(proxies.transform,false);
            proxy.transform.SetPositionAndRotation(matrices[i].GetColumn(3),matrices[i].rotation); proxy.transform.localScale=matrices[i].lossyScale;
            proxy.GetComponent<MeshFilter>().sharedMesh=mesh;
            var view=proxy.GetComponent<MeshRenderer>(); view.sharedMaterials=Enumerable.Repeat(material,slots.Length).ToArray();
            view.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;
            for(int slot=0;slot<slots.Length;slot++)
            {
                var properties=new MaterialPropertyBlock(); properties.SetVector("_Color",((Vector4[])field(slots[slot],"Colors"))[i]);
                if(kind==ProjectY.Samples.MapPreviewRenderer.Kind.Terrain)properties.SetVector("_GroundData",((Vector4[])field(slots[slot],"GroundData"))[i]);
                if(kind==ProjectY.Samples.MapPreviewRenderer.Kind.Water)properties.SetVector("_WaterFlow",((Vector4[])field(slots[slot],"WaterFlows"))[i]);
                view.SetPropertyBlock(properties,slot);
            }
        }
    }
    var nodes=new System.Collections.Generic.Stack<object>(); var root=field(nature,"root"); if(root!=null)nodes.Push(root);
    while(nodes.Count>0)
    {
        var node=nodes.Pop(); var bucket=field(node,"Bucket");
        if(bucket==null){nodes.Push(field(node,"Left"));nodes.Push(field(node,"Right"));continue;}
        foreach(object batch in (System.Collections.IEnumerable)field(bucket,"Batches"))
        {
            var matrices=(Matrix4x4[])field(batch,"Matrices"); var colors=(Vector4[])field(batch,"Tints"); var data=(Vector4[])field(batch,"Data");
            for(int i=0;i<(int)field(batch,"Count");i++)
            {
                var proxy=new GameObject("Nature",typeof(MeshFilter),typeof(MeshRenderer)); proxy.transform.SetParent(proxies.transform,false);
                proxy.transform.SetPositionAndRotation(matrices[i].GetColumn(3),matrices[i].rotation);proxy.transform.localScale=matrices[i].lossyScale;
                proxy.GetComponent<MeshFilter>().sharedMesh=meshes[(int)field(batch,"MeshIndex")];
                var view=proxy.GetComponent<MeshRenderer>();view.sharedMaterial=nature.SharedMaterial;view.shadowCastingMode=UnityEngine.Rendering.ShadowCastingMode.Off;
                var properties=new MaterialPropertyBlock();properties.SetVector("_NatureTint",colors[i]);properties.SetVector("_NatureData",data[i]);view.SetPropertyBlock(properties);covers++;
            }
        }
    }
    check(covers==map.Groundcover.Length,"Nature Build lost generated placements");
    renderer.SetVisible(false); check(!(bool)field(nature,"visible"),"Nature did not hide with world map"); renderer.SetVisible(true);
    target=new RenderTexture(1280,800,24,RenderTextureFormat.ARGB32,RenderTextureReadWrite.sRGB); target.Create(); camera.targetTexture=target;
    image=new Texture2D(1280,800,TextureFormat.RGB24,false);
    var center=renderer.Bounds.center; camera.transform.position=center+new Vector3(0,30,-26);camera.transform.LookAt(center);
    camera.orthographicSize=Mathf.Max(renderer.Bounds.size.x/(2*camera.aspect),renderer.Bounds.size.z*.55f)*1.06f;
    ground.Material.SetFloat("_GroundPreviewTime",0);nature.SharedMaterial.SetFloat("_NaturePreviewTime",0);water.SurfaceMaterial.SetFloat("_WaterPreviewTime",0);
    ProjectY.Rendering.UrpCameraRendering.Render(camera);RenderTexture.active=target;image.ReadPixels(new Rect(0,0,1280,800),0,0);image.Apply();
    System.IO.Directory.CreateDirectory(folder);System.IO.File.WriteAllBytes(folder+"/map-ground-overview.png",image.EncodeToPNG());
    camera.targetTexture=null;target.Release();UnityEngine.Object.DestroyImmediate(target);UnityEngine.Object.DestroyImmediate(image);
    target=new RenderTexture(800,500,24,RenderTextureFormat.ARGB32,RenderTextureReadWrite.sRGB);target.Create();camera.targetTexture=target;image=new Texture2D(800,500,TextureFormat.RGB24,false);
    var butterfly=map.Groundcover.First(c=>c.Kind==4);center=map.Cells[butterfly.Cell].Position+new Vector3(butterfly.OffsetX,.2f,butterfly.OffsetZ);
    camera.transform.position=center+new Vector3(3,5,-7);camera.transform.LookAt(center);camera.orthographicSize=2.2f;
    Color32[] before=null;System.IO.Directory.CreateDirectory("Temp/GroundPresentation/frames");
    for(int frame=0;frame<36;frame++)
    {
        float time=frame/12f;ground.Material.SetFloat("_GroundPreviewTime",time);nature.SharedMaterial.SetFloat("_NaturePreviewTime",time);water.SurfaceMaterial.SetFloat("_WaterPreviewTime",time);
        ProjectY.Rendering.UrpCameraRendering.Render(camera);RenderTexture.active=target;image.ReadPixels(new Rect(0,0,800,500),0,0);image.Apply();
        if(frame==0)before=image.GetPixels32();
        System.IO.File.WriteAllBytes("Temp/GroundPresentation/frames/frame-"+frame.ToString("D3")+".png",image.EncodeToPNG());
    }
    var after=image.GetPixels32();int pink=0;
    for(int i=0;i<after.Length;i++)
    {
        if(after[i].r>230&&after[i].b>230&&after[i].g<30)pink++;
        if(Mathf.Abs(after[i].r-before[i].r)+Mathf.Abs(after[i].g-before[i].g)+Mathf.Abs(after[i].b-before[i].b)>8)changedPixels++;
    }
    check(pink==0&&changedPixels>200,"Nature motion preview did not change or has missing shader");
    System.IO.File.WriteAllBytes(folder+"/map-ground-meadow.png",image.EncodeToPNG());
    check(!UnityEditor.ShaderUtil.ShaderHasError(ground.Material.shader)&&!UnityEditor.ShaderUtil.ShaderHasError(nature.SharedMaterial.shader),"Ground/nature shader error");
    var groundMaterial=ground.Material;var natureMaterial=nature.SharedMaterial;UnityEngine.Object.DestroyImmediate(proxies);
    renderer.Dispose();renderer=null;
    check(textureArray==null&&groundMaterial==null&&natureMaterial==null&&meshes.All(m=>m==null),"Ground presentation leaked owned resources");
    check(logErrors.Count==0,"Render errors: "+string.Join("; ",logErrors.ToArray()));
}
finally
{
    if(renderer!=null)renderer.Dispose();
    if(camera!=null)camera.targetTexture=null;RenderTexture.active=oldTarget;
    if(target!=null){target.Release();UnityEngine.Object.DestroyImmediate(target);}if(image!=null)UnityEngine.Object.DestroyImmediate(image);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);Application.logMessageReceived-=log;
    check(UnityEngine.SceneManagement.SceneManager.GetActiveScene()==originalScene&&originalScene.isDirty==originalDirty,"Preview changed user's scene state");
}
return new { covers, changedPixels, frames=36, rebuilt=true, disposed=true, restored=true, playMode=false };
