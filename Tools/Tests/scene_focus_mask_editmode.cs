// Unity MCP execute_code body. Compare the final UI composite to the same scene without a mask.
// Asymmetric targets catch RT flips; covers both Renderer and GPU-instanced submission.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.Exception("Edit Mode required");
var scene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var target = new RenderTexture(320,240,24); target.Create(); var previous = RenderTexture.active;
ProjectY.UI.SceneFocusMask mask = null; Material material = null; Texture2D image = null;
try
{
    var cameraObject = new GameObject("Focus composite camera"); UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);
    var camera = cameraObject.AddComponent<Camera>(); camera.enabled=false; camera.scene=scene;
    camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
    camera.orthographic=true; camera.orthographicSize=4; camera.nearClipPlane=.1f; camera.farClipPlane=30;
    camera.transform.position=new Vector3(0,0,-10); camera.targetTexture=target;
    camera.clearFlags=CameraClearFlags.SolidColor; camera.backgroundColor=Color.black;
    ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
    material=new Material(Shader.Find("ProjectY/Map Preview Instanced")); material.color=Color.black; material.SetColor("_EmissionColor",Color.white);
    var selected=GameObject.CreatePrimitive(PrimitiveType.Cube); UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(selected,scene);
    selected.transform.position=new Vector3(-1.5f,1.5f,0); selected.transform.localScale=new Vector3(1.3f,1.3f,1);
    var selectedRenderer=selected.GetComponent<Renderer>(); selectedRenderer.sharedMaterial=material;
    var other=GameObject.CreatePrimitive(PrimitiveType.Cube); UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(other,scene);
    other.transform.position=new Vector3(1.5f,-1.5f,0); other.transform.localScale=selected.transform.localScale;
    other.GetComponent<Renderer>().sharedMaterial=material;
    // This smaller object is fully behind the chosen cube. It must not punch out
    // the foreground silhouette (a double GPU projection reverses this ordering).
    var occluder=GameObject.CreatePrimitive(PrimitiveType.Cube); UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(occluder,scene);
    occluder.transform.position=selected.transform.position+Vector3.forward*2; occluder.transform.localScale=Vector3.one*.8f;
    occluder.GetComponent<Renderer>().sharedMaterial=material;
    var black=new MaterialPropertyBlock(); black.SetVectorArray("_SiteMask",new[]{Vector4.zero});
    var ui=new GameObject("Focus composite UI",typeof(RectTransform),typeof(Canvas)); UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(ui,scene);
    var canvas=ui.GetComponent<Canvas>(); canvas.renderMode=RenderMode.ScreenSpaceCamera; canvas.worldCamera=camera; canvas.planeDistance=1;
    mask=ProjectY.UI.SceneFocusMask.Create((RectTransform)ui.transform); Canvas.ForceUpdateCanvases();
    image=new Texture2D(320,240,TextureFormat.RGBA32,false);
    System.Func<Color32[]> capture=()=>{
        ProjectY.Rendering.UrpCameraRendering.Render(camera); RenderTexture.active=target;
        image.ReadPixels(new Rect(0,0,320,240),0,0); image.Apply(); return image.GetPixels32();
    };
    var baseline=capture(); var results=new System.Collections.Generic.List<object>();
    for(var mode=0;mode<2;mode++)
    {
        var commands=mask.Begin(camera);
        if(mode==0)mask.DrawRenderers(new[]{selectedRenderer});
        else commands.DrawMeshInstanced(selected.GetComponent<MeshFilter>().sharedMesh,0,mask.SilhouetteMaterial,0,new[]{selected.transform.localToWorldMatrix},1);
        commands.DrawMeshInstanced(occluder.GetComponent<MeshFilter>().sharedMesh,0,mask.SilhouetteMaterial,0,new[]{occluder.transform.localToWorldMatrix},1,black);
        mask.End(1); mask.Image.color=Color.black; Canvas.ForceUpdateCanvases(); var composite=capture();
        int selectedPixels=0,retained=0,otherPixels=0,leaked=0;
        for(var i=0;i<baseline.Length;i++) if(baseline[i].r>200)
        {
            if(i%320<160){selectedPixels++;if(composite[i].r>180)retained++;}
            else{otherPixels++;if(composite[i].r>100)leaked++;}
        }
        if(selectedPixels<100 || retained<selectedPixels*.9f || otherPixels<100 || leaked>otherPixels*.02f)
            throw new System.Exception("Final composite does not match selected geometry: "+mode+" selected="+selectedPixels+" retained="+retained+" other="+otherPixels+" leaked="+leaked);
        results.Add(new{mode=mode==0?"Renderer":"DrawMeshInstanced",selectedPixels=selectedPixels,retained=retained,otherPixels=otherPixels,leaked=leaked});
    }
    occluder.transform.position=selected.transform.position-Vector3.forward*2;
    var foreground=mask.Begin(camera);mask.DrawRenderers(new[]{selectedRenderer});
    foreground.DrawMeshInstanced(occluder.GetComponent<MeshFilter>().sharedMesh,0,mask.SilhouetteMaterial,0,new[]{occluder.transform.localToWorldMatrix},1,black);
    mask.End(1);mask.Image.color=Color.black;var front=capture();var center=camera.WorldToViewportPoint(selected.transform.position);
    if(front[(int)(center.y*240)*320+(int)(center.x*320)].r>20)throw new System.Exception("A real foreground occluder must cover the selected silhouette");
    return new{passed=true,graphics=SystemInfo.graphicsDeviceType.ToString(),results=results,depth="Background preserves foreground; foreground occludes background"};
}
finally
{
    mask?.Dispose(); if(material!=null)UnityEngine.Object.DestroyImmediate(material); if(image!=null)UnityEngine.Object.DestroyImmediate(image);
    RenderTexture.active=previous; target.Release(); UnityEngine.Object.DestroyImmediate(target);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
}
