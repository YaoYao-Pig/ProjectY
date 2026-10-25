// Run through Unity MCP in the existing idle Editor. No world, Play Mode or player saves.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode||UnityEditor.EditorApplication.isCompiling||UnityEditor.EditorApplication.isUpdating)
    throw new System.InvalidOperationException("Typography verification requires idle Edit Mode");
var manifest=Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Tools/UITypography/roles.json"));
var fontRoot="Assets/DynamicAsset/UI/Fonts/";
var utility=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Font>(fontRoot+"NotoSansCJKsc-Regular.otf");
var sources=new System.Collections.Generic.Dictionary<string,string>{{"title","SourceHanSerifSC-SemiBold"},{"body","LXGWWenKai-Regular"}};
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var oldActive=UnityEngine.RenderTexture.active;
var cameraObject=new UnityEngine.GameObject("TypographyPreviewCamera");
UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);
var camera=cameraObject.AddComponent<UnityEngine.Camera>();camera.enabled=false;camera.scene=scene;
camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
camera.orthographic=true;camera.orthographicSize=360;camera.nearClipPlane=.1f;camera.farClipPlane=100;
camera.transform.position=new UnityEngine.Vector3(0,0,-10);camera.cullingMask=1<<31;
camera.clearFlags=UnityEngine.CameraClearFlags.SolidColor;camera.backgroundColor=new UnityEngine.Color(.05f,.12f,.14f);
ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
var target=new UnityEngine.RenderTexture(1280,720,24);target.Create();camera.targetTexture=target;
var pixels=new UnityEngine.Texture2D(1280,720,UnityEngine.TextureFormat.RGB24,false);
var canvasObject=new UnityEngine.GameObject("TypographyPreviewCanvas",typeof(UnityEngine.RectTransform),typeof(UnityEngine.Canvas));
UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(canvasObject,scene);
var canvas=canvasObject.GetComponent<UnityEngine.Canvas>();canvas.renderMode=UnityEngine.RenderMode.ScreenSpaceCamera;canvas.worldCamera=camera;canvas.planeDistance=1;
var report=new System.Collections.Generic.List<string>();
var output="Art/UITypography/2026-10-25/native";System.IO.Directory.CreateDirectory(output);
var mission=Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Config/Tables/Narrative/MissionTable.json"))["rows"][0];
var eventRow=Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Config/Tables/Adventure/AdventureEventTable.json"))["rows"][0];
try
{
    foreach(var entry in ((Newtonsoft.Json.Linq.JObject)manifest["roles"]).Properties())
    {
        var prefab=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>((string)manifest["prefabRoot"]+entry.Name+".prefab");
        var go=UnityEngine.Object.Instantiate(prefab,canvasObject.transform,false);
        try
        {
            var rootRect=(UnityEngine.RectTransform)go.transform;
            rootRect.anchorMin=UnityEngine.Vector2.zero;rootRect.anchorMax=UnityEngine.Vector2.one;
            rootRect.offsetMin=rootRect.offsetMax=UnityEngine.Vector2.zero;rootRect.localScale=UnityEngine.Vector3.one;
            foreach(var group in go.GetComponents<UnityEngine.CanvasGroup>())group.alpha=1;
            go.SetActive(true);UnityEngine.Canvas.ForceUpdateCanvases();
            foreach(var reference in go.GetComponentsInChildren<ProjectY.UI.LuaReference>(true))reference.ValidateBindings();
            for(int pass=0;pass<2;pass++)
            {
                foreach(var view in go.GetComponents<ProjectY.UI.StoryGrowthView>())view.Prepare();
                foreach(var view in go.GetComponents<ProjectY.UI.NarrativeView>())view.Prepare(utility,1100);
                foreach(var view in go.GetComponents<ProjectY.UI.InventoryPanelView>())view.Prepare();
                foreach(var view in go.GetComponents<ProjectY.UI.EquipmentWorkbenchView>())view.Prepare();
                foreach(var role in ((Newtonsoft.Json.Linq.JObject)entry.Value).Properties())foreach(var node in role.Value)
                {
                    var t=go.transform.Find((string)node);var text=t.GetComponent<UnityEngine.UI.Text>();var tmp=t.GetComponent<TMPro.TMP_Text>();
                    var font=text!=null?text.font.name:tmp.font.name;
                    if(font!=sources[role.Name])throw new System.InvalidOperationException(entry.Name+"/"+node+": font was overridden with "+font);
                }
            }
            report.Add("PASS "+entry.Name+": serialized roles survive two Prepare calls; bindings valid");
            var imageName=entry.Name=="Narrative/MissionJournalPanel"?"mission":entry.Name=="Adventure/StoryEventPanel"?"event":null;
            if(imageName!=null)
            {
                if(imageName=="mission")
                {
                    go.transform.Find("Page/Scroll/Viewport/Content/DetailTitle").GetComponent<ProjectY.UI.UITxt>().DefaultText=(string)mission["name"];
                    go.transform.Find("Page/Scroll/Viewport/Content/Description").GetComponent<ProjectY.UI.UITxt>().DefaultText=(string)mission["description"];
                }
                else
                {
                    go.transform.Find("Page/Title").GetComponent<UnityEngine.UI.Text>().text=(string)eventRow["name"];
                    go.transform.Find("Page/Description").GetComponent<UnityEngine.UI.Text>().text=(string)eventRow["description"];
                    go.GetComponent<ProjectY.UI.StoryGrowthView>().SetArt(go.GetComponent<ProjectY.UI.LuaReference>().GetImage("Illustration"),(string)eventRow["illustration"]);
                }
                foreach(var t in go.GetComponentsInChildren<UnityEngine.Transform>(true))t.gameObject.layer=31;
                for(int settle=0;settle<3;settle++)
                {
                    UnityEngine.Canvas.ForceUpdateCanvases();
                    foreach(var t in go.GetComponentsInChildren<UnityEngine.UI.Text>())t.font.RequestCharactersInTexture(t.text,t.fontSize,t.fontStyle);
                    foreach(var t in go.GetComponentsInChildren<TMPro.TMP_Text>())t.ForceMeshUpdate(true,true);
                    foreach(var r in go.GetComponentsInChildren<UnityEngine.RectTransform>())UnityEngine.UI.LayoutRebuilder.ForceRebuildLayoutImmediate(r);
                }
                ProjectY.Rendering.UrpCameraRendering.Render(camera);UnityEngine.RenderTexture.active=target;
                pixels.ReadPixels(new UnityEngine.Rect(0,0,1280,720),0,0);pixels.Apply();
                System.IO.File.WriteAllBytes(output+"/"+imageName+".png",pixels.EncodeToPNG());
            }
        }
        finally{UnityEngine.Object.DestroyImmediate(go);}
    }
    var dialogue=UnityEngine.Object.Instantiate(UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>("Assets/DynamicAsset/UI/Prefabs/Narrative/DialogueEntryWidget.prefab"),canvasObject.transform,false);
    var choice=UnityEngine.Object.Instantiate(UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>("Assets/DynamicAsset/UI/Prefabs/Adventure/StoryChoiceWidget.prefab"),canvasObject.transform,false);
    using(var lua=new XLua.LuaEnv())
    {
        var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);
        lua.Global.Set("TypographyDialogue",dialogue.GetComponent<ProjectY.UI.LuaReference>());
        lua.Global.Set("TypographyChoice",choice.GetComponent<ProjectY.UI.LuaReference>());
        lua.Global.Set("TypographyUtilityFont",utility);
        lua.Global.Set("TypographyTitle",(string)mission["name"]);lua.Global.Set("TypographyBody",(string)mission["description"]);
        report.Add((string)lua.DoString(System.IO.File.ReadAllText("Tools/UITypography/verify_widgets.lua"),"@Tools/UITypography/verify_widgets.lua")[0]);
    }
    report.Add("LIMITATION native screenshots use prefab layout and configured text; this check does not initialize the world or validate full game UI flows.");
    System.IO.File.WriteAllText(output+"/checks.txt",string.Join("\n",report.ToArray()));
    return string.Join("\n",report.ToArray());
}
finally
{
    UnityEngine.RenderTexture.active=oldActive;camera.targetTexture=null;target.Release();
    UnityEngine.Object.DestroyImmediate(target);UnityEngine.Object.DestroyImmediate(pixels);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
}
