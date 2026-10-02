// Existing game forest assets, real day/night lighting, isolated scene. Compare only volumetric sunlight.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.Exception("Edit Mode required");
ProjectY.Samples.MapEnvironmentData lighting;
using (var lua = new XLua.LuaEnv())
{
    var services = new ProjectY.FrameworkServices(null); var loader = new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot); lua.AddLoader(loader.Load); lua.Global.Set("Services", services);
    try { var result = lua.DoString(System.IO.File.ReadAllText("Tools/Rendering/preview_daylight.lua")); using (var table = (XLua.LuaTable)result[0]) {} using (var table = (XLua.LuaTable)result[1]) lighting = ProjectY.Samples.MapEnvironmentData.Read(table); }
    finally { lua.Global.Set<string,object>("Services",null); services.Player.ClearListeners(); }
}
var originalScene = UnityEngine.SceneManagement.SceneManager.GetActiveScene(); bool dirty = originalScene.isDirty;
var pipeline = QualitySettings.renderPipeline; var sky = RenderSettings.skybox; var activeTarget = RenderTexture.active;
var manager = UnityEngine.Rendering.VolumeManager.instance; var previousStack = manager.stack; var stack = manager.CreateStack(); manager.stack = stack;
var scene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
ProjectY.Samples.MapEnvironmentController environment = null; UnityEngine.Rendering.VolumeProfile profile = null;
Material grass = null; RenderTexture target = null; Texture2D linear = null, image = null;
try
{
    var host = new GameObject("Forest Lighting Comparison"); UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(host,scene);
    var sunObject = new GameObject("Sun"); sunObject.transform.SetParent(host.transform,false); var sun = sunObject.AddComponent<Light>(); sun.type = LightType.Directional;
    var cameraObject = new GameObject("Camera"); cameraObject.transform.SetParent(host.transform,false); var camera = cameraObject.AddComponent<Camera>();
    camera.enabled=false; camera.scene=scene; camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
    camera.clearFlags=CameraClearFlags.SolidColor; camera.nearClipPlane=.1f;camera.farClipPlane=160;camera.fieldOfView=60;camera.aspect=1.6f;
    camera.transform.position=new Vector3(0,2,18);camera.transform.rotation=Quaternion.Euler(-5,145,0);
    var forward=Vector3.ProjectOnPlane(camera.transform.forward,Vector3.up).normalized; var right=camera.transform.right;
    grass=new Material(Shader.Find("Universal Render Pipeline/Lit"));grass.color=new Color(.28f,.43f,.16f);grass.SetFloat("_Smoothness",.15f);
    var ground=GameObject.CreatePrimitive(PrimitiveType.Cube);ground.transform.SetParent(host.transform,false);ground.transform.position=camera.transform.position+forward*23-Vector3.up*2.15f;ground.transform.localScale=new Vector3(90,.3f,90);ground.GetComponent<Renderer>().sharedMaterial=grass;
    var oak=UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/ForestAnimals/Models/ForestOak.fbx");
    var pine=UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/ForestAnimals/Models/ForestPine.fbx");
    var positions=new[]{new Vector2(-5,10),new Vector2(4,14),new Vector2(-1.5f,19),new Vector2(8,21),new Vector2(-10,23),new Vector2(-5,30),new Vector2(3,34),new Vector2(12,38),new Vector2(-13,42)};
    for(int i=0;i<positions.Length;i++)
    {
        var obj=(GameObject)UnityEditor.PrefabUtility.InstantiatePrefab(i%3==0?pine:oak,scene);obj.transform.SetParent(host.transform,false);
        var p=camera.transform.position+forward*positions[i].y+right*positions[i].x;p.y=0;obj.transform.position=p;obj.transform.localScale=Vector3.one*(i<4?1.45f:1.65f);obj.transform.rotation=Quaternion.Euler(0,i*43,0);
    }
    environment=new ProjectY.Samples.MapEnvironmentController(lighting,sun,camera,host.transform);environment.Running=false;environment.Hour=17.5f;
    ProjectY.Rendering.FantasyPresentation.ApplyToActive(ProjectY.Rendering.WorldVisualStyle.MedievalFantasy);environment.Tick(3,null);environment.ApplyCameraFocus(camera.transform.position+forward*12);
    var volume=host.GetComponentInChildren<UnityEngine.Rendering.Volume>();profile=volume.profile;ProjectY.Rendering.FantasyAtmosphere atmosphere;profile.TryGet(out atmosphere);float strength=atmosphere.sunlight.value;
    target=new RenderTexture(1600,1000,24,RenderTextureFormat.ARGBHalf,RenderTextureReadWrite.Linear);target.Create();camera.targetTexture=target;
    linear=new Texture2D(1600,1000,TextureFormat.RGBAFloat,false,true);image=new Texture2D(1600,1000,TextureFormat.RGB24,false);
    Color32[] before=null;int changed=0;
    foreach(bool enabled in new[]{false,true})
    {
        atmosphere.sunlight.value=enabled?strength:0;manager.Update(stack,camera.transform,1);ProjectY.Rendering.UrpCameraRendering.Render(camera);
        RenderTexture.active=target;linear.ReadPixels(new Rect(0,0,1600,1000),0,0);linear.Apply();var source=linear.GetPixels();var encoded=new Color32[source.Length];
        for(int i=0;i<source.Length;i++)encoded[i]=source[i].gamma;
        if(!enabled)before=encoded;else for(int i=0;i<encoded.Length;i++)if(Mathf.Abs(encoded[i].r-before[i].r)+Mathf.Abs(encoded[i].g-before[i].g)+Mathf.Abs(encoded[i].b-before[i].b)>12)changed++;
        image.SetPixels32(encoded);image.Apply();System.IO.File.WriteAllBytes("Docs/Previews/Rendering/forest-tyndall-"+(enabled?"on":"off")+".png",image.EncodeToPNG());
    }
    if(changed<1000)throw new System.Exception("Sun shafts had no visible effect");
    return new{changedPixels=changed,sun=sun.intensity,hdrTarget=true,playMode=false};
}
finally
{
    if(environment!=null)environment.Dispose();if(profile!=null){foreach(var c in profile.components)UnityEngine.Object.DestroyImmediate(c);UnityEngine.Object.DestroyImmediate(profile);}
    manager.stack=previousStack;manager.DestroyStack(stack);RenderTexture.active=activeTarget;
    if(target!=null){target.Release();UnityEngine.Object.DestroyImmediate(target);}if(linear!=null)UnityEngine.Object.DestroyImmediate(linear);if(image!=null)UnityEngine.Object.DestroyImmediate(image);if(grass!=null)UnityEngine.Object.DestroyImmediate(grass);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
    if(QualitySettings.renderPipeline!=pipeline || RenderSettings.skybox!=sky || originalScene.isDirty!=dirty)throw new System.Exception("Forest preview leaked state");
}
