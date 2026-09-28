using System;
using System.IO;
using ProjectY.Data;
using ProjectY.Samples;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;
using XLua;

namespace ProjectY.Editor
{
    public static class PawnAnimationValidation
    {
        [MenuItem("Project Y/角色/验证 Humanoid 动画接入")]
        public static void Run()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("Edit Mode required.");
            var scene=EditorSceneManager.NewPreviewScene();
            var services=new FrameworkServices(null);
            try
            {
                using(var lua=new LuaEnv())
                {
                    var loader=new LuaFileLoader(LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
                    try
                    {
                        var result=lua.DoString(File.ReadAllText("Tools/Tests/pawn_animation_preview.lua"));
                        var actor=(CombatActorData)result[0];AdventureViewData.Actor state;
                        using(var row=(LuaTable)result[1])state=AdventureViewData.ReadActor(row);
                        var asset=AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/PawnLowPoly/PawnRig.prefab");
                        var pawn=UnityEngine.Object.Instantiate(asset).GetComponent<PawnView>();SceneManager.MoveGameObjectToScene(pawn.gameObject,scene);
                        pawn.ApplyAppearance(state.Appearance,part=>AssetDatabase.LoadAssetAtPath<GameObject>(part.Path));
                        var animator=pawn.GetComponentInChildren<Animator>();
                        if(animator==null || !animator.avatar.isHuman || animator.applyRootMotion)throw new InvalidOperationException("Invalid humanoid binding.");
                        pawn.Capture(state,Vector3.forward*3,0);
                        var lightObject=new GameObject("AnimationSun");SceneManager.MoveGameObjectToScene(lightObject,scene);
                        var light=lightObject.AddComponent<Light>();light.type=LightType.Directional;light.intensity=1.2f;light.transform.rotation=Quaternion.Euler(35,-30,0);
                        var cameraObject=new GameObject("AnimationCamera");SceneManager.MoveGameObjectToScene(cameraObject,scene);
                        var camera=cameraObject.AddComponent<Camera>();camera.enabled=false;camera.scene=scene;
                        camera.overrideSceneCullingMask=EditorSceneManager.GetSceneCullingMask(scene);
                        camera.orthographic=true;camera.orthographicSize=1.25f;camera.nearClipPlane=.1f;camera.farClipPlane=30;
                        camera.transform.position=new Vector3(2.6f,2.0f,5);camera.transform.LookAt(Vector3.up*.95f);
                        camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.16f,.20f,.19f);
                        Action<string> capture=name=>Capture(camera,name);
                        for(int i=0;i<15;i++)pawn.TickPresentation(1f/30);
                        capture("idle");
                        // Optional customization renderers exist on the shared rig but are disabled for legacy appearances.
                        if(Array.FindAll(pawn.GetComponentsInChildren<SkinnedMeshRenderer>(), skin => skin.enabled && skin.sharedMesh != null).Length!=3)
                            throw new InvalidOperationException("Body, trousers and boots must all be skinned.");
                        foreach(int weaponIndex in new[]{0,1,4,6})
                        {
                            using(var row=(LuaTable)lua.DoString("return PawnAnimationEquip("+weaponIndex+")")[0])state=AdventureViewData.ReadActor(row);
                            pawn.ApplyAppearance(state.Appearance,part=>AssetDatabase.LoadAssetAtPath<GameObject>(part.Path));
                            for(int i=0;i<10;i++)pawn.TickPresentation(1f/30);
                            if(state.Appearance.Equipment.Hold.OffHandFollowsWeapon)
                            {
                                var animation=pawn.GetComponentInChildren<PawnAnimationView>();var hold=state.Appearance.Equipment.Hold;
                                var weapon=Array.Find(pawn.GetComponentsInChildren<WeaponModelView>(),w=>w.transform.IsChildOf(animation.MainGrip));
                                if(Vector3.Distance(animation.OffGrip.position,weapon.transform.TransformPoint(state.Appearance.Equipment.WeaponView.SecondaryGrip.Position))>.035f)
                                    throw new InvalidOperationException("Off-hand missed weapon grip: "+hold.Id);
                            }
                            capture("weapon-"+weaponIndex);
                        }
                        using(var row=(LuaTable)lua.DoString("return PawnAnimationEquip(2)")[0])state=AdventureViewData.ReadActor(row);
                        pawn.ApplyAppearance(state.Appearance,part=>AssetDatabase.LoadAssetAtPath<GameObject>(part.Path));
                        var foot=animator.GetBoneTransform(HumanBodyBones.RightFoot);var before=foot.position;
                        for(int i=0;i<12;i++)pawn.TickPresentation(1f/30,2);
                        if(Vector3.Distance(before,foot.position)<.02f)throw new InvalidOperationException("Walk did not move the feet.");
                        capture("walk");
                        var root=pawn.transform.position;
                        actor.RecordAction(4,1,0,3);actor.RecordAction(0,1,0,3);
                        using(var row=(LuaTable)lua.DoString("return PawnAnimationSnapshot()")[0])state=AdventureViewData.ReadActor(row);
                        if(state.Actions.Length!=2)throw new InvalidOperationException("AI action history lost the attack.");
                        pawn.Capture(state,Vector3.forward*3,0);
                        pawn.TickPresentation(.17f);capture("attack");
                        var hand=animator.GetBoneTransform(HumanBodyBones.RightHand);var paused=hand.position;
                        pawn.TickPresentation(0);if(Vector3.Distance(paused,hand.position)>.00001f)throw new InvalidOperationException("Paused animation moved.");
                        for(int i=0;i<60;i++)pawn.TickPresentation(1f/30);
                        if(pawn.PresentationBusy)throw new InvalidOperationException("Animation queue failed to release.");
                        pawn.Capture(state,Vector3.forward*3,0);
                        if(pawn.PresentationBusy)throw new InvalidOperationException("Duplicate snapshot replayed an action.");
                        actor.Damage(3);
                        using(var row=(LuaTable)lua.DoString("return PawnAnimationSnapshot()")[0])state=AdventureViewData.ReadActor(row);
                        pawn.Capture(state,Vector3.forward*3,0);pawn.TickPresentation(.12f);capture("hit");
                        actor.Damage(100);
                        using(var row=(LuaTable)lua.DoString("return PawnAnimationSnapshot()")[0])state=AdventureViewData.ReadActor(row);
                        pawn.Capture(state,Vector3.forward*3,0);
                        for(int i=0;i<70;i++)pawn.TickPresentation(1f/30);
                        capture("death");
                        for(int i=0;i<35;i++)pawn.TickPresentation(1f/30);
                        if(!pawn.DeathFinished)throw new InvalidOperationException("Death lifetime did not finish.");
                        if(pawn.transform.position!=root)throw new InvalidOperationException("Animation changed authoritative root position.");
                        CheckRoute(scene);
                        File.WriteAllText("Art/PawnAnimation/Integration/unity-validation.json",JsonUtility.ToJson(new Report {validAvatar=true,rootMotion=false,duplicateSuppressed=true,pauseVerified=true,deathVerified=true,navigationVerified=true},true));
                        Debug.Log("Pawn animation: valid Humanoid, walk, attack + guard history, duplicate suppression, pause, hit, death and wall-safe display route passed.");
                    }
                    finally {lua.DoString("if ClosePawnAnimationFixture then ClosePawnAnimationFixture() end");lua.Global.Set<string,object>("Services",null);}
                }
            }
            finally {services.Player.ClearListeners();EditorSceneManager.ClosePreviewScene(scene);}
        }
        [Serializable] private sealed class Report {public bool validAvatar,rootMotion,duplicateSuppressed,pauseVerified,deathVerified,navigationVerified;}
        private static void CheckRoute(Scene scene)
        {
            var layout=new MapAreaViewData {Cells=new[] {
                new MapAreaViewData.Cell {Position=Vector3.zero,Neighbors=new[]{1},WalkMask=1},
                new MapAreaViewData.Cell {Position=Vector3.right,Neighbors=new[]{0,2},WalkMask=3},
                new MapAreaViewData.Cell {Position=new Vector3(1,0,1),Neighbors=new[]{1,3},WalkMask=3},
                new MapAreaViewData.Cell {Position=Vector3.forward,Neighbors=new[]{2},WalkMask=1}
            }};
            var obj=new GameObject("RouteProbe");SceneManager.MoveGameObjectToScene(obj,scene);
            var motion=new PawnMotion(obj.transform,0,layout) {Speed=1};motion.SetDestination(3,new System.Collections.Generic.HashSet<int>());
            motion.Tick(.5f);if(Mathf.Abs(obj.transform.position.x-.5f)>.01f||Mathf.Abs(obj.transform.position.z)>.01f)throw new InvalidOperationException("Display cut across a wall.");
            motion.Skip();if(Vector3.Distance(obj.transform.position,Vector3.forward+Vector3.up*.015f)>.001f)throw new InvalidOperationException("Skip changed destination.");
        }
        private static void Capture(Camera camera,string name)
        {
            var texture=new RenderTexture(960,960,24);var previous=RenderTexture.active;Texture2D image=null;
            var skins=new System.Collections.Generic.List<SkinnedMeshRenderer>();
            var copies=new System.Collections.Generic.List<GameObject>();var meshes=new System.Collections.Generic.List<Mesh>();
            try
            {
                // Multiple poses are captured in one Editor frame. GPU skinning otherwise reuses the first pose.
                foreach(var root in camera.scene.GetRootGameObjects()) foreach(var skin in root.GetComponentsInChildren<SkinnedMeshRenderer>())
                {
                    if(!skin.enabled)continue;
                    var mesh=new Mesh();skin.BakeMesh(mesh);meshes.Add(mesh);
                    var copy=new GameObject("BakedPreview");copy.transform.SetParent(skin.transform,false);copies.Add(copy);
                    copy.AddComponent<MeshFilter>().sharedMesh=mesh;copy.AddComponent<MeshRenderer>().sharedMaterials=skin.sharedMaterials;
                    skins.Add(skin);skin.enabled=false;
                }
                camera.targetTexture=texture;camera.Render();RenderTexture.active=texture;image=new Texture2D(960,960,TextureFormat.RGB24,false);
                image.ReadPixels(new Rect(0,0,960,960),0,0);image.Apply();Directory.CreateDirectory("Art/PawnAnimation/Previews");
                File.WriteAllBytes("Art/PawnAnimation/Previews/"+name+".png",image.EncodeToPNG());
            }
            finally
            {
                foreach(var skin in skins)skin.enabled=true;
                foreach(var copy in copies)UnityEngine.Object.DestroyImmediate(copy);
                foreach(var mesh in meshes)UnityEngine.Object.DestroyImmediate(mesh);
                camera.targetTexture=null;RenderTexture.active=previous;if(image!=null)UnityEngine.Object.DestroyImmediate(image);UnityEngine.Object.DestroyImmediate(texture);
            }
        }
    }
}
