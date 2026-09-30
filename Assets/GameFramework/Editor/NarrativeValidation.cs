using System;
using System.IO;
using System.Runtime.CompilerServices;
using UnityEditor;
using UnityEngine;
using XLua;
using UnityEditor.SceneManagement;
using UnityEngine.SceneManagement;
using ProjectY.UI;
using ProjectY.Samples;

namespace ProjectY.Editor
{
    public static class NarrativeValidation
    {
        [MenuItem("Project Y/叙事/验证任务对话与 NPC")]
        public static void Run()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode)throw new InvalidOperationException("Narrative checks require Edit Mode.");
            var file=Path.Combine(Path.GetTempPath(),"project-y-narrative-"+Guid.NewGuid().ToString("N")+".json");
            var services=new FrameworkServices(null,file);
            try
            {
                using(var lua=new LuaEnv())
                {
                    var loader=new LuaFileLoader(LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
                    try{Debug.Log(Check(lua));}
                    finally{lua.DoString("if CloseNarrativeFixture then CloseNarrativeFixture() end");lua.Global.Set<string,object>("Services",null);}
                }
            }
            finally{services.Player.ClearListeners();foreach(var path in new[]{file,file+".bak",file+".tmp"})if(File.Exists(path))File.Delete(path);}
        }
        [MethodImpl(MethodImplOptions.NoInlining)]
        private static string Check(LuaEnv lua)=> (string)lua.DoString(File.ReadAllText("Tools/Tests/narrative_integration.lua"),"@Tools/Tests/narrative_integration.lua")[0];

        [MenuItem("Project Y/叙事/验证对话 UI 与镜头")]
        public static void RunUI()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode)throw new InvalidOperationException("Narrative UI checks require Edit Mode.");
            var scene=EditorSceneManager.NewPreviewScene();var root=new GameObject("NarrativePreview");SceneManager.MoveGameObjectToScene(root,scene);
            var host=root.AddComponent<UIHost>();host.Initialize();
            var font=Font.CreateDynamicFontFromOSFont(new[]{"Microsoft YaHei","Arial"},18);
            var cameraObject=new GameObject("NarrativePreviewCamera");SceneManager.MoveGameObjectToScene(cameraObject,scene);var camera=cameraObject.AddComponent<Camera>();
            camera.scene=scene;camera.overrideSceneCullingMask=EditorSceneManager.GetSceneCullingMask(scene);camera.enabled=false;camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.12f,.18f,.16f);
            camera.transform.SetPositionAndRotation(new Vector3(0,4,-9),Quaternion.Euler(18,0,0));camera.fieldOfView=50;
            var lightObject=new GameObject("NarrativePreviewSun");SceneManager.MoveGameObjectToScene(lightObject,scene);var light=lightObject.AddComponent<Light>();light.type=LightType.Directional;light.intensity=1.1f;light.transform.rotation=Quaternion.Euler(45,-30,0);
            var rig=AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/PawnLowPoly/PawnRig.prefab").GetComponent<PawnView>();
            var pawns=new[]{UnityEngine.Object.Instantiate(rig),UnityEngine.Object.Instantiate(rig)};
            for(int i=0;i<pawns.Length;i++){SceneManager.MoveGameObjectToScene(pawns[i].gameObject,scene);pawns[i].transform.position=new Vector3(i==0?-1.8f:1.8f,0,0);pawns[i].transform.rotation=Quaternion.Euler(0,i==0?70:-70,0);}
            var services=new FrameworkServices(host);
            try
            {
                using(var lua=new LuaEnv())
                {
                    var loader=new LuaFileLoader(LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);lua.Global.Set("PreviewNarrativeFont",font);
                    try
                    {
                        Debug.Log((string)lua.DoString(File.ReadAllText("Tools/Tests/narrative_ui.lua"),"@Tools/Tests/narrative_ui.lua")[0]);
                        using(var appearances=(LuaTable)lua.DoString("return NarrativePreviewActors()")[0])
                            for(int i=0;i<2;i++)using(var row=appearances.Get<int,LuaTable>(i+1))pawns[i].ApplyAppearance(PawnAppearanceData.Read(row),part=>AssetDatabase.LoadAssetAtPath<GameObject>(part.Path));
                        var originalPosition=camera.transform.position;var originalRect=camera.rect;
                        using(var cinematic=new DialogueCamera(camera,root.transform,5,1.25f,22,45,0,.7f,new System.Collections.Generic.List<Bounds>(),(ray,distance)=>distance))
                        {
                            lua.DoString("PreviewNarrativePage('dialogue')");
                            cinematic.Tick(pawns[0].transform.position,pawns[1].transform.position,"pair",440f/1280);
                            Capture(root,camera,"dialogue");
                            foreach(var pawn in pawns){var point=camera.WorldToViewportPoint(pawn.transform.position+Vector3.up);if(point.z<=0||point.x<=0||point.x>=1||point.y<=0||point.y>=1)throw new InvalidOperationException("Dialogue target outside camera composition.");}
                            cinematic.Return();cinematic.Tick(Vector3.zero,Vector3.zero,"pair",0);
                        }
                        if(camera.rect!=originalRect || Vector3.Distance(camera.transform.position,originalPosition)>.001f)throw new InvalidOperationException("Dialogue camera failed to restore output.");
                        lua.DoString("PreviewNarrativePage('missions')");Capture(root,camera,"missions");
                        Debug.Log("PASS narrative UI visibility, two-person Cinemachine framing and camera restoration; previews in Docs/Previews.");
                    }
                    finally{lua.DoString("if CloseNarrativePreview then CloseNarrativePreview() end");lua.Global.Set<string,object>("Services",null);lua.Global.Set<string,object>("PreviewNarrativeFont",null);services.Player.ClearListeners();}
                }
            }
            finally{host.Shutdown();UnityEngine.Object.DestroyImmediate(font);EditorSceneManager.ClosePreviewScene(scene);}
        }
        private static void Capture(GameObject root,Camera camera,string name)
        {
            var texture=new RenderTexture(1280,720,24);var previous=RenderTexture.active;Texture2D image=null;
            var uiObject=new GameObject("NarrativeUICamera");SceneManager.MoveGameObjectToScene(uiObject,camera.scene);var uiCamera=uiObject.AddComponent<Camera>();
            uiCamera.enabled=false;uiCamera.scene=camera.scene;uiCamera.overrideSceneCullingMask=camera.overrideSceneCullingMask;uiCamera.clearFlags=CameraClearFlags.Depth;
            uiCamera.cullingMask=1<<31;uiCamera.orthographic=true;uiCamera.orthographicSize=360;uiCamera.transform.position=new Vector3(0,0,-10);
            uiCamera.nearClipPlane=.1f;uiCamera.farClipPlane=100;var oldMask=camera.cullingMask;camera.cullingMask=~(1<<31);
            try
            {
                camera.targetTexture=texture;uiCamera.targetTexture=texture;
                foreach(var item in root.GetComponentsInChildren<Transform>(true))item.gameObject.layer=31;
                foreach(var canvas in root.GetComponentsInChildren<Canvas>(true))if(canvas.transform.parent==root.transform && canvas.renderMode!=RenderMode.WorldSpace)
                {canvas.renderMode=RenderMode.ScreenSpaceCamera;canvas.worldCamera=uiCamera;canvas.planeDistance=1;}
                Canvas.ForceUpdateCanvases();
                foreach(var style in root.GetComponentsInChildren<NarrativeView>())style.ScrollToEnd();
                Canvas.ForceUpdateCanvases();ProjectY.Rendering.UrpCameraRendering.Render(camera);ProjectY.Rendering.UrpCameraRendering.Render(uiCamera);RenderTexture.active=texture;
                image=new Texture2D(1280,720,TextureFormat.RGB24,false);image.ReadPixels(new Rect(0,0,1280,720),0,0);image.Apply();
                Directory.CreateDirectory("Docs/Previews");File.WriteAllBytes("Docs/Previews/Narrative-"+name+".png",image.EncodeToPNG());
            }
            finally{RenderTexture.active=previous;camera.targetTexture=null;camera.cullingMask=oldMask;uiCamera.targetTexture=null;if(image!=null)UnityEngine.Object.DestroyImmediate(image);UnityEngine.Object.DestroyImmediate(texture);UnityEngine.Object.DestroyImmediate(uiObject);}
        }
    }
}
