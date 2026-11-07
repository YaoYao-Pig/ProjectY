// Native layout checks and real Lua UI previews. No Play or active-scene edits.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode||UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
var originalScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();bool dirty=originalScene.isDirty;
var originalTime=Time.timeScale;var originalRandom=UnityEngine.Random.state;var originalTarget=RenderTexture.active;
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();var root=new GameObject("Character identity validation");
UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
var host=root.AddComponent<ProjectY.UI.UIHost>();host.Initialize();
var cameraObject=new GameObject("Identity camera");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);
var camera=cameraObject.AddComponent<Camera>();camera.enabled=false;camera.scene=scene;
camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
camera.orthographic=true;camera.orthographicSize=360;camera.nearClipPlane=.1f;camera.farClipPlane=100;camera.cullingMask=1<<31;
camera.transform.position=new Vector3(0,0,-10);camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.04f,.06f,.05f);
ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
var target=new RenderTexture(1280,720,24);target.Create();camera.targetTexture=target;
var output="Docs/Previews/CharacterIdentity";System.IO.Directory.CreateDirectory(output);
var report=new System.Text.StringBuilder();
System.Action<string> capture=name=>
{
    foreach(var child in root.GetComponentsInChildren<Transform>(true))child.gameObject.layer=31;
    foreach(var canvas in root.GetComponentsInChildren<Canvas>(true))if(canvas.transform.parent==root.transform&&canvas.renderMode!=RenderMode.WorldSpace)
    {canvas.renderMode=RenderMode.ScreenSpaceCamera;canvas.worldCamera=camera;canvas.planeDistance=1;}
    Canvas.ForceUpdateCanvases();
    ProjectY.Rendering.UrpCameraRendering.Render(camera);RenderTexture.active=target;
    var pixels=new Texture2D(1280,720,TextureFormat.RGB24,false);
    try{pixels.ReadPixels(new Rect(0,0,1280,720),0,0);pixels.Apply();System.IO.File.WriteAllBytes(output+"/"+name+".png",pixels.EncodeToPNG());}
    finally{UnityEngine.Object.DestroyImmediate(pixels);RenderTexture.active=originalTarget;}
};
System.Action<UnityEngine.UI.Text> check=text=>
{
    Canvas.ForceUpdateCanvases();var height=text.preferredHeight;var available=text.rectTransform.rect.height;
    report.AppendLine(text.name+": "+height+" / "+available);
    if(height>available+.1f)throw new System.Exception(text.name+" text clips: "+height+" > "+available);
};
try
{
    using(var lua=new XLua.LuaEnv())
    {
        var services=new ProjectY.FrameworkServices(host,System.IO.Path.Combine(System.IO.Path.GetTempPath(),"identity-unused-"+System.Guid.NewGuid()+".json"));
        var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
        System.Action<string,ProjectY.UI.LuaReference> capturePanel=(name,reference)=>
        {
            foreach(var style in reference.GetComponentsInChildren<ProjectY.UI.StoryGrowthView>(true))style.Prepare();
            Canvas.ForceUpdateCanvases();
            for(int i=1;i<=4;i++)check(reference.GetText(name=="Inventory"||name=="EquipmentWorkbench"?"ActorText"+i:"Party"+i+"Text"));
            if(name=="CharacterGrowth")check(reference.GetText("Title"));
            if(name=="EquipmentWorkbench")
            {
                var layout=reference.GetComponent<ProjectY.UI.EquipmentWorkbenchView>().EditorLayout;
                if(-layout.Inventory.anchoredPosition.y< -layout.Actors.anchoredPosition.y+layout.Actors.rect.height)throw new System.Exception("Workbench selector overlaps inventory");
            }
            capture(name);
        };
        System.Action<string,string,string,string,string> captureWidgets=(hudText,turnText,plain,inspectionText,headingText)=>
        {
            var canvasRoot=new GameObject("Identity widgets",typeof(RectTransform),typeof(Canvas));canvasRoot.transform.SetParent(root.transform,false);
            var canvas=canvasRoot.GetComponent<Canvas>();canvas.renderMode=RenderMode.ScreenSpaceCamera;canvas.worldCamera=camera;canvas.planeDistance=1;
            var config=UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.UI.PanelConfig>("Assets/DynamicAsset/UI/Resources/PanelConfig.asset");
            int index=0;
            foreach(var name in new[]{"HudParty","BattleTurn","BattleParty","InspectionTarget"})
            {
                var prefab=config.Entries.Find(e=>e.Name==name).Prefab;
                var instance=UnityEngine.Object.Instantiate(prefab,canvasRoot.transform,false);var r=(RectTransform)instance.transform;
                r.anchorMin=r.anchorMax=r.pivot=new Vector2(0,1);r.anchoredPosition=new Vector2(80+index*290,-180);
                if(name=="BattleTurn")r.sizeDelta=new Vector2(150,62);
                if(name=="InspectionTarget")
                {
                    var t=instance.GetComponent<ProjectY.UI.LuaReference>().GetUITxt("Title");t.DefaultText=inspectionText;t.ForceMeshUpdate();
                    if(t.preferredHeight>t.rectTransform.rect.height+1)throw new System.Exception("Inspection title clips");
                }
                else
                {
                    var reference=instance.GetComponent<ProjectY.UI.LuaReference>();var t=reference.GetText("Name");t.text=name=="BattleTurn"?turnText:hudText;check(t);
                    if(name=="HudParty")reference.GetText("HealthText").text="100 / 100";
                }
                index++;
            }
            var camp=config.Entries.Find(e=>e.Name=="Camp").Prefab.GetComponent<ProjectY.UI.CampPanelView>();
            var row=UnityEngine.Object.Instantiate(camp.EditorLayout.EntryTemplate,canvasRoot.transform,false);row.gameObject.SetActive(true);row.Initialize(key=>{});
            var rr=(RectTransform)row.transform;rr.anchorMin=rr.anchorMax=rr.pivot=new Vector2(0,1);rr.anchoredPosition=new Vector2(80,-360);
            float initial=rr.rect.height;row.Show("sample",inspectionText,"Lv. 1   HP 100/100",null,true);
            Canvas.ForceUpdateCanvases();
            if(row.Title.preferredHeight>row.Title.rectTransform.rect.height+1)throw new System.Exception("Camp roster title clips");
            row.Show("sample",plain,"Lv. 1   HP 100/100",null,true);row.Show("sample",inspectionText,"Lv. 1   HP 100/100",null,true);
            capture("Widgets");UnityEngine.Object.DestroyImmediate(canvasRoot);
        };
        lua.Global.Set("CaptureIdentityUI",capturePanel);lua.Global.Set("CaptureIdentityWidgets",captureWidgets);
        try
        {
            var result=lua.DoString(System.IO.File.ReadAllText("Tools/Tests/character_identity_ui.lua"),"@Tools/Tests/character_identity_ui.lua")[0];
            System.IO.File.WriteAllText(output+"/validation.txt",result+"\n"+report);
            return result+"\n"+report;
        }
        finally{lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();}
    }
}
finally
{
    host.Shutdown();camera.targetTexture=null;RenderTexture.active=originalTarget;target.Release();UnityEngine.Object.DestroyImmediate(target);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);Time.timeScale=originalTime;UnityEngine.Random.state=originalRandom;
    if(originalScene.isDirty!=dirty)throw new System.Exception("Identity preview changed active scene");
}
