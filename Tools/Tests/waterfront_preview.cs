// Targeted static waterfront preview in an isolated scene; no Play, game clock or save writes.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Editor required");
var original=UnityEngine.SceneManagement.SceneManager.GetActiveScene();bool dirty=original.isDirty;
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();var root=new GameObject("WaterfrontGeometryReview");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
var host=root.AddComponent<ProjectY.UI.UIHost>();host.Initialize();float timeScale=Time.timeScale;
var previous=RenderTexture.active;ProjectY.Samples.MapAreaRenderer renderer=null;RenderTexture texture=null;Texture2D pixels=null;
var reports=new System.Collections.Generic.List<object>();
try
{
    using(var lua=new XLua.LuaEnv())
    {
        var services=new ProjectY.FrameworkServices(host,System.IO.Path.Combine(System.IO.Path.GetTempPath(),"waterfront-preview-"+System.Guid.NewGuid().ToString("N")+".json"));
        var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
        try
        {
            using(var rows=(XLua.LuaTable)lua.DoString(System.IO.File.ReadAllText("Tools/Tests/waterfront_preview.lua"),"@waterfront_preview.lua")[0])
            {
                var cameraObject=new GameObject("Waterfront camera",typeof(Camera));cameraObject.transform.SetParent(root.transform,false);var camera=cameraObject.GetComponent<Camera>();camera.enabled=false;camera.scene=scene;
                camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);camera.orthographic=true;camera.aspect=1.6f;camera.nearClipPlane=.1f;camera.farClipPlane=700;
                camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.22f,.28f,.3f);ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
                var lightObject=new GameObject("Waterfront sun",typeof(Light));lightObject.transform.SetParent(root.transform,false);var sun=lightObject.GetComponent<Light>();sun.type=LightType.Directional;sun.intensity=1.4f;sun.transform.rotation=Quaternion.Euler(45,-30,0);
                texture=new RenderTexture(1600,1000,24,RenderTextureFormat.ARGB32,RenderTextureReadWrite.sRGB);texture.Create();camera.targetTexture=texture;
                for(int rowIndex=1;rowIndex<=1;rowIndex++)using(var row=rows.Get<int,XLua.LuaTable>(rowIndex))using(var layout=row.Get<XLua.LuaTable>("layout"))
                {
                    var map=ProjectY.Samples.MapAreaViewData.Read(layout);var all=new int[map.Cells.Length];for(int i=0;i<all.Length;i++)all[i]=i;
                    renderer=new ProjectY.Samples.MapAreaRenderer(Shader.Find("ProjectY/Map Preview Instanced"),UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(map.AssetPath),map,asset=>UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(asset.Path));
                    renderer.UpdateVisibility(new ProjectY.Samples.MapAreaViewData.State{Revision=1,ConstructionRevision=0,Known=all,Visible=all,Members=new ProjectY.Samples.MapAreaViewData.Member[0]},true);
                    var dock=map.Cells[row.Get<int>("dockIndex")-1].Position;int direction=row.Get<int>("direction");
                    var qs=new[]{1,1,0,-1,-1,0};var rs=new[]{0,-1,-1,0,1,1};int d=direction-1;
                    var outward=new Vector3(Mathf.Sqrt(3)*(qs[d]+rs[d]*.5f),0,1.5f*rs[d]).normalized;
                    var side=Vector3.Cross(Vector3.up,outward);
                    foreach(string view in new[]{"coast","dock"})
                    {
                        bool close=view=="dock";var focus=close?dock:Vector3.Lerp(renderer.Bounds.center,dock,.2f);
                        camera.orthographicSize=close?23:Mathf.Max(renderer.Bounds.size.x,renderer.Bounds.size.z)*.43f;
                        camera.transform.position=focus+outward*(close?34:110)+side*(close?18:36)+Vector3.up*(close?32:105);camera.transform.LookAt(focus);
                        renderer.Draw(camera);ProjectY.Rendering.UrpCameraRendering.Render(camera);RenderTexture.active=texture;
                        pixels=new Texture2D(1600,1000,TextureFormat.RGB24,false);pixels.ReadPixels(new Rect(0,0,1600,1000),0,0);pixels.Apply();
                        string path="Art/DocksLowPoly/Previews/waterfront-v10-"+row.Get<int>("dockId")+"-"+view+".png";System.IO.File.WriteAllBytes(path,pixels.EncodeToPNG());UnityEngine.Object.DestroyImmediate(pixels);pixels=null;
                        reports.Add(new{dockId=row.Get<int>("dockId"),view=view,waterCells=row.Get<int>("waterCount"),path=path});
                    }
                    renderer.Dispose();renderer=null;
                }
            }
            string report=Newtonsoft.Json.JsonConvert.SerializeObject(reports,Newtonsoft.Json.Formatting.Indented);System.IO.File.WriteAllText("Art/DocksLowPoly/Integration/waterfront-v10-preview.json",report);return report;
        }
        finally{using(var shutdown=lua.Global.Get<XLua.LuaFunction>("GameShutdown"))if(shutdown!=null)shutdown.Call();lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();}
    }
}
finally
{
    renderer?.Dispose();RenderTexture.active=previous;if(texture!=null){texture.Release();UnityEngine.Object.DestroyImmediate(texture);}if(pixels!=null)UnityEngine.Object.DestroyImmediate(pixels);
    host.Shutdown();UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);Time.timeScale=timeScale;
    if(UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=original)UnityEngine.SceneManagement.SceneManager.SetActiveScene(original);
    if(original.isDirty!=dirty)throw new System.Exception("Waterfront preview changed the original scene");
}
