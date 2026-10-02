// Inspect only the seven newly authored assets in an isolated scene.
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var root=new GameObject("ConstructionArtPreview");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
var cameraObject=new GameObject("PreviewCamera");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);
var camera=cameraObject.AddComponent<Camera>();camera.enabled=false;camera.scene=scene;camera.orthographic=true;camera.orthographicSize=3.8f;
camera.transform.position=new Vector3(9,10,-12);camera.transform.LookAt(new Vector3(0,.25f,0));camera.nearClipPlane=.01f;camera.farClipPlane=60;
camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.12f,.15f,.13f);ProjectY.Rendering.UrpCameraRendering.ConfigurePreview(camera);
var lightObject=new GameObject("PreviewSun");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(lightObject,scene);var light=lightObject.AddComponent<Light>();light.type=LightType.Directional;light.intensity=1.7f;light.transform.rotation=Quaternion.Euler(48,-35,0);light.shadows=LightShadows.Soft;
var target=new RenderTexture(1440,900,24,RenderTextureFormat.ARGB32);target.Create();camera.targetTexture=target;var previous=RenderTexture.active;
var palette=new System.Collections.Generic.List<Material>();var report=new System.Collections.Generic.List<string>();
try
{
    var ground=GameObject.CreatePrimitive(PrimitiveType.Cube);ground.name="Ground";UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(ground,scene);ground.transform.SetParent(root.transform,false);
    ground.transform.position=new Vector3(0,-.20f,0);ground.transform.localScale=new Vector3(9.7f,.3f,6);
    var shader=Shader.Find("Universal Render Pipeline/Lit");var mat=new Material(shader);mat.color=new Color(.36f,.44f,.29f);mat.SetFloat("_Smoothness",.08f);palette.Add(mat);ground.GetComponent<Renderer>().sharedMaterial=mat;
    string[] names={"Craft_Fence","Craft_Wall","Craft_Step","Craft_Platform","Craft_WoodBundle","Craft_RopeCoil","Craft_IronParts"};
    for(int i=0;i<names.Length;i++)
    {
        var asset=UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(ProjectY.Editor.ConstructionAssets.Root+"/Models/"+names[i]+".fbx");
        if(asset==null)throw new System.Exception("Missing model "+names[i]);
        var obj=UnityEngine.Object.Instantiate(asset,root.transform,false);obj.transform.position=new Vector3(i<4?-3.2f+i*2.1f:-2.1f+(i-4)*2.1f,0,i<4?1.1f:-1.45f);
        var renderers=obj.GetComponentsInChildren<Renderer>();var bounds=renderers[0].bounds;
        foreach(var renderer in renderers){bounds.Encapsulate(renderer.bounds);foreach(var material in renderer.sharedMaterials)if(material==null||material.shader.name=="Hidden/InternalErrorShader")throw new System.Exception("Invalid material "+names[i]);}
        if(bounds.size.x>2.6f||bounds.size.z>2.6f)throw new System.Exception("Model exceeds a single map cell "+names[i]);
        report.Add(names[i]+" "+bounds.size.ToString("F3"));
    }
    ProjectY.Rendering.UrpCameraRendering.Render(camera);RenderTexture.active=target;var image=new Texture2D(target.width,target.height,TextureFormat.RGBA32,false);
    try{image.ReadPixels(new Rect(0,0,target.width,target.height),0,0);image.Apply();System.IO.Directory.CreateDirectory("Docs/Previews/SkillAtlas");System.IO.File.WriteAllBytes("Docs/Previews/SkillAtlas/construction-models.png",image.EncodeToPNG());}
    finally{UnityEngine.Object.DestroyImmediate(image);}
    return string.Join("\n",report.ToArray());
}
finally{camera.targetTexture=null;RenderTexture.active=previous;target.Release();UnityEngine.Object.DestroyImmediate(target);foreach(var material in palette)UnityEngine.Object.DestroyImmediate(material);UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);}
