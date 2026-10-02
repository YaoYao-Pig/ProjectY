// Native Unity MCP method body. Uses actual generated snapshot, no gameplay mutation.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode)throw new System.Exception("Edit Mode required");
var root="D:/Program/Unity/Project Y/Art/AssetExpansion202610/Shipwreck";
ProjectY.Samples.MapAreaViewData map;
using(var lua=new XLua.LuaEnv()){
    using(var rows=(XLua.LuaTable)lua.DoString(System.IO.File.ReadAllText(root+"/Integration/layout_snapshot.lua"))[0])map=ProjectY.Samples.MapAreaViewData.Read(rows);
}
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
ProjectY.Samples.MapAreaRenderer renderer=null;
UnityEngine.RenderTexture target=null;UnityEngine.Texture2D image=null;
var previous=UnityEngine.RenderTexture.active;
var models=new System.Collections.Generic.Dictionary<int,UnityEngine.GameObject>();
foreach(var asset in map.PropAssets){var p=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(asset.Path);if(p==null)throw new System.Exception("Missing "+asset.Path);models.Add(asset.Id,p);}
try{
    var shader=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
    renderer=new ProjectY.Samples.MapAreaRenderer(shader,UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(map.AssetPath),map,a=>models[a.Id]);
    var all=new int[map.Cells.Length];for(int i=0;i<all.Length;i++)all[i]=i;
    var state=new ProjectY.Samples.MapAreaViewData.State{Known=all,Visible=all,Members=new ProjectY.Samples.MapAreaViewData.Member[0],Revision=1,ConstructionRevision=0};
    renderer.UpdateVisibility(state,true);
    var hull=System.Array.Find(map.Props,p=>models[p.AssetId].name=="SW_Hull_CogWreck");
    if(hull==null)throw new System.Exception("Generated map lacks hull");
    var focus=hull.Position+UnityEngine.Vector3.up*1.5f;
    var cam=new UnityEngine.GameObject("Shipwreck_GeneratedCamera").AddComponent<UnityEngine.Camera>();UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cam.gameObject,scene);
    cam.scene=scene;cam.enabled=false;cam.orthographic=true;cam.orthographicSize=21;cam.nearClipPlane=.1f;cam.farClipPlane=250;cam.allowHDR=false;
    cam.clearFlags=UnityEngine.CameraClearFlags.SolidColor;cam.backgroundColor=new UnityEngine.Color(.18f,.32f,.36f);
    for(int i=0;i<2;i++){
        var light=new UnityEngine.GameObject("Shipwreck_Light"+i).AddComponent<UnityEngine.Light>();UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(light.gameObject,scene);
        light.type=UnityEngine.LightType.Directional;light.intensity=i==0?1.35f:.75f;light.color=i==0?new UnityEngine.Color(1,.96f,.84f):new UnityEngine.Color(.7f,.83f,1);
        light.transform.rotation=UnityEngine.Quaternion.Euler(i==0?new UnityEngine.Vector3(48,-35,0):new UnityEngine.Vector3(25,145,0));
    }
    target=new UnityEngine.RenderTexture(1400,1000,24,UnityEngine.RenderTextureFormat.ARGB32);target.Create();cam.targetTexture=target;
    image=new UnityEngine.Texture2D(1400,1000,UnityEngine.TextureFormat.RGBA32,false);
    for(int v=0;v<3;v++){
        var direction=v==0?new UnityEngine.Vector3(36,42,46):v==1?new UnityEngine.Vector3(0,70,0):new UnityEngine.Vector3(60,25,0);
        cam.transform.position=focus+direction;cam.transform.LookAt(focus);
        renderer.Draw(cam);ProjectY.Rendering.UrpCameraRendering.Render(cam);
        UnityEngine.RenderTexture.active=target;image.ReadPixels(new UnityEngine.Rect(0,0,1400,1000),0,0);image.Apply();
        System.IO.File.WriteAllBytes(root+"/Previews/generated_"+(v==0?"hero":v==1?"top":"side")+".png",image.EncodeToPNG());
    }
    cam.targetTexture=null;
    var output=new Newtonsoft.Json.Linq.JObject();output["areaType"]=map.AreaType;output["cells"]=map.Cells.Length;output["props"]=map.Props.Length;
    output["cameraObstacles"]=renderer.CameraObstacles.Count;output["renderPath"]="actual MapAreaViewData.Read -> MapAreaRenderer.UpdateVisibility/Draw -> URP offscreen camera";
    output["playing"]=false;System.IO.File.WriteAllText(root+"/Integration/unity_generated_preview.json",output.ToString());return output;
}finally{
    UnityEngine.RenderTexture.active=previous;
    if(renderer!=null)renderer.Dispose();if(target!=null){target.Release();UnityEngine.Object.DestroyImmediate(target);}if(image!=null)UnityEngine.Object.DestroyImmediate(image);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
}
