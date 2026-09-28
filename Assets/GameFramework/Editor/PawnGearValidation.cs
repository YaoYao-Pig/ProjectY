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
    public static class PawnGearValidation
    {
        [Serializable] private sealed class Report { public string race, worstFrame; public int combinations, poses, fits, coveredBodies; public float maxGripError, maxHeadPenetration; }
        [MenuItem("Project Y/角色/验证全部装备适配")]
        public static void Run()
        { foreach (string race in new[] { "human", "elf", "goblin", "dragon", "orc" }) RunRace(race); RunLegacy(); }
        public static string RunLegacy()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("Edit Mode required.");
            var scene = EditorSceneManager.NewPreviewScene(); var services = new FrameworkServices(null); var baked = new Mesh(); int combinations = 0, poses = 0;
            try
            {
                using (var lua = new LuaEnv())
                {
                    var loader = new LuaFileLoader(LuaScriptPaths.RuntimeRoot); lua.AddLoader(loader.Load); lua.Global.Set("Services", services);
                    var actor = (CombatActorData)lua.DoString(File.ReadAllText("Tools/CharacterPreview/export_equipment.lua"))[0];
                    try
                    {
                        var catalog = AssetDatabase.LoadAssetAtPath<PawnCustomizationCatalog>(PawnCustomizationAssets.CatalogPath);
                        foreach (var race in catalog.Rules.races) foreach (string sex in new[] { "male", "female" }) for (int body = 0; body < 3; body++) for (int face = 0; face < 2; face++)
                        {
                            var value = catalog.Rules.Randomize(42, race.id, sex); value.body = "body_" + sex + "_" + body; value.head = "head_" + race.id + "_" + sex + "_" + face;
                            services.Appearances.Apply(actor, JsonUtility.ToJson(value));
                            foreach (int unit in new[] { 1, 2, 3, 6, 4, 5 })
                            {
                                PawnAppearanceData appearance;
                                using (var row = (LuaTable)lua.DoString("return CharacterLegacyAppearance(" + unit + ")")[0]) appearance = PawnAppearanceData.Read(row);
                                var pawn = UnityEngine.Object.Instantiate(AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/PawnLowPoly/PawnRig.prefab")).GetComponent<PawnView>(); SceneManager.MoveGameObjectToScene(pawn.gameObject, scene);
                                try
                                {
                                    pawn.ApplyAppearance(appearance, p => AssetDatabase.LoadAssetAtPath<GameObject>(p.Path)); var animator = pawn.GetComponentInChildren<Animator>();
                                    if (animator == null || !animator.avatar.isValid || !animator.avatar.isHuman) throw new InvalidOperationException("Legacy outfit lost its avatar.");
                                    foreach (string state in new[] { "Idle", "Move", "Attack" })
                                    {
                                        animator.Play(state, 0, .5f); animator.Update(0);
                                        foreach (var skin in pawn.GetComponentsInChildren<SkinnedMeshRenderer>()) if (skin.enabled)
                                        { skin.BakeMesh(baked); foreach (var v in baked.vertices) if (float.IsNaN(v.x) || float.IsInfinity(v.y) || v.magnitude > 5) throw new InvalidOperationException("Invalid legacy fitted deformation."); }
                                        poses++;
                                    }
                                    combinations++;
                                }
                                finally { UnityEngine.Object.DestroyImmediate(pawn.gameObject); }
                            }
                        }
                    }
                    finally { lua.DoString("CloseCharacterEquipmentFixture()"); lua.Global.Set<string, object>("Services", null); }
                }
                string json = "{\"combinations\":" + combinations + ",\"poses\":" + poses + ",\"templates\":6}";
                File.WriteAllText("Art/PawnCustomization/Integration/equipment-legacy.json", json); return json;
            }
            finally { UnityEngine.Object.DestroyImmediate(baked); services.Player.ClearListeners(); EditorSceneManager.ClosePreviewScene(scene); }
        }
        public static string RunRace(string race)
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("Edit Mode required.");
            var catalog = AssetDatabase.LoadAssetAtPath<PawnCustomizationCatalog>(PawnCustomizationAssets.CatalogPath);
            if (!Array.Exists(catalog.Rules.races, r => r.id == race)) throw new ArgumentException("Unknown test race.");
            var scene = EditorSceneManager.NewPreviewScene(); var services = new FrameworkServices(null); var baked = new Mesh();
            var report = new Report { race = race, fits = catalog.GearFits.Length, coveredBodies = catalog.CoveredBodies.Length, worstFrame = "" };
            try
            {
                var camera = new GameObject("GearAcceptanceCamera").AddComponent<Camera>(); SceneManager.MoveGameObjectToScene(camera.gameObject, scene);
                camera.scene = scene; camera.overrideSceneCullingMask = EditorSceneManager.GetSceneCullingMask(scene); camera.orthographic = true; camera.orthographicSize = 1.24f;
                camera.transform.position = new Vector3(2.4f, 1.95f, 4.6f); camera.transform.LookAt(new Vector3(0, 1.06f, 0)); camera.clearFlags = CameraClearFlags.SolidColor; camera.backgroundColor = new Color(.13f, .17f, .16f);
                var light = new GameObject("GearAcceptanceLight").AddComponent<Light>(); SceneManager.MoveGameObjectToScene(light.gameObject, scene); light.type = LightType.Directional; light.intensity = 1.3f; light.transform.rotation = Quaternion.Euler(35, -30, 0);
                using (var lua = new LuaEnv())
                {
                    var loader = new LuaFileLoader(LuaScriptPaths.RuntimeRoot); lua.AddLoader(loader.Load); lua.Global.Set("Services", services);
                    var actor = (CombatActorData)lua.DoString(File.ReadAllText("Tools/CharacterPreview/export_equipment.lua"))[0];
                    try
                    {
                        foreach (string sex in new[] { "male", "female" }) for (int body = 0; body < 3; body++) for (int face = 0; face < 2; face++)
                        {
                            var value = catalog.Rules.Randomize(412, race, sex); value.body = "body_" + sex + "_" + body; value.head = "head_" + race + "_" + sex + "_" + face;
                            services.Appearances.Apply(actor, JsonUtility.ToJson(value));
                            foreach (var fit in catalog.GearFits.Where(f => (f.Body == "" || f.Body == value.body) && (f.Race == "" || f.Race == race)))
                                if (fit.Part.Mesh.bindposes.Length != 23 || fit.Part.Mesh.boneWeights.Length != fit.Part.Mesh.vertexCount) throw new InvalidOperationException("Incomplete fitted skin.");
                            for (int weapon = 0; weapon < 11; weapon++)
                            {
                                AdventureViewData.Actor state;
                                using (var row = (LuaTable)lua.DoString("return CharacterEquipmentLoadout(" + weapon + ",true)")[0]) state = AdventureViewData.ReadActor(row);
                                var pawn = UnityEngine.Object.Instantiate(AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/PawnLowPoly/PawnRig.prefab")).GetComponent<PawnView>(); SceneManager.MoveGameObjectToScene(pawn.gameObject, scene);
                                Mesh headMesh = null;
                                try
                                {
                                    pawn.ApplyAppearance(state.Appearance, p => AssetDatabase.LoadAssetAtPath<GameObject>(p.Path));
                                    var custom = pawn.GetComponentInChildren<PawnCustomizationView>(); var animation = pawn.GetComponentInChildren<PawnAnimationView>();
                                    if (custom.Modules[2].enabled || custom.Modules[0].sharedMesh != catalog.BodyMesh(value.body, 7)) throw new InvalidOperationException("Wearable coverage did not apply.");
                                    var root = pawn.transform.position; pawn.Capture(state, Vector3.forward * 3, 0);
                                    headMesh = new Mesh(); var headCollider = custom.Modules[1].gameObject.AddComponent<MeshCollider>(); headCollider.convex = true;
                                    var weaponColliders = new List<MeshCollider>();
                                    foreach (var model in pawn.GetComponentsInChildren<WeaponModelView>()) foreach (var filter in model.GetComponentsInChildren<MeshFilter>())
                                    { var collider = filter.gameObject.AddComponent<MeshCollider>(); collider.sharedMesh = filter.sharedMesh; collider.convex = true; weaponColliders.Add(collider); }
                                    for (int sample = 0; sample < 30; sample++)
                                    {
                                        if (sample == 15)
                                        {
                                            int action = state.Appearance.Equipment.Hold.AttackActionId;
                                            actor.RecordAction(action, 1, 0, 3);
                                            using (var row = (LuaTable)lua.DoString("return CharacterEquipmentSnapshot()")[0]) state = AdventureViewData.ReadActor(row);
                                            pawn.Capture(state, Vector3.forward * 3, 0);
                                        }
                                        pawn.TickPresentation(.12f / animation.Settings.PresentationSpeed, sample > 0 && sample < 15 ? 2 : 0);
                                        foreach (var skin in pawn.GetComponentsInChildren<SkinnedMeshRenderer>()) if (skin.enabled)
                                        {
                                            skin.BakeMesh(baked);
                                            foreach (var v in baked.vertices) if (float.IsNaN(v.x) || float.IsInfinity(v.y) || v.magnitude > 5) throw new InvalidOperationException("Invalid fitted deformation.");
                                        }
                                        if (state.Appearance.Equipment.Hold.OffHandFollowsWeapon)
                                        {
                                            var mainWeapon = Array.Find(pawn.GetComponentsInChildren<WeaponModelView>(), w => w.transform.IsChildOf(animation.MainGrip));
                                            report.maxGripError = Mathf.Max(report.maxGripError, Vector3.Distance(animation.OffGrip.position, mainWeapon.transform.TransformPoint(state.Appearance.Equipment.WeaponView.SecondaryGrip.Position)));
                                        }
                                        custom.Modules[1].BakeMesh(headMesh); headCollider.sharedMesh = null; headCollider.sharedMesh = headMesh;
                                        foreach (var collider in weaponColliders) if (Physics.ComputePenetration(headCollider, headCollider.transform.position, headCollider.transform.rotation, collider, collider.transform.position, collider.transform.rotation, out var direction, out var depth) && depth > report.maxHeadPenetration)
                                        { report.maxHeadPenetration = depth; report.worstFrame = value.head + "/" + value.body + "/weapon" + weapon + "/sample" + sample; }
                                        report.poses++;
                                    }
                                    if (pawn.transform.position != root) throw new InvalidOperationException("Equipment changed authoritative position.");
                                    if (body == 1 && face == 0 && weapon == 9)
                                    {
                                        animation.Skip(); pawn.TickPresentation(.01f);
                                        var image = PawnCustomizationValidation.Capture(camera, custom, 720, 820);
                                        try { File.WriteAllBytes("Art/PawnCustomization/Previews/equipment-" + race + "-" + sex + ".png", image.EncodeToPNG()); }
                                        finally { UnityEngine.Object.DestroyImmediate(image); }
                                    }
                                    report.combinations++;
                                }
                                finally { UnityEngine.Object.DestroyImmediate(pawn.gameObject); if (headMesh != null) UnityEngine.Object.DestroyImmediate(headMesh); }
                            }
                        }
                    }
                    finally { lua.DoString("CloseCharacterEquipmentFixture()"); lua.Global.Set<string, object>("Services", null); }
                }
                string json = JsonUtility.ToJson(report, true); File.WriteAllText("Art/PawnCustomization/Integration/equipment-" + race + ".json", json);
                if (report.maxGripError > .035f || report.maxHeadPenetration > .008f) throw new InvalidOperationException("Equipment clearance failed: " + json);
                return json;
            }
            finally { UnityEngine.Object.DestroyImmediate(baked); services.Player.ClearListeners(); EditorSceneManager.ClosePreviewScene(scene); }
        }
    }
}
