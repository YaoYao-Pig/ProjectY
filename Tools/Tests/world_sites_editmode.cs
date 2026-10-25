// Unity MCP execute_code body. Existing Editor, Edit Mode only; temporary PreviewScene, no Play or scene saves.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.InvalidOperationException("Edit Mode required");
var flags = System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic;
System.Func<object,string,object> field = (o,n) => o.GetType().GetField(n,flags).GetValue(o);
System.Func<object,string,object[],object> call = (o,n,a) => o.GetType().GetMethod(n,flags).Invoke(o,a);
System.Action<bool,string> check = (ok,message) => { if (!ok) throw new System.Exception(message); };
var scene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var owned = new System.Collections.Generic.List<UnityEngine.Object>();
var previousTarget = RenderTexture.active;
ProjectY.Samples.MapPreviewRenderer renderer = null;
System.IDisposable siteView = null;
Texture2D pixels = null;
try
{
    var host = new GameObject("World site checks"); UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(host,scene);
    var cameraObject = new GameObject("Camera"); cameraObject.transform.SetParent(host.transform,false);
    var camera = cameraObject.AddComponent<Camera>(); camera.enabled=false; camera.orthographic=true;
    camera.nearClipPlane=.1f; camera.farClipPlane=200; camera.orthographicSize=8;
    camera.transform.SetPositionAndRotation(new Vector3(0,20,-20),Quaternion.Euler(45,0,0));
    var map = new ProjectY.Samples.MapPreviewData { Radius=1,
        Towns=new[]{new ProjectY.Samples.MapPreviewData.Town {Center=0,Name="测试城镇",GroundColor=Color.gray}},
        Buildings=new ProjectY.Samples.MapPreviewData.Building[0], Roads=new[]{new ProjectY.Samples.MapPreviewData.Road{Kind="street",Cells=new[]{0,1}}},
        Decorations=new ProjectY.Samples.MapPreviewData.Decoration[0], Waterfalls=new ProjectY.Samples.MapPreviewData.Waterfall[0],
        Groundcover=new ProjectY.Samples.MapPreviewData.Cover[0] };
    var rows=Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Config/Tables/Map/MapAssetTable.json"))["rows"];
    var ground=rows.First(row=>(string)row["name"]=="Hex_Shore");
    map.Assets=new[]{new ProjectY.Samples.MapPreviewData.Asset {Id=(int)ground["id"],Path=(string)ground["prefabPath"],
        TintMaterial=(string)ground["tintMaterial"],ReferenceHeight=(float)ground["referenceHeight"]}};
    map.Surfaces=Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Config/Tables/Map/MapBiomeTable.json"))["rows"].Select(row=>{
        Color tint;check(ColorUtility.TryParseHtmlString((string)row["groundColor"],out tint),"Biome color");
        return new ProjectY.Samples.MapPreviewData.Surface{Id=(int)row["id"],GroundTexture=(string)row["groundTexture"],Color=tint,
            TextureWorldSize=(float)row["textureWorldSize"],TextureStrength=(float)row["textureStrength"],WindStrength=(float)row["windStrength"]};}).ToArray();
    map.Cells=new[]{
        new ProjectY.Samples.MapPreviewData.Cell {Q=0,R=0,TownId=1,Position=Vector3.zero},
        new ProjectY.Samples.MapPreviewData.Cell {Q=1,R=0,TownId=1,Position=new Vector3(1.7320508f,0,0)},
        new ProjectY.Samples.MapPreviewData.Cell {Q=-2,R=0,Position=new Vector3(-3.4641016f,0,0)} };
    foreach(var cell in map.Cells){cell.Color=new Color(.55f,.7f,.3f);cell.TerrainAssetId=map.Assets[0].Id;cell.SurfaceA=cell.SurfaceB=map.Surfaces[0].Id;cell.Neighbors=new int[0];}
    var distant=new System.Collections.Generic.List<ProjectY.Samples.MapPreviewData.Cell>(map.Cells);
    for(int q=10;q<40;q++)for(int r=10;r<40;r++)distant.Add(new ProjectY.Samples.MapPreviewData.Cell{
        Q=q,R=r,Position=new Vector3(1.7320508f*(q+r*.5f),0,r*1.5f),Color=Color.gray,TerrainAssetId=map.Assets[0].Id,
        SurfaceA=map.Surfaces[0].Id,SurfaceB=map.Surfaces[0].Id,Neighbors=new int[0]});
    map.Cells=distant.ToArray();
    renderer=new ProjectY.Samples.MapPreviewRenderer(Shader.Find("ProjectY/Map Preview Instanced"),host.transform);
    renderer.Build(map,asset=>UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(asset.Path));
    var canvasObject=new GameObject("HUD",typeof(RectTransform),typeof(Canvas),typeof(ProjectY.UI.MainHudView));canvasObject.transform.SetParent(host.transform,false);
    var canvas=canvasObject.GetComponent<Canvas>();canvas.renderMode=RenderMode.ScreenSpaceOverlay;
    var reference=canvasObject.AddComponent<ProjectY.UI.LuaReference>();
    var toggleObject=new GameObject("SiteTags",typeof(RectTransform),typeof(UnityEngine.UI.Toggle));toggleObject.transform.SetParent(canvasObject.transform,false);
    var siteTags=toggleObject.GetComponent<UnityEngine.UI.Toggle>();siteTags.isOn=true;
    reference.SetEditorBindings(new ProjectY.UI.LuaReference.Entry("SiteTags",siteTags));
    var hud=canvasObject.GetComponent<ProjectY.UI.MainHudView>();hud.SetEditorBindings(new ProjectY.UI.MainHudView.Layout{Root=(RectTransform)canvas.transform,Canvas=canvas,Labels=new UnityEngine.UI.Text[0]});
    var type=typeof(ProjectY.Samples.AdventureRuntimeDemo).Assembly.GetType("ProjectY.Samples.WorldSiteView",true);
    siteView=(System.IDisposable)System.Activator.CreateInstance(type,flags,null,new object[]{hud,map,renderer},null);
    var town=new ProjectY.Samples.AdventureViewData.Site{Id=7,Q=0,R=0,WorldTownId=1,Name="青石镇",Position=Vector3.zero,Available=true};
    var point=new ProjectY.Samples.AdventureViewData.Site{Id=33,Q=-2,R=0,Name="古旧营地",Position=map.Cells[2].Position,Available=true};
    call(siteView,"Sync",new object[]{new[]{town,point}});
    Canvas.ForceUpdateCanvases();
    var tags=(System.Collections.IDictionary)field(siteView,"tags");
    check(((int[])field(tags[7],"Cells")).Length==2,"Town footprint must include both cells");
    check(((int[])field(tags[33],"Cells")).Length==1,"Standalone site must keep its own cell");
    camera.orthographicSize=80;call(siteView,"Tick",new object[]{camera,false,Vector2.zero,.2f});hud.UpdateFollowers();
    foreach(System.Collections.DictionaryEntry entry in tags)check(((RectTransform)field(entry.Value,"Rect")).gameObject.activeSelf,"Far labels must show");
    // A click can query Pick before Tick has hidden the previous frame's labels.
    var townRect=(RectTransform)field(tags[7],"Rect");var originalPosition=townRect.position;
    townRect.position=new Vector3(60,60,0);
    var oldLabelPointer=RectTransformUtility.WorldToScreenPoint(null,townRect.TransformPoint(townRect.rect.center));
    var labelPick=(ProjectY.Samples.AdventureViewData.Site)call(siteView,"Pick",new object[]{camera,oldLabelPointer});
    check(labelPick!=null&&labelPick.Id==7,"Visible label must be pickable before disabling");
    siteTags.isOn=false;
    check(call(siteView,"Pick",new object[]{camera,oldLabelPointer})==null,"Disabled label must not survive the cached pick before Tick");
    townRect.position=originalPosition;
    call(siteView,"Tick",new object[]{camera,false,Vector2.zero,.2f});
    foreach(System.Collections.DictionaryEntry entry in tags)check(!((RectTransform)field(entry.Value,"Rect")).gameObject.activeSelf,"Disabled far labels must hide");
    var farPointer=(Vector2)camera.WorldToScreenPoint(map.Cells[1].Position);
    call(siteView,"Tick",new object[]{camera,true,farPointer,.2f});
    check(townRect.gameObject.activeSelf,"Disabled far labels must still show hovered town");
    check(!((RectTransform)field(tags[33],"Rect")).gameObject.activeSelf,"Other far labels must remain hidden during hover");
    call(siteView,"Hide",new object[0]);call(siteView,"Tick",new object[]{camera,false,Vector2.zero,.2f});
    check(!siteTags.isOn&&!townRect.gameObject.activeSelf,"Hide and re-show must preserve disabled state");
    // The original zoom hysteresis remains intact while labels are disabled.
    camera.orthographicSize=60;call(siteView,"Tick",new object[]{camera,false,Vector2.zero,.2f});
    siteTags.isOn=true;call(siteView,"Tick",new object[]{camera,false,Vector2.zero,.2f});
    foreach(System.Collections.DictionaryEntry entry in tags)check(((RectTransform)field(entry.Value,"Rect")).gameObject.activeSelf,"Re-enabled far labels must restore within the hysteresis band");
    camera.orthographicSize=40;call(siteView,"Tick",new object[]{camera,false,Vector2.zero,.2f});
    foreach(System.Collections.DictionaryEntry entry in tags)check(!((RectTransform)field(entry.Value,"Rect")).gameObject.activeSelf,"Mid-distance labels must hide without hover");
    camera.orthographicSize=8;call(siteView,"Tick",new object[]{camera,false,Vector2.zero,.2f});
    foreach(System.Collections.DictionaryEntry entry in tags)check(!((RectTransform)field(entry.Value,"Rect")).gameObject.activeSelf,"Near labels must hide without hover");
    var pointer=(Vector2)camera.WorldToScreenPoint(map.Cells[1].Position);
    var picked=(ProjectY.Samples.AdventureViewData.Site)call(siteView,"Pick",new object[]{camera,pointer});
    check(picked!=null && picked.Id==7,"Hovering any town cell must pick its place");
    call(siteView,"Tick",new object[]{camera,true,pointer,.2f});hud.UpdateFollowers();
    check(((RectTransform)field(tags[7],"Rect")).gameObject.activeSelf,"Hovered near label must show");
    check(!((RectTransform)field(tags[33],"Rect")).gameObject.activeSelf,"Unhovered near label must stay hidden");
    var instances=(System.Collections.IList)field(renderer,"focusedInstances");check(instances.Count>0,"Focus must include rendered instances");
    foreach(var entry in instances)
    {
        var batch=field(entry,"Batch");var index=(int)field(entry,"Index");var before=(Matrix4x4)field(entry,"Matrix");
        var current=((Matrix4x4[])field(batch,"Matrices"))[index];check(Mathf.Abs(current.m13-before.m13-.24f)<.0001f,"Selected instances must lift exactly once");
    }
    var mask=(ProjectY.UI.SceneFocusMask)field(siteView,"mask");var texture=(RenderTexture)mask.Image.texture;
    check((int)field(renderer,"maskInstanceCount")<map.Cells.Length/4,"Mask must cull the distant world instead of drawing every cell");
    var renderCount=(int)field(renderer,"maskRenderCount");call(renderer,"RenderFocusMask",new object[]{camera,mask});
    check((int)field(renderer,"maskRenderCount")==renderCount,"Stationary focus must reuse the existing mask");
    check(mask.Image.gameObject.activeSelf && !mask.Image.raycastTarget,"Mask must be visible and never block clicks");
    pixels=new Texture2D(texture.width,texture.height,TextureFormat.RGBA32,false);RenderTexture.active=texture;
    pixels.ReadPixels(new Rect(0,0,texture.width,texture.height),0,0);pixels.Apply();
    int white=0,black=0;foreach(var pixel in pixels.GetPixels32()){if(pixel.r>220)white++;if(pixel.r<20)black++;}
    check(white>20 && black>white,"Silhouette must contain selected geometry and a black exterior");
    var screen=camera.WorldToViewportPoint(map.Cells[1].Position+Vector3.up*.24f);
    var textureY=screen.y;
    var at=pixels.GetPixel(Mathf.Clamp((int)(screen.x*texture.width),0,texture.width-1),Mathf.Clamp((int)(textureY*texture.height),0,texture.height-1));
    check(at.r>.8f,"Mask RT must contain the projected lifted surface; final UI composition is checked by scene_focus_mask_editmode.cs");
    var saved=new System.Collections.Generic.List<object>();foreach(var entry in instances)saved.Add(entry);
    call(siteView,"Hide",new object[0]);
    foreach(var entry in saved){var batch=field(entry,"Batch");var index=(int)field(entry,"Index");check(((Matrix4x4[])field(batch,"Matrices"))[index]==(Matrix4x4)field(entry,"Matrix"),"Leaving the map must restore original transforms");}
    check(!mask.Image.gameObject.activeSelf,"Leaving map must hide mask");
    call(siteView,"Sync",new object[]{new[]{town}});check(tags.Count==1,"Expired sites must release their tags");
    // Repeated hover cannot accumulate height or tint.
    call(siteView,"Tick",new object[]{camera,true,pointer,.2f});call(siteView,"Hide",new object[0]);
    foreach(var entry in saved){var batch=field(entry,"Batch");var index=(int)field(entry,"Index");check(((Matrix4x4[])field(batch,"Matrices"))[index]==(Matrix4x4)field(entry,"Matrix"),"Repeated hover drifted");}
    return "PASS world sites: full footprint, spatial picking, far/near/hover tags, toggle off/on, stale label picks, retained preference, zoom hysteresis, lift, GPU silhouette pixels, passive mask, expired sites and restoration";
}
finally
{
    RenderTexture.active=previousTarget;siteView?.Dispose();renderer?.Dispose();
    if(pixels!=null)UnityEngine.Object.DestroyImmediate(pixels);
    foreach(var value in owned)if(value!=null)UnityEngine.Object.DestroyImmediate(value);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
}
