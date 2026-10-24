// Unity MCP method body: native prefab/socket/material/icon audit and isolated offscreen renders.
if(EditorApplication.isPlayingOrWillChangePlaymode)throw new System.InvalidOperationException("Edit Mode required");
var root="D:/Program/Unity/Project Y/Art/FirearmsExpansion202610";
var rows=Newtonsoft.Json.Linq.JArray.Parse(System.IO.File.ReadAllText(root+"/manifest.json"));
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var previous=RenderTexture.active;
RenderTexture target=null;Texture2D image=null;
var audit=new Newtonsoft.Json.Linq.JArray();
try {
    var camera=new GameObject("FirearmReview").AddComponent<Camera>();
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(camera.gameObject,scene);
    camera.scene=scene;camera.enabled=false;camera.orthographic=true;camera.allowHDR=false;
    camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.065f,.08f,.10f,1);
    camera.nearClipPlane=.01f;camera.farClipPlane=30;
    for(int j=0;j<2;j++){
        var light=new GameObject("FirearmLight"+j).AddComponent<Light>();
        UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(light.gameObject,scene);
        light.type=LightType.Directional;light.intensity=j==0?1.25f:.65f;
        light.color=j==0?new Color(1,.92f,.80f):new Color(.65f,.8f,1);
        light.transform.rotation=Quaternion.Euler(j==0?new Vector3(28,-32,0):new Vector3(15,145,0));
    }
    target=new RenderTexture(720,360,24,RenderTextureFormat.ARGB32);target.Create();camera.targetTexture=target;
    image=new Texture2D(720,360,TextureFormat.RGBA32,false);
    System.IO.Directory.CreateDirectory(root+"/Previews");
    foreach(var row in rows){
        int id=(int)row["id"];bool weapon=(string)row["kind"]=="weapon";
        string model=(string)row["model"];
        string path="Assets/DynamicAsset/FirearmsExpansion202610/"+(weapon?"Weapons/"+model+".prefab":"Models/"+model+".fbx");
        var prefab=AssetDatabase.LoadAssetAtPath<GameObject>(path);
        if(prefab==null)throw new System.Exception("Missing prefab "+id);
        var sprite=AssetDatabase.LoadAssetAtPath<Sprite>("Assets/DynamicAsset/FirearmsExpansion202610/Icons/Item_"+id+".png");
        if(sprite==null)throw new System.Exception("Missing sprite "+id);
        var obj=(GameObject)PrefabUtility.InstantiatePrefab(prefab,scene);
        if(weapon){
            var view=obj.GetComponent<ProjectY.Samples.WeaponModelView>();
            int[] modules=new int[]{(int)row["magazine"],id==802||id==803?814:813,id==802||id==803?816:815,818};
            for(int n=0;n<4;n++){
                var socket=view.Socket(400+(id-800)*4+n);
                string modulePath=modules[n]==21?"Assets/DynamicAsset/EquipmentDemo/Models/Equip_Magazine.fbx":"Assets/DynamicAsset/FirearmsExpansion202610/Models/Firearm_"+modules[n]+".fbx";
                var module=(GameObject)PrefabUtility.InstantiatePrefab(AssetDatabase.LoadAssetAtPath<GameObject>(modulePath),scene);
                module.transform.SetParent(socket,false);
            }
            obj.transform.rotation=Quaternion.Euler(0,-90,0);
        } else obj.transform.rotation=Quaternion.Euler(0,25,0);
        var renderers=obj.GetComponentsInChildren<Renderer>();var bounds=renderers[0].bounds;
        foreach(var renderer in renderers){
            bounds.Encapsulate(renderer.bounds);
            foreach(var mat in renderer.sharedMaterials)if(mat==null||mat.shader==null||mat.shader.name=="Hidden/InternalErrorShader")throw new System.Exception("Missing material "+id);
        }
        float span=Mathf.Max(bounds.size.x,bounds.size.y,bounds.size.z);
        if(span<=0||span>4)throw new System.Exception("Invalid model dimensions "+id);
        audit.Add(new Newtonsoft.Json.Linq.JObject{{"id",id},{"renderers",renderers.Length},{"maximumExtent",span},{"sockets",weapon?4:0},{"sprite",true}});
        obj.transform.localScale=Vector3.one/span;obj.transform.position=-bounds.center/span;
        camera.orthographicSize=.32f;camera.transform.position=new Vector3(-.3f,.8f,-4);camera.transform.LookAt(Vector3.zero);
        ProjectY.Rendering.UrpCameraRendering.Render(camera);
        RenderTexture.active=target;image.ReadPixels(new Rect(0,0,720,360),0,0);image.Apply();
        System.IO.File.WriteAllBytes(root+"/Previews/"+id+".png",image.EncodeToPNG());
        UnityEngine.Object.DestroyImmediate(obj);
    }
    camera.targetTexture=null;
    System.IO.File.WriteAllText(root+"/Integration/unity-assets.json",audit.ToString());
} finally {
    RenderTexture.active=previous;
    if(image!=null)UnityEngine.Object.DestroyImmediate(image);
    if(target!=null){target.Release();UnityEngine.Object.DestroyImmediate(target);}
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
}
return new {audited=audit.Count,installedWeapons=6,socketBindings=24,play=EditorApplication.isPlaying};
