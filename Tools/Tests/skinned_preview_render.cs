// Unity MCP execute_code method body; isolated PreviewScene, no Play or imported-asset mutation.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode)throw new System.InvalidOperationException("Edit Mode required");
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var root=UnityEngine.Object.Instantiate(UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/PawnLowPoly/PawnRig.prefab"));
UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
root.transform.localScale=Vector3.one*.8f;
var view=root.GetComponentInChildren<ProjectY.Samples.PawnCustomizationView>(true);
view.gameObject.SetActive(true);
var animator=view.GetComponent<Animator>();
animator.runtimeAnimatorController=UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.Samples.PawnAnimationSet>("Assets/DynamicAsset/PawnAnimation/PawnAnimations.asset").Controller;
animator.applyRootMotion=false;animator.cullingMode=AnimatorCullingMode.AlwaysAnimate;animator.enabled=false;
var cameraObject=new GameObject("SkinPreviewRegressionCamera");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);
var camera=cameraObject.AddComponent<Camera>();camera.enabled=false;camera.scene=scene;
camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
camera.orthographic=true;camera.orthographicSize=1.1f;camera.transform.position=new Vector3(0,.85f,4);camera.transform.LookAt(new Vector3(0,.85f,0));
camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.07f,.09f,.12f);
ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
var lightObject=new GameObject("SkinPreviewRegressionLight");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(lightObject,scene);
var light=lightObject.AddComponent<Light>();light.type=LightType.Directional;light.intensity=1.2f;light.transform.rotation=Quaternion.Euler(45,30,0);
var target=new RenderTexture(256,256,24);var image=new Texture2D(256,256,TextureFormat.RGB24,false);var previous=RenderTexture.active;camera.targetTexture=target;
var snapshot=new ProjectY.Rendering.SkinnedPreviewSnapshot(root.transform);
var errors=new System.Collections.Generic.List<string>();var failures=new System.Collections.Generic.List<string>();
var meshes=new System.Collections.Generic.Dictionary<SkinnedMeshRenderer,int>();
var originalMeshes=view.Catalog.Parts.Select(p=>p.Mesh).ToArray();var originalCounts=originalMeshes.Select(m=>m.vertexCount).ToArray();
var originalPositions=originalMeshes.Select(m=>m.vertices).ToArray();
int callbacks=0,renders=0;
Application.LogCallback log=(message,stack,type)=>{if(message.Contains("expected mesh data")||message.Contains("vertex stride")){lock(errors)errors.Add(message);}};
System.Action<UnityEngine.Rendering.ScriptableRenderContext,Camera> check=(context,renderCamera)=>{
    if(renderCamera!=camera)return;callbacks++;
    foreach(var skin in root.GetComponentsInChildren<SkinnedMeshRenderer>(true)){
        var proxy=skin.GetComponentInChildren<MeshRenderer>(true);
        if(!skin.enabled||skin.sharedMesh==null){if(proxy!=null&&proxy.enabled)failures.Add("Hidden source was drawn");continue;}
        if(!skin.forceRenderingOff||proxy==null||!proxy.enabled){failures.Add("Missing pose snapshot: "+skin.name+" active="+skin.gameObject.activeInHierarchy+" forceOff="+skin.forceRenderingOff+" proxy="+(proxy==null?"null":proxy.name+"/"+proxy.enabled));continue;}
        var mesh=proxy.GetComponent<MeshFilter>().sharedMesh;
        if(mesh.vertexCount!=skin.sharedMesh.vertexCount)failures.Add("Snapshot retained old topology");
        if(meshes.ContainsKey(skin)&&meshes[skin]!=mesh.GetInstanceID())failures.Add("Snapshot mesh was reallocated");
        meshes[skin]=mesh.GetInstanceID();
        if(proxy.sharedMaterials.Length!=skin.sharedMaterials.Length)failures.Add("Material layout differs");
        var sourceBlock=new MaterialPropertyBlock();var proxyBlock=new MaterialPropertyBlock();
        skin.GetPropertyBlock(sourceBlock,0);proxy.GetPropertyBlock(proxyBlock,0);
        if(sourceBlock.GetColor("_BaseColor")!=proxyBlock.GetColor("_BaseColor"))failures.Add("Tint was not copied");
        // Independent bone/bind-pose calculation verifies transformed output without double-applying scale.
        var indices=new[]{0,skin.sharedMesh.vertexCount-1};var positions=skin.sharedMesh.vertices;var weights=skin.sharedMesh.boneWeights;var binds=skin.sharedMesh.bindposes;var baked=mesh.vertices;
        foreach(var i in indices){var weight=weights[i];var boneIds=new[]{weight.boneIndex0,weight.boneIndex1,weight.boneIndex2,weight.boneIndex3};var values=new[]{weight.weight0,weight.weight1,weight.weight2,weight.weight3};var expected=Vector3.zero;
            for(int j=0;j<4;j++)if(values[j]>0)expected+=(skin.bones[boneIds[j]].localToWorldMatrix*binds[boneIds[j]]).MultiplyPoint3x4(positions[i])*values[j];
            if(Vector3.Distance(expected,proxy.transform.TransformPoint(baked[i]))>.002f)failures.Add("Snapshot pose/scale differs: "+skin.name+" expected="+expected+" actual="+proxy.transform.TransformPoint(baked[i])+" baked="+baked[i]+" scale="+skin.transform.lossyScale);
        }
    }
};
Application.logMessageReceivedThreaded+=log;UnityEngine.Rendering.RenderPipelineManager.beginCameraRendering+=check;
try{
    var look=view.Catalog.Rules.Randomize(42,"human","male");
    foreach(var hair in new[]{"hair_0","hair_2","hair_1","none","hair_0"}){
        look.hair=hair;view.Apply(look);animator.Rebind();animator.Play("Idle",0,.25f);animator.Update(0);snapshot.RefreshSources();snapshot.Render(camera,null);renders++;
        RenderTexture.active=target;image.ReadPixels(new Rect(0,0,256,256),0,0);image.Apply();
        foreach(var skin in root.GetComponentsInChildren<SkinnedMeshRenderer>(true))if(skin.forceRenderingOff||skin.GetComponentInChildren<MeshRenderer>(true).enabled)throw new System.Exception("Source/proxy state was not restored");
    }
    look=view.Catalog.Rules.Randomize(47,"human","female");look.hair="hair_0";view.Apply(look);snapshot.RefreshSources();snapshot.Render(camera,null);renders++;
    var fit=view.Catalog.GearFits.First(f=>f.HideHair&&(f.Body==""||f.Body==look.body)&&(f.Race==""||f.Race==look.race));
    view.Apply(look,fit.Coverage,true);var clothing=view.CreateFit(fit.SourcePath);snapshot.RefreshSources();snapshot.Render(camera,null);renders++;
    if(view.Modules[2].enabled)throw new System.Exception("Helmet did not hide hair");
    UnityEngine.Object.DestroyImmediate(clothing);view.Apply(look);snapshot.RefreshSources();snapshot.Render(camera,null);renders++;
    if(!view.Modules[2].enabled||view.Modules[2].sharedMesh.name!="hair_0")throw new System.Exception("Hair did not return after unequipping");
    bool rejected=false;try{snapshot.Render(null,null);}catch(System.InvalidOperationException){rejected=true;}
    if(!rejected)throw new System.Exception("Missing render target was accepted");
    foreach(var skin in root.GetComponentsInChildren<SkinnedMeshRenderer>(true))if(skin.forceRenderingOff||skin.GetComponentInChildren<MeshRenderer>(true).enabled)throw new System.Exception("Failed render leaked visibility state");
    if(callbacks!=renders)throw new System.Exception("Preview render callback coverage differs");
    if(failures.Count>0)throw new System.Exception(string.Join("; ",failures.Distinct().ToArray()));
    lock(errors)if(errors.Count>0)throw new System.Exception(string.Join("; ",errors.ToArray()));
    for(int i=0;i<originalMeshes.Length;i++)if(originalMeshes[i].vertexCount!=originalCounts[i]||!originalMeshes[i].vertices.SequenceEqual(originalPositions[i]))throw new System.Exception("Imported source mesh changed");
    RenderTexture.active=target;image.ReadPixels(new Rect(0,0,256,256),0,0);image.Apply();
    System.IO.File.WriteAllBytes("Docs/Previews/SkinnedPreview-regression.png",image.EncodeToPNG());
    return "PASS eight same-frame hair/body/gear renders, hair cover/restore, cached mesh reuse, tint/pose/scale, failure cleanup, immutable assets and no mesh-stride errors";
}finally{
    UnityEngine.Rendering.RenderPipelineManager.beginCameraRendering-=check;Application.logMessageReceivedThreaded-=log;snapshot.Dispose();
    RenderTexture.active=previous;camera.targetTexture=null;UnityEngine.Object.DestroyImmediate(image);UnityEngine.Object.DestroyImmediate(target);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
}
