// Asset-only preview using the saved generated layout; no movement tests or Play.
var root="Art/AssetExpansion202610/ShipwreckV2";
ProjectY.Samples.MapAreaViewData map;
using(var lua=new XLua.LuaEnv())using(var row=(XLua.LuaTable)lua.DoString(System.IO.File.ReadAllText(root+"/Integration/sail_layout_snapshot.lua"))[0])map=ProjectY.Samples.MapAreaViewData.Read(row);
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
ProjectY.Samples.MapAreaRenderer renderer=null;
var previous=UnityEngine.RenderTexture.active;
var target=new UnityEngine.RenderTexture(1600,1000,24,UnityEngine.RenderTextureFormat.ARGBHalf,UnityEngine.RenderTextureReadWrite.Linear);target.Create();
var pixels=new UnityEngine.Texture2D(1600,1000,UnityEngine.TextureFormat.RGBAFloat,false,true);
var image=new UnityEngine.Texture2D(1600,1000,UnityEngine.TextureFormat.RGB24,false);
try{
 var host=new UnityEngine.GameObject("SailSizePreview");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(host,scene);
 var shader=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
 renderer=new ProjectY.Samples.MapAreaRenderer(shader,UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(map.AssetPath),map,a=>UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(a.Path));
 var all=new int[map.Cells.Length];for(int i=0;i<all.Length;i++)all[i]=i;
 renderer.UpdateVisibility(new ProjectY.Samples.MapAreaViewData.State{Known=all,Visible=all,Members=new ProjectY.Samples.MapAreaViewData.Member[0],Revision=1},true);
 var camera=new UnityEngine.GameObject("SailCamera").AddComponent<UnityEngine.Camera>();camera.transform.SetParent(host.transform,false);camera.scene=scene;camera.enabled=false;
 camera.targetTexture=target;camera.overrideSceneCullingMask=UnityEditor.SceneManagement.EditorSceneManager.GetSceneCullingMask(scene);camera.orthographic=true;camera.aspect=1.6f;camera.nearClipPlane=.1f;camera.farClipPlane=800;
 camera.clearFlags=UnityEngine.CameraClearFlags.SolidColor;camera.backgroundColor=new UnityEngine.Color(.13f,.22f,.25f);
 for(int i=0;i<2;i++){var light=new UnityEngine.GameObject("SailLight"+i).AddComponent<UnityEngine.Light>();light.transform.SetParent(host.transform,false);light.type=UnityEngine.LightType.Directional;light.intensity=i==0?1.15f:.38f;light.color=i==0?new UnityEngine.Color(1,.95f,.84f):new UnityEngine.Color(.7f,.83f,1);light.transform.rotation=UnityEngine.Quaternion.Euler(i==0?new UnityEngine.Vector3(48,-35,0):new UnityEngine.Vector3(32,140,0));}
 var hull=System.Array.Find(map.Props,p=>p.AssetId==800);var mast=System.Array.Find(map.Props,p=>p.AssetId==815);
 for(int v=0;v<2;v++){
  var focus=v==0?hull.Position+UnityEngine.Vector3.up*3:mast.Position+UnityEngine.Vector3.up*20;
  var rotation=UnityEngine.Quaternion.Euler(v==0?new UnityEngine.Vector3(50,-35,0):new UnityEngine.Vector3(22,-25,0));camera.orthographicSize=v==0?62:32;camera.transform.SetPositionAndRotation(focus-rotation*UnityEngine.Vector3.forward*250,rotation);
  renderer.Draw(camera);ProjectY.Rendering.UrpCameraRendering.Render(camera);UnityEngine.RenderTexture.active=target;pixels.ReadPixels(new UnityEngine.Rect(0,0,1600,1000),0,0);pixels.Apply();
  var linear=pixels.GetPixels();var encoded=new UnityEngine.Color32[linear.Length];for(int i=0;i<linear.Length;i++)encoded[i]=linear[i].gamma;image.SetPixels32(encoded);image.Apply();
  System.IO.File.WriteAllBytes(root+"/Previews/"+(v==0?"sail-enlarged-overview":"sail-enlarged-close")+".png",image.EncodeToPNG());
 }
 camera.targetTexture=null;
 var prefab=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>("Assets/DynamicAsset/AssetExpansion202610/ShipwreckV2/Prefabs/S2_Mast_Tall.prefab");
 var mesh=prefab.GetComponent<UnityEngine.MeshFilter>().sharedMesh;
 var geometry=Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText(root+"/Integration/sail_geometry.json"));
 if((float)geometry["sail_width"]<52f||(float)geometry["sail_height"]<23f||UnityEngine.Mathf.Abs(mesh.bounds.size.y-(float)geometry["mast_height"])>.002f)throw new System.Exception("Imported sail size differs from the measured source");
 var result=new Newtonsoft.Json.Linq.JObject(geometry);result["mast_height"]=mesh.bounds.size.y;result["base_unchanged"]=true;result["project_compile_requested"]=false;
 System.IO.File.WriteAllText(root+"/Integration/sail_resize_validation.json",result.ToString());return result;
}finally{UnityEngine.RenderTexture.active=previous;if(renderer!=null)renderer.Dispose();target.Release();UnityEngine.Object.DestroyImmediate(target);UnityEngine.Object.DestroyImmediate(pixels);UnityEngine.Object.DestroyImmediate(image);UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);}
