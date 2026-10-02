// Unity MCP execute_code body: isolated Edit Mode host, real pointer events and offscreen UI captures.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling) throw new System.Exception("Idle Edit Mode required");
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var root=new GameObject("LootUIValidation");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
var host=root.AddComponent<ProjectY.UI.UIHost>();host.Initialize();
var cameraObject=new GameObject("LootPreviewCamera");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);
var camera=cameraObject.AddComponent<Camera>();camera.enabled=false;camera.scene=scene;camera.orthographic=true;camera.orthographicSize=5;camera.nearClipPlane=.01f;camera.farClipPlane=100;
camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.025f,.035f,.04f);camera.transform.position=new Vector3(0,0,-10);
ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
var target=new RenderTexture(1440,900,24,RenderTextureFormat.ARGB32);target.Create();camera.targetTexture=target;
var previous=RenderTexture.active;var oldTimeScale=Time.timeScale;
try {
    foreach(var canvas in root.GetComponentsInChildren<Canvas>(true)) {canvas.renderMode=RenderMode.ScreenSpaceCamera;canvas.worldCamera=camera;canvas.planeDistance=1;}
    System.Action<ProjectY.UI.LuaReference> arrange=reference=>{
        foreach(var canvas in reference.GetComponentsInChildren<Canvas>(true)) {canvas.renderMode=RenderMode.ScreenSpaceCamera;canvas.worldCamera=camera;canvas.planeDistance=1;}
        Canvas.ForceUpdateCanvases();reference.GetComponent<ProjectY.UI.InventoryPanelView>().Prepare();Canvas.ForceUpdateCanvases();
    };
    System.Action<ProjectY.UI.LuaReference,string> capture=(reference,name)=>{
        Canvas.ForceUpdateCanvases();ProjectY.Rendering.UrpCameraRendering.Render(camera);RenderTexture.active=target;
        var image=new Texture2D(target.width,target.height,TextureFormat.RGBA32,false);
        try {image.ReadPixels(new Rect(0,0,target.width,target.height),0,0);image.Apply();System.IO.Directory.CreateDirectory("Docs/Previews/Loot");System.IO.File.WriteAllBytes("Docs/Previews/Loot/"+name+".png",image.EncodeToPNG());}
        finally {UnityEngine.Object.DestroyImmediate(image);RenderTexture.active=previous;}
    };
    ProjectY.UI.InventoryItemView currentTile=null;
    UnityEngine.EventSystems.PointerEventData currentEvent=null;
    System.Func<ProjectY.UI.LuaReference,string,ProjectY.UI.InventoryItemView> findTile=(reference,key)=>{
        foreach(var tile in reference.GetComponentsInChildren<ProjectY.UI.InventoryItemView>()) {
            var item=typeof(ProjectY.UI.InventoryItemView).GetProperty("Item",System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic).GetValue(tile);
            if(item!=null && (string)item.GetType().GetField("Key").GetValue(item)==key)return tile;
        }
        throw new System.Exception("Missing visible loot tile "+key);
    };
    System.Action<ProjectY.UI.LuaReference,string> click=(reference,key)=>{
        arrange(reference);var tile=findTile(reference,key);
        tile.OnPointerClick(new UnityEngine.EventSystems.PointerEventData(UnityEngine.EventSystems.EventSystem.current) {button=UnityEngine.EventSystems.PointerEventData.InputButton.Left});
    };
    System.Action<ProjectY.UI.LuaReference,string,int,int,bool> beginDrag=(reference,key,x,y,cancel)=>{
        arrange(reference);
        var bag=reference.GetComponent<ProjectY.UI.InventoryPanelView>();var layout=bag.EditorLayout;
        var selected=findTile(reference,key);
        var rect=(RectTransform)selected.transform;
        var e=new UnityEngine.EventSystems.PointerEventData(UnityEngine.EventSystems.EventSystem.current) {button=UnityEngine.EventSystems.PointerEventData.InputButton.Left};
        e.pointerPressRaycast=new UnityEngine.EventSystems.RaycastResult {module=reference.GetComponent<UnityEngine.UI.GraphicRaycaster>()};
        float cell=layout.Grid.rect.width/12;
        e.position=RectTransformUtility.WorldToScreenPoint(camera,rect.TransformPoint(new Vector3(rect.rect.xMin+cell*.5f,rect.rect.yMax-cell*.5f,0)));
        selected.OnBeginDrag(e);
        e.position=cancel?new Vector2(-1000,-1000):RectTransformUtility.WorldToScreenPoint(camera,layout.Grid.TransformPoint(new Vector3(layout.Grid.rect.xMin+(x+.5f)*cell,layout.Grid.rect.yMax-(y+.5f)*cell,0)));
        selected.OnDrag(e);currentTile=selected;currentEvent=e;
    };
    System.Action endDrag=()=>{currentTile.OnEndDrag(currentEvent);currentTile=null;currentEvent=null;};
    System.Action<ProjectY.UI.LuaReference,string,int,int,bool> drag=(reference,key,x,y,cancel)=>{beginDrag(reference,key,x,y,cancel);endDrag();};
    System.Action<ProjectY.UI.LuaReference,bool> checkDrag=(reference,active)=>{
        var bag=reference.GetComponent<ProjectY.UI.InventoryPanelView>();
        var flags=System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic;
        var icon=(UnityEngine.UI.Image)typeof(ProjectY.UI.InventoryPanelView).GetField("dragIcon",flags).GetValue(bag);
        if(!active) {if(icon!=null && icon.gameObject.activeSelf)throw new System.Exception("Drag image remained visible after cancel/drop/close.");return;}
        if(icon==null || !icon.gameObject.activeSelf || icon.sprite==null || icon.raycastTarget || icon.transform.parent!=bag.EditorLayout.Frame)
            throw new System.Exception("Drag image is missing, blocks the pointer or is inside a grid mask.");
        var source=(UnityEngine.UI.Image)typeof(ProjectY.UI.InventoryItemView).GetField("icon",flags).GetValue(currentTile);
        if(icon.sprite!=source.sprite)throw new System.Exception("Dragged image differs from the source item.");
        var start=RectTransformUtility.WorldToScreenPoint(camera,icon.transform.position);
        var pointer=currentEvent.position;var delta=new Vector2(51,29);
        currentEvent.position=pointer+delta;currentTile.OnDrag(currentEvent);
        var moved=RectTransformUtility.WorldToScreenPoint(camera,icon.transform.position);
        if(Vector2.Distance(moved-start,delta)>.1f)throw new System.Exception("Drag image does not track the pointer continuously.");
        currentEvent.position=pointer;currentTile.OnDrag(currentEvent);
        var rotate=typeof(ProjectY.UI.InventoryPanelView).GetMethod("RotateDrag",flags);
        rotate.Invoke(bag,null);
        var turned=RectTransformUtility.WorldToScreenPoint(camera,icon.transform.position);var offset=start-pointer;
        if(Vector2.Distance(turned-pointer,new Vector2(offset.y,-offset.x))>.1f)throw new System.Exception("Rotation moved the mouse grab point.");
        rotate.Invoke(bag,null);
        if(Vector2.Distance(RectTransformUtility.WorldToScreenPoint(camera,icon.transform.position),start)>.1f)throw new System.Exception("Reverse rotation lost the grab point.");
    };
    using(var lua=new XLua.LuaEnv()) {
        var services=new ProjectY.FrameworkServices(host);var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);
        lua.Global.Set("Services",services);lua.Global.Set("CaptureLoot",capture);lua.Global.Set("DragLoot",drag);lua.Global.Set("BeginLootDrag",beginDrag);lua.Global.Set("EndLootDrag",endDrag);lua.Global.Set("CheckLootDrag",checkDrag);lua.Global.Set("ClickLoot",click);
        try {return lua.DoString(System.IO.File.ReadAllText("Tools/Tests/loot_ui_integration.lua"),"@Tools/Tests/loot_ui_integration.lua")[0];}
        finally {lua.Global.Set<string,object>("Services",null);lua.Global.Set<string,object>("CaptureLoot",null);lua.Global.Set<string,object>("DragLoot",null);lua.Global.Set<string,object>("BeginLootDrag",null);lua.Global.Set<string,object>("EndLootDrag",null);lua.Global.Set<string,object>("CheckLootDrag",null);lua.Global.Set<string,object>("ClickLoot",null);services.Player.ClearListeners();}
    }
} finally {
    host.Shutdown();Time.timeScale=oldTimeScale;camera.targetTexture=null;RenderTexture.active=previous;target.Release();UnityEngine.Object.DestroyImmediate(target);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
}
