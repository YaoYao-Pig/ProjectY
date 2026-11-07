// Read real saved HUD prefab in a disposable scene; no gameplay state or asset edits.
var originalScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();bool dirty=originalScene.isDirty;
var oldTarget=RenderTexture.active;var random=UnityEngine.Random.state;
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
RenderTexture target=null;Texture2D image=null;
try
{
    var host=new GameObject("Casting point layout preview");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(host,scene);
    var cameraObject=new GameObject("Camera");cameraObject.transform.SetParent(host.transform,false);
    var camera=cameraObject.AddComponent<Camera>();camera.enabled=false;camera.scene=scene;
    camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
    camera.cullingMask=1<<5;camera.orthographic=true;camera.orthographicSize=150;camera.aspect=3;
    camera.transform.position=new Vector3(0,-30,-500);camera.transform.rotation=Quaternion.identity;
    camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.035f,.045f,.055f,1);
    var extra=cameraObject.AddComponent<UnityEngine.Rendering.Universal.UniversalAdditionalCameraData>();extra.SetRenderer(0);extra.renderPostProcessing=false;
    var sun=new GameObject("Preview light");sun.transform.SetParent(host.transform,false);sun.AddComponent<Light>().type=LightType.Directional;
    var prefab=UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/UI/Prefabs/MainHud/HudHealthWidget.prefab");
    var maximums=new[]{6,18,30};var currents=new[]{4,11,17};
    for(int i=0;i<3;i++)
    {
        var row=UnityEngine.Object.Instantiate(prefab);row.transform.SetParent(host.transform,false);
        foreach(var child in row.GetComponentsInChildren<Transform>(true))child.gameObject.layer=5;
        row.transform.localPosition=new Vector3((i-1)*280,0,0);row.transform.localRotation=Quaternion.identity;row.transform.localScale=Vector3.one;
        var refs=row.GetComponent<ProjectY.UI.LuaReference>();
        ((Behaviour)refs.Get("Follower")).enabled=false;((Behaviour)refs.Get("DamageFollower")).enabled=false;
        row.SetActive(true);refs.Get("Root").gameObject.SetActive(true);
        foreach(var group in row.GetComponentsInChildren<CanvasGroup>(true))group.alpha=1;
        var canvas=(Canvas)refs.Get("WorldCanvas");canvas.renderMode=RenderMode.WorldSpace;canvas.worldCamera=camera;
        canvas.enabled=true;
        refs.Get("Name").gameObject.SetActive(false);
        ProjectY.UI.SpellcastingPresentation.SetPoints((ProjectY.UI.CastingPointRing)refs.Get("CastingPoints"),currents[i],maximums[i]);
        var slots=(RectTransform)refs.Get("EffectSlots");
        for(int b=0;b<3;b++)
        {
            var icon=new GameObject("Preview status",typeof(RectTransform),typeof(UnityEngine.UI.Image));icon.layer=5;
            icon.transform.SetParent(slots,false);icon.GetComponent<UnityEngine.UI.Image>().color=new Color(.4f+.18f*b,.35f,.7f-.18f*b,1);
        }
        UnityEngine.UI.LayoutRebuilder.ForceRebuildLayoutImmediate(slots);
        var titleObject=new GameObject("Capacity",typeof(RectTransform),typeof(UnityEngine.UI.Text));titleObject.layer=5;titleObject.transform.SetParent(canvas.transform,false);
        var rect=(RectTransform)titleObject.transform;rect.sizeDelta=new Vector2(200,35);rect.anchoredPosition=new Vector2(0,85);
        var title=titleObject.GetComponent<UnityEngine.UI.Text>();title.font=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");title.fontSize=18;title.alignment=TextAnchor.MiddleCenter;
        title.text=currents[i]+" / "+maximums[i];title.color=Color.white;
    }
    Canvas.ForceUpdateCanvases();target=new RenderTexture(1500,500,24,RenderTextureFormat.ARGB32);target.Create();camera.targetTexture=target;
    ProjectY.Rendering.UrpCameraRendering.Render(camera,new UnityEngine.Rendering.Universal.UniversalRenderPipeline.SingleCameraRequest());
    RenderTexture.active=target;image=new Texture2D(1500,500,TextureFormat.RGB24,false);image.ReadPixels(new Rect(0,0,1500,500),0,0);image.Apply();
    const string path="Docs/Previews/Spellcasting/casting-points-layout.png";System.IO.Directory.CreateDirectory(System.IO.Path.GetDirectoryName(path));System.IO.File.WriteAllBytes(path,image.EncodeToPNG());
    return path;
}
finally
{
    RenderTexture.active=oldTarget;UnityEngine.Random.state=random;
    if(target!=null){target.Release();UnityEngine.Object.DestroyImmediate(target);}if(image!=null)UnityEngine.Object.DestroyImmediate(image);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
    if(originalScene.isDirty!=dirty)throw new System.Exception("Preview changed the active scene");
}
