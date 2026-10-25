// Unity MCP execute_code method body. Existing idle Editor only; never enters Play or imports assets.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling || UnityEditor.EditorApplication.isUpdating)
    throw new System.InvalidOperationException("UIRefresh requires an existing idle Editor in Edit Mode");
var project=System.IO.Directory.GetParent(UnityEngine.Application.dataPath).FullName;
var captureWidth=1280;var captureHeight=720;var captureVariant="";
var output=System.IO.Path.Combine(project,"Art/UIRefresh/2026-10-25/matte/native");
if(captureVariant!="")output=System.IO.Path.Combine(output,captureVariant);
var oldTime=UnityEngine.Time.timeScale;
var oldRandom=UnityEngine.Random.state;
var oldActiveTexture=UnityEngine.RenderTexture.active;
var oldEventSystem=UnityEngine.EventSystems.EventSystem.current;
var flags=System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic;
var localization=ProjectY.Data.LocalizationService.Shared;
var sourceField=typeof(ProjectY.Data.LocalizationService).GetField("sources",flags);
var previousTexts=new System.Collections.Generic.Dictionary<string,System.Collections.Generic.Dictionary<string,string>>();
foreach(var entry in (System.Collections.Generic.Dictionary<string,System.Collections.Generic.Dictionary<string,string>>)sourceField.GetValue(localization))
    previousTexts.Add(entry.Key,new System.Collections.Generic.Dictionary<string,string>(entry.Value));
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
ProjectY.UI.UIHost host=null;
UnityEngine.Camera camera=null;
UnityEngine.RenderTexture target=null;
UnityEngine.Texture2D pixels=null;
var captures=new System.Collections.Generic.List<string>();
try
{
    var root=new UnityEngine.GameObject("UIRefreshPreview");
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
    host=root.AddComponent<ProjectY.UI.UIHost>();host.Initialize();
    var spriteKeys=new[]{"panel_light","panel_dark","header_strip","inset_light","button_light","button_accent","button_hover","button_pressed","tab_light","tab_accent","slot_frame","selected_frame","node_round","rule_horizontal","node_learned","node_available","node_locked"};
    var colorKeys=new[]{"ink","muted","accent_ink","on_accent","disabled_ink","on_dark"};
    foreach(var name in new[]{"CharacterGrowth","MissionJournal","DialogueEntry","StoryChoice"})
    {
        var reference=host.GetConfig(name).Prefab.GetComponent<ProjectY.UI.LuaReference>();
        var skin=reference.GetReference("Skin");skin.ValidateBindings();
        foreach(var key in spriteKeys)if(skin.GetImage(key).sprite==null)throw new System.InvalidOperationException(name+" missing Skin Sprite "+key);
        foreach(var key in colorKeys)skin.GetImage(key);
    }
    var font=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Font>("Assets/DynamicAsset/UI/Fonts/NotoSansCJKsc-Regular.otf");
    if(font==null)throw new System.InvalidOperationException("Project Noto Sans CJK font is unavailable");
    var cameraObject=new UnityEngine.GameObject("UIRefreshCaptureCamera");
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);
    camera=cameraObject.AddComponent<UnityEngine.Camera>();camera.enabled=false;camera.scene=scene;
    camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
    camera.clearFlags=UnityEngine.CameraClearFlags.SolidColor;camera.backgroundColor=new UnityEngine.Color(.105f,.125f,.135f,1);
    camera.orthographic=true;camera.orthographicSize=captureHeight*.5f;camera.nearClipPlane=.1f;camera.farClipPlane=100;
    camera.cullingMask=1<<31;camera.transform.position=new UnityEngine.Vector3(0,0,-10);
    ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
    target=new UnityEngine.RenderTexture(captureWidth,captureHeight,24);target.Create();camera.targetTexture=target;
    pixels=new UnityEngine.Texture2D(captureWidth,captureHeight,UnityEngine.TextureFormat.RGB24,false);
    foreach(var canvas in root.GetComponentsInChildren<UnityEngine.Canvas>(true))
        if(canvas.transform.parent==root.transform&&canvas.renderMode!=UnityEngine.RenderMode.WorldSpace)
        {canvas.renderMode=UnityEngine.RenderMode.ScreenSpaceCamera;canvas.worldCamera=camera;canvas.planeDistance=1;}
    UnityEngine.Canvas.ForceUpdateCanvases();
    var narrativeFit=typeof(ProjectY.UI.NarrativeView).GetMethod("Fit",flags);
    if(narrativeFit==null)throw new System.InvalidOperationException("NarrativeView Fit method is unavailable");
    System.Action<string> capture=name=>
    {
        if(name!="inventory"&&name!="skills"&&name!="mission"&&name!="dialogue"&&name!="event"&&name!="mission-wrap"&&name!="event-wrap"&&name!="dialogue-wrap")
            throw new System.ArgumentException("Unexpected preview name: "+name);
        foreach(var item in root.GetComponentsInChildren<UnityEngine.Transform>(true))item.gameObject.layer=31;
        foreach(var canvas in root.GetComponentsInChildren<UnityEngine.Canvas>(true))
            if(canvas.transform.parent==root.transform && canvas.renderMode!=UnityEngine.RenderMode.WorldSpace)
            {canvas.renderMode=UnityEngine.RenderMode.ScreenSpaceCamera;canvas.worldCamera=camera;canvas.planeDistance=1;}
        UnityEngine.Canvas.ForceUpdateCanvases();
        foreach(var style in root.GetComponentsInChildren<ProjectY.UI.StoryGrowthView>())style.Prepare();
        foreach(var style in root.GetComponentsInChildren<ProjectY.UI.NarrativeView>())narrativeFit.Invoke(style,null);
        foreach(var inventory in root.GetComponentsInChildren<ProjectY.UI.InventoryPanelView>())inventory.Prepare();
        foreach(var rect in root.GetComponentsInChildren<UnityEngine.RectTransform>())UnityEngine.UI.LayoutRebuilder.ForceRebuildLayoutImmediate(rect);
        UnityEngine.Canvas.ForceUpdateCanvases();
        foreach(var text in root.GetComponentsInChildren<UnityEngine.UI.Text>())
            if(text.font!=null)text.font.RequestCharactersInTexture(text.text,text.fontSize,text.fontStyle);
        foreach(var text in root.GetComponentsInChildren<TMPro.TMP_Text>())text.ForceMeshUpdate(true,true);
        // Resolve wrapped preferred heights after fonts and the camera-backed canvas width settle.
        foreach(var rect in root.GetComponentsInChildren<UnityEngine.RectTransform>())UnityEngine.UI.LayoutRebuilder.ForceRebuildLayoutImmediate(rect);
        UnityEngine.Canvas.ForceUpdateCanvases();
        var metrics=new System.Collections.Generic.List<object>();
        foreach(var text in root.GetComponentsInChildren<TMPro.TMP_Text>()){
            text.ForceMeshUpdate(true,true);
            metrics.Add(new {path=UnityEditor.AnimationUtility.CalculateTransformPath(text.transform,root.transform),size=text.rectTransform.rect.size.ToString(),pos=text.rectTransform.anchoredPosition.ToString(),preferred=text.preferredHeight,text=text.text,overflow=text.isTextOverflowing});
        }
        foreach(var text in root.GetComponentsInChildren<UnityEngine.UI.Text>())metrics.Add(new {path=UnityEditor.AnimationUtility.CalculateTransformPath(text.transform,root.transform),size=text.rectTransform.rect.size.ToString(),pos=text.rectTransform.anchoredPosition.ToString(),preferred=text.preferredHeight,text=text.text});
        System.IO.Directory.CreateDirectory(output);System.IO.File.WriteAllText(System.IO.Path.Combine(output,name+"-layout.json"),Newtonsoft.Json.JsonConvert.SerializeObject(metrics,Newtonsoft.Json.Formatting.Indented));
        // Insert inside render_preview.cs's capture lambda after its final layout/font refresh,
        // before RenderPreview/Render. Requires root (GameObject), name (string), captures (List<string>).
        // Read-only presentation checks; no classes, imports, scene creation or layout mutation.
        {
            const float adaptiveTolerance=1f;
            var adaptiveFailures=new System.Collections.Generic.List<string>();
            int adaptiveWidgets=0,adaptiveTexts=0;
            System.Func<UnityEngine.Transform,string> adaptivePath=adaptiveTransform=>UnityEditor.AnimationUtility.CalculateTransformPath(adaptiveTransform,root.transform);
            System.Func<UnityEngine.RectTransform,UnityEngine.RectTransform,UnityEngine.Rect> adaptiveBounds=(adaptiveChild,adaptiveParent)=>{
                var adaptiveCorners=new UnityEngine.Vector3[4];adaptiveChild.GetWorldCorners(adaptiveCorners);
                var adaptiveMin=new UnityEngine.Vector2(float.PositiveInfinity,float.PositiveInfinity);
                var adaptiveMax=new UnityEngine.Vector2(float.NegativeInfinity,float.NegativeInfinity);
                foreach(var adaptiveCorner in adaptiveCorners){
                    var adaptivePoint=(UnityEngine.Vector2)adaptiveParent.InverseTransformPoint(adaptiveCorner);
                    adaptiveMin=UnityEngine.Vector2.Min(adaptiveMin,adaptivePoint);adaptiveMax=UnityEngine.Vector2.Max(adaptiveMax,adaptivePoint);
                }
                return UnityEngine.Rect.MinMaxRect(adaptiveMin.x,adaptiveMin.y,adaptiveMax.x,adaptiveMax.y);
            };
            System.Func<UnityEngine.Transform,bool> adaptiveVisibleText=adaptiveTransform=>{
                if(adaptiveTransform==null||!adaptiveTransform.gameObject.activeInHierarchy)return false;
                var adaptiveTmp=adaptiveTransform.GetComponent<TMPro.TMP_Text>();
                if(adaptiveTmp!=null)return adaptiveTmp.isActiveAndEnabled&&!string.IsNullOrEmpty(adaptiveTmp.text);
                var adaptiveLegacy=adaptiveTransform.GetComponent<UnityEngine.UI.Text>();
                return adaptiveLegacy!=null&&adaptiveLegacy.isActiveAndEnabled&&!string.IsNullOrEmpty(adaptiveLegacy.text);
            };
            System.Action<UnityEngine.Transform,bool> adaptiveCheckText=(adaptiveTransform,adaptiveSingleLine)=>{
                var adaptiveRect=(UnityEngine.RectTransform)adaptiveTransform;
                var adaptiveTmp=adaptiveTransform.GetComponent<TMPro.TMP_Text>();
                var adaptiveLegacy=adaptiveTransform.GetComponent<UnityEngine.UI.Text>();
                float adaptivePreferredHeight=adaptiveTmp!=null?adaptiveTmp.preferredHeight:adaptiveLegacy.preferredHeight;
                float adaptivePreferredWidth=adaptiveTmp!=null?adaptiveTmp.preferredWidth:adaptiveLegacy.preferredWidth;
                if(adaptivePreferredHeight>adaptiveRect.rect.height+adaptiveTolerance)
                    adaptiveFailures.Add(adaptivePath(adaptiveTransform)+": preferredHeight "+adaptivePreferredHeight+" exceeds rect height "+adaptiveRect.rect.height);
                if(adaptiveTmp!=null&&adaptiveTmp.isTextOverflowing)
                    adaptiveFailures.Add(adaptivePath(adaptiveTransform)+": TMP text overflows");
                if(adaptiveSingleLine&&adaptivePreferredWidth>adaptiveRect.rect.width+adaptiveTolerance)
                    adaptiveFailures.Add(adaptivePath(adaptiveTransform)+": label preferredWidth "+adaptivePreferredWidth+" exceeds rect width "+adaptiveRect.rect.width);
                adaptiveTexts++;
            };
            System.Action<UnityEngine.Transform,UnityEngine.Rect,UnityEngine.Rect> adaptiveCheckInside=(adaptiveTransform,adaptiveBox,adaptiveSafe)=>{
                if(adaptiveBox.xMin<adaptiveSafe.xMin-adaptiveTolerance||adaptiveBox.xMax>adaptiveSafe.xMax+adaptiveTolerance||
                   adaptiveBox.yMin<adaptiveSafe.yMin-adaptiveTolerance||adaptiveBox.yMax>adaptiveSafe.yMax+adaptiveTolerance)
                    adaptiveFailures.Add(adaptivePath(adaptiveTransform)+": text rect "+adaptiveBox+" enters padding outside "+adaptiveSafe);
            };
            System.Action<System.Collections.Generic.List<System.Collections.Generic.KeyValuePair<string,UnityEngine.Rect>>> adaptiveCheckOverlap=adaptiveRows=>{
                for(int adaptiveA=0;adaptiveA<adaptiveRows.Count;adaptiveA++)for(int adaptiveB=adaptiveA+1;adaptiveB<adaptiveRows.Count;adaptiveB++){
                    var adaptiveFirst=adaptiveRows[adaptiveA].Value;var adaptiveSecond=adaptiveRows[adaptiveB].Value;
                    if(UnityEngine.Mathf.Min(adaptiveFirst.xMax,adaptiveSecond.xMax)-UnityEngine.Mathf.Max(adaptiveFirst.xMin,adaptiveSecond.xMin)>adaptiveTolerance&&
                       UnityEngine.Mathf.Min(adaptiveFirst.yMax,adaptiveSecond.yMax)-UnityEngine.Mathf.Max(adaptiveFirst.yMin,adaptiveSecond.yMin)>adaptiveTolerance)
                        adaptiveFailures.Add(adaptiveRows[adaptiveA].Key+" overlaps "+adaptiveRows[adaptiveB].Key);
                }
            };
            foreach(var adaptiveWidget in root.GetComponentsInChildren<UnityEngine.RectTransform>()){
                var adaptiveKind=adaptiveWidget.name;
                if(adaptiveKind.EndsWith("(Clone)",System.StringComparison.Ordinal))adaptiveKind=adaptiveKind.Substring(0,adaptiveKind.Length-7);
                bool adaptiveColumn=adaptiveKind=="NarrativeEntryWidget"||adaptiveKind=="DialogueEntryWidget"||adaptiveKind=="StoryChoiceWidget"||adaptiveKind=="JournalSkillWidget";
                bool adaptiveReward=adaptiveKind=="MissionRewardWidget",adaptiveTab=adaptiveKind=="TabButtonWidget";
                if(!adaptiveColumn&&!adaptiveReward&&!adaptiveTab)continue;
                adaptiveWidgets++;
                var adaptiveSafe=adaptiveWidget.rect;
                if(adaptiveColumn){
                    var adaptiveLayout=adaptiveWidget.GetComponent<UnityEngine.UI.VerticalLayoutGroup>();
                    if(adaptiveLayout==null||!adaptiveLayout.isActiveAndEnabled){adaptiveFailures.Add(adaptivePath(adaptiveWidget)+": active VerticalLayoutGroup is required");continue;}
                    adaptiveSafe=UnityEngine.Rect.MinMaxRect(adaptiveSafe.xMin+adaptiveLayout.padding.left,adaptiveSafe.yMin+adaptiveLayout.padding.bottom,
                        adaptiveSafe.xMax-adaptiveLayout.padding.right,adaptiveSafe.yMax-adaptiveLayout.padding.top);
                }else if(adaptiveReward){
                    adaptiveSafe=UnityEngine.Rect.MinMaxRect(adaptiveSafe.xMin+12,adaptiveSafe.yMin+12,adaptiveSafe.xMax-12,adaptiveSafe.yMax-12);
                }else{
                    adaptiveSafe=UnityEngine.Rect.MinMaxRect(adaptiveSafe.xMin+16,adaptiveSafe.yMin,adaptiveSafe.xMax-16,adaptiveSafe.yMax);
                }
                var adaptiveFields=adaptiveColumn?new[]{"Title","Body"}:adaptiveReward?new[]{"Name","Amount","Note"}:new[]{"Label"};
                var adaptiveRows=new System.Collections.Generic.List<System.Collections.Generic.KeyValuePair<string,UnityEngine.Rect>>();
                foreach(var adaptiveField in adaptiveFields){
                    var adaptiveText=adaptiveWidget.Find(adaptiveField);
                    if(adaptiveText==null){adaptiveFailures.Add(adaptivePath(adaptiveWidget)+": missing direct text "+adaptiveField);continue;}
                    if(!adaptiveVisibleText(adaptiveText))continue;
                    adaptiveCheckText(adaptiveText,adaptiveTab);
                    var adaptiveBox=adaptiveBounds((UnityEngine.RectTransform)adaptiveText,adaptiveWidget);
                    adaptiveCheckInside(adaptiveText,adaptiveBox,adaptiveSafe);
                    adaptiveRows.Add(new System.Collections.Generic.KeyValuePair<string,UnityEngine.Rect>(adaptivePath(adaptiveText),adaptiveBox));
                }
                adaptiveCheckOverlap(adaptiveRows);
            }
            captures.Add(name+": adaptive layout "+(adaptiveFailures.Count==0?"PASS":"FAIL")+"; "+adaptiveWidgets+" active widgets / "+adaptiveTexts+" nonempty active texts / "+adaptiveFailures.Count+" failures (1 px tolerance)");
            if(adaptiveFailures.Count>0)throw new System.InvalidOperationException(name+" adaptive layout validation failed:\n"+string.Join("\n",adaptiveFailures.ToArray()));
        }
        foreach(var preview in root.GetComponentsInChildren<ProjectY.UI.InventoryCharacterView>())preview.RenderPreview();
        UnityEngine.Canvas.ForceUpdateCanvases();
        ProjectY.Rendering.UrpCameraRendering.Render(camera);
        UnityEngine.RenderTexture.active=target;pixels.ReadPixels(new UnityEngine.Rect(0,0,captureWidth,captureHeight),0,0);pixels.Apply();
        System.IO.Directory.CreateDirectory(output);System.IO.File.WriteAllBytes(System.IO.Path.Combine(output,name+".png"),pixels.EncodeToPNG());
        int enabled=0,total=0;
        foreach(var button in root.GetComponentsInChildren<UnityEngine.UI.Button>()){total++;if(button.interactable)enabled++;}
        captures.Add(name+": "+enabled+" / "+total+" buttons interactable (original controller state)");
        UnityEngine.Debug.Log("[UIRefresh] Captured "+name);
    };
    using(var lua=new XLua.LuaEnv())
    {
        // A unique directory prevents reading any existing user or shared Temp/Campaigns save.
        var saveRoot=System.IO.Path.Combine(System.IO.Path.GetTempPath(),"project-y-ui-refresh-"+System.Guid.NewGuid().ToString("N"));
        var services=new ProjectY.FrameworkServices(host,System.IO.Path.Combine(saveRoot,"party.json"));
        var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);
        lua.Global.Set("Services",services);lua.Global.Set("UIRefreshFont",font);lua.Global.Set("CaptureUIRefresh",capture);
        try
        {
            var path=System.IO.Path.Combine(project,"Tools/UIRefresh/preview.lua");
            var result=(string)lua.DoString(System.IO.File.ReadAllText(path),"@"+path)[0];
            var report=result+"\n"+string.Join("\n",captures.ToArray())+"\nOutput: "+output;
            System.IO.File.WriteAllText(System.IO.Path.Combine(output,"checks.txt"),report,new System.Text.UTF8Encoding(false));
            return report;
        }
        finally
        {
            try{lua.DoString("if CloseUIRefreshPreview then CloseUIRefreshPreview() end");}
            finally
            {
                lua.Global.Set<string,object>("CaptureUIRefresh",null);lua.Global.Set<string,object>("UIRefreshFont",null);
                lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();
            }
        }
    }
}
finally
{
    if(host!=null)host.Shutdown();
    UnityEngine.RenderTexture.active=oldActiveTexture;
    if(camera!=null)camera.targetTexture=null;
    if(target!=null){target.Release();UnityEngine.Object.DestroyImmediate(target);}
    if(pixels!=null)UnityEngine.Object.DestroyImmediate(pixels);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
    UnityEngine.Time.timeScale=oldTime;UnityEngine.Random.state=oldRandom;
    if(oldEventSystem!=null)UnityEngine.EventSystems.EventSystem.current=oldEventSystem;
    localization.Clear();
    foreach(var source in previousTexts)foreach(var entry in source.Value)localization.SetText(source.Key,entry.Key,entry.Value);
    localization.NotifyChanged();
}
