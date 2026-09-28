using System;
using System.IO;
using ProjectY.UI;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;
using XLua;

namespace ProjectY.Editor
{
    public static class StoryGrowthValidation
    {
        [MenuItem("Project Y/UI/验证事件与养成 UI")]
        public static void Run()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("验证仅限 Edit Mode。");
            var scene=EditorSceneManager.NewPreviewScene();
            var root=new GameObject("StoryGrowthValidation");SceneManager.MoveGameObjectToScene(root,scene);
            var host=root.AddComponent<UIHost>();host.Initialize();
            try
            {
                using(var lua=new LuaEnv())
                {
                    var services=new FrameworkServices(host);var loader=new LuaFileLoader(LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);
                    lua.Global.Set("Services",services);
                    try
                    {
                        var path=Path.Combine(Directory.GetParent(Application.dataPath).FullName,"Tools/Tests/growth_ui_integration.lua");
                        Debug.Log((string)lua.DoString(File.ReadAllText(path),"@"+path)[0]);
                        foreach(var page in new[]{"overview","skills","history","event"})
                        {
                            lua.DoString("PreviewGrowthPage('"+page+"')");
                            Capture(root,scene,page);
                        }
                    }
                    finally
                    {
                        lua.DoString("if CloseGrowthPreview then CloseGrowthPreview() end");
                        lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();
                    }
                }
            }
            finally {host.Shutdown();EditorSceneManager.ClosePreviewScene(scene);}
        }
        private static void Capture(GameObject root,Scene scene,string name)
        {
            var cameraObject=new GameObject("PreviewCamera");SceneManager.MoveGameObjectToScene(cameraObject,scene);
            var camera=cameraObject.AddComponent<Camera>();camera.transform.position=new Vector3(0,0,-10);
            camera.scene=scene;camera.overrideSceneCullingMask=EditorSceneManager.GetSceneCullingMask(scene);
            camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.035f,.055f,.045f);
            camera.orthographic=true;camera.orthographicSize=360;camera.nearClipPlane=.1f;camera.farClipPlane=100;camera.cullingMask=1<<31;
            var texture=new RenderTexture(1280,720,24);var previous=RenderTexture.active;Texture2D image=null;
            try
            {
                foreach(var transform in root.GetComponentsInChildren<Transform>(true)) transform.gameObject.layer=31;
                camera.targetTexture=texture;
                foreach(var canvas in root.GetComponentsInChildren<Canvas>(true))
                {
                    if(canvas.transform.parent==root.transform && canvas.renderMode!=RenderMode.WorldSpace)
                    {canvas.renderMode=RenderMode.ScreenSpaceCamera;canvas.worldCamera=camera;canvas.planeDistance=1;}
                }
                Canvas.ForceUpdateCanvases();
                foreach(var style in root.GetComponentsInChildren<StoryGrowthView>()) style.Prepare();
                Canvas.ForceUpdateCanvases();camera.Render();RenderTexture.active=texture;
                image=new Texture2D(1280,720,TextureFormat.RGB24,false);image.ReadPixels(new Rect(0,0,1280,720),0,0);image.Apply();
                Directory.CreateDirectory("Docs/Previews");File.WriteAllBytes("Docs/Previews/StoryGrowth-"+name+".png",image.EncodeToPNG());
            }
            finally
            {
                RenderTexture.active=previous;camera.targetTexture=null;
                if(image!=null) UnityEngine.Object.DestroyImmediate(image);
                UnityEngine.Object.DestroyImmediate(texture);UnityEngine.Object.DestroyImmediate(cameraObject);
            }
        }
    }
}
