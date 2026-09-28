using System;
using System.IO;
using ProjectY.Samples;
using ProjectY.UI;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;
using XLua;

namespace ProjectY.Editor
{
    public static class MainHudValidation
    {
        [MenuItem("Project Y/UI/验证 MainHud 与 UIFollower")]
        public static void Run()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("验证仅限 Edit Mode。");
            var scene=EditorSceneManager.NewPreviewScene();var root=new GameObject("MainHudValidation");SceneManager.MoveGameObjectToScene(root,scene);
            var host=root.AddComponent<UIHost>();host.Initialize();
            var cameraObject=new GameObject("HudWorldCamera");SceneManager.MoveGameObjectToScene(cameraObject,scene);var camera=cameraObject.AddComponent<Camera>();
            camera.enabled=false;camera.transform.position=new Vector3(0,7,-15);camera.transform.LookAt(new Vector3(0,1,1));camera.fieldOfView=55;
            camera.scene=scene;camera.overrideSceneCullingMask=EditorSceneManager.GetSceneCullingMask(scene);camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.16f,.20f,.18f);
            var lightObject=new GameObject("HudSun");SceneManager.MoveGameObjectToScene(lightObject,scene);var light=lightObject.AddComponent<Light>();light.type=LightType.Directional;light.intensity=1.1f;light.transform.rotation=Quaternion.Euler(42,-25,0);
            var rig=AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/PawnLowPoly/PawnRig.prefab").GetComponent<PawnView>();var pawns=new PawnView[4];
            for(var i=0;i<4;i++) {pawns[i]=UnityEngine.Object.Instantiate(rig);SceneManager.MoveGameObjectToScene(pawns[i].gameObject,scene);pawns[i].transform.position=new Vector3(-6+i*4,0,(i%2)*2);}
            try
            {
                using(var lua=new LuaEnv())
                {
                    var services=new FrameworkServices(host);var loader=new LuaFileLoader(LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);lua.Global.Set("HudWorldCamera",camera);
                    for(var i=0;i<4;i++) lua.Global.Set("HudTarget"+(i+1),pawns[i].transform);
                    try
                    {
                        Debug.Log((string)lua.DoString(File.ReadAllText("Tools/Tests/main_hud_integration.lua"),"@Tools/Tests/main_hud_integration.lua")[0]);
                        using(var actors=(LuaTable)lua.DoString("return HudPreviewActors()")[0])
                            for(var i=0;i<4;i++) using(var row=actors.Get<int,LuaTable>(i+1)) using(var appearance=row.Get<LuaTable>("appearance"))
                                pawns[i].ApplyAppearance(PawnAppearanceData.Read(appearance),part=>AssetDatabase.LoadAssetAtPath<GameObject>(part.Path));
                        foreach(var mode in new[]{"map","area"})
                        {
                            lua.DoString("PreviewMainHud('"+mode+"')");foreach(var pawn in pawns) pawn.gameObject.SetActive(mode=="area");
                            Capture(root,camera,mode);
                        }
                        CheckProjection(root,camera,pawns[0].HealthTarget);
                        lua.DoString("PreviewMainHud('battle')");foreach(var pawn in pawns)pawn.gameObject.SetActive(false);
                        Canvas.ForceUpdateCanvases();
                        var battle=root.GetComponentInChildren<BattleHUDView>();
                        if(battle==null || battle.transform.localScale!=Vector3.one || ((RectTransform)battle.transform).rect.width<300)
                            throw new InvalidOperationException("Embedded battle HUD is invisible or collapsed.");
                        Capture(root,camera,"battle");
                        Debug.Log("MainHud: battle content visible; head projection remains exact with arbitrary anchors and overlapping followers; perspective/orthographic zoom fade passed.");
                    }
                    finally {lua.DoString("if CloseHudPreview then CloseHudPreview() end");lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();}
                }
            }
            finally {host.Shutdown();EditorSceneManager.ClosePreviewScene(scene);}
        }
        private static void Capture(GameObject root,Camera camera,string mode)
        {
            var rt=new RenderTexture(1280,720,24);var previous=RenderTexture.active;Texture2D image=null;
            try
            {
                camera.targetTexture=rt;
                foreach(var canvas in root.GetComponentsInChildren<Canvas>(true)) if(canvas.transform.parent==root.transform&&canvas.renderMode!=RenderMode.WorldSpace)
                {canvas.renderMode=RenderMode.ScreenSpaceCamera;canvas.worldCamera=camera;canvas.planeDistance=1;}
                Canvas.ForceUpdateCanvases();foreach(var view in root.GetComponentsInChildren<MainHudView>()) {view.ApplyLayout();view.UpdateFollowers();}
                foreach(var view in root.GetComponentsInChildren<BattleHUDView>())view.ApplyLayout();
                Canvas.ForceUpdateCanvases();camera.Render();RenderTexture.active=rt;image=new Texture2D(1280,720,TextureFormat.RGB24,false);
                image.ReadPixels(new Rect(0,0,1280,720),0,0);image.Apply();Directory.CreateDirectory("Docs/Previews");File.WriteAllBytes("Docs/Previews/MainHud-"+mode+".png",image.EncodeToPNG());
            }
            finally
            {
                RenderTexture.active=previous;camera.targetTexture=null;
                foreach(var canvas in root.GetComponentsInChildren<Canvas>(true))
                    if(canvas.transform.parent==root.transform&&canvas.renderMode==RenderMode.ScreenSpaceCamera)
                    {canvas.renderMode=RenderMode.ScreenSpaceOverlay;canvas.worldCamera=null;}
                Canvas.ForceUpdateCanvases();
                if(image!=null) UnityEngine.Object.DestroyImmediate(image);UnityEngine.Object.DestroyImmediate(rt);
            }
        }
        private static void CheckProjection(GameObject root,Camera camera,Transform target)
        {
            // 探索页面不再创建头顶血条；独立实例只检查跟随组件，不改变游戏阶段。
            if(root.GetComponentsInChildren<UIFollower>().Length!=0) throw new InvalidOperationException("Exploration must not show overhead health.");
            var overlay=Array.Find(root.GetComponentsInChildren<Canvas>(true),item=>item.transform.parent==root.transform&&item.renderMode==RenderMode.ScreenSpaceOverlay);
            if(overlay==null) throw new InvalidOperationException("Overlay canvas missing.");
            var prefab=AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/UI/Prefabs/MainHud/HudHealthWidget.prefab");
            var container=(RectTransform)new GameObject("FollowerContainer",typeof(RectTransform)).transform;container.SetParent(overlay.transform,false);
            container.anchorMin=Vector2.zero;container.anchorMax=Vector2.one;container.pivot=new Vector2(.2f,.7f);container.offsetMin=container.offsetMax=Vector2.zero;
            var fixture=UnityEngine.Object.Instantiate(prefab,container,false);
            var second=UnityEngine.Object.Instantiate(prefab,container,false);
            var hud=root.GetComponentInChildren<MainHudView>();
            try
            {
                var rect=(RectTransform)fixture.transform;rect.anchorMin=rect.anchorMax=new Vector2(1,0);
                CheckFollower(fixture,camera,target,overlay);
                camera.orthographic=true;camera.orthographicSize=8;
                var firstFollower=fixture.GetComponent<UIFollower>();var secondFollower=second.GetComponent<UIFollower>();
                hud.Track(firstFollower,camera,target);hud.Track(secondFollower,camera,target);hud.UpdateFollowers();
                if(Vector3.Distance(fixture.transform.position,second.transform.position)>.001f)
                    throw new InvalidOperationException("Overlap avoidance moved a health bar away from its head anchor.");
                hud.Untrack(firstFollower);hud.Untrack(secondFollower);
            }
            finally {UnityEngine.Object.DestroyImmediate(container.gameObject);}
        }
        private static void CheckFollower(GameObject fixture,Camera camera,Transform target,Canvas overlay)
        {
            var follower=fixture.GetComponent<UIFollower>();follower.Bind(camera,target,overlay);
            var settings=new SerializedObject(follower);var offset=settings.FindProperty("worldOffset").vector3Value;var screenOffset=settings.FindProperty("screenOffset").vector2Value;
            var group=fixture.GetComponent<CanvasGroup>();
            var originalPosition=camera.transform.position;var originalRotation=camera.transform.rotation;var originalFov=camera.fieldOfView;
            foreach(var orthographic in new[]{false,true})
            {
                camera.orthographic=orthographic;camera.orthographicSize=8;camera.transform.position=originalPosition;camera.transform.rotation=originalRotation;
                if(!follower.Project()||follower.Bounds.width<96||follower.Bounds.width>128.1f) throw new InvalidOperationException("Health follower size is outside the compact range.");
                var expected=camera.WorldToScreenPoint(target.position+offset)+fixture.transform.parent.TransformVector(new Vector3(screenOffset.x,screenOffset.y,0));
                var actual=RectTransformUtility.WorldToScreenPoint(null,fixture.transform.position);
                if(Vector2.Distance((Vector2)expected,actual)>1)throw new InvalidOperationException("Health bar does not project to its actual head anchor.");
                var before=follower.Bounds.center;camera.transform.RotateAround(Vector3.zero,Vector3.up,25);follower.Project();
                if((before-follower.Bounds.center).sqrMagnitude<1) throw new InvalidOperationException("Follower did not respond to camera orbit.");
                expected=camera.WorldToScreenPoint(target.position+offset)+fixture.transform.parent.TransformVector(new Vector3(screenOffset.x,screenOffset.y,0));
                actual=RectTransformUtility.WorldToScreenPoint(null,fixture.transform.position);
                if(Vector2.Distance((Vector2)expected,actual)>1)throw new InvalidOperationException("Camera orbit detached the health bar from the head.");
            }
            camera.orthographic=false;camera.transform.position=target.position+offset;camera.transform.rotation=originalRotation;
            if(follower.Project()) throw new InvalidOperationException("Near-plane follower should be hidden.");
            camera.transform.position=originalPosition;camera.transform.rotation=originalRotation*Quaternion.Euler(0,180,0);
            if(follower.Project()) throw new InvalidOperationException("Behind-camera follower should be hidden.");
            camera.transform.rotation=originalRotation;camera.rect=new Rect(.25f,0,.75f,1);
            if(!follower.Project()) throw new InvalidOperationException("Split viewport failed.");
            camera.rect=new Rect(0,0,1,1);camera.transform.position=originalPosition;camera.transform.rotation=originalRotation;
            foreach(var orthographic in new[]{false,true})
            {
                camera.orthographic=orthographic;camera.fieldOfView=60;camera.transform.rotation=originalRotation;
                var range=settings.FindProperty(orthographic?"orthographicFade":"perspectiveFade").vector2Value;
                var values=new[]{range.x,(range.x+range.y)*.5f,range.y,range.x*.5f};
                var alphas=new[]{1f,.5f,0f,1f};
                for(var i=0;i<values.Length;i++)
                {
                    if(orthographic) {camera.transform.position=originalPosition;camera.orthographicSize=values[i];}
                    else camera.transform.position=target.position+offset-camera.transform.forward*values[i];
                    var shown=follower.Project();
                    if(Mathf.Abs(group.alpha-alphas[i])>.015f||shown!=(alphas[i]>0))
                        throw new InvalidOperationException("Unexpected zoom fade alpha: "+group.alpha+" at "+values[i]+" (orthographic="+orthographic+").");
                }
            }
            follower.BindScreen(overlay,new Vector2(Screen.width*.5f,Screen.height*.5f));
            if(!follower.Project()||group.alpha!=1) throw new InvalidOperationException("2D board screen points must remain visible.");
            camera.fieldOfView=originalFov;camera.transform.position=originalPosition;camera.transform.rotation=originalRotation;
        }
    }
}
