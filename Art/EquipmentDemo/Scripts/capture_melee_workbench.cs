if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.InvalidOperationException("Edit Mode required");
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var hostObj=new GameObject("MeleeWorkbenchPreview");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(hostObj,scene);
var host=hostObj.AddComponent<ProjectY.UI.UIHost>();host.Initialize();
var prior=RenderTexture.active;var paths=new System.Collections.Generic.List<string>();
using(var lua=new XLua.LuaEnv()){
var services=new ProjectY.FrameworkServices(host);var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
try{
lua.DoString(System.IO.File.ReadAllText("Tools/Tests/equipment_preview.lua"));lua.DoString("EquipmentPreviewModify()");
var camera=new GameObject("CaptureCamera").AddComponent<Camera>();UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(camera.gameObject,scene);camera.scene=scene;camera.enabled=false;camera.orthographic=true;camera.nearClipPlane=.1f;camera.farClipPlane=100;camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.04f,.05f,.045f);camera.cullingMask=1<<30;camera.transform.position=new Vector3(0,0,-10);
Canvas canvas=null;foreach(var c in hostObj.GetComponentsInChildren<Canvas>(true)) if(c.name=="UIRoot")canvas=c;
canvas.GetComponent<UnityEngine.UI.CanvasScaler>().enabled=false;canvas.renderMode=RenderMode.WorldSpace;canvas.worldCamera=camera;
var root=(RectTransform)canvas.transform;root.localPosition=Vector3.zero;root.localScale=Vector3.one;
var workbench=hostObj.GetComponentInChildren<ProjectY.UI.EquipmentWorkbenchView>(true);var layout=workbench.EditorLayout;
var folder="Art/EquipmentDemo/Previews";
var dimensions=new int[,]{{1280,720},{1024,768},{2560,1080},{720,1280},{1280,720},{1280,720},{1280,720}};
for(int i=0;i<dimensions.GetLength(0);i++){
 if(i==4)lua.DoString("EquipmentPreviewMelee(45,false,4)");
 if(i==5)lua.DoString("EquipmentPreviewMelee(45,true,4)");
 if(i==6)lua.DoString("EquipmentPreviewMelee(41,false,1)");
 if(i==4||i==5)workbench.GetType().GetField("yaw",System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Instance).SetValue(workbench,-35f);
 int w=dimensions[i,0],h=dimensions[i,1];var scale=Mathf.Sqrt((w/1280f)*(h/720f));var lw=w/scale;var lh=h/scale;
 root.sizeDelta=new Vector2(lw,lh);camera.orthographicSize=lh/2;camera.aspect=(float)w/h;
 Canvas.ForceUpdateCanvases();workbench.Arrange();UnityEngine.UI.LayoutRebuilder.ForceRebuildLayoutImmediate(root);Canvas.ForceUpdateCanvases();workbench.RenderPreview();Canvas.ForceUpdateCanvases();
 for(int n=0;n<layout.Sockets.Length;n++){
  var label=layout.Sockets[n];if(!label.gameObject.activeSelf)continue;
  var p=label.anchoredPosition;var half=label.sizeDelta*.5f;var sz=layout.Preview.rect.size;
  if(p.x-half.x<0||p.y-half.y<0||p.x+half.x>sz.x||p.y+half.y>sz.y)throw new System.Exception("Callout outside preview "+w+"x"+h);
  if(!layout.SocketLeads[n].gameObject.activeSelf||layout.SocketLeads[n].sizeDelta.x<1)throw new System.Exception("Missing socket leader");
  if(Vector2.Distance(layout.SocketLeads[n].anchoredPosition,layout.SocketDots[n].anchoredPosition)>.01f)throw new System.Exception("Leader does not begin at socket marker");
 }
 foreach(var t in canvas.GetComponentsInChildren<Transform>(true)) t.gameObject.layer=30;
 var target=new RenderTexture(w,h,24,RenderTextureFormat.ARGB32);target.antiAliasing=4;target.Create();Texture2D picture=null;
 try{
 camera.targetTexture=target;camera.Render();RenderTexture.active=target;picture=new Texture2D(w,h,TextureFormat.RGB24,false);picture.ReadPixels(new Rect(0,0,w,h),0,0);picture.Apply();
 var name=i<4?"workbench-leaders-"+w+"x"+h:i==4?"workbench-colossal-base":i==5?"workbench-colossal-thruster":"workbench-knight-sword";
 var path=System.IO.Path.GetFullPath(folder+"/"+name+".png");System.IO.File.WriteAllBytes(path,picture.EncodeToPNG());paths.Add(path);
 }finally{camera.targetTexture=null;RenderTexture.active=prior;if(picture!=null)UnityEngine.Object.DestroyImmediate(picture);target.Release();UnityEngine.Object.DestroyImmediate(target);}
}
lua.DoString("EquipmentPreviewRegistry:Get('UI'):Close('EquipmentWorkbench')");
foreach(var c in UnityEngine.Resources.FindObjectsOfTypeAll<Camera>())if(c.name=="PreviewCamera")throw new System.Exception("Workbench leaked preview camera");
return paths;
}finally{lua.DoString("EquipmentPreviewRegistry:Shutdown();EquipmentPreviewRegistry=nil;EquipmentPreviewPanel=nil;EquipmentPreviewAppearance=nil;EquipmentPreviewModify=nil;EquipmentPreviewGun=nil;EquipmentPreviewMelee=nil;Services=nil;collectgarbage('collect')");services.Player.ClearListeners();host.Shutdown();UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);}
}
