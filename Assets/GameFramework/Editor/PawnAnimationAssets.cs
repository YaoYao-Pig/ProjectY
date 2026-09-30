using System;
using System.Collections.Generic;
using System.IO;
using ProjectY.Samples;
using UnityEditor;
using UnityEditor.Animations;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace ProjectY.Editor
{
    /// <summary>Reproducible animation asset pipeline; edits prefab bindings through the Unity API.</summary>
    public static class PawnAnimationAssets
    {
        public const string Folder = "Assets/DynamicAsset/PawnAnimation";
        public const string SetPath = Folder + "/PawnAnimations.asset";
        private const string RigPath = "Assets/DynamicAsset/PawnLowPoly/PawnRig.prefab";
        private static readonly HumanBodyBones[] BoneIds = {
            HumanBodyBones.Hips, HumanBodyBones.Spine, HumanBodyBones.Chest, HumanBodyBones.UpperChest,
            HumanBodyBones.Neck, HumanBodyBones.Head, HumanBodyBones.LeftShoulder, HumanBodyBones.LeftUpperArm,
            HumanBodyBones.LeftLowerArm, HumanBodyBones.LeftHand, HumanBodyBones.RightShoulder, HumanBodyBones.RightUpperArm,
            HumanBodyBones.RightLowerArm, HumanBodyBones.RightHand, HumanBodyBones.LeftUpperLeg, HumanBodyBones.LeftLowerLeg,
            HumanBodyBones.LeftFoot, HumanBodyBones.LeftToes, HumanBodyBones.RightUpperLeg, HumanBodyBones.RightLowerLeg,
            HumanBodyBones.RightFoot, HumanBodyBones.RightToes
        };
        [Serializable] private sealed class ActionRow {public int id; public float duration; public string kind;}
        [Serializable] private sealed class ActionRows {public ActionRow[] rows;}
        [Serializable] private sealed class PoseRow {public int id; public float[] weaponRotation;}
        [Serializable] private sealed class PoseRows {public PoseRow[] rows;}
        private static T Table<T>(string name) => JsonUtility.FromJson<T>(File.ReadAllText("Config/Tables/Equipment/" + name + ".json"));

        [MenuItem("Project Y/角色/同步 Humanoid 动画资源")]
        public static void Build()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("Edit Mode required.");
            var clips = Clips();
            var controller = AssetDatabase.LoadAssetAtPath<AnimatorController>(Folder + "/Pawn.controller");
            if(controller == null) controller = BuildController(clips);
            var settings = AssetDatabase.LoadAssetAtPath<PawnAnimationSet>(SetPath);
            bool created = settings == null;
            if(created)
            {
                settings = ScriptableObject.CreateInstance<PawnAnimationSet>();
                settings.Controller = controller; settings.Hit = clips["Hit_Chest"]; settings.Death = clips["Death01"];
                var actions = new List<PawnAnimationSet.Action>();
                foreach(var row in Table<ActionRows>("EquipmentActionTable").rows)
                {
                    string state, clip;
                    switch(row.kind)
                    {
                        case "none": state="";clip="Idle_Loop";break;
                        case "slash": state=row.id==5||row.id==6?"HeavySlash":"Attack";clip=state=="HeavySlash"?"Punch_Cross":"Sword_Attack";break;
                        case "offhand_slash":state="OffAttack";clip="Sword_Attack";break;
                        case "cast":state="Cast";clip="Spell_Simple_Shoot";break;
                        case "fire":state="Fire";clip="Pistol_Shoot";break;
                        case "reload":state="Reload";clip="Pistol_Reload";break;
                        default:throw new InvalidOperationException("Unknown action kind: "+row.kind);
                    }
                    var action=new PawnAnimationSet.Action {TemplateId=row.id,State=state,Clip=clips[clip],Duration=Mathf.Max(.05f,row.duration),Impact=.45f};
                    ConfigureGrip(action);actions.Add(action);
                }
                settings.Actions=actions.ToArray();
                var holds = new List<PawnAnimationSet.Hold> {new PawnAnimationSet.Hold {PoseId=0,IdleState="Idle"}};
                foreach(var row in Table<PoseRows>("EquipmentPoseTable").rows)
                    holds.Add(new PawnAnimationSet.Hold {PoseId=row.id,IdleState=row.id==1?"IdleSpell":row.id==2?"IdleRifle":row.id==3?"IdleSword":"Idle"});
                settings.Holds=holds.ToArray(); settings.Skins=Array.Empty<PawnAnimationSet.Skin>();
                AssetDatabase.CreateAsset(settings,SetPath);
            }
            EnsureAmbientAssets(settings,controller,clips);
            var preview=EditorSceneManager.NewPreviewScene();
            try
            {
                var model=UnityEngine.Object.Instantiate(AssetDatabase.LoadAssetAtPath<GameObject>(Folder+"/PawnHumanoid.fbx"));
                UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(model,preview);
                var animator=model.GetComponent<Animator>();animator.runtimeAnimatorController=controller;animator.applyRootMotion=false;
                var bones=new Transform[BoneIds.Length];
                for(int i=0;i<bones.Length;i++) bones[i]=animator.GetBoneTransform(BoneIds[i]) ?? throw new InvalidOperationException("Missing human bone: "+BoneIds[i]);
                if(created) settings.Skins=new[] {
                    BuildSkin(24,"Assets/DynamicAsset/EquipmentDemo/Models/Equip_Trousers.fbx",new Vector3(0,.65f,0),bones,model.transform,false),
                    BuildSkin(25,"Assets/DynamicAsset/EquipmentDemo/Models/Equip_Boots.fbx",new Vector3(0,.235f,0),bones,model.transform,true)
                };
                if(created)
                {
                    var right=animator.GetBoneTransform(HumanBodyBones.RightHand);var left=animator.GetBoneTransform(HumanBodyBones.LeftHand);
                    foreach(var hold in settings.Holds)
                    {
                        animator.cullingMode=AnimatorCullingMode.AlwaysAnimate;animator.enabled=false;
                        animator.Rebind();animator.SetFloat("PlaybackSpeed",1);animator.Play(hold.IdleState,0,.2f);animator.Update(.01f);
                        var row=Array.Find(Table<PoseRows>("EquipmentPoseTable").rows,p=>p.id==hold.PoseId);
                        var angles=row==null?Vector3.zero:new Vector3(row.weaponRotation[0],row.weaponRotation[1],row.weaponRotation[2]);
                        hold.MainGripRotation=(Quaternion.Inverse(right.rotation)*Quaternion.Euler(angles)).eulerAngles;
                        angles.z=-angles.z;
                        hold.OffGripRotation=(Quaternion.Inverse(left.rotation)*Quaternion.Euler(angles)).eulerAngles;
                    }
                }
                EditorUtility.SetDirty(settings);AssetDatabase.SaveAssets();
            }
            finally {EditorSceneManager.ClosePreviewScene(preview);}
            var rig=PrefabUtility.LoadPrefabContents(RigPath);
            try {Attach(rig.GetComponent<PawnView>());PrefabUtility.SaveAsPrefabAsset(rig,RigPath);}
            finally {PrefabUtility.UnloadPrefabContents(rig);}
            AssetDatabase.SaveAssets();
        }
        private static Dictionary<string,AnimationClip> Clips()
        {
            var clips=new Dictionary<string,AnimationClip>();
            foreach(var asset in AssetDatabase.LoadAllAssetsAtPath(Folder+"/UAL1_Standard.fbx"))
                if(asset is AnimationClip clip && !clip.name.StartsWith("__preview__")) clips.Add(clip.name,clip);
            if(clips.Count!=43) throw new InvalidOperationException("Expected verified UAL Standard inventory of 43 clips.");
            return clips;
        }
        private static void EnsureAmbientAssets(PawnAnimationSet settings,AnimatorController controller,Dictionary<string,AnimationClip> clips)
        {
            var machine=controller.layers[0].stateMachine;
            if(!Array.Exists(machine.states,s=>s.state.name=="IdleTalking"))
            {
                var state=machine.AddState("IdleTalking");state.motion=clips["Idle_Talking_Loop"];
                state.speedParameter="PlaybackSpeed";state.speedParameterActive=true;
            }
            if(!Array.Exists(machine.states,s=>s.state.name=="MoveFormal"))
            {
                var tree=new BlendTree {name="Formal gait",blendType=BlendTreeType.Simple1D,blendParameter="Speed",useAutomaticThresholds=false};
                tree.AddChild(clips["Walk_Formal_Loop"],0);tree.AddChild(clips["Sprint_Loop"],1);
                var children=tree.children;children[1].timeScale=clips["Sprint_Loop"].length/clips["Jog_Fwd_Loop"].length;tree.children=children;
                AssetDatabase.AddObjectToAsset(tree,controller);
                var state=machine.AddState("MoveFormal");state.motion=tree;state.speedParameter="PlaybackSpeed";state.speedParameterActive=true;
            }
            if(settings.IdleVariants==null || settings.IdleVariants.Length==0)
            {
                settings.VariationSeed=137;settings.IdleChangeSeconds=new Vector2(4,9);settings.MoveChangeSeconds=new Vector2(7,13);
                settings.IdlePlaybackRange=new Vector2(.92f,1.08f);settings.MovePlaybackRange=new Vector2(.96f,1.04f);settings.AmbientBlendSeconds=.35f;
                settings.IdleVariants=new[] {
                    new PawnAnimationSet.AmbientVariant {State="Idle",ReferenceClip=clips["Idle_Loop"],Weight=4},
                    new PawnAnimationSet.AmbientVariant {State="IdleSword",ReferenceClip=clips["Sword_Idle"],Weight=3},
                    new PawnAnimationSet.AmbientVariant {State="IdleTalking",ReferenceClip=clips["Idle_Talking_Loop"],Weight=1},
                    new PawnAnimationSet.AmbientVariant {State="IdleSpell",ReferenceClip=clips["Spell_Simple_Idle_Loop"],Weight=3},
                    new PawnAnimationSet.AmbientVariant {State="IdleRifle",ReferenceClip=clips["Pistol_Idle_Loop"],Weight=3}
                };
            }
            if(settings.MoveVariants==null || settings.MoveVariants.Length==0)
                settings.MoveVariants=new[] {
                    new PawnAnimationSet.AmbientVariant {State="Move",ReferenceClip=clips["Walk_Loop"]},
                    new PawnAnimationSet.AmbientVariant {State="MoveFormal",ReferenceClip=clips["Walk_Formal_Loop"]}
                };
            foreach(var hold in settings.Holds)if(hold.IdleVariants==null || hold.IdleVariants.Length==0)
            {
                hold.KeepWeaponUpright=true;
                switch(hold.PoseId)
                {
                    case 0:hold.IdleVariants=new[]{"Idle","IdleTalking","IdleSword"};break;
                    case 1:hold.IdleVariants=new[]{"IdleSpell","Idle"};break;
                    case 2:hold.IdleVariants=new[]{"IdleRifle","Idle"};break;
                    case 3:hold.IdleVariants=new[]{"IdleSword","Idle"};break;
                    default:hold.IdleVariants=new[]{"Idle","IdleTalking"};break;
                }
            }
            EditorUtility.SetDirty(controller);EditorUtility.SetDirty(settings);
        }
        public static void ConfigureGrip(PawnAnimationSet.Action action)
        {
            if(action.TemplateId==6)
            {
                action.UseAuthoredGrip=true;action.Impact=.48f;action.OffGripOffset=Vector3.zero;
                // Turn the edge into the shoulder-side cutting plane before accelerating through the strike.
                // Constant X/Y fixes the blade-face normal while Z swings the edge through the cutting plane.
                action.GripKeys=new[] {
                    new PawnAnimationSet.GripKey {Time=0,WeaponRotation=new Vector3(40,0,4)},
                    new PawnAnimationSet.GripKey {Time=.26f,WeaponRotation=new Vector3(60,90,35)},
                    new PawnAnimationSet.GripKey {Time=.32f,WeaponRotation=new Vector3(60,90,35)},
                    new PawnAnimationSet.GripKey {Time=.48f,WeaponRotation=new Vector3(60,90,115)},
                    new PawnAnimationSet.GripKey {Time=.56f,WeaponRotation=new Vector3(60,90,145)},
                    new PawnAnimationSet.GripKey {Time=.76f,WeaponRotation=new Vector3(60,90,80)},
                    new PawnAnimationSet.GripKey {Time=1,WeaponRotation=new Vector3(40,0,4)}
                };
                return;
            }
            float[] times={0,.2f,.45f,.8f,1};Vector3[] angles;
            if(action.TemplateId==5)
                angles=new[]{new Vector3(40,0,4),new Vector3(55,-10,4),new Vector3(100,5,4),new Vector3(75,5,4),new Vector3(40,0,4)};
            else if(action.TemplateId==2)
                angles=new[]{new Vector3(0,-25,0),new Vector3(-5,-25,0),new Vector3(-2,-25,0),new Vector3(0,-25,0),new Vector3(0,-25,0)};
            else if(action.TemplateId==3)
            {
                angles=new[]{new Vector3(0,-25,0),new Vector3(12,-10,-12),new Vector3(12,-10,-12),new Vector3(5,-20,-5),new Vector3(0,-25,0)};
                action.OffGripOffset=new Vector3(0,-.14f,-.12f);
            }
            else return;
            action.UseAuthoredGrip=true;action.GripKeys=new PawnAnimationSet.GripKey[times.Length];
            for(int i=0;i<times.Length;i++)action.GripKeys[i]=new PawnAnimationSet.GripKey {Time=times[i],WeaponRotation=angles[i]};
        }
        private static AnimatorController BuildController(Dictionary<string,AnimationClip> clips)
        {
            var controller=AnimatorController.CreateAnimatorControllerAtPath(Folder+"/Pawn.controller");
            controller.AddParameter("Speed",AnimatorControllerParameterType.Float);
            controller.AddParameter("PlaybackSpeed",AnimatorControllerParameterType.Float);
            var parameters=controller.parameters;parameters[1].defaultFloat=1;controller.parameters=parameters;
            var layers=controller.layers;layers[0].iKPass=true;controller.layers=layers;
            var machine=layers[0].stateMachine;
            var names=new Dictionary<string,string> {
                {"Idle","Idle_Loop"},{"IdleSword","Sword_Idle"},{"IdleSpell","Spell_Simple_Idle_Loop"},
                {"IdleRifle","Pistol_Idle_Loop"},{"Attack","Sword_Attack"},{"OffAttack","Sword_Attack"},
                {"Fire","Pistol_Shoot"},{"Reload","Pistol_Reload"},{"Cast","Spell_Simple_Shoot"},
                {"HeavySlash","Punch_Cross"},
                {"Hit","Hit_Chest"},{"Death","Death01"},{"Interact","PickUp_Table"},{"Talk","Idle_Talking_Loop"}
            };
            foreach(var pair in names)
            {
                var state=machine.AddState(pair.Key);state.motion=clips[pair.Value];state.writeDefaultValues=true;
                state.speedParameter="PlaybackSpeed";state.speedParameterActive=true;state.mirror=pair.Key=="OffAttack";
                if(pair.Key=="Idle")machine.defaultState=state;
            }
            var tree=new BlendTree {name="Locomotion",blendType=BlendTreeType.Simple1D,blendParameter="Speed",useAutomaticThresholds=false};
            tree.AddChild(clips["Walk_Loop"],0);tree.AddChild(clips["Jog_Fwd_Loop"],1);AssetDatabase.AddObjectToAsset(tree,controller);
            var move=machine.AddState("Move");move.motion=tree;move.speedParameter="PlaybackSpeed";move.speedParameterActive=true;
            EditorUtility.SetDirty(controller);return controller;
        }
        internal static void Attach(PawnView pawn)
        {
            var settings=AssetDatabase.LoadAssetAtPath<PawnAnimationSet>(SetPath);
            if(settings==null) return; // Static resource pipeline remains usable before animation installation.
            foreach(var prior in pawn.GetComponentsInChildren<PawnAnimationView>(true)) UnityEngine.Object.DestroyImmediate(prior.gameObject);
            var model=UnityEngine.Object.Instantiate(AssetDatabase.LoadAssetAtPath<GameObject>(Folder+"/PawnHumanoid.fbx"),pawn.transform,false);
            model.name="AnimatedBody";
            var animator=model.GetComponent<Animator>();animator.runtimeAnimatorController=settings.Controller;animator.applyRootMotion=false;animator.enabled=false;
            var bones=new Transform[BoneIds.Length];
            for(int i=0;i<bones.Length;i++)bones[i]=animator.GetBoneTransform(BoneIds[i]);
            var renderer=model.GetComponentInChildren<SkinnedMeshRenderer>();
            var materials=new List<Material>();
            foreach(var name in new[]{"Timber","Window","PlasterShade"}) materials.Add(AssetDatabase.LoadAssetAtPath<Material>("Assets/DynamicAsset/MapLowPoly/Materials/M_MapLP_"+name+".mat"));
            renderer.sharedMaterials=materials.ToArray();renderer.updateWhenOffscreen=true;
            var bindings=new List<PawnAnimationView.Mount>();
            Func<string,HumanBodyBones,Vector3,Transform> mount=(name,bone,position)=> {
                var anchor=new GameObject(name).transform;anchor.SetParent(animator.GetBoneTransform(bone),false);
                anchor.position=pawn.transform.TransformPoint(position);anchor.rotation=pawn.transform.rotation;
                bindings.Add(new PawnAnimationView.Mount {Slot=name,Anchor=anchor});return anchor;
            };
            var right=animator.GetBoneTransform(HumanBodyBones.RightHand);var left=animator.GetBoneTransform(HumanBodyBones.LeftHand);
            var main=mount("mainHand",HumanBodyBones.RightHand,pawn.transform.InverseTransformPoint(right.position)+Vector3.right*.07f);
            var off=mount("offHand",HumanBodyBones.LeftHand,pawn.transform.InverseTransformPoint(left.position)-Vector3.right*.07f);
            mount("head",HumanBodyBones.Head,new Vector3(0,1.59f,0));mount("chest",HumanBodyBones.Chest,new Vector3(0,1.05f,0));
            mount("back",HumanBodyBones.UpperChest,new Vector3(0,1.13f,-.2f));mount("legs",HumanBodyBones.Hips,new Vector3(0,.65f,0));
            mount("feet",HumanBodyBones.RightFoot,new Vector3(0,.235f,0));
            var view=model.AddComponent<PawnAnimationView>();view.Bind(animator,settings,bones,bindings.ToArray(),main,off);pawn.BindAnimation(view);
            model.transform.localPosition=Vector3.up*settings.BaseHeight;
            model.SetActive(false);
            PawnCustomizationAssets.Attach(pawn);
        }
        private static PawnAnimationSet.Skin BuildSkin(int id,string path,Vector3 offset,Transform[] bones,Transform root,bool feet)
        {
            var source=AssetDatabase.LoadAssetAtPath<GameObject>(path);var combine=new List<CombineInstance>();var materials=new List<Material>();
            foreach(var filter in source.GetComponentsInChildren<MeshFilter>())
            {
                var renderer=filter.GetComponent<MeshRenderer>();
                for(int s=0;s<filter.sharedMesh.subMeshCount;s++)
                {combine.Add(new CombineInstance {mesh=filter.sharedMesh,subMeshIndex=s,transform=Matrix4x4.Translate(offset)*filter.transform.localToWorldMatrix});materials.Add(renderer.sharedMaterials[s]);}
            }
            var merged=new Mesh();merged.CombineMeshes(combine.ToArray(),false,true);
            var vertices=new List<Vector3>();var triangles=new List<int[]>();var weights=new List<BoneWeight>();
            Func<Vector3,int> add=point=> {
                int bone;
                bool right=point.x>=0;
                if(feet)bone=right?20:16;
                else if(point.y>.82f)bone=0;
                else if(point.y>=.56f-.00001f)bone=right?18:14;
                else bone=right?19:15;
                int index=vertices.Count;vertices.Add(point);weights.Add(new BoneWeight {boneIndex0=bone,weight0=1});return index;
            };
            var points=merged.vertices;
            for(int sub=0;sub<merged.subMeshCount;sub++)
            {
                var indices=merged.GetTriangles(sub);var output=new List<int>();
                for(int t=0;t<indices.Length;t+=3)
                {
                    var polygon=new[]{points[indices[t]],points[indices[t+1]],points[indices[t+2]]};
                    // Split at the actual knee before assigning rigid segment weights.
                    for(int side=0;side<(feet?1:2);side++)
                    {
                        var clipped=new List<Vector3>();
                        for(int i=0;i<3;i++)
                        {
                            var a=polygon[i];var b=polygon[(i+1)%3];bool inside=feet||(side==0?a.y>=.56f:a.y<=.56f);
                            bool next=feet||(side==0?b.y>=.56f:b.y<=.56f);
                            if(inside)clipped.Add(a);
                            if(inside!=next)clipped.Add(Vector3.Lerp(a,b,(.56f-a.y)/(b.y-a.y)));
                        }
                        for(int i=1;i+1<clipped.Count;i++) {output.Add(add(clipped[0]));output.Add(add(clipped[i]));output.Add(add(clipped[i+1]));}
                    }
                }
                triangles.Add(output.ToArray());
            }
            var mesh=new Mesh {name="PawnWearable_"+id};mesh.SetVertices(vertices);mesh.boneWeights=weights.ToArray();mesh.subMeshCount=triangles.Count;
            for(int i=0;i<triangles.Count;i++)mesh.SetTriangles(triangles[i],i);
            var bindposes=new Matrix4x4[bones.Length];for(int i=0;i<bones.Length;i++)bindposes[i]=bones[i].worldToLocalMatrix*root.localToWorldMatrix;
            mesh.bindposes=bindposes;mesh.RecalculateNormals();mesh.RecalculateBounds();UnityEngine.Object.DestroyImmediate(merged);
            AssetDatabase.CreateAsset(mesh,Folder+"/Wearable_"+id+".asset");
            return new PawnAnimationSet.Skin {AssetId=id,Mesh=mesh,Materials=materials.ToArray()};
        }
    }
}
