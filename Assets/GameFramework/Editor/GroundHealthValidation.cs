using System;
using System.IO;
using System.Reflection;
using ProjectY.UI;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;
using XLua;
using Object=UnityEngine.Object;

namespace ProjectY.Editor
{
    public static class GroundHealthValidation
    {
        private static void Check(bool value,string message){if(!value)throw new InvalidOperationException(message);}
        [MenuItem("Project Y/UI/验证脚下 HP AP 圆环")]
        public static void Run()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode)throw new InvalidOperationException("Ground HUD checks require Edit Mode.");
            var scene=EditorSceneManager.NewPreviewScene();var owner=new GameObject("GroundHealthValidation");SceneManager.MoveGameObjectToScene(owner,scene);
            var host=owner.AddComponent<UIHost>();host.Initialize();
            try
            {
                var cameraObject=new GameObject("Camera");cameraObject.transform.SetParent(owner.transform,false);
                var camera=cameraObject.AddComponent<Camera>();camera.enabled=false;camera.orthographic=true;camera.orthographicSize=5;
                camera.transform.position=new Vector3(0,7,-8);camera.transform.LookAt(Vector3.zero);
                camera.scene=scene;camera.overrideSceneCullingMask=EditorSceneManager.GetSceneCullingMask(scene);
                camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.14f,.17f,.19f);
                var lightObject=new GameObject("Light");lightObject.transform.SetParent(owner.transform,false);lightObject.AddComponent<Light>().type=LightType.Directional;
                var canvasObject=new GameObject("Canvas",typeof(RectTransform),typeof(Canvas));canvasObject.transform.SetParent(owner.transform,false);
                // Match MainHud's actual Overlay canvas. An Edit Mode camera canvas does not track camera orbit until rendered.
                var canvas=canvasObject.GetComponent<Canvas>();canvas.renderMode=RenderMode.ScreenSpaceOverlay;
                var style=owner.AddComponent<MainHudView>();style.SetEditorBindings(new MainHudView.Layout{Canvas=canvas});
                var feedback=owner.AddComponent<BattleFeedbackSystem>();
                var foot=new GameObject("Feet");foot.transform.SetParent(owner.transform,false);
                var head=new GameObject("Head");head.transform.SetParent(foot.transform,false);head.transform.localPosition=Vector3.up*1.8f;
                var prefab=AssetDatabase.LoadAssetAtPath<PanelConfig>(PanelConfig.AssetPath).Get("HudHealth").Prefab;
                var reference=host.CreateWidget("HudHealth",canvas.transform);var root=reference.gameObject;root.SetActive(true);reference.ValidateBindings();
                Check(root.GetComponent<Canvas>().rootCanvas.renderMode==RenderMode.WorldSpace,"World widget must be owned by WorldUIRoot");
                Check(!root.GetComponent<Image>().enabled && !reference.GetText("Name").gameObject.activeSelf,"Old panel/name must be hidden");
                var hp=reference.GetImage("Health");var ap=reference.GetImage("AP");
                Check(hp.GetComponent<HealthRingMesh>()!=null && ap.GetComponent<HealthRingMesh>()!=null,"Both saved Images must be annular");
                Check(reference.GetText("HealthText").GetComponent<ArcText>()!=null && reference.GetText("HealthText").GetComponent<Outline>().effectColor==Color.black,"Curved text needs black outline");
                using(var lua=new LuaEnv())
                {
                    var loader=new LuaFileLoader(LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);
                    lua.Global.Set("RingReference",reference);lua.Global.Set("RingCamera",camera);lua.Global.Set("RingStyle",style);lua.Global.Set("RingFeedback",feedback);
                    lua.Global.Set("RingFoot",foot.transform);lua.Global.Set("RingHead",head.transform);
                    Debug.Log(lua.DoString(File.ReadAllText("Tools/Tests/hud_health_rings.lua"),"@Tools/Tests/hud_health_rings.lua")[0]);
                }
                root.SetActive(true);
                var follower=(UIFollower)reference.Get("Follower");var damage=(UIFollower)reference.Get("DamageFollower");
                follower.Bind(camera,foot.transform,canvas);damage.Bind(camera,head.transform,canvas);Canvas.ForceUpdateCanvases();
                CheckStatusArc(reference,camera,follower,style.Font);
                foreach(bool orthographic in new[]{true,false})
                {
                    camera.orthographic=orthographic;
                    Check(follower.Project() && damage.Project(),"Foot and head must both project");
                    Check(Vector3.Distance(root.transform.position,foot.transform.position+Vector3.up*.035f)<.001f,"Foot ring drifted from feet");
                    Check(Vector3.Dot(root.transform.forward,Vector3.down)>.999f,"Ring surface must lie on the ground");
                    var width=((RectTransform)root.transform).rect.width*root.transform.lossyScale.x;
                    camera.transform.RotateAround(foot.transform.position,Vector3.up,40);follower.Project();damage.Project();
                    Check(Mathf.Abs(((RectTransform)root.transform).rect.width*root.transform.lossyScale.x-width)<.001f,"World ring size changed while orbiting");
                    Check(damage.transform.position!=follower.transform.position,"Damage text should follow its separate head anchor");
                }
                camera.orthographic=true;camera.orthographicSize=20;Check(!follower.Project(),"Distant ground HUD must fade out");
                camera.orthographicSize=5;Check(follower.Project(),"Zooming in restores rings");
                follower.RetainLastWorldPosition();damage.RetainLastWorldPosition();Object.DestroyImmediate(foot);
                Check(follower.Project() && damage.Project(),"Retiring head/feet must retain their last world positions");
                follower.Clear();damage.Clear();
                var bar=(HealthBarAnimation)reference.Get("HealthAnimation");bar.SetValue(1,1,0);bar.SetValue(1,.5f,0);
                typeof(HealthBarAnimation).GetMethod("Advance",BindingFlags.Instance|BindingFlags.NonPublic).Invoke(bar,new object[]{.23f});
                Check(Mathf.Abs(bar.ForegroundFraction-.5f)<.001f && bar.TrailFraction>.5f,"Radial damage must preserve delayed trail");bar.Complete();
                using(var mesh=new VertexHelper())
                {
                    hp.fillAmount=0;hp.GetComponent<HealthRingMesh>().ModifyMesh(mesh);Check(mesh.currentVertCount==0,"Zero HP must draw no foreground arc");
                    hp.fillAmount=.5f;hp.GetComponent<HealthRingMesh>().ModifyMesh(mesh);int half=mesh.currentVertCount;
                    hp.fillAmount=1;hp.GetComponent<HealthRingMesh>().ModifyMesh(mesh);Check(mesh.currentVertCount>half,"Full HP must span the complete ring");
                }
                var worldParent=root.transform.parent;host.DestroyWidget(reference);
                Capture(prefab,worldParent,canvas,camera,style.Font);
                Debug.Log("GroundHealth PASS: saved WorldUIRoot ownership, Lua lifecycle/2D fallback, perspective/orthographic world placement, orbit, zoom fade, retained death anchors, damage trail and rendered depth occlusion. Preview: Docs/Previews/GroundHealth-WorldSpace.png");
            }
            finally{host.Shutdown();EditorSceneManager.ClosePreviewScene(scene);}
        }
        private static void CheckStatusArc(LuaReference reference,Camera camera,UIFollower follower,Font font)
        {
            var slots=(RectTransform)reference.Get("EffectSlots");
            Check(slots.GetComponent<GridLayoutGroup>()==null && slots.GetComponent<ArcLayoutGroup>()!=null,"Saved status layout must follow an arc instead of a grid");
            var icons=CreateEffects(slots,7,font);
            var originalCameraPosition=camera.transform.position;var originalCameraRotation=camera.transform.rotation;
            follower.Project();
            var ringPosition=follower.transform.position;
            foreach(bool orthographic in new[]{true,false})
            {
                camera.orthographic=orthographic;
                foreach(int count in new[]{1,3,6,7})
                {
                    for(int i=0;i<icons.Length;i++)icons[i].gameObject.SetActive(i<count);
                    follower.Project();LayoutRebuilder.ForceRebuildLayoutImmediate(slots);
                    Check(Vector3.Distance(ringPosition,follower.transform.position)<.001f,"Status count must not move the foot ring");
                    for(int i=0;i<count;i++)
                    {
                        Check(Vector3.Dot(icons[i].forward,camera.transform.forward)>.999f,"Each status icon must face the camera");
                        Check(icons[i].localPosition.y<-64,"Status icons must remain outside the front HP ring");
                        Check(icons[i].position.y>ringPosition.y,"Status billboards must remain above ground");
                    }
                    if(count==1)
                    {
                        var corners=new Vector3[4];icons[0].GetWorldCorners(corners);
                        var top=camera.WorldToScreenPoint(corners[1]).y;
                        var hpBaseline=camera.WorldToScreenPoint(reference.transform.TransformPoint(new Vector3(0,-64*1.08f,-11))).y;
                        Check(top<hpBaseline,"The status icon must clear the HP label below the outer ring");
                    }
                    if(count>=3)Check(icons[1].localPosition.y<icons[0].localPosition.y,"Icons must curve around the front instead of forming a straight row");
                    if(count==7)Check(icons[6].localPosition.y<icons[2].localPosition.y-25,"Overflow icons must use a separate outer arc");
                    camera.transform.RotateAround(ringPosition,Vector3.up,25);
                }
            }
            camera.transform.SetPositionAndRotation(originalCameraPosition,originalCameraRotation);camera.orthographic=true;
            foreach(var icon in icons)Object.DestroyImmediate(icon.gameObject);
            follower.Project();
        }
        private static RectTransform[] CreateEffects(RectTransform parent,int count,Font font)
        {
            var prefab=AssetDatabase.LoadAssetAtPath<PanelConfig>(PanelConfig.AssetPath).Get("HudStatusEffect").Prefab;
            var icons=new RectTransform[count];var names=new[]{"毒","燃","血","湿","晕","愈","追"};
            for(int i=0;i<count;i++)
            {
                var root=Object.Instantiate(prefab,parent,false);root.SetActive(true);icons[i]=(RectTransform)root.transform;
                var reference=root.GetComponent<LuaReference>();
                reference.GetImage("Icon").gameObject.SetActive(false);
                var glyph=reference.GetText("Glyph");glyph.font=font;glyph.text=names[i%names.Length];glyph.gameObject.SetActive(true);glyph.color=i%2==0?new Color(.45f,1,.45f):new Color(1,.55f,.25f);
                var timer=reference.GetText("Count");timer.font=font;timer.text=(i+2).ToString();
            }
            return icons;
        }
        private static void Capture(GameObject prefab,Transform worldParent,Canvas canvas,Camera camera,Font font)
        {
            var target=new RenderTexture(1100,620,24);var previous=RenderTexture.active;Texture2D clear=null,image=null;
            var groundMaterial=new Material(Shader.Find("Universal Render Pipeline/Unlit"));groundMaterial.color=new Color(.22f,.29f,.24f);
            var bodyMaterial=new Material(groundMaterial);bodyMaterial.color=new Color(.65f,.56f,.35f);
            var blockers=new GameObject[3];
            try
            {
                camera.orthographic=true;camera.orthographicSize=3.3f;camera.transform.position=new Vector3(0,5,-7);camera.transform.LookAt(new Vector3(0,.3f,0));
                camera.targetTexture=target;
                var ground=GameObject.CreatePrimitive(PrimitiveType.Cube);ground.transform.SetParent(worldParent,false);
                ground.transform.position=new Vector3(0,-.12f,0);ground.transform.localScale=new Vector3(12,.2f,6);ground.GetComponent<Renderer>().sharedMaterial=groundMaterial;
                Canvas.ForceUpdateCanvases();
                for(int i=0;i<3;i++)
                {
                    var anchor=new GameObject("Foot"+i);anchor.transform.SetParent(worldParent,false);anchor.transform.position=new Vector3((i-1)*2.7f,0,0);
                    var root=Object.Instantiate(prefab,worldParent);var follower=root.GetComponent<UIFollower>();
                    follower.SetGroundRadius(1.1f);follower.Bind(camera,anchor.transform,canvas);follower.Project();
                    var reference=root.GetComponent<LuaReference>();reference.GetImage("Health").fillAmount=reference.GetImage("HealthTrail").fillAmount=1-i*.5f;reference.GetImage("AP").fillAmount=1-i*.5f;
                    reference.GetText("HealthText").font=font;reference.GetText("HealthText").text=(20-i*10)+"/20";
                    reference.GetText("APText").font=font;reference.GetText("APText").text=(4-i*2)+"/4 AP";
                    var slots=(RectTransform)reference.Get("EffectSlots");CreateEffects(slots,i*3+1,font);LayoutRebuilder.ForceRebuildLayoutImmediate(slots);
                    blockers[i]=GameObject.CreatePrimitive(PrimitiveType.Cube);blockers[i].transform.SetParent(worldParent,false);
                    blockers[i].transform.position=anchor.transform.position+Vector3.up*.8f;blockers[i].transform.localScale=new Vector3(.85f,1.6f,.7f);
                    blockers[i].GetComponent<Renderer>().sharedMaterial=bodyMaterial;blockers[i].SetActive(false);
                }
                clear=ReadFrame(camera,target);
                foreach(var blocker in blockers)blocker.SetActive(true);
                image=ReadFrame(camera,target);
                int visible=RingPixels(clear),occluded=RingPixels(image);
                Check(visible>100 && occluded>100 && occluded<visible*.97f,"World geometry must occlude part of the rings: "+visible+" -> "+occluded);
                Directory.CreateDirectory("Docs/Previews");File.WriteAllBytes("Docs/Previews/GroundHealth-WorldSpace.png",image.EncodeToPNG());
                Debug.Log("World ring depth test: coloured ring pixels "+visible+" -> "+occluded+" with opaque blockers.");
            }
            finally{RenderTexture.active=previous;camera.targetTexture=null;if(clear!=null)Object.DestroyImmediate(clear);if(image!=null)Object.DestroyImmediate(image);Object.DestroyImmediate(target);Object.DestroyImmediate(groundMaterial);Object.DestroyImmediate(bodyMaterial);}
        }
        private static Texture2D ReadFrame(Camera camera,RenderTexture target)
        {
            Canvas.ForceUpdateCanvases();ProjectY.Rendering.UrpCameraRendering.Render(camera);RenderTexture.active=target;
            var image=new Texture2D(target.width,target.height,TextureFormat.RGB24,false);image.ReadPixels(new Rect(0,0,target.width,target.height),0,0);image.Apply();return image;
        }
        private static int RingPixels(Texture2D image)
        {
            int count=0;foreach(var color in image.GetPixels32())if((color.r>120 && color.r>color.g*1.6f && color.r>color.b*1.6f) || (color.b>120 && color.b>color.r*1.6f && color.b>color.g*1.2f))count++;
            return count;
        }
    }
}
