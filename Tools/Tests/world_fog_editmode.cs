// Real Data, save transaction, MainHud and fog shaders in a temporary PreviewScene. Never enters Play.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)throw new Exception("Idle Edit Mode required");
var original=UnityEngine.SceneManagement.SceneManager.GetActiveScene();bool dirty=original.isDirty;
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var owner=new GameObject("World fog validation");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(owner,scene);
var host=owner.AddComponent<ProjectY.UI.UIHost>();host.Initialize();
var cameraObject=new GameObject("Preview camera");cameraObject.transform.SetParent(owner.transform,false);
var camera=cameraObject.AddComponent<Camera>();camera.enabled=false;camera.scene=scene;
camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
camera.orthographic=true;camera.nearClipPlane=.1f;camera.farClipPlane=600;camera.aspect=16f/9;
camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.1f,.13f,.15f);
ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
var lightObject=new GameObject("Preview sun");lightObject.transform.SetParent(owner.transform,false);
var light=lightObject.AddComponent<Light>();light.type=LightType.Directional;light.intensity=1.5f;light.transform.rotation=Quaternion.Euler(52,-30,0);
var path=System.IO.Path.Combine(System.IO.Path.GetTempPath(),"project-y-world-fog-"+Guid.NewGuid().ToString("N")+".json");
var services=new ProjectY.FrameworkServices(host,path);var oldScale=Time.timeScale;var oldTarget=RenderTexture.active;
ProjectY.Samples.MapPreviewRenderer renderer=null;RenderTexture target=null;Texture2D image=null;
var flags=System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.Public|System.Reflection.BindingFlags.NonPublic;
Func<object,string,object> field=(o,n)=>o.GetType().GetField(n,flags).GetValue(o);
Action<bool,string> check=(ok,message)=>{if(!ok)throw new Exception(message);};
string folder="Docs/Previews/WorldFog";System.IO.Directory.CreateDirectory(folder);
try
{
    using(var lua=new XLua.LuaEnv())
    {
        var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);
        lua.Global.Set("Services",services);lua.Global.Set("OpenDemo",false);lua.Global.Set("FogCamera",camera);
        try
        {
            ProjectY.Samples.MapPreviewData map;
            using(var data=(XLua.LuaTable)lua.DoString(System.IO.File.ReadAllText("Tools/Tests/world_fog_hud.lua"),"@world_fog_hud")[0])
                map=ProjectY.Samples.MapPreviewData.Read(data);
            var fog=lua.Global.Get<ProjectY.Data.WorldMapExplorationData>("FogTestData");
            var shader=UnityEditor.AssetDatabase.LoadAssetAtPath<Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
            renderer=new ProjectY.Samples.MapPreviewRenderer(shader,owner.transform);
            renderer.Build(map,asset=>UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(asset.Path));renderer.SetExploration(fog);
            var cloud=field(renderer,"worldFog");var fogMaterial=(Material)field(cloud,"material");
            check(!UnityEditor.ShaderUtil.ShaderHasError(fogMaterial.shader),"Fog shader compilation failed");
            var doc=Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText(path));
            check((int)doc["version"]==20 && (int)doc["expedition"]["worldFog"]["cells"]==2500,"Fog save format missing");
            var valid=doc.ToString();doc["expedition"]["worldFog"]=null;System.IO.File.WriteAllText(path,doc.ToString());
            bool rejected=false;try{services.CharacterSaves.Prepare(services.Adventure.Equipment);}catch{rejected=true;}
            check(rejected,"v20 without fog data was accepted");System.IO.File.WriteAllText(path,valid);
            target=new RenderTexture(1600,900,24,RenderTextureFormat.ARGB32,RenderTextureReadWrite.sRGB);target.Create();
            camera.targetTexture=target;image=new Texture2D(1600,900,TextureFormat.RGB24,false);
            var center=renderer.Bounds.center;camera.transform.position=center+new Vector3(0,150,-125);camera.transform.LookAt(center);
            camera.orthographicSize=Mathf.Max(renderer.Bounds.size.x/(2*camera.aspect),renderer.Bounds.size.z*.55f)*1.12f;
            foreach(var canvas in owner.GetComponentsInChildren<Canvas>(true))if(canvas.renderMode!=RenderMode.WorldSpace)
            {canvas.renderMode=RenderMode.ScreenSpaceCamera;canvas.worldCamera=camera;canvas.planeDistance=1;}
            Canvas.ForceUpdateCanvases();foreach(var hud in owner.GetComponentsInChildren<ProjectY.UI.MainHudView>())hud.ApplyLayout();Canvas.ForceUpdateCanvases();
            Color32[] before=null;int animated=0;
            for(int frame=0;frame<2;frame++)
            {
                fogMaterial.SetFloat("_FogPreviewTime",frame*9);
                renderer.Draw(camera,true,true,true,true);ProjectY.Rendering.UrpCameraRendering.Render(camera);
                RenderTexture.active=target;image.ReadPixels(new Rect(0,0,1600,900),0,0);image.Apply();
                var pixels=image.GetPixels32();int pink=0;
                for(int i=0;i<pixels.Length;i++)
                {
                    var c=pixels[i];if(c.r>230 && c.b>230 && c.g<30)pink++;
                    if(before!=null && Mathf.Abs(c.r-before[i].r)+Mathf.Abs(c.g-before[i].g)+Mathf.Abs(c.b-before[i].b)>12)animated++;
                }
                check(pink==0,"Fog preview contains missing shader pixels");
                if(frame==0)before=pixels;
                System.IO.File.WriteAllBytes(folder+"/world-fog-"+frame+".png",image.EncodeToPNG());
            }
            check(animated>500,"Cloud shader did not animate");
            // Three real renderer states: unknown black, explored gray, current full color.
            var localMap=new ProjectY.Samples.MapAreaViewData{AreaType=1,Radius=1,TintMaterial="M_MapLP_Rock",
                Cells=new ProjectY.Samples.MapAreaViewData.Cell[3],Props=new ProjectY.Samples.MapAreaViewData.Prop[0],PropAssets=new ProjectY.Samples.MapAreaViewData.Asset[0]};
            localMap.Surfaces.Add(1,new ProjectY.Samples.MapAreaViewData.Surface{Color=Color.green,DetailColor=new Color(.15f,.3f,.1f)});
            for(int i=0;i<3;i++)localMap.Cells[i]=new ProjectY.Samples.MapAreaViewData.Cell{Q=i,R=0,Position=new Vector3(i*1.73205f,0,0),Kind="floor",Color=new Color(.12f,.3f,.09f),SurfaceId=1,SideSurfaceId=1,Corners=new float[6],Neighbors=new int[6]};
            var prefab=UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/MapLowPoly/Models/Hex_Rock.fbx");
            using(var area=new ProjectY.Samples.MapAreaRenderer(shader,prefab,localMap,asset=>null))
            {
                area.UpdateVisibility(new ProjectY.Samples.MapAreaViewData.State{Revision=1,Known=new[]{1,2},Visible=new[]{2},Members=new ProjectY.Samples.MapAreaViewData.Member[0]},false);
                var batch=((System.Collections.IEnumerable)field(area,"batches")).Cast<object>().First();
                var colors=(Vector4[])field(batch,"Colors");Color memory=colors[1];if(QualitySettings.activeColorSpace==ColorSpace.Linear)memory=memory.gamma;
                check(Mathf.Abs(memory.r-memory.g)<.0001f && Mathf.Abs(memory.g-memory.b)<.0001f && memory.r>.38f,"Explored terrain is not legible gray");
                check(colors[0].x<colors[1].x && colors[2].y>colors[2].x,"Unknown/current terrain states collapsed");
            }
            var legacy=Newtonsoft.Json.Linq.JObject.Parse(valid);legacy["version"]=18;legacy["expedition"]["worldFog"]=null;
            System.IO.File.WriteAllText(path,legacy.ToString());
            lua.DoString("local a=require('Main'):Get('Adventure'); local q,r=a.travel.data.Q,a.travel.data.R; assert(require('Game.Adventure.CharacterSave').Read(a)); assert(a.travel.data.Q==q and a.travel.data.R==r); assert(a.fog.data.KnownCount==a.fog.data.VisibleCount and a.fog.data.KnownCount>0 and a.fog.data.KnownCount<2500)","@legacy_fog_migration");
            string report=lua.Global.Get<string>("FogTestReport")+"\nPASS fog cloud animation: "+animated+" changed pixels\nPASS three-state local terrain colors\nPASS v20 rejects missing exploration data\nPASS v18 migration preserves position and reveals current surroundings";
            System.IO.File.WriteAllText(folder+"/validation.txt",report);return report;
        }
        finally
        {
            renderer?.Dispose();renderer=null;
            using(var shutdown=lua.Global.Get<XLua.LuaFunction>("GameShutdown"))if(shutdown!=null)shutdown.Call();
            lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();
        }
    }
}
finally
{
    renderer?.Dispose();host.Shutdown();camera.targetTexture=null;RenderTexture.active=oldTarget;
    if(target!=null){target.Release();UnityEngine.Object.DestroyImmediate(target);}if(image!=null)UnityEngine.Object.DestroyImmediate(image);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);Time.timeScale=oldScale;
    check(UnityEngine.SceneManagement.SceneManager.GetActiveScene()==original && original.isDirty==dirty,"Fog preview changed the user's scene");
}
