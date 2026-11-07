// Native MCP method body: optical-depth behavior of the production water shader; no Play or project asset writes.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)throw new Exception("Idle Edit Mode required");
var original=UnityEngine.SceneManagement.SceneManager.GetActiveScene();bool dirty=original.isDirty;
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var owner=new GameObject("Water depth validation");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(owner,scene);
var camera=new GameObject("Camera").AddComponent<Camera>();camera.transform.SetParent(owner.transform,false);camera.enabled=false;camera.scene=scene;
camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);
camera.orthographic=true;camera.orthographicSize=5;camera.aspect=1.6f;camera.nearClipPlane=.1f;camera.farClipPlane=100;
camera.transform.SetPositionAndRotation(new Vector3(0,20,-16.8f),Quaternion.Euler(50,0,0));
camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=Color.black;
ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
var sun=new GameObject("Sun").AddComponent<Light>();sun.transform.SetParent(owner.transform,false);sun.type=LightType.Directional;sun.intensity=1.3f;sun.transform.rotation=Quaternion.Euler(50,-30,0);
var plane=GameObject.CreatePrimitive(PrimitiveType.Plane);plane.transform.SetParent(owner.transform,false);plane.transform.localScale=Vector3.one*4;
var material=new Material(Resources.Load<Shader>("MapWater"));plane.GetComponent<MeshRenderer>().sharedMaterial=material;
var field=new Texture2D(1,1,TextureFormat.RGBAFloat,false,true){filterMode=FilterMode.Bilinear,wrapMode=TextureWrapMode.Clamp};
material.SetTexture("_WaterBoundaryField",field);material.SetFloat("_WaterBoundaryEnabled",1);material.SetFloat("_WaterScale",1);
material.SetVector("_WaterBoundaryBounds",new Vector4(0,0,1,1));material.SetFloat("_WorldFogEnabled",0);material.SetFloat("_WaterPreviewTime",0);
var target=new RenderTexture(640,400,24,RenderTextureFormat.ARGB32,RenderTextureReadWrite.sRGB);target.Create();camera.targetTexture=target;
var image=new Texture2D(640,400,TextureFormat.RGB24,false);var previous=RenderTexture.active;
var means=new System.Collections.Generic.List<Color>();var luminances=new System.Collections.Generic.List<float>();
float rippleContrast=0;
string folder="Docs/Previews/WaterStyle";System.IO.Directory.CreateDirectory(folder);
try
{
    if(UnityEditor.ShaderUtil.ShaderHasError(material.shader))throw new Exception("Water shader compile error");
    foreach(float depth in new[]{.25f,1.5f,5f,12f})
    {
        field.SetPixel(0,0,new Color(1,0,16,depth));field.Apply(false,false);
        ProjectY.Rendering.UrpCameraRendering.Render(camera);RenderTexture.active=target;image.ReadPixels(new Rect(0,0,640,400),0,0);image.Apply();
        var colors=image.GetPixels();var average=Color.black;
        foreach(var color in colors)average+=color;average/=colors.Length;means.Add(average);
        luminances.Add(average.r*.2126f+average.g*.7152f+average.b*.0722f);
        if(depth==1.5f)
        {
            var values=colors.Select(c=>c.r*.2126f+c.g*.7152f+c.b*.0722f).OrderBy(v=>v).ToArray();
            rippleContrast=values[(int)(values.Length*.95f)]-values[(int)(values.Length*.05f)];
            if(rippleContrast<.045f)throw new Exception("Close-view ripple contrast is too weak: "+rippleContrast);
        }
        System.IO.File.WriteAllBytes(folder+"/depth-"+depth.ToString("0.00",System.Globalization.CultureInfo.InvariantCulture)+".png",image.EncodeToPNG());
    }
    for(int i=1;i<luminances.Count;i++)if(luminances[i]>=luminances[i-1]-.015f)throw new Exception("Depth does not darken progressively: "+string.Join(",",luminances));
    if(luminances[0]<luminances[3]+.10f)throw new Exception("Shallow water is not distinctly lighter");
    if(means[0].g<=means[0].b)throw new Exception("Shallow water did not shift toward muted green/teal");
    string report="PASS production shader: shallow water is lighter/teal, increasing optical depth darkens progressively; display luminance="+string.Join(",",luminances)+"; close ripple p95-p05 contrast="+rippleContrast;
    System.IO.File.WriteAllText(folder+"/depth-validation.txt",report);return report;
}
finally
{
    camera.targetTexture=null;RenderTexture.active=previous;target.Release();UnityEngine.Object.DestroyImmediate(target);
    UnityEngine.Object.DestroyImmediate(image);UnityEngine.Object.DestroyImmediate(field);UnityEngine.Object.DestroyImmediate(material);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
    if(UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=original)UnityEngine.SceneManagement.SceneManager.SetActiveScene(original);
    if(original.isDirty!=dirty)throw new Exception("Water depth validation modified original scene");
}
