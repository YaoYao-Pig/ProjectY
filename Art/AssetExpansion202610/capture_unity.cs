// Offscreen isolated PreviewScene, no scene load, play, or project compilation.
var group="Terrain";
var root="D:/Program/Unity/Project Y/Art/AssetExpansion202610/"+group;
var rows=Newtonsoft.Json.Linq.JArray.Parse(System.IO.File.ReadAllText(root+"/manifest.json"));
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var previous=UnityEngine.RenderTexture.active;
UnityEngine.RenderTexture target=null;
UnityEngine.Texture2D image=null;
try {
    var camera=new UnityEngine.GameObject("AE_ReviewCamera").AddComponent<UnityEngine.Camera>();
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(camera.gameObject,scene);
    camera.scene=scene;camera.enabled=false;camera.orthographic=true;camera.allowHDR=false;
    camera.clearFlags=UnityEngine.CameraClearFlags.SolidColor;camera.backgroundColor=new UnityEngine.Color(.08f,.095f,.12f,0);
    camera.nearClipPlane=.01f;camera.farClipPlane=30f;
    for(int j=0;j<2;j++){
        var light=new UnityEngine.GameObject("AE_Light"+j).AddComponent<UnityEngine.Light>();
        UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(light.gameObject,scene);
        light.type=UnityEngine.LightType.Directional;light.intensity=j==0?1.3f:.7f;
        light.color=j==0?new UnityEngine.Color(1,.92f,.80f):new UnityEngine.Color(.65f,.80f,1);
        light.transform.rotation=UnityEngine.Quaternion.Euler(j==0?new UnityEngine.Vector3(28,-32,0):new UnityEngine.Vector3(15,145,0));
    }
    target=new UnityEngine.RenderTexture(512,512,24,UnityEngine.RenderTextureFormat.ARGB32);target.Create();
    camera.targetTexture=target;
    image=new UnityEngine.Texture2D(512,512,UnityEngine.TextureFormat.RGBA32,false);
    System.IO.Directory.CreateDirectory(root+"/UnityPreviews");
    foreach(var row in rows){
        var name=(string)row["name"];
        var prefab=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>("Assets/DynamicAsset/AssetExpansion202610/"+group+"/Prefabs/"+name+".prefab");
        var obj=(UnityEngine.GameObject)UnityEditor.PrefabUtility.InstantiatePrefab(prefab,scene);
        var rs=obj.GetComponentsInChildren<UnityEngine.Renderer>();var bounds=rs[0].bounds;
        foreach(var r in rs)bounds.Encapsulate(r.bounds);
        var span=UnityEngine.Mathf.Max(bounds.size.x,bounds.size.y,bounds.size.z);
        obj.transform.localScale=UnityEngine.Vector3.one/span;obj.transform.position=-bounds.center/span;
        camera.orthographicSize=.8f;camera.transform.position=new UnityEngine.Vector3(-2.6f,2.6f,4f);camera.transform.LookAt(UnityEngine.Vector3.zero);
        ProjectY.Rendering.UrpCameraRendering.Render(camera);
        UnityEngine.RenderTexture.active=target;image.ReadPixels(new UnityEngine.Rect(0,0,512,512),0,0);image.Apply();
        System.IO.File.WriteAllBytes(root+"/UnityPreviews/"+name+".png",image.EncodeToPNG());
        UnityEngine.Object.DestroyImmediate(obj);
    }
    camera.targetTexture=null;
} finally {
    UnityEngine.RenderTexture.active=previous;
    if(image!=null)UnityEngine.Object.DestroyImmediate(image);
    if(target!=null){target.Release();UnityEngine.Object.DestroyImmediate(target);}
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
}
return new {group=group,rendered=rows.Count,directory=root+"/UnityPreviews"};
