if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Editor required");
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();var root=new GameObject("WaterTravelSmoke");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
var host=root.AddComponent<ProjectY.UI.UIHost>();host.Initialize();float timeScale=Time.timeScale;
string save=System.IO.Path.Combine(System.IO.Path.GetTempPath(),"project-y-water-"+System.Guid.NewGuid().ToString("N")+".json");
var previous=RenderTexture.active;ProjectY.Samples.MapAreaRenderer renderer=null;RenderTexture texture=null;Texture2D pixels=null;
try
{
    using(var lua=new XLua.LuaEnv())
    {
        var services=new ProjectY.FrameworkServices(host,save);var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);
        lua.Global.Set("Services",services);lua.Global.Set("OpenDemo",false);lua.Global.Set("WaterSmokeFont",UnityEditor.AssetDatabase.LoadAssetAtPath<Font>("Assets/DynamicAsset/UI/Fonts/NotoSansCJKsc-Regular.otf"));
        try
        {
            using(var result=(XLua.LuaTable)lua.DoString(System.IO.File.ReadAllText("Tools/Tests/water_travel_smoke.lua"),"@water_travel_smoke.lua")[0])
            using(var layout=result.Get<XLua.LuaTable>("layout"))
            using(var state=result.Get<XLua.LuaTable>("view"))
            {
                var map=ProjectY.Samples.MapAreaViewData.Read(layout);var view=ProjectY.Samples.AdventureViewData.Read(state);
                var shader=Shader.Find("ProjectY/Map Preview Instanced");if(shader==null)throw new System.Exception("Missing map preview shader");
                renderer=new ProjectY.Samples.MapAreaRenderer(shader,UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(map.AssetPath),map,asset=>UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(asset.Path));
                renderer.UpdateVisibility(view.Area,false);
                var cameraObject=new GameObject("Dock review camera",typeof(Camera));cameraObject.transform.SetParent(root.transform,false);var camera=cameraObject.GetComponent<Camera>();camera.enabled=false;camera.scene=scene;camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
                camera.orthographic=true;camera.orthographicSize=15;camera.aspect=1.6f;camera.nearClipPlane=.1f;camera.farClipPlane=300;camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.22f,.28f,.3f);
                var focus=map.Cells[result.Get<int>("dockIndex")-1].Position;camera.transform.position=focus+new Vector3(23,28,-25);camera.transform.LookAt(focus);
                ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
                var lightObject=new GameObject("Dock review sun",typeof(Light));lightObject.transform.SetParent(root.transform,false);var sun=lightObject.GetComponent<Light>();sun.type=LightType.Directional;sun.intensity=1.4f;sun.transform.rotation=Quaternion.Euler(45,-30,0);
                texture=new RenderTexture(1600,1000,24,RenderTextureFormat.ARGB32,RenderTextureReadWrite.sRGB);texture.Create();camera.targetTexture=texture;renderer.Draw(camera);ProjectY.Rendering.UrpCameraRendering.Render(camera);
                RenderTexture.active=texture;pixels=new Texture2D(1600,1000,TextureFormat.RGB24,false);pixels.ReadPixels(new Rect(0,0,1600,1000),0,0);pixels.Apply();
                string path="Art/DocksLowPoly/Previews/town-waterfront-unity.png";System.IO.File.WriteAllBytes(path,pixels.EncodeToPNG());
                string report=result.Get<string>("report")+"\nPASS real city waterfront rendered: "+path;
                System.IO.File.WriteAllText("Art/DocksLowPoly/Integration/production-smoke.txt",report);return report;
            }
        }
        finally{using(var shutdown=lua.Global.Get<XLua.LuaFunction>("GameShutdown"))if(shutdown!=null)shutdown.Call();lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();}
    }
}
finally
{
    renderer?.Dispose();RenderTexture.active=previous;if(texture!=null){texture.Release();UnityEngine.Object.DestroyImmediate(texture);}if(pixels!=null)UnityEngine.Object.DestroyImmediate(pixels);
    host.Shutdown();UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);Time.timeScale=timeScale;
}
