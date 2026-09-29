using System;
using System.Collections.Generic;
using System.IO;
using ProjectY.Samples;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;
using XLua;

namespace ProjectY.Editor
{
    public static class PawnAmbientValidation
    {
        [Serializable] private sealed class Report {public string[] idleStates,moveStates;public float[] phases;public bool independentRng,paused;public float battleMoveSpeed;}
        [MenuItem("Project Y/角色/验证待机与步态变化")]
        public static void Run()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode)throw new InvalidOperationException("Edit Mode required.");
            var settings=AssetDatabase.LoadAssetAtPath<PawnAnimationSet>(PawnAnimationAssets.SetPath);
            var idle=new HashSet<string>();var move=new HashSet<string>();var phases=new float[8];
            var globalRandom=UnityEngine.Random.state;
            for(int id=1;id<=8;id++)
            {
                var a=new PawnAmbientMotion(settings,id);var b=new PawnAmbientMotion(settings,id);var hold=settings.GetHold(3);
                a.Update(0,hold,false);b.Update(0,hold,false);idle.Add(a.Current.State);phases[id-1]=a.Phase;
                if(a.Current.State!=b.Current.State||a.Phase!=b.Phase||a.Rate!=b.Rate)throw new InvalidOperationException("Character variation seed is not repeatable.");
                var prior=a.Current.State;var phase=a.Phase;
                if(a.Update(0,hold,false)||a.Current.State!=prior||a.Phase!=phase)throw new InvalidOperationException("Paused ambient animation changed.");
                if(!a.Update(settings.IdleChangeSeconds.y+1,hold,false)||a.Current.State==prior)throw new InvalidOperationException("Idle did not switch to a different clip.");
                a.Update(0,hold,true);move.Add(a.Current.State);
            }
            if(idle.Count<2||move.Count<2||Mathf.Abs(phases[0]-phases[1])<.01f)throw new InvalidOperationException("Characters still share the same ambient clip/phase.");
            if(!globalRandom.Equals(UnityEngine.Random.state))throw new InvalidOperationException("Ambient player consumed Unity random state.");
            var scene=EditorSceneManager.NewPreviewScene();var services=new FrameworkServices(null);
            try
            {
                using(var lua=new LuaEnv())
                {
                    var loader=new LuaFileLoader(LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
                    var result=lua.DoString(File.ReadAllText("Tools/Tests/pawn_animation_preview.lua"));AdventureViewData.Actor state;
                    using(var row=(LuaTable)result[1])state=AdventureViewData.ReadActor(row);
                    try
                    {
                        var pawns=new PawnView[4];var prefab=AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/PawnLowPoly/PawnRig.prefab");
                        for(int i=0;i<pawns.Length;i++)
                        {
                            var pawn=UnityEngine.Object.Instantiate(prefab).GetComponent<PawnView>();SceneManager.MoveGameObjectToScene(pawn.gameObject,scene);
                            pawn.transform.position=new Vector3((i-1.5f)*2,0,0);pawn.ApplyAppearance(state.Appearance,p=>AssetDatabase.LoadAssetAtPath<GameObject>(p.Path));
                            pawn.Capture(new AdventureViewData.Actor {Id=i+1,HP=state.HP,ActionSequence=0,Actions=Array.Empty<ProjectY.Data.CombatActorData.PresentationAction>()},Vector3.forward,0);
                            pawns[i]=pawn;
                        }
                        var light=new GameObject("AmbientPreviewLight").AddComponent<Light>();SceneManager.MoveGameObjectToScene(light.gameObject,scene);
                        light.type=LightType.Directional;light.intensity=1.3f;light.transform.rotation=Quaternion.Euler(40,-30,0);
                        var camera=new GameObject("AmbientPreviewCamera").AddComponent<Camera>();SceneManager.MoveGameObjectToScene(camera.gameObject,scene);
                        camera.enabled=false;camera.scene=scene;camera.overrideSceneCullingMask=EditorSceneManager.GetSceneCullingMask(scene);
                        camera.orthographic=true;camera.orthographicSize=1.8f;camera.nearClipPlane=.1f;camera.farClipPlane=30;
                        camera.transform.position=new Vector3(0,2.4f,7);camera.transform.LookAt(Vector3.up*.95f);camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=new Color(.16f,.20f,.19f);
                        foreach(bool walking in new[]{false,true})
                        {
                            var actual=new HashSet<string>();
                            for(int frame=0;frame<30;frame++)foreach(var pawn in pawns)pawn.TickPresentation(1f/30,walking?3:0);
                            foreach(var pawn in pawns)
                            {
                                actual.Add(pawn.GetComponentInChildren<PawnAnimationView>().AmbientState);
                                if(pawn.PresentationBusy)throw new InvalidOperationException("Ambient loops block gameplay commands.");
                            }
                            if(actual.Count<2)throw new InvalidOperationException("Rendered characters did not use different clips.");
                            Capture(camera,walking?"ambient-move":"ambient-idle");
                        }
                    }
                    finally {lua.DoString("ClosePawnAnimationFixture()");lua.Global.Set<string,object>("Services",null);}
                }
            }
            finally {services.Player.ClearListeners();EditorSceneManager.ClosePreviewScene(scene);}
            File.WriteAllText("Art/PawnAnimation/Integration/ambient-validation.json",JsonUtility.ToJson(new Report {idleStates=new List<string>(idle).ToArray(),moveStates=new List<string>(move).ToArray(),phases=phases,independentRng=true,paused=true,battleMoveSpeed=settings.BattleMoveSpeed},true));
            Debug.Log("Ambient animation: different clips and phases, repeatable per-character RNG, pause, transition and gameplay independence passed.");
        }
        private static void Capture(Camera camera,string name)
        {
            var meshes=new List<Mesh>();var copies=new List<GameObject>();var skins=new List<SkinnedMeshRenderer>();
            var rt=new RenderTexture(1600,600,24);var previous=RenderTexture.active;Texture2D image=null;
            try
            {
                foreach(var root in camera.scene.GetRootGameObjects())foreach(var skin in root.GetComponentsInChildren<SkinnedMeshRenderer>())
                {
                    var mesh=new Mesh();skin.BakeMesh(mesh);meshes.Add(mesh);
                    var copy=new GameObject("AmbientPose");copy.transform.SetParent(skin.transform,false);copies.Add(copy);
                    copy.AddComponent<MeshFilter>().sharedMesh=mesh;copy.AddComponent<MeshRenderer>().sharedMaterials=skin.sharedMaterials;skins.Add(skin);skin.enabled=false;
                }
                camera.aspect=1600f/600;camera.targetTexture=rt;ProjectY.Rendering.UrpCameraRendering.Render(camera);RenderTexture.active=rt;image=new Texture2D(1600,600,TextureFormat.RGB24,false);
                image.ReadPixels(new Rect(0,0,1600,600),0,0);image.Apply();File.WriteAllBytes("Art/PawnAnimation/Previews/"+name+".png",image.EncodeToPNG());
            }
            finally
            {
                foreach(var skin in skins)skin.enabled=true;foreach(var copy in copies)UnityEngine.Object.DestroyImmediate(copy);foreach(var mesh in meshes)UnityEngine.Object.DestroyImmediate(mesh);
                camera.targetTexture=null;RenderTexture.active=previous;if(image!=null)UnityEngine.Object.DestroyImmediate(image);UnityEngine.Object.DestroyImmediate(rt);
            }
        }
    }
}
