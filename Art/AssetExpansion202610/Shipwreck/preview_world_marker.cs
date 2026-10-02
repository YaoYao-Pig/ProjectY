var root="D:/Program/Unity/Project Y/Art/AssetExpansion202610/Shipwreck";
ProjectY.Samples.MapPreviewData map;
using(var lua=new XLua.LuaEnv())using(var row=(XLua.LuaTable)lua.DoString(System.IO.File.ReadAllText(root+"/Integration/world_snapshot.lua"))[0])map=ProjectY.Samples.MapPreviewData.Read(row);
var site=System.Array.Find(map.Decorations,d=>d.AssetId==600||d.AssetId==601);
if(site==null)throw new System.Exception("No natural shipwreck marker in generated world");
var focus=map.Cells[site.Cell].Position;focus.y=site.Height;
if(UnityEngine.Mathf.Abs(site.Height-map.Cells[site.Cell].WaterLevel)>.0001f)throw new System.Exception("Ship marker is not at actual water level");
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
ProjectY.Samples.MapPreviewRenderer renderer=null;UnityEngine.RenderTexture target=null;UnityEngine.Texture2D image=null;
var previous=UnityEngine.RenderTexture.active;
try{
    var host=new UnityEngine.GameObject("Shipwreck_WorldPreview");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(host,scene);
    var shader=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
    renderer=new ProjectY.Samples.MapPreviewRenderer(shader,host.transform);renderer.Build(map,a=>UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(a.Path));
    var camera=new UnityEngine.GameObject("WorldCamera").AddComponent<UnityEngine.Camera>();UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(camera.gameObject,scene);
    camera.scene=scene;camera.enabled=false;camera.orthographic=true;camera.orthographicSize=4;camera.nearClipPlane=.01f;camera.farClipPlane=200;camera.allowHDR=false;
    camera.clearFlags=UnityEngine.CameraClearFlags.SolidColor;camera.backgroundColor=new UnityEngine.Color(.16f,.26f,.30f);
    camera.transform.position=focus+new UnityEngine.Vector3(7,10,10);camera.transform.LookAt(focus);
    for(int i=0;i<2;i++){
        var light=new UnityEngine.GameObject("WorldLight"+i).AddComponent<UnityEngine.Light>();UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(light.gameObject,scene);
        light.type=UnityEngine.LightType.Directional;light.intensity=i==0?1.4f:.6f;light.transform.rotation=UnityEngine.Quaternion.Euler(i==0?new UnityEngine.Vector3(48,-35,0):new UnityEngine.Vector3(25,145,0));
    }
    target=new UnityEngine.RenderTexture(1200,900,24,UnityEngine.RenderTextureFormat.ARGB32);target.Create();camera.targetTexture=target;
    renderer.Draw(camera,true,true,true,true);ProjectY.Rendering.UrpCameraRendering.Render(camera);
    UnityEngine.RenderTexture.active=target;image=new UnityEngine.Texture2D(1200,900,UnityEngine.TextureFormat.RGBA32,false);image.ReadPixels(new UnityEngine.Rect(0,0,1200,900),0,0);image.Apply();
    System.IO.File.WriteAllBytes(root+"/Previews/generated_world_marker.png",image.EncodeToPNG());camera.targetTexture=null;
    var report=new Newtonsoft.Json.Linq.JObject(new Newtonsoft.Json.Linq.JProperty("assetId",site.AssetId),new Newtonsoft.Json.Linq.JProperty("height",site.Height),new Newtonsoft.Json.Linq.JProperty("waterLevel",map.Cells[site.Cell].WaterLevel),new Newtonsoft.Json.Linq.JProperty("real_world_cells",map.Cells.Length));
    System.IO.File.WriteAllText(root+"/Integration/world_marker_preview.json",report.ToString());return report;
}finally{
    UnityEngine.RenderTexture.active=previous;if(renderer!=null)renderer.Dispose();if(target!=null){target.Release();UnityEngine.Object.DestroyImmediate(target);}if(image!=null)UnityEngine.Object.DestroyImmediate(image);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
}
