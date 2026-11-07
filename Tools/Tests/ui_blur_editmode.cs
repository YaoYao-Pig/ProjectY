// Focused GPU/filter/Image/lifetime check. Does not enter Play or alter the active scene.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode)throw new System.InvalidOperationException("Idle Edit Mode required");
var activeScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();bool dirty=activeScene.isDirty;float timeScale=Time.timeScale;
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
ProjectY.UI.UIHost host=null;RenderTexture target=null;Texture2D pattern=null,map=null,tiny=null;
var reports=new System.Collections.Generic.List<string>();
System.Func<RenderTexture,Texture2D> read=texture=>{
    var old=RenderTexture.active;var image=new Texture2D(texture.width,texture.height,TextureFormat.RGB24,false);
    try{RenderTexture.active=texture;image.ReadPixels(new Rect(0,0,texture.width,texture.height),0,0);image.Apply();return image;}
    finally{RenderTexture.active=old;}
};
System.Action<bool,string> check=(condition,message)=>{if(!condition)throw new System.Exception(message);};
System.Func<Color,Color,bool> near=(a,b)=>Mathf.Abs(a.r-b.r)<.09f&&Mathf.Abs(a.g-b.g)<.09f&&Mathf.Abs(a.b-b.b)<.09f;
var red=new Color(1,.05f,.05f);var green=new Color(.05f,1,.05f);var blue=new Color(.05f,.05f,1);var yellow=new Color(1,.8f,.05f);
try{
    var root=new GameObject("UI Blur isolated validation");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
    host=root.AddComponent<ProjectY.UI.UIHost>();host.Initialize();
    var reference=host.CreateView("PauseMenu");host.SetVisible(reference,true);host.SetOrder(reference,100);
    var blur=reference.GetComponentInChildren<ProjectY.UI.Blur>(true);check(blur!=null,"ESC prefab has no Blur");
    var image=blur.GetComponent<UnityEngine.UI.Image>();var originalMaterial=image.material;
    check(new UnityEditor.SerializedObject(blur).FindProperty("captureGroup").objectReferenceValue==reference.GetComponent<CanvasGroup>(),"Capture must exclude the whole ESC menu");
    pattern=new Texture2D(513,257,TextureFormat.RGB24,false);var pixels=new Color[513*257];
    for(int y=0;y<257;y++)for(int x=0;x<513;x++){
        var c=x<256?(y<128?red:blue):(y<128?green:yellow);
        if(x>=200&&x<312&&y>=96&&y<160)c=((x+y)%2)==0?Color.black:Color.white;
        pixels[y*513+x]=c;
    }
    pattern.SetPixels(pixels);pattern.Apply();pattern.filterMode=FilterMode.Point;pattern.wrapMode=TextureWrapMode.Repeat;
    var oldTarget=RenderTexture.active;var oldSrgb=GL.sRGBWrite;
    blur.CaptureFrom(pattern);
    check(blur.IsReady&&!blur.IsCapturing&&blur.BlurredTexture.width==256&&blur.BlurredTexture.height==128,"Invalid odd-size snapshot");
    check(RenderTexture.active==oldTarget&&GL.sRGBWrite==oldSrgb&&pattern.filterMode==FilterMode.Point&&pattern.wrapMode==TextureWrapMode.Repeat,"Capture leaked GPU/source state");
    var filtered=read(blur.BlurredTexture);
    try{
        check(near(filtered.GetPixel(20,20),red)&&near(filtered.GetPixel(230,20),green)&&near(filtered.GetPixel(20,108),blue)&&near(filtered.GetPixel(230,108),yellow),"Blur changed solid colors or flipped the source");
        float minimum=1,maximum=0;
        for(int y=60;y<68;y++)for(int x=122;x<134;x++){float v=filtered.GetPixel(x,y).r;minimum=Mathf.Min(minimum,v);maximum=Mathf.Max(maximum,v);}
        check(maximum-minimum<.08f,"High-frequency checkerboard was not blurred");
    }finally{UnityEngine.Object.DestroyImmediate(filtered);}
    reports.Add("GPU dual filter, odd dimensions, color/orientation, high-frequency smoothing, source/GPU state restoration");
    var first=blur.BlurredTexture;blur.CaptureFrom(pattern);check(first==null&&!ReferenceEquals(first,blur.BlurredTexture),"Recapture did not release the old RT");
    // Exercise the same hide/restore path used before the end-of-frame screenshot without starting Play.
    var group=reference.GetComponent<CanvasGroup>();group.alpha=.47f;
    typeof(ProjectY.UI.Blur).GetMethod("HideForCapture",System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Instance).Invoke(blur,null);
    check(group.alpha==0,"Capture exclusion failed");blur.Clear();check(Mathf.Abs(group.alpha-.47f)<.001f&&!blur.IsReady&&image.material==originalMaterial,"Cancelled capture did not restore UI state");group.alpha=1;
    tiny=new Texture2D(1,1,TextureFormat.RGB24,false);tiny.SetPixel(0,0,green);tiny.Apply();blur.CaptureFrom(tiny);
    check(blur.BlurredTexture.width==1&&blur.BlurredTexture.height==1,"Tiny inputs must stay valid");
    host.SetVisible(reference,false);check(!blur.IsReady&&image.material==originalMaterial,"Disable did not release snapshot/materials");
    reports.Add("Recapture, cancellation visibility, 1x1 input and disable cleanup");

    var cameraObject=new GameObject("Blur preview camera");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);
    var camera=cameraObject.AddComponent<Camera>();camera.enabled=false;camera.scene=scene;camera.cullingMask=1<<31;camera.orthographic=true;camera.orthographicSize=360;
    camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.2f,.2f,.2f,1);camera.nearClipPlane=.1f;camera.farClipPlane=100;
    camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
    target=new RenderTexture(1280,720,24,RenderTextureFormat.ARGB32);target.Create();camera.targetTexture=target;
    System.Action render=()=>{
        foreach(var node in root.GetComponentsInChildren<Transform>(true))node.gameObject.layer=31;
        foreach(var canvas in root.GetComponentsInChildren<Canvas>(true))if(canvas.isRootCanvas){canvas.renderMode=RenderMode.ScreenSpaceCamera;canvas.worldCamera=camera;canvas.planeDistance=10;}
        Canvas.ForceUpdateCanvases();ProjectY.Rendering.UrpCameraRendering.Render(camera);
    };
    var clip=new GameObject("Partial UI clip",typeof(RectTransform),typeof(UnityEngine.UI.RectMask2D));clip.transform.SetParent(reference.transform.parent,false);
    var clipRect=(RectTransform)clip.transform;clipRect.anchorMin=new Vector2(.5f,0);clipRect.anchorMax=new Vector2(.75f,1);clipRect.offsetMin=clipRect.offsetMax=Vector2.zero;
    var probe=new GameObject("Partial Image Blur",typeof(RectTransform),typeof(UnityEngine.UI.Image),typeof(ProjectY.UI.Blur));probe.transform.SetParent(clip.transform,false);
    var probeRect=(RectTransform)probe.transform;probeRect.anchorMin=Vector2.zero;probeRect.anchorMax=new Vector2(2,1);probeRect.offsetMin=probeRect.offsetMax=Vector2.zero;
    var probeBlur=probe.GetComponent<ProjectY.UI.Blur>();probeBlur.CaptureFrom(pattern);render();
    var composed=read(target);
    try{
        check(near(composed.GetPixel(780,600),yellow)&&near(composed.GetPixel(780,120),green),"Partial Image screen UV alignment is incorrect");
        check(near(composed.GetPixel(1150,600),composed.GetPixel(100,600)),"RectMask2D did not clip Blur");
    }finally{UnityEngine.Object.DestroyImmediate(composed);}
    clip.GetComponent<UnityEngine.UI.RectMask2D>().enabled=false;
    clip.AddComponent<UnityEngine.UI.Image>();var mask=clip.AddComponent<UnityEngine.UI.Mask>();mask.showMaskGraphic=false;
    probeBlur.CaptureFrom(pattern);render();composed=read(target);
    try{check(near(composed.GetPixel(780,600),yellow)&&near(composed.GetPixel(1150,600),composed.GetPixel(100,600)),"Stencil Mask or recapture material is incorrect");}
    finally{UnityEngine.Object.DestroyImmediate(composed);}
    UnityEngine.Object.DestroyImmediate(clip);
    reports.Add("Native partial Image screen coordinates, RectMask2D, stencil Mask and masked recapture");

    map=new Texture2D(2,2,TextureFormat.RGB24,false);
    check(ImageConversion.LoadImage(map,System.IO.File.ReadAllBytes("Docs/Previews/Rendering/urp-runtime-map.png")),"Missing preview source");
    host.SetVisible(reference,true);blur.CaptureFrom(map);
    ((ProjectY.UI.UITxt)reference.Get("Hint")).DefaultText=ProjectY.UI.LuaLanguage.Get("PauseMenuHint");
    render();composed=read(target);
    try{System.IO.Directory.CreateDirectory("Docs/Previews/PauseMenu");System.IO.File.WriteAllBytes("Docs/Previews/PauseMenu/blur.png",composed.EncodeToPNG());}
    finally{UnityEngine.Object.DestroyImmediate(composed);}
    host.SetVisible(reference,false);check(!host.IsWorldPaused&&!blur.IsReady,"Closing ESC left resources or pause ownership");
    reports.Add("Saved ESC prefab preview, clear foreground and released pause/snapshot");
}finally{
    if(host!=null)host.Shutdown();UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
    if(target!=null){target.Release();UnityEngine.Object.DestroyImmediate(target);}
    if(pattern!=null)UnityEngine.Object.DestroyImmediate(pattern);if(map!=null)UnityEngine.Object.DestroyImmediate(map);if(tiny!=null)UnityEngine.Object.DestroyImmediate(tiny);
}
check(activeScene==UnityEngine.SceneManagement.SceneManager.GetActiveScene()&&dirty==activeScene.isDirty&&Time.timeScale==timeScale,"User scene/time was modified");
return new{passed=true,checks=reports,playMode=false,screenshot="Docs/Previews/PauseMenu/blur.png",notValidated="Real Game View end-of-frame capture timing in Play/Player"};
