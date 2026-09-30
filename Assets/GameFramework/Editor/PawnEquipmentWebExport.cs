using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using ProjectY.Data;
using ProjectY.Samples;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;
using XLua;

namespace ProjectY.Editor
{
    internal static class PawnEquipmentWebExport
    {
        [Serializable] private sealed class ItemRow { public int id; public string name, kind; }
        [Serializable] private sealed class ItemRows { public ItemRow[] rows; }
        internal static PawnCustomizationAssets.WebLoadout[] Export()
        {
            var scene = EditorSceneManager.NewPreviewScene(); var services = new FrameworkServices(null);
            var result = new List<PawnCustomizationAssets.WebLoadout>();
            try
            {
                using (var lua = new LuaEnv())
                {
                    var loader = new LuaFileLoader(LuaScriptPaths.RuntimeRoot); lua.AddLoader(loader.Load); lua.Global.Set("Services", services);
                    var actor = (CombatActorData)lua.DoString(File.ReadAllText("Tools/CharacterPreview/export_equipment.lua"))[0];
                    try
                    {
                        string[] labels = { "法杖与双符文", "步枪与弹匣", "铁制单手剑", "骑士单手剑", "佣兵大剑", "皇家大剑", "破城巨剑与推进器", "黑曜石巨剑", "双持单手剑", "剑盾", "长弓 · 基础射击" };
                        var selections = labels.Select((label, index) => new { label, id = "weapon_" + index, command = "CharacterEquipmentLoadout(" + index + ",false)" }).ToList();
                        var existing = new HashSet<int>(new[] { 1, 2, 40, 41, 42, 43, 44, 45, 46 });
                        foreach (var item in JsonUtility.FromJson<ItemRows>(File.ReadAllText("Config/Tables/Equipment/EquipmentItemTable.json")).rows)
                            if (item.kind == "weapon" && !existing.Contains(item.id)) selections.Add(new { label = item.name, id = "item_" + item.id, command = "CharacterEquipmentByItem(" + item.id + ")" });
                        for (int index = 0; index < selections.Count; index++)
                        {
                            AdventureViewData.Actor state;
                            using (var row = (LuaTable)lua.DoString("return " + selections[index].command)[0]) state = AdventureViewData.ReadActor(row);
                            var pawn = UnityEngine.Object.Instantiate(AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/PawnLowPoly/PawnRig.prefab")).GetComponent<PawnView>();
                            SceneManager.MoveGameObjectToScene(pawn.gameObject, scene);
                            try
                            {
                                pawn.ApplyAppearance(state.Appearance, p => AssetDatabase.LoadAssetAtPath<GameObject>(p.Path));
                                var view = pawn.GetComponentInChildren<PawnAnimationView>(); var custom = pawn.GetComponentInChildren<PawnCustomizationView>(); var animator = pawn.GetComponentInChildren<Animator>();
                                view.SetHold(state.Appearance.Equipment.Hold); pawn.TickPresentation(0.001f);
                                var attachments = pawn.GetComponentsInChildren<MeshFilter>().Where(f => f.transform.IsChildOf(view.MainGrip) || f.transform.IsChildOf(view.OffGrip)).ToArray();
                                var meshes = ExportAttachments(attachments, "weapon_" + index + "_");
                                var animations = Sample(pawn, custom, view, animator, actor, state, attachments);
                                var primary=state.Appearance.Equipment.Hold.PrimaryGrip;var secondary=state.Appearance.Equipment.Hold.SecondaryGrip;
                                result.Add(new PawnCustomizationAssets.WebLoadout { id = selections[index].id, label = selections[index].label, moduleId=state.Appearance.Equipment.Hold.ModuleId,moduleName=state.Appearance.Equipment.Hold.ModuleName,
                                    primaryGrip=new[]{primary.Position.x,primary.Position.y,primary.Position.z,primary.Rotation.x,primary.Rotation.y,primary.Rotation.z},
                                    secondaryGrip=new[]{secondary.Position.x,secondary.Position.y,secondary.Position.z,secondary.Rotation.x,secondary.Rotation.y,secondary.Rotation.z},meshes = meshes, animations = animations,
                                    gripEditor = ExportGripEditor(lua, state.Appearance.Equipment, view, custom, animator, attachments) });
                            }
                            finally { UnityEngine.Object.DestroyImmediate(pawn.gameObject); }
                        }
                    }
                    finally { lua.DoString("CloseCharacterEquipmentFixture()"); lua.Global.Set<string, object>("Services", null); }
                }
            }
            finally { services.Player.ClearListeners(); EditorSceneManager.ClosePreviewScene(scene); }
            return result.ToArray();
        }
        private static PawnCustomizationAssets.WebGripEditor ExportGripEditor(LuaEnv lua, EquipmentVisualData equipment, PawnAnimationView view, PawnCustomizationView custom, Animator animator, MeshFilter[] attachments)
        {
            var ids = lua.DoString("return CharacterEquipmentGripIds()");
            var mirror = Matrix4x4.Scale(new Vector3(1, 1, -1));
            Func<Vector3, float[]> vector = v => new[] { v.x, v.y, v.z };
            Func<Vector3, float[]> point = p => vector(mirror.MultiplyPoint3x4(custom.transform.InverseTransformPoint(view.transform.TransformPoint(p))));
            Func<HumanBodyBones, int> bone = kind => {
                int index = Array.IndexOf(custom.Bones, animator.GetBoneTransform(kind));
                if (index < 0) throw new InvalidOperationException("Grip editor bone is missing: " + kind);
                return index;
            };
            var arms = new List<PawnCustomizationAssets.WebGripArm>(); var weapons = new List<PawnCustomizationAssets.WebGripWeapon>();
            for (int side = 0; side < 2; side++)
            {
                var mount = side == 0 ? view.MainGrip : view.OffGrip;
                var hand = animator.GetBoneTransform(side == 0 ? HumanBodyBones.RightHand : HumanBodyBones.LeftHand);
                var mountMatrix = mirror * (hand.worldToLocalMatrix * mount.localToWorldMatrix) * mirror;
                var mountRotation = mountMatrix.rotation;
                arms.Add(new PawnCustomizationAssets.WebGripArm {
                    bones = side == 0 ? new[] { bone(HumanBodyBones.RightUpperArm), bone(HumanBodyBones.RightLowerArm), bone(HumanBodyBones.RightHand) } : new[] { bone(HumanBodyBones.LeftUpperArm), bone(HumanBodyBones.LeftLowerArm), bone(HumanBodyBones.LeftHand) },
                    mountPosition = vector(mountMatrix.GetColumn(3)), mountRotation = new[] { mountRotation.x, mountRotation.y, mountRotation.z, mountRotation.w },
                    pole = point(side == 0 ? equipment.Hold.MainElbow : equipment.Hold.OffElbow)
                });
                var weapon = side == 0 ? equipment.WeaponView : equipment.OffhandView;
                if (weapon == null) continue;
                var indices = Enumerable.Range(0, attachments.Length).Where(i => attachments[i].transform.IsChildOf(mount)).ToArray();
                if (indices.Length == 0) throw new InvalidOperationException("Weapon has no grip editor meshes.");
                var root = attachments[indices[0]].transform;
                while (root.parent != mount) root = root.parent;
                weapons.Add(new PawnCustomizationAssets.WebGripWeapon {
                    slot = side == 0 ? "main" : "off", itemId = Convert.ToInt32(ids[side * 2]), gripId = Convert.ToInt32(ids[side * 2 + 1]), meshes = indices, scale = vector(root.localScale),
                    mainPosition = vector(weapon.PrimaryGrip.Position), mainRotation = vector(weapon.PrimaryGrip.Rotation),
                    offPosition = vector(weapon.SecondaryGrip.Position), offRotation = vector(weapon.SecondaryGrip.Rotation), rotationOffset = vector(side == 0 ? equipment.Hold.WeaponRotationOffset : equipment.Hold.OffWeaponRotationOffset)
                });
            }
            return new PawnCustomizationAssets.WebGripEditor { moduleId = equipment.Hold.ModuleId, weapons = weapons.ToArray(), arms = arms.ToArray(), shared = equipment.Hold.OffHandFollowsWeapon,
                head = bone(HumanBodyBones.Head), clearance = view.Settings.GetHold(equipment.Hold.HoldId).HandHeadClearance, mainHand = point(equipment.Hold.MainHand) };
        }
        private static PawnCustomizationAssets.WebMesh[] ExportAttachments(MeshFilter[] attachments, string prefix)
        {
            var output = new List<PawnCustomizationAssets.WebMesh>(); int serial = 0;
            // Keep original rigid mesh coordinates; each frame carries its actual post-grip transform.
            foreach (var filter in attachments)
            {
                var renderer = filter.GetComponent<MeshRenderer>();
                var mesh = UnityEngine.Object.Instantiate(filter.sharedMesh); mesh.name = prefix + serial++;
                try
                {
                    mesh.boneWeights = Array.Empty<BoneWeight>(); mesh.bindposes = Array.Empty<Matrix4x4>();
                    var part = new PawnCustomizationCatalog.Part { Id = mesh.name, Mesh = mesh, Materials = renderer.sharedMaterials, Roles = renderer.sharedMaterials.Select(m => "Equipment").ToArray() };
                    var exported = PawnCustomizationAssets.ExportMesh(part); exported.rigid = true; exported.path = AssetDatabase.GetAssetPath(filter.sharedMesh); output.Add(exported);
                }
                finally { UnityEngine.Object.DestroyImmediate(mesh); }
            }
            if (output.Count == 0) throw new InvalidOperationException("Selected loadout has no exported meshes.");
            return output.ToArray();
        }
        private static PawnCustomizationAssets.WebAnimation[] Sample(PawnView pawn, PawnCustomizationView custom, PawnAnimationView view, Animator animator, CombatActorData actor, AdventureViewData.Actor state, MeshFilter[] attachments)
        {
            var animations = new List<PawnCustomizationAssets.WebAnimation>();
            int action = state.Appearance.Equipment.Hold.AttackActionId;
            var settings = view.Settings;
            var mirror = Matrix4x4.Scale(new Vector3(1, 1, -1));
            // Use production Tick/Capture for held-weapon idle, locomotion, attacks and reload.
            foreach (var id in new[] { "Idle", "Move", "Attack" })
            {
                view.Skip(); view.SetHold(state.Appearance.Equipment.Hold);
                state.HP = actor.HP; state.ActionSequence = actor.ActionSequence; state.Actions = Array.Empty<CombatActorData.PresentationAction>(); pawn.Capture(state, Vector3.forward * 3, 0);
                if (id == "Attack")
                {
                    actor.RecordAction(action, 1, 0, 3); state.ActionSequence = actor.ActionSequence; state.Actions = actor.CopyPresentationActions(); pawn.Capture(state, Vector3.forward * 3, 0);
                }
                float duration = id == "Attack" ? settings.GetAction(action).Duration : id == "Move" ? 1.333333f : 2.5f;
                if (id != "Attack")
                {
                    pawn.TickPresentation((settings.AmbientBlendSeconds + .01f) / settings.PresentationSpeed, id == "Move" ? settings.WalkSpeed : 0);
                    var clips = animator.GetCurrentAnimatorClipInfo(0);
                    if (clips.Length == 0) throw new InvalidOperationException("Held animation has no sampled clip.");
                    duration = clips.OrderByDescending(c => c.weight).First().clip.length / animator.GetFloat("PlaybackSpeed");
                }
                int count = Mathf.CeilToInt(duration * 20) + 1; var poses = new List<float>(); var attachmentPoses = new List<float>();
                for (int frame = 0; frame < count; frame++)
                {
                    pawn.TickPresentation(frame == 0 ? .0001f : duration / (count - 1) / settings.PresentationSpeed, id == "Move" ? settings.WalkSpeed : 0);
                    foreach (var bone in custom.Bones)
                    {
                        var matrix = mirror * (custom.transform.worldToLocalMatrix * bone.localToWorldMatrix) * mirror;
                        var p = matrix.GetColumn(3); var q = matrix.rotation; var scale = matrix.lossyScale;
                        poses.AddRange(new[] { p.x, p.y, p.z, q.x, q.y, q.z, q.w, scale.x, scale.y, scale.z }.Select(v => (float)Math.Round(v, 6)));
                    }
                    foreach (var filter in attachments)
                    {
                        var matrix = mirror * (custom.transform.worldToLocalMatrix * filter.transform.localToWorldMatrix) * mirror;
                        var p = matrix.GetColumn(3); var q = matrix.rotation; var scale = matrix.lossyScale;
                        attachmentPoses.AddRange(new[] { p.x, p.y, p.z, q.x, q.y, q.z, q.w, scale.x, scale.y, scale.z }.Select(v => (float)Math.Round(v, 6)));
                    }
                }
                animations.Add(new PawnCustomizationAssets.WebAnimation { id = id, label = id == "Idle" ? "持握待机" : id == "Move" ? "持械行走" : "武器动作", duration = duration, loop = id != "Attack", frameCount = count, poses = poses.ToArray(), attachmentPoses = attachmentPoses.ToArray() });
            }
            return animations.ToArray();
        }
    }
}
