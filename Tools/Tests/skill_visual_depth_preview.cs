// Execute via Unity MCP after the shared compilation in the existing idle Editor.
// Uses real source profiles and the current URP renderer; no Play, scene save, pipeline swap or asset import.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Idle Edit Mode required for the skill preview.");
if(!(UnityEngine.Rendering.GraphicsSettings.currentRenderPipeline is UnityEngine.Rendering.Universal.UniversalRenderPipelineAsset))
    throw new System.InvalidOperationException("The existing Editor must already use the project URP pipeline.");
const int width=800,height=540,previewLayer=29;
var originalScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
bool originalDirty=originalScene.isDirty;
var originalPipeline=UnityEngine.QualitySettings.renderPipeline;
var originalTarget=UnityEngine.RenderTexture.active;
var originalRandom=UnityEngine.Random.state;
var manager=UnityEngine.Rendering.VolumeManager.instance;
var originalStack=manager.stack;
var stack=manager.CreateStack();
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
ProjectY.Samples.BlockParticleEffects effects=null;
UnityEngine.Rendering.VolumeProfile previewProfile=null;
UnityEngine.RenderTexture target=null;
UnityEngine.Texture2D linear=null,sheet=null;
UnityEngine.Material groundMaterial=null;
UnityEngine.Mesh groundMesh=null;
int baselineParticles=ProjectY.Samples.BlockParticleEffects.ActiveGlobalParticleCount;
var captures=new System.Collections.Generic.List<object>();
try
{
    var table=Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Config/Tables/Adventure/VisualEffectTable.json"));
    var profiles=new System.Collections.Generic.Dictionary<int,ProjectY.Samples.BlockEffectProfile>();
    foreach(var row in table["rows"])
    {
        UnityEngine.Color color,accent;
        if(!UnityEngine.ColorUtility.TryParseHtmlString((string)row["color"],out color) ||
           !UnityEngine.ColorUtility.TryParseHtmlString((string)row["accent"],out accent))
            throw new System.InvalidOperationException("Invalid source profile color.");
        profiles.Add((int)row["id"],new ProjectY.Samples.BlockEffectProfile {Id=(int)row["id"],Name=(string)row["name"],
            Pattern=(string)row["pattern"],Color=color,Accent=accent,Count=(int)row["count"],Lifetime=(float)row["lifetime"],
            Size=(float)row["size"],Radius=(float)row["radius"],Height=(float)row["height"],Emission=(float)row["emission"],
            Speed=(float)row["speed"],Gravity=(float)row["gravity"]});
    }
    var host=new UnityEngine.GameObject("Spell depth isolated capture") {layer=previewLayer};
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(host,scene);
    var cameraObject=new UnityEngine.GameObject("Camera") {layer=previewLayer};cameraObject.transform.SetParent(host.transform,false);
    var camera=cameraObject.AddComponent<UnityEngine.Camera>();
    camera.enabled=false;camera.scene=scene;
    camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
    camera.cullingMask=1<<previewLayer;camera.clearFlags=UnityEngine.CameraClearFlags.SolidColor;
    camera.backgroundColor=new UnityEngine.Color(.035f,.052f,.075f);camera.allowHDR=true;
    camera.orthographic=true;camera.orthographicSize=3.35f;camera.aspect=width/(float)height;
    camera.nearClipPlane=.05f;camera.farClipPlane=50f;
    var focus=new UnityEngine.Vector3(0,.9f,0);
    camera.transform.position=focus+new UnityEngine.Vector3(5,6,-8);camera.transform.LookAt(focus);
    var cameraData=cameraObject.AddComponent<UnityEngine.Rendering.Universal.UniversalAdditionalCameraData>();
    cameraData.SetRenderer(0);cameraData.renderPostProcessing=true;cameraData.renderShadows=true;
    cameraData.volumeLayerMask=1<<previewLayer;cameraData.volumeTrigger=camera.transform;
    cameraData.antialiasing=UnityEngine.Rendering.Universal.AntialiasingMode.None;
    cameraData.requiresDepthOption=UnityEngine.Rendering.Universal.CameraOverrideOption.On;

    // Copy the authored world volume to this camera's isolated layer. Shared assets stay untouched.
    var styles=UnityEngine.Resources.Load<ProjectY.Rendering.WorldVisualStyles>(ProjectY.Rendering.WorldVisualStyles.ResourcePath);
    if(styles==null || styles.fantasyProfile==null)throw new System.InvalidOperationException("The authored fantasy volume is missing.");
    previewProfile=UnityEngine.ScriptableObject.CreateInstance<UnityEngine.Rendering.VolumeProfile>();
    foreach(var component in styles.fantasyProfile.components)previewProfile.components.Add(UnityEngine.Object.Instantiate(component));
    var volumeObject=new UnityEngine.GameObject("Camera local authored grading") {layer=previewLayer};
    volumeObject.transform.SetParent(camera.transform,false);
    var collider=volumeObject.AddComponent<UnityEngine.BoxCollider>();collider.size=UnityEngine.Vector3.one;
    var volume=volumeObject.AddComponent<UnityEngine.Rendering.Volume>();
    volume.isGlobal=false;volume.priority=1000;volume.blendDistance=0;volume.sharedProfile=previewProfile;
    UnityEngine.Rendering.Universal.Bloom bloom;
    if(!previewProfile.TryGet(out bloom) || !bloom.active || bloom.intensity.value<=0)
        throw new System.InvalidOperationException("The authored fantasy profile must provide Bloom for this capture.");
    manager.stack=stack;

    var sunObject=new UnityEngine.GameObject("Preview key light") {layer=previewLayer};sunObject.transform.SetParent(host.transform,false);
    var sun=sunObject.AddComponent<UnityEngine.Light>();sun.type=UnityEngine.LightType.Directional;
    sun.intensity=.85f;sun.color=new UnityEngine.Color(.78f,.85f,1f);sun.cullingMask=1<<previewLayer;
    sun.shadows=UnityEngine.LightShadows.Soft;sun.transform.rotation=UnityEngine.Quaternion.Euler(42,135,0);
    groundMaterial=new UnityEngine.Material(UnityEngine.Shader.Find("Universal Render Pipeline/Lit"));
    groundMaterial.color=new UnityEngine.Color(.16f,.21f,.25f);groundMaterial.SetFloat("_Smoothness",.18f);
    var vertices=new UnityEngine.Vector3[7];var triangles=new int[18];
    for(int i=0;i<6;i++)
    {
        float angle=i*UnityEngine.Mathf.PI/3f;
        vertices[i+1]=new UnityEngine.Vector3(UnityEngine.Mathf.Cos(angle)*.94f,0,UnityEngine.Mathf.Sin(angle)*.94f);
        triangles[i*3]=0;triangles[i*3+1]=(i+1)%6+1;triangles[i*3+2]=i+1;
    }
    groundMesh=new UnityEngine.Mesh {name="Preview hex ground"};groundMesh.vertices=vertices;groundMesh.triangles=triangles;
    groundMesh.RecalculateNormals();groundMesh.RecalculateBounds();
    for(int q=-3;q<=3;q++)for(int r=-3;r<=3;r++)
    {
        if(UnityEngine.Mathf.Max(UnityEngine.Mathf.Abs(q),UnityEngine.Mathf.Abs(r),UnityEngine.Mathf.Abs(q+r))>3)continue;
        var tile=new UnityEngine.GameObject("Ground hex",typeof(UnityEngine.MeshFilter),typeof(UnityEngine.MeshRenderer)) {layer=previewLayer};
        tile.transform.SetParent(host.transform,false);tile.transform.position=new UnityEngine.Vector3(q*1.5f,-.05f,(r+q*.5f)*1.73205f);
        tile.GetComponent<UnityEngine.MeshFilter>().sharedMesh=groundMesh;tile.GetComponent<UnityEngine.MeshRenderer>().sharedMaterial=groundMaterial;
    }
    // A camera-only caption makes contact-sheet stages unambiguous without an external image editor.
    var canvasObject=new UnityEngine.GameObject("Capture caption",typeof(UnityEngine.RectTransform),typeof(UnityEngine.Canvas)) {layer=previewLayer};
    canvasObject.transform.SetParent(host.transform,false);
    var canvas=canvasObject.GetComponent<UnityEngine.Canvas>();canvas.renderMode=UnityEngine.RenderMode.ScreenSpaceCamera;
    canvas.worldCamera=camera;canvas.planeDistance=.5f;
    var titleObject=new UnityEngine.GameObject("Stage",typeof(UnityEngine.RectTransform),typeof(UnityEngine.UI.Text)) {layer=previewLayer};
    titleObject.transform.SetParent(canvasObject.transform,false);
    var titleRect=(UnityEngine.RectTransform)titleObject.transform;titleRect.anchorMin=new UnityEngine.Vector2(0,1);titleRect.anchorMax=new UnityEngine.Vector2(1,1);
    titleRect.pivot=new UnityEngine.Vector2(0,1);titleRect.anchoredPosition=new UnityEngine.Vector2(24,-16);titleRect.sizeDelta=new UnityEngine.Vector2(-48,40);
    var title=titleObject.GetComponent<UnityEngine.UI.Text>();title.font=UnityEngine.Resources.GetBuiltinResource<UnityEngine.Font>("LegacyRuntime.ttf");
    title.fontSize=24;title.color=new UnityEngine.Color(.9f,.95f,1f);title.alignment=UnityEngine.TextAnchor.UpperLeft;title.raycastTarget=false;

    effects=new ProjectY.Samples.BlockParticleEffects(host.transform,previewLayer,illuminate:true);
    target=new UnityEngine.RenderTexture(width,height,24,UnityEngine.RenderTextureFormat.ARGBHalf,UnityEngine.RenderTextureReadWrite.Linear);
    target.Create();camera.targetTexture=target;
    linear=new UnityEngine.Texture2D(width,height,UnityEngine.TextureFormat.RGBAFloat,false,true);
    sheet=new UnityEngine.Texture2D(width*2,height*3,UnityEngine.TextureFormat.RGB24,false);
    var request=new UnityEngine.Rendering.Universal.UniversalRenderPipeline.SingleCameraRequest();
    var labels=new[]{"01  FIREBALL / FLIGHT","02  METEOR / DESCENT","03  METEOR / IMPACT","04  BURNING GROUND / EMBERS","05  MIST / LOW COVER","06  WATER / SURGE"};
    var ids=new[]{2301,2304,2304,2304,2305,2303};var times=new[]{.14f,.18f,.57f,.45f,.6f,.28f};
    var fieldAnchors=new System.Collections.Generic.List<UnityEngine.Vector3>{new UnityEngine.Vector3(0,.08f,0)};
    for(int i=0;i<6;i++){float a=i*UnityEngine.Mathf.PI/3f;fieldAnchors.Add(new UnityEngine.Vector3(UnityEngine.Mathf.Cos(a)*1.65f,.08f,UnityEngine.Mathf.Sin(a)*1.65f));}
    for(int panel=0;panel<labels.Length;panel++)
    {
        effects.Clear();title.text=labels[panel];
        var profile=profiles[ids[panel]];
        var origin=new UnityEngine.Vector3(-2,.65f,0);var landing=new UnityEngine.Vector3(.8f,.1f,0);
        if(panel==0)landing.y=.65f;
        if(panel==3 || panel==4)
        {
            profile=ProjectY.Samples.BlockEffectCatalog.Variant(profile,panel==3?"embers":"mist",panel==3?42:49,1.15f);
            profile.Radius=.75f;profile.Height=panel==3?.35f:.55f;profile.Size=panel==3?.16f:.2f;
            profile.Speed=panel==3?1f:.16f;profile.Gravity=0;
            if(panel==4)profile.Emission=1.2f;
            effects.Play(profile,UnityEngine.Vector3.zero,UnityEngine.Vector3.zero,2304,anchors:fieldAnchors);
        }
        else effects.Play(profile,origin,landing,2304);
        float remaining=times[panel];while(remaining>0f){float step=UnityEngine.Mathf.Min(.02f,remaining);effects.Tick(step);remaining-=step;}
        UnityEngine.Canvas.ForceUpdateCanvases();manager.Update(stack,camera.transform,1<<previewLayer);
        ProjectY.Rendering.UrpCameraRendering.Render(camera,request);
        UnityEngine.RenderTexture.active=target;linear.ReadPixels(new UnityEngine.Rect(0,0,width,height),0,0);linear.Apply();
        var pixels=linear.GetPixels();var encoded=new UnityEngine.Color[pixels.Length];int pink=0,bright=0;
        for(int i=0;i<pixels.Length;i++)
        {
            encoded[i]=pixels[i].gamma;
            if(encoded[i].r>.9f && encoded[i].b>.9f && encoded[i].g<.12f)pink++;
            if(encoded[i].r>.65f || encoded[i].g>.65f || encoded[i].b>.65f)bright++;
        }
        if(pink>100)throw new System.InvalidOperationException("Shader error pixels in "+labels[panel]);
        if(bright<100)throw new System.InvalidOperationException("No readable effect in "+labels[panel]);
        sheet.SetPixels((panel%2)*width,(2-panel/2)*height,width,height,encoded);
        captures.Add(new {stage=labels[panel],skillId=ids[panel],seconds=times[panel],particles=effects.ActiveParticleCount,brightPixels=bright,pinkPixels=pink});
    }
    sheet.Apply();string output="Docs/Previews/Spellcasting";System.IO.Directory.CreateDirectory(output);
    string imagePath=output+"/skill-effects-contact-sheet.png";System.IO.File.WriteAllBytes(imagePath,sheet.EncodeToPNG());
    var result=new {image=imagePath,width=width*2,height=height*3,hdrTarget=true,bloomIntensity=bloom.intensity.value,
        currentPipeline=UnityEngine.Rendering.GraphicsSettings.currentRenderPipeline.name,playMode=false,sourceProfiles=true,captures};
    System.IO.File.WriteAllText(output+"/skill-effects-preview.json",Newtonsoft.Json.JsonConvert.SerializeObject(result,Newtonsoft.Json.Formatting.Indented));
    return result;
}
finally
{
    effects?.Dispose();manager.stack=originalStack;manager.DestroyStack(stack);UnityEngine.RenderTexture.active=originalTarget;
    if(target!=null){target.Release();UnityEngine.Object.DestroyImmediate(target);}
    if(linear!=null)UnityEngine.Object.DestroyImmediate(linear);if(sheet!=null)UnityEngine.Object.DestroyImmediate(sheet);
    if(previewProfile!=null){foreach(var component in previewProfile.components)UnityEngine.Object.DestroyImmediate(component);UnityEngine.Object.DestroyImmediate(previewProfile);}
    if(groundMaterial!=null)UnityEngine.Object.DestroyImmediate(groundMaterial);if(groundMesh!=null)UnityEngine.Object.DestroyImmediate(groundMesh);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
    UnityEngine.Random.state=originalRandom;
    if(UnityEngine.QualitySettings.renderPipeline!=originalPipeline || originalScene.isDirty!=originalDirty ||
       !UnityEngine.Random.state.Equals(originalRandom) || ProjectY.Samples.BlockParticleEffects.ActiveGlobalParticleCount!=baselineParticles)
        throw new System.InvalidOperationException("Skill capture leaked scene, pipeline, gameplay RNG or particle-budget state.");
}
