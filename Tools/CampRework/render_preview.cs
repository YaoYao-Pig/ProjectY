// Execute through Unity MCP in the existing idle Editor. No Play or player save access.
if(EditorApplication.isPlayingOrWillChangePlaymode||EditorApplication.isCompiling||EditorApplication.isUpdating)throw new System.InvalidOperationException("Camp preview requires idle Edit Mode.");
var captureWidth=1280;var captureHeight=720;var captureVariant="";var previewScript="Tools/CampRework/preview.lua";
var output=System.IO.Path.Combine(System.IO.Path.GetFullPath("Art/CampPresentation/Previews"),captureVariant);System.IO.Directory.CreateDirectory(output);
var previousScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();var oldTime=Time.timeScale;var oldRandom=UnityEngine.Random.state;var oldTarget=RenderTexture.active;
var oldEvent=UnityEngine.EventSystems.EventSystem.current;
var flags=System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic;
var texts=ProjectY.Data.LocalizationService.Shared;var sourceField=typeof(ProjectY.Data.LocalizationService).GetField("sources",flags);
var previousTexts=new System.Collections.Generic.Dictionary<string,System.Collections.Generic.Dictionary<string,string>>();
foreach(var pair in (System.Collections.Generic.Dictionary<string,System.Collections.Generic.Dictionary<string,string>>)sourceField.GetValue(texts))previousTexts.Add(pair.Key,new System.Collections.Generic.Dictionary<string,string>(pair.Value));
var previewScene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var campScene=UnityEditor.SceneManagement.EditorSceneManager.OpenScene(ProjectY.UI.CampSceneView.ScenePath,UnityEditor.SceneManagement.OpenSceneMode.Additive);
ProjectY.UI.UIHost host=null;RenderTexture target=null;Texture2D pixels=null;Material worldMaterial=null;
var captures=new System.Collections.Generic.List<string>();
try
{
    var stage=campScene.GetRootGameObjects()[0].GetComponent<ProjectY.UI.CampStage>();
    var root=new GameObject("CampUIPreview");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,previewScene);host=root.AddComponent<ProjectY.UI.UIHost>();host.Initialize();
    var cameraObject=new GameObject("CampUICaptureCamera");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,previewScene);
    var camera=cameraObject.AddComponent<Camera>();camera.enabled=false;camera.orthographic=true;camera.orthographicSize=captureHeight*.5f;camera.transform.position=new Vector3(0,0,-10);camera.nearClipPlane=.1f;camera.farClipPlane=100;camera.cullingMask=1<<31;
    camera.scene=previewScene;camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(previewScene);camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.07f,.11f,.09f);
    ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);target=new RenderTexture(captureWidth,captureHeight,24);target.Create();camera.targetTexture=target;pixels=new Texture2D(captureWidth,captureHeight,TextureFormat.RGB24,false);
    var worldObject=new GameObject("IsolatedBackdropCamera");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(worldObject,previewScene);var worldCamera=worldObject.AddComponent<Camera>();worldCamera.enabled=false;worldCamera.orthographic=true;worldCamera.orthographicSize=12;worldCamera.transform.position=new Vector3(0,15,18);worldCamera.transform.LookAt(Vector3.zero);worldCamera.cullingMask=1<<29;worldCamera.scene=previewScene;worldCamera.clearFlags=CameraClearFlags.SolidColor;worldCamera.backgroundColor=new Color(.12f,.19f,.16f);worldCamera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(previewScene);ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(worldCamera);
    worldMaterial=new Material(Shader.Find("Universal Render Pipeline/Unlit"));worldMaterial.SetColor("_BaseColor",new Color(.26f,.32f,.23f));
    for(int i=0;i<5;i++){var terrain=GameObject.CreatePrimitive(PrimitiveType.Cube);UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(terrain,previewScene);terrain.name="NeutralBackdrop"+i;terrain.layer=29;terrain.transform.position=new Vector3((i-2)*8,-1,i%2*7);terrain.transform.localScale=new Vector3(10,.5f,12);terrain.GetComponent<Renderer>().sharedMaterial=worldMaterial;}
    ProjectY.UI.LuaReference reference=null;ProjectY.UI.CampPanelView view=null;
    System.Action configureCanvas=()=>{
        foreach(var canvas in root.GetComponentsInChildren<Canvas>(true)){if(canvas.renderMode!=RenderMode.WorldSpace){canvas.renderMode=RenderMode.ScreenSpaceCamera;canvas.worldCamera=camera;canvas.planeDistance=1;}}
        foreach(var transform in root.GetComponentsInChildren<Transform>(true))transform.gameObject.layer=31;
        Canvas.ForceUpdateCanvases();
    };
    System.Action<ProjectY.UI.LuaReference> attach=refView=>{reference=refView;view=(ProjectY.UI.CampPanelView)refView.Get("Camp");((ProjectY.UI.CampSceneView)refView.Get("Scene")).AttachPreviewStage(stage);configureCanvas();};
    System.Action<string> capture=name=>{
        configureCanvas();view.Prepare();
        foreach(var rect in root.GetComponentsInChildren<RectTransform>())UnityEngine.UI.LayoutRebuilder.ForceRebuildLayoutImmediate(rect);
        Canvas.ForceUpdateCanvases();foreach(var text in root.GetComponentsInChildren<TMPro.TMP_Text>())text.ForceMeshUpdate(true,true);
        var sceneView=(ProjectY.UI.CampSceneView)reference.Get("Scene");typeof(ProjectY.UI.CampSceneView).GetMethod("CaptureWorld",flags).Invoke(sceneView,null);sceneView.Render();
        using(var skin=new ProjectY.Rendering.SkinnedPreviewSnapshot(stage.transform)){skin.RefreshSources();skin.Render(stage.Camera,new UnityEngine.Rendering.Universal.UniversalRenderPipeline.SingleCameraRequest());}
        ((ProjectY.UI.CampItemPreview)reference.Get("ItemPreview")).Render();
        ProjectY.Rendering.UrpCameraRendering.Render(camera);RenderTexture.active=target;pixels.ReadPixels(new Rect(0,0,captureWidth,captureHeight),0,0);pixels.Apply();
        System.IO.File.WriteAllBytes(System.IO.Path.Combine(output,name+".png"),pixels.EncodeToPNG());captures.Add(name);
        if(name=="camp-level-2")
        {
            var tag=view.EditorLayout.Facilities[0].GetComponent<ProjectY.UI.CampFacilityTagGraphic>();
            var pointer=new UnityEngine.EventSystems.PointerEventData(UnityEngine.EventSystems.EventSystem.current);pointer.button=UnityEngine.EventSystems.PointerEventData.InputButton.Left;
            for(int state=0;state<3;state++)
            {
                if(state==1)tag.OnPointerEnter(pointer);if(state==2)tag.OnPointerDown(pointer);
                Canvas.ForceUpdateCanvases();ProjectY.Rendering.UrpCameraRendering.Render(camera);RenderTexture.active=target;pixels.ReadPixels(new Rect(0,0,captureWidth,captureHeight),0,0);pixels.Apply();
                var corners=new Vector3[4];tag.rectTransform.GetWorldCorners(corners);var a=RectTransformUtility.WorldToScreenPoint(camera,corners[0]);var b=RectTransformUtility.WorldToScreenPoint(camera,corners[2]);
                int x=Mathf.Clamp(Mathf.FloorToInt(a.x)-8,0,captureWidth-1),y=Mathf.Clamp(Mathf.FloorToInt(a.y)-8,0,captureHeight-1);
                int width=Mathf.Min(captureWidth-x,Mathf.CeilToInt(b.x-a.x)+16),height=Mathf.Min(captureHeight-y,Mathf.CeilToInt(b.y-a.y)+16);
                var crop=new Texture2D(width,height,TextureFormat.RGB24,false);crop.SetPixels(pixels.GetPixels(x,y,width,height));crop.Apply();System.IO.File.WriteAllBytes(System.IO.Path.Combine(output,"camp-tag-"+state+".png"),crop.EncodeToPNG());UnityEngine.Object.DestroyImmediate(crop);
            }
            tag.OnPointerUp(pointer);tag.OnPointerExit(pointer);
        }
    };
    System.Action<string> click=command=>{
        var parts=command.Split(':');var layout=view.EditorLayout;UnityEngine.UI.Button button=null;
        switch(parts[0]){
            case "facility":button=layout.Facilities[int.Parse(parts[1])];break;
            case "primary":button=layout.Primary;break;case "back":button=layout.Back;break;case "close":button=layout.Close;break;case "claim":button=layout.Claim;break;
            case "wait":button=layout.Wait[int.Parse(parts[1])];break;
            case "secondary":button=layout.Secondary[int.Parse(parts[1])];break;
            case "row":button=layout.ListContent.GetChild(int.Parse(parts[1])).GetComponent<ProjectY.UI.CampListEntry>().Button;break;
            default:throw new System.ArgumentException(command);
        }
        if(!button.interactable)throw new System.InvalidOperationException("Disabled preview action: "+command);button.onClick.Invoke();
    };
    System.Action<string> drag=command=>{
        configureCanvas();var parts=command.Split(':');var key=parts[0];var layout=view.EditorLayout;var inventory=layout.Inventory;
        var property=typeof(ProjectY.UI.InventoryItemView).GetProperty("Item",System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.Public|System.Reflection.BindingFlags.NonPublic);
        ProjectY.UI.InventoryItemView tile=null;object item=null;
        foreach(var candidate in root.GetComponentsInChildren<ProjectY.UI.InventoryItemView>()){
            var value=property.GetValue(candidate,null);if(value!=null&&(string)value.GetType().GetField("Key").GetValue(value)==key){tile=candidate;item=value;break;}}
        if(tile==null)throw new System.InvalidOperationException("Missing drag tile: "+key);
        var targetGrid=parts[1]=="bag"?inventory.EditorLayout.Grid:(RectTransform)typeof(ProjectY.UI.CampWarehouseView).GetField("grid",flags).GetValue(layout.Warehouse);
        float cell=targetGrid.rect.width/12;int width=(int)item.GetType().GetField("Width").GetValue(item),height=(int)item.GetType().GetField("Height").GetValue(item);
        var tileRect=(RectTransform)tile.transform;var start=RectTransformUtility.WorldToScreenPoint(camera,tileRect.TransformPoint(tileRect.rect.center));
        var end=RectTransformUtility.WorldToScreenPoint(camera,targetGrid.TransformPoint(new Vector3(targetGrid.rect.xMin+(int.Parse(parts[2])+width*.5f)*cell,targetGrid.rect.yMax-(int.Parse(parts[3])+height*.5f)*cell,0)));
        var pointer=new UnityEngine.EventSystems.PointerEventData(UnityEngine.EventSystems.EventSystem.current);pointer.button=UnityEngine.EventSystems.PointerEventData.InputButton.Left;pointer.position=start;pointer.pressPosition=start;
        pointer.pointerPressRaycast=new UnityEngine.EventSystems.RaycastResult{module=reference.GetComponent<UnityEngine.UI.GraphicRaycaster>()};
        tile.OnBeginDrag(pointer);pointer.position=end;tile.OnDrag(pointer);tile.OnEndDrag(pointer);
    };
    using(var lua=new XLua.LuaEnv())
    {
        var saveRoot=System.IO.Path.Combine(System.IO.Path.GetTempPath(),"project-y-camp-"+System.Guid.NewGuid().ToString("N"));
        var services=new ProjectY.FrameworkServices(host,System.IO.Path.Combine(saveRoot,"party.json"));var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);
        lua.Global.Set("Services",services);lua.Global.Set("AttachCampPreview",attach);lua.Global.Set("CaptureCamp",capture);lua.Global.Set("ClickCamp",click);lua.Global.Set("DragCamp",drag);lua.Global.Set("CampWorldCamera",worldCamera);
        try
        {
            var result=(string)lua.DoString(System.IO.File.ReadAllText(previewScript),"@"+previewScript)[0];
            var report=result+"\nCaptures: "+string.Join(", ",captures.ToArray())+"\nBackdrop is an isolated neutral preview, not a running campaign.";
            System.IO.File.WriteAllText(System.IO.Path.Combine(output,"validation.txt"),report);return report;
        }
        finally{try{lua.DoString("if CloseCampPreview then CloseCampPreview() end");}finally{lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();}}
    }
}
finally
{
    if(host!=null)host.Shutdown();RenderTexture.active=oldTarget;if(target!=null){target.Release();UnityEngine.Object.DestroyImmediate(target);}if(pixels!=null)UnityEngine.Object.DestroyImmediate(pixels);if(worldMaterial!=null)UnityEngine.Object.DestroyImmediate(worldMaterial);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(previewScene);UnityEditor.SceneManagement.EditorSceneManager.CloseScene(campScene,true);if(previousScene.IsValid())UnityEngine.SceneManagement.SceneManager.SetActiveScene(previousScene);
    Time.timeScale=oldTime;UnityEngine.Random.state=oldRandom;if(oldEvent!=null)UnityEngine.EventSystems.EventSystem.current=oldEvent;
    texts.Clear();foreach(var source in previousTexts)foreach(var item in source.Value)texts.SetText(source.Key,item.Key,item.Value);texts.NotifyChanged();
}
