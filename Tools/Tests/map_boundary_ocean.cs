// Unity MCP method body. Real renderers in an isolated PreviewScene; never enters Play.
const bool shipwreckOnly=false; // Set true for the legacy kind=water surface compatibility check.
const bool captureMotion=false; // Export a short real-rendered close-up sequence when reviewing ripple readability.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)throw new Exception("Idle Editor required");
var original=UnityEngine.SceneManagement.SceneManager.GetActiveScene();bool dirty=original.isDirty;
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var owner=new GameObject("Boundary ocean validation");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(owner,scene);
var camera=new GameObject("Camera").AddComponent<Camera>();camera.transform.SetParent(owner.transform,false);camera.enabled=false;camera.scene=scene;
camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
camera.orthographic=true;camera.aspect=1.6f;camera.nearClipPlane=.1f;camera.farClipPlane=2000;camera.clearFlags=CameraClearFlags.SolidColor;
ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
var sun=new GameObject("Sun").AddComponent<Light>();sun.transform.SetParent(owner.transform,false);sun.type=LightType.Directional;sun.intensity=1.3f;sun.transform.rotation=Quaternion.Euler(50,-30,0);
var target=new RenderTexture(960,600,24,RenderTextureFormat.ARGB32,RenderTextureReadWrite.sRGB);target.Create();camera.targetTexture=target;
var image=new Texture2D(960,600,TextureFormat.RGB24,false);var previous=RenderTexture.active;
ProjectY.Samples.MapPreviewRenderer worldRenderer=null;ProjectY.Samples.MapAreaRenderer areaRenderer=null;
var flags=System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic;
Func<object,string,object> field=(value,name)=>value.GetType().GetField(name,flags).GetValue(value);
Action<bool,string> check=(ok,message)=>{if(!ok)throw new Exception(message);};
var reports=new System.Collections.Generic.List<string>();
string folder="Docs/Previews/MapOcean"+(shipwreckOnly?"/Shipwreck":"");System.IO.Directory.CreateDirectory(folder);
try
{
    using(var lua=new XLua.LuaEnv())
    {
        var services=new ProjectY.FrameworkServices(null);var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
        try
        {
            lua.Global.Set("OceanPreviewShipwreck",shipwreckOnly);
            var snapshots=lua.DoString(System.IO.File.ReadAllText("Tools/Tests/map_boundary_ocean.lua"));
            ProjectY.Samples.MapPreviewData world;ProjectY.Samples.MapAreaViewData area;
            using(var row=(XLua.LuaTable)snapshots[0])world=ProjectY.Samples.MapPreviewData.Read(row);
            using(var row=(XLua.LuaTable)snapshots[1])area=ProjectY.Samples.MapAreaViewData.Read(row);
            var shader=UnityEditor.AssetDatabase.LoadAssetAtPath<Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
            worldRenderer=new ProjectY.Samples.MapPreviewRenderer(shader,owner.transform);
            worldRenderer.Build(world,asset=>UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(asset.Path));
            var exploration=new ProjectY.Data.WorldMapExplorationData();exploration.Reset(world.Cells.Length);
            var allWorld=Enumerable.Range(1,world.Cells.Length).ToArray();exploration.Reveal(allWorld);worldRenderer.SetExploration(exploration);
            ((Material)field(field(worldRenderer,"worldFog"),"material")).SetFloat("_FogPreviewTime",0);
            int revision=exploration.Revision;
            areaRenderer=new ProjectY.Samples.MapAreaRenderer(shader,UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(area.AssetPath),area,asset=>UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(asset.Path));
            var allArea=Enumerable.Range(0,area.Cells.Length).ToArray();
            areaRenderer.UpdateVisibility(new ProjectY.Samples.MapAreaViewData.State{Revision=1,Known=allArea,Visible=allArea,Members=new ProjectY.Samples.MapAreaViewData.Member[0]},true);
            var localWaterCells=area.Cells.Where(c=>c.WaterDepth>0 || c.Kind=="water").ToArray();
            var localWaterMesh=(Mesh)field(field(areaRenderer,"townWater"),"mesh");var waterVertices=localWaterMesh.vertices;
            check(waterVertices.Length==localWaterCells.Length*7,"Local water geometry count changed");
            for(int i=0;i<localWaterCells.Length;i++)
            {
                var cell=localWaterCells[i];float level=cell.WaterDepth>0?cell.WaterLevel:cell.Position.y;
                check(Mathf.Abs(waterVertices[i*7].y-level)<.00001f,"Local water was placed at bed height instead of WaterLevel");
            }
            reports.Add("PASS local water geometry follows explicit WaterLevel; legacy water planes retain their surface elevation");
            foreach(string kind in shipwreckOnly?new[]{"local"}:new[]{"world","local"})
            {
                bool local=kind=="local";worldRenderer.SetVisible(!local);
                object renderer=local?(object)areaRenderer:worldRenderer;
                var boundaryMaterial=(Material)field(field(renderer,"boundary"),"material");boundaryMaterial.SetFloat("_WaterPreviewTime",0);
                var boundaryObject=field(renderer,"boundary");
                var boundaryMesh=(Mesh)field(boundaryObject,"mesh");
                var staticField=(Texture2D)field(boundaryObject,"field");
                check(boundaryMesh.vertexCount==4 && boundaryMesh.GetIndexCount(0)==6,"Ocean adds unexpected geometry");
                check(!staticField.isReadable && staticField.width<=1024 && staticField.height<=1024,"Ocean field retains CPU pixels or exceeds texture budget");
                var drawBoundary=(Action<Camera>)Delegate.CreateDelegate(typeof(Action<Camera>),boundaryObject,boundaryObject.GetType().GetMethod("Draw",flags));
                for(int warm=0;warm<4;warm++)drawBoundary(camera);
                System.GC.GetAllocatedBytesForCurrentThread();
                long allocationStart=System.GC.GetAllocatedBytesForCurrentThread();
                for(int iteration=0;iteration<16;iteration++)drawBoundary(camera);
                long allocated=System.GC.GetAllocatedBytesForCurrentThread()-allocationStart;
                check(allocated==0,"Ocean Draw allocates managed memory: "+allocated);
                reports.Add("PASS "+kind+": 2 ocean triangles, field="+staticField.width+"x"+staticField.height+" ("+(staticField.width*staticField.height*16)+" bytes), 16 warmed Draw calls allocate "+allocated+" bytes, uniform-height fast path="+(boundaryMaterial.GetVector("_OceanParameters").z>.5f));
                check(!UnityEditor.ShaderUtil.ShaderHasError(boundaryMaterial.shader),"Boundary shader error");
                var innerWater=local?(Material)field(field(areaRenderer,"townWater"),"material"):((ProjectY.Samples.MapWaterEffects)field(worldRenderer,"waterEffects")).SurfaceMaterial;
                check(innerWater!=null && !UnityEditor.ShaderUtil.ShaderHasError(innerWater.shader),"Interior water shader error");
                check(innerWater.GetTexture("_WaterBoundaryField")==boundaryMaterial.GetTexture("_WaterBoundaryField"),"Interior water uses a different shoreline/elevation field");
                innerWater.SetFloat("_WaterPreviewTime",0);
                var bounds=local?areaRenderer.Bounds:worldRenderer.Bounds;
                Action<string> capture=name=>
                {
                    // Graphics.DrawMesh submissions live until the next Editor frame. A separate camera per capture
                    // prevents earlier world/local batches from leaking into later captures in this single MCP call.
                    var shot=new GameObject(name).AddComponent<Camera>();shot.transform.SetParent(owner.transform,false);
                    shot.CopyFrom(camera);shot.transform.SetPositionAndRotation(camera.transform.position,camera.transform.rotation);
                    shot.scene=scene;shot.overrideSceneCullingMask=camera.overrideSceneCullingMask;
                    ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(shot);
                    if(local)areaRenderer.Draw(shot);else worldRenderer.Draw(shot,true,true,true,true);
                    ProjectY.Rendering.UrpCameraRendering.Render(shot);RenderTexture.active=target;image.ReadPixels(new Rect(0,0,960,600),0,0);image.Apply();
                    System.IO.File.WriteAllBytes(folder+"/"+name+".png",image.EncodeToPNG());
                };
                camera.orthographic=true;camera.orthographicSize=Mathf.Max(bounds.size.x,bounds.size.z)*.72f;
                var rotation=Quaternion.Euler(50,-35,0);camera.transform.SetPositionAndRotation(bounds.center-rotation*Vector3.forward*800,rotation);
                camera.backgroundColor=Color.magenta;capture(kind+"-overview");
                var first=image.GetPixels32();int pink=0;foreach(var c in first)if(c.r>240 && c.b>240 && c.g<15)pink++;
                check(pink==0,kind+" exposes background or a missing shader");
                camera.backgroundColor=Color.black;capture(kind+"-black-background");var second=image.GetPixels32();
                boundaryMaterial.SetShaderPassEnabled("SRPDefaultUnlit",false);
                capture(kind+"-interior-reference");var baseline=image.GetPixels32();boundaryMaterial.SetShaderPassEnabled("SRPDefaultUnlit",true);
                int middle=300*960+480;
                check(Mathf.Abs(second[middle].r-baseline[middle].r)+Mathf.Abs(second[middle].g-baseline[middle].g)+Mathf.Abs(second[middle].b-baseline[middle].b)<=3,kind+" ocean covers map interior");
                int[] samples={20*960+20,20*960+939,579*960+20,579*960+939};
                foreach(int i in samples)check(Mathf.Abs(first[i].r-second[i].r)+Mathf.Abs(first[i].g-second[i].g)+Mathf.Abs(first[i].b-second[i].b)<=3,kind+" exterior is not opaque");
                boundaryMaterial.SetFloat("_WaterPreviewTime",12);innerWater.SetFloat("_WaterPreviewTime",12);capture(kind+"-moving");var moving=image.GetPixels32();int changed=0;
                // The full-map view deliberately attenuates wave contrast; near-view motion is checked separately below.
                for(int i=0;i<moving.Length;i++)if(Mathf.Abs(moving[i].r-second[i].r)+Mathf.Abs(moving[i].g-second[i].g)+Mathf.Abs(moving[i].b-second[i].b)>2)changed++;
                check(changed>1000,kind+" currents did not animate");
                boundaryMaterial.SetFloat("_WaterPreviewTime",0);innerWater.SetFloat("_WaterPreviewTime",0);camera.orthographicSize*=2.5f;rotation=Quaternion.Euler(38,145,0);camera.transform.SetPositionAndRotation(bounds.center-rotation*Vector3.forward*800,rotation);capture(kind+"-far-rotated");
                var farBlack=image.GetPixels32();camera.backgroundColor=Color.magenta;capture(kind+"-far-background-check");var farPink=image.GetPixels32();
                // Water/highlight animation may differ by a few 8-bit levels between render requests.
                for(int i=0;i<farBlack.Length;i++)check(Mathf.Abs(farBlack[i].r-farPink[i].r)+Mathf.Abs(farBlack[i].g-farPink[i].g)+Mathf.Abs(farBlack[i].b-farPink[i].b)<=18,kind+" far view exposes background at "+i);
                camera.backgroundColor=Color.black;
                camera.orthographic=false;camera.fieldOfView=50;rotation=Quaternion.Euler(40,35,0);camera.transform.SetPositionAndRotation(bounds.center-rotation*Vector3.forward*(bounds.size.magnitude*1.2f),rotation);capture(kind+"-perspective");
                camera.orthographic=true;camera.orthographicSize=(local?area.Radius:world.Radius)*15;
                var wet=local?area.Cells.Where(c=>c.WaterDepth>0 || c.Kind=="water").Select(c=>new Vector3(c.Position.x,c.WaterDepth>0?c.WaterLevel:c.Position.y,c.Position.z)).ToArray():world.Cells.Where(c=>c.HasWater).Select(c=>new Vector3(c.Position.x,c.WaterLevel,c.Position.z)).ToArray();
                var edge=local?wet.Aggregate(Vector3.zero,(sum,p)=>sum+p)/wet.Length:wet.OrderBy(p=>p.x).First();
                var focus=edge;rotation=Quaternion.Euler(50,-35,0);
                camera.transform.SetPositionAndRotation(focus-rotation*Vector3.forward*800,rotation);capture(kind+"-shore");
                var shoreBefore=image.GetPixels32();boundaryMaterial.SetFloat("_WaterPreviewTime",4);innerWater.SetFloat("_WaterPreviewTime",4);
                capture(kind+"-shore-moving");var shoreAfter=image.GetPixels32();int movingWater=0;
                for(int i=0;i<shoreAfter.Length;i++)
                {
                    var c=shoreBefore[i];
                    if(c.g>c.r+8 && c.b>c.r+8 && Mathf.Abs(c.r-shoreAfter[i].r)+Mathf.Abs(c.g-shoreAfter[i].g)+Mathf.Abs(c.b-shoreAfter[i].b)>6)movingWater++;
                }
                check(movingWater>500,kind+" close water has no visible animated lighting: "+movingWater);
                boundaryMaterial.SetFloat("_WaterPreviewTime",0);innerWater.SetFloat("_WaterPreviewTime",0);
                reports.Add("PASS "+kind+": close-view animated water lighting affects "+movingWater+" water-colored pixels");
                if(captureMotion && !local)
                {
                    System.IO.Directory.CreateDirectory(folder+"/Motion");
                    for(int frame=0;frame<24;frame++)
                    {
                        boundaryMaterial.SetFloat("_WaterPreviewTime",frame*.18f);innerWater.SetFloat("_WaterPreviewTime",frame*.18f);
                        capture("Motion/world-"+frame.ToString("D2"));
                    }
                    boundaryMaterial.SetFloat("_WaterPreviewTime",0);innerWater.SetFloat("_WaterPreviewTime",0);
                }
                if(!local)
                {
                    var partial=new ProjectY.Data.WorldMapExplorationData();partial.Reset(world.Cells.Length);partial.Reveal(allWorld.Take(64).ToArray());
                    worldRenderer.SetExploration(partial);
                    ((Material)field(field(worldRenderer,"worldFog"),"material")).SetFloat("_FogPreviewTime",0);
                    camera.orthographicSize=Mathf.Max(bounds.size.x,bounds.size.z)*.58f;
                    camera.transform.SetPositionAndRotation(bounds.center-rotation*Vector3.forward*800,rotation);capture("world-exploration-contrast");
                    int gray=0;foreach(var c in image.GetPixels32())if(c.r>80 && c.r<c.b && c.b-c.r<55 && c.g-c.r<40)gray++;
                    check(gray>10000,"Boundary ocean overpainted the exploration clouds");
                    worldRenderer.SetExploration(exploration);reports.Add("PASS gray exploration clouds remain visible above the blue ocean; inner and outer water share the same field");
                }
                reports.Add("PASS "+kind+": opaque exterior, animated currents ("+changed+" pixels), far zoom/rotation and perspective captures");
            }
            check(exploration.Revision==revision && exploration.VisibleCount==world.Cells.Length,"Boundary ocean changed exploration state");
            check(!UnityEditor.ShaderUtil.ShaderHasError(Resources.Load<Shader>("WorldFog")),"World fog shader error");
            reports.Add("PASS exploration state unchanged; existing world fog shader compiled");
        }
        finally
        {
            using(var shutdown=lua.Global.Get<XLua.LuaFunction>("GameShutdown"))if(shutdown!=null)shutdown.Call();
            lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();
        }
    }
}
finally
{
    worldRenderer?.Dispose();areaRenderer?.Dispose();foreach(var shot in owner.GetComponentsInChildren<Camera>())shot.targetTexture=null;RenderTexture.active=previous;
    target.Release();UnityEngine.Object.DestroyImmediate(target);UnityEngine.Object.DestroyImmediate(image);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
    if(UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=original)UnityEngine.SceneManagement.SceneManager.SetActiveScene(original);
    if(original.isDirty!=dirty)throw new Exception("Boundary preview dirtied the original scene");
}
reports.Add("PASS original scene and Edit Mode preserved");
string report=string.Join("\n",reports);System.IO.File.WriteAllText(folder+"/validation.txt",report);return report;
