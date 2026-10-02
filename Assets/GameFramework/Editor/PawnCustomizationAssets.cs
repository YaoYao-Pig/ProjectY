using ProjectY.Data;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using ProjectY.Samples;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace ProjectY.Editor
{
    public static class PawnCustomizationAssets
    {
        public const string Folder = "Assets/DynamicAsset/PawnCustomization";
        public const string CatalogPath = Folder + "/PawnCustomization.asset";
        private const string ModelPath = Folder + "/PawnCustomization.fbx";
        private const string RigPath = "Assets/DynamicAsset/PawnLowPoly/PawnRig.prefab";
        private const string OriginalPath = "Assets/DynamicAsset/PawnAnimation/PawnHumanoid.fbx";
        private const string RulePath = "Art/PawnCustomization/Integration/catalog.json";
        private const string DefaultsPath = "Art/PawnCustomization/Integration/body-defaults.json";
        [Serializable] private sealed class BodyDefaultsFile { public PawnCustomizationCatalog.BodyDefault[] entries; }

        internal static void SaveAsset(UnityEngine.Object value, string path)
        {
            var prior = AssetDatabase.LoadAssetAtPath<UnityEngine.Object>(path);
            if (prior == null) AssetDatabase.CreateAsset(value, path);
            else
            {
                if (value is Mesh source && prior is Mesh target)
                {
                    // CopySerialized can retain the old native vertex layout while replacing indices.
                    // Explicitly rebuild the mesh buffers so topology changes keep the existing GUID safely.
                    target.Clear(false);
                    target.indexFormat = source.indexFormat;
                    target.vertices = source.vertices; target.normals = source.normals;
                    target.tangents = source.tangents; target.colors32 = source.colors32;
                    var uv = new List<Vector4>();
                    for (int channel = 0; channel < 8; channel++)
                    {
                        source.GetUVs(channel, uv);
                        if (uv.Count > 0) target.SetUVs(channel, uv);
                    }
                    target.boneWeights = source.boneWeights; target.bindposes = source.bindposes;
                    target.subMeshCount = source.subMeshCount;
                    for (int i = 0; i < source.subMeshCount; i++)
                        target.SetIndices(source.GetIndices(i), source.GetTopology(i), i, false);
                    target.bounds = source.bounds; target.name = source.name;
                }
                else EditorUtility.CopySerialized(value, prior);
                UnityEngine.Object.DestroyImmediate(value); EditorUtility.SetDirty(prior);
            }
        }
        private static float MatrixError(Matrix4x4 a, Matrix4x4 b)
        { float error = 0; for (int i = 0; i < 16; i++) error = Mathf.Max(error, Mathf.Abs(a[i] - b[i])); return error; }

        internal static PawnCustomizationCatalog.Part ImportPart(GameObject source, SkinnedMeshRenderer renderer, GameObject original, string id)
        {
            var reference = original.GetComponentInChildren<SkinnedMeshRenderer>();
            var names = reference.bones.Select(b => b.name).ToArray();
            var binds = reference.bones.Select(b => b.worldToLocalMatrix * original.transform.localToWorldMatrix).ToArray();
            var shader = reference.sharedMaterials[0].shader;
            var matrix = source.transform.worldToLocalMatrix * renderer.transform.localToWorldMatrix;
            var mesh = UnityEngine.Object.Instantiate(renderer.sharedMesh); mesh.name = id;
            var vertices = mesh.vertices; var normals = mesh.normals;
            for (int i = 0; i < vertices.Length; i++) { vertices[i] = matrix.MultiplyPoint3x4(vertices[i]); normals[i] = matrix.inverse.transpose.MultiplyVector(normals[i]).normalized; }
            mesh.vertices = vertices; mesh.normals = normals;
            var remap = renderer.bones.Select(b => Array.IndexOf(names, b.name)).ToArray();
            for (int i = 0; i < remap.Length; i++)
            {
                if (remap[i] < 0 || MatrixError(mesh.bindposes[i] * matrix.inverse, binds[remap[i]]) > .002f)
                    throw new InvalidOperationException("Bind pose mismatch: " + id + "/" + renderer.bones[i].name);
            }
            var weights = mesh.boneWeights;
            for (int i = 0; i < weights.Length; i++)
            {
                var w = weights[i];
                if (Mathf.Abs(w.weight0 + w.weight1 + w.weight2 + w.weight3 - 1) > .001f) throw new InvalidOperationException("Unnormalized weights.");
                w.boneIndex0 = remap[w.boneIndex0]; w.boneIndex1 = remap[w.boneIndex1]; w.boneIndex2 = remap[w.boneIndex2]; w.boneIndex3 = remap[w.boneIndex3]; weights[i] = w;
            }
            mesh.boneWeights = weights; mesh.bindposes = binds; mesh.RecalculateBounds();
            string meshPath = Folder + "/Meshes/" + id + ".asset"; SaveAsset(mesh, meshPath);
            var materials = new List<Material>(); var roles = new List<string>();
            foreach (var material in renderer.sharedMaterials)
            {
                if (!material.name.StartsWith("PC_", StringComparison.Ordinal))
                    throw new InvalidOperationException("Character material must map to its canonical PC_ role: " + material.name);
                string role = material.name.Substring("PC_".Length), path = Folder + "/Materials/PC_" + role + ".mat";
                var external = AssetDatabase.LoadAssetAtPath<Material>(path);
                if (external == null)
                {
                    external = new Material(shader) { name = "PC_" + role, color = material.color };
                    external.SetFloat("_Smoothness", .12f); AssetDatabase.CreateAsset(external, path);
                }
                materials.Add(external); roles.Add(role);
            }
            return new PawnCustomizationCatalog.Part { Id = id, Mesh = AssetDatabase.LoadAssetAtPath<Mesh>(meshPath), Materials = materials.ToArray(), Roles = roles.ToArray() };
        }

        [MenuItem("Project Y/角色/同步模块化角色资源")]
        public static void Build()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("Edit Mode required.");
            Directory.CreateDirectory(Folder + "/Meshes"); Directory.CreateDirectory(Folder + "/Materials");
            var rules = JsonUtility.FromJson<PawnCustomizationRules>(File.ReadAllText(RulePath));
            var source = AssetDatabase.LoadAssetAtPath<GameObject>(ModelPath);
            if (source == null) throw new InvalidOperationException("Import character FBX first.");
            var original = AssetDatabase.LoadAssetAtPath<GameObject>(OriginalPath);
            var reference = original.GetComponentInChildren<SkinnedMeshRenderer>();
            var names = reference.bones.Select(b => b.name).ToArray();
            var binds = reference.bones.Select(b => b.worldToLocalMatrix * original.transform.localToWorldMatrix).ToArray();
            var parts = new List<PawnCustomizationCatalog.Part>();
            var shader = reference.sharedMaterials[0].shader;
            if (shader.name != "Universal Render Pipeline/Lit") throw new InvalidOperationException("Expected project URP Lit material.");
            foreach (var definition in rules.modules)
            {
                if (definition.id == "none") continue;
                var renderer = Array.Find(source.GetComponentsInChildren<SkinnedMeshRenderer>(true), s => s.name == definition.id + "_export");
                if (renderer == null) throw new InvalidOperationException("Missing Blender module: " + definition.id);
                parts.Add(ImportPart(source, renderer, original, definition.id));
            }
            var catalog = AssetDatabase.LoadAssetAtPath<PawnCustomizationCatalog>(CatalogPath);
            if (catalog == null) { catalog = ScriptableObject.CreateInstance<PawnCustomizationCatalog>(); AssetDatabase.CreateAsset(catalog, CatalogPath); }
            catalog.Rules = rules; catalog.BoneNames = names; catalog.Parts = parts.ToArray();
            ConfigureBodyDefaults(catalog);
            PawnGearFitAssets.Build(catalog, original);
            EquipmentMotionAssets.Sync();
            const string runtimeRules = "Assets/GameFramework/Resources/CharacterAppearanceCatalog.json";
            File.WriteAllText(runtimeRules, JsonUtility.ToJson(rules)); AssetDatabase.ImportAsset(runtimeRules, ImportAssetOptions.ForceSynchronousImport);
            EditorUtility.SetDirty(catalog);
            var rig = PrefabUtility.LoadPrefabContents(RigPath);
            try { Attach(rig.GetComponent<PawnView>()); PrefabUtility.SaveAsPrefabAsset(rig, RigPath); }
            finally { PrefabUtility.UnloadPrefabContents(rig); }
            AssetDatabase.SaveAssets();
            Debug.Log("Character modules: " + parts.Count + ", shared bones: " + names.Length + ".");
        }

        private static void ConfigureBodyDefaults(PawnCustomizationCatalog catalog)
        {
            var entries = JsonUtility.FromJson<BodyDefaultsFile>(File.ReadAllText(DefaultsPath)).entries;
            if (entries == null || entries.Length == 0) throw new InvalidOperationException("Character body defaults are missing.");
            var ids = new HashSet<int>();
            foreach (var entry in entries)
            {
                if (entry.BodyPartId <= 0 || !ids.Add(entry.BodyPartId)) throw new InvalidOperationException("Duplicate or invalid default body: " + entry.BodyPartId);
                catalog.Rules.Validate(entry.Appearance);
                catalog.GetPart(entry.Appearance.body); catalog.GetPart(entry.Appearance.head);
                if (entry.Appearance.hair != "none") catalog.GetPart(entry.Appearance.hair);
            }
            var animations = AssetDatabase.LoadAssetAtPath<PawnAnimationSet>(PawnAnimationAssets.SetPath);
            if (animations == null) throw new InvalidOperationException("Character animation set is missing.");
            catalog.BodyDefaults = entries;
            animations.BodyParts = animations.BodyParts.Concat(ids).Distinct().OrderBy(id => id).ToArray();
            EditorUtility.SetDirty(catalog); EditorUtility.SetDirty(animations);
        }

        [MenuItem("Project Y/角色/同步旧角色与城镇默认外观")]
        public static void SyncBodyDefaults()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("Edit Mode required.");
            var catalog = AssetDatabase.LoadAssetAtPath<PawnCustomizationCatalog>(CatalogPath);
            if (catalog == null) throw new InvalidOperationException("Sync character modules first.");
            ConfigureBodyDefaults(catalog);
            AssetDatabase.SaveAssetIfDirty(catalog);
            AssetDatabase.SaveAssetIfDirty(AssetDatabase.LoadAssetAtPath<PawnAnimationSet>(PawnAnimationAssets.SetPath));
        }

        public static void Attach(PawnView pawn)
        {
            var catalog = AssetDatabase.LoadAssetAtPath<PawnCustomizationCatalog>(CatalogPath);
            if (catalog == null) return; // The original animation importer also runs before customization installation.
            var animator = pawn.GetComponentInChildren<Animator>(true);
            var baseline = Array.Find(animator.GetComponentsInChildren<SkinnedMeshRenderer>(true), s => !s.name.StartsWith("Customization_"));
            var previous = animator.GetComponent<PawnCustomizationView>();
            if (previous != null)
            {
                foreach (var renderer in previous.Modules) UnityEngine.Object.DestroyImmediate(renderer.gameObject);
                UnityEngine.Object.DestroyImmediate(previous);
            }
            var targets = catalog.BoneNames.Select(name => Array.Find(baseline.bones, b => b.name == name) ?? throw new InvalidOperationException("Missing mapped bone: " + name)).ToArray();
            var view = animator.gameObject.AddComponent<PawnCustomizationView>(); view.Bind(catalog, targets, baseline); pawn.BindCustomization(view);
        }

        [MenuItem("Project Y/角色/从网页外观 JSON 创建预览 Prefab")]
        public static void ImportAppearance()
        {
            string path = EditorUtility.OpenFilePanel("选择网页导出的角色外观", "", "json");
            if (string.IsNullOrEmpty(path)) return;
            var data = JsonUtility.FromJson<PawnCustomizationData>(File.ReadAllText(path));
            var catalog = AssetDatabase.LoadAssetAtPath<PawnCustomizationCatalog>(CatalogPath); catalog.Rules.Validate(data);
            var root = PrefabUtility.LoadPrefabContents(RigPath);
            try
            {
                var view = root.GetComponentInChildren<PawnCustomizationView>(true); view.gameObject.SetActive(true); view.Apply(data);
                var preset = root.AddComponent<PawnCustomizationPreset>(); preset.Appearance = data; preset.View = view;
                Directory.CreateDirectory(Folder + "/Presets");
                string output = AssetDatabase.GenerateUniqueAssetPath(Folder + "/Presets/" + data.race + "_" + data.sex + ".prefab");
                PrefabUtility.SaveAsPrefabAsset(root, output); Selection.activeObject = AssetDatabase.LoadAssetAtPath<GameObject>(output);
            }
            finally { PrefabUtility.UnloadPrefabContents(root); }
        }

        [Serializable] private sealed class Dependency { public string path, sha256; }
        [Serializable] internal sealed class WebMaterial { public string role, path; public float[] color; }
        [Serializable] internal sealed class WebGroup { public int[] indices; public WebMaterial material; }
        [Serializable] internal sealed class WebMesh { public string id, path; public bool rigid; public float[] positions, normals, weights, bindposes; public int[] joints; public WebGroup[] groups; }
        [Serializable] internal sealed class WebAnimation { public string id, label; public float duration; public bool loop; public int frameCount; public float[] poses, attachmentPoses; }
        [Serializable] internal sealed class WebLoadout { public string id, label, moduleName; public int moduleId; public float[] primaryGrip, secondaryGrip; public WebMesh[] meshes; public WebAnimation[] animations; public WebGripEditor gripEditor; }
        [Serializable] internal sealed class WebGripWeapon { public string slot; public int itemId, gripId; public int[] meshes; public float[] scale, mainPosition, mainRotation, offPosition, offRotation, rotationOffset; }
        [Serializable] internal sealed class WebGripArm { public int[] bones; public float[] mountPosition, mountRotation, pole; }
        [Serializable] internal sealed class WebGripEditor { public int version = 2, head, moduleId; public bool shared; public float clearance; public float[] mainHand; public WebGripArm[] arms; public WebGripWeapon[] weapons; }
        [Serializable] private sealed class WebFit { public string id, sourcePath, body, race, slot; public int coverage; public bool hideHair; }
        [Serializable] private sealed class WebCovered { public string body, id; public int mask; }
        [Serializable] private sealed class WebBundle
        {
            public int version = 1; public string exportedAt, source = "Unity imported Mesh + PawnRig Animator", unityVersion;
            public float[] rootOffset;
            public PawnCustomizationRules rules; public string[] bones; public WebMesh[] meshes; public WebAnimation[] animations;
            public Dependency[] dependencies; public PawnCustomizationData[] randomFixtures;
            public WebFit[] gearFits; public WebCovered[] coveredBodies; public WebLoadout[] loadouts;
        }
        private static float[] MatrixValues(Matrix4x4 matrix)
        { var values = new float[16]; for (int i = 0; i < 16; i++) values[i] = matrix[i]; return values; }
        private static readonly Matrix4x4 Mirror = Matrix4x4.Scale(new Vector3(1, 1, -1));
        internal static WebMesh ExportMesh(PawnCustomizationCatalog.Part part)
        {
            var mesh = part.Mesh; var joints = new List<int>(); var weights = new List<float>();
            foreach (var w in mesh.boneWeights) { joints.AddRange(new[] { w.boneIndex0, w.boneIndex1, w.boneIndex2, w.boneIndex3 }); weights.AddRange(new[] { w.weight0, w.weight1, w.weight2, w.weight3 }); }
            var groups = new List<WebGroup>();
            for (int i = 0; i < mesh.subMeshCount; i++)
            {
                var indices = mesh.GetTriangles(i);
                for (int t = 0; t < indices.Length; t += 3) { int swap = indices[t + 1]; indices[t + 1] = indices[t + 2]; indices[t + 2] = swap; }
                var c = part.Materials[i].color;
                groups.Add(new WebGroup { indices = indices, material = new WebMaterial { role = part.Roles[i], path = AssetDatabase.GetAssetPath(part.Materials[i]), color = new[] { c.r, c.g, c.b } } });
            }
            return new WebMesh { id = part.Id, path = AssetDatabase.GetAssetPath(mesh),
                positions = mesh.vertices.SelectMany(v => new[] { v.x, v.y, -v.z }).ToArray(),
                normals = mesh.normals.SelectMany(v => new[] { v.x, v.y, -v.z }).ToArray(), joints = joints.ToArray(), weights = weights.ToArray(),
                bindposes = mesh.bindposes.SelectMany(m => MatrixValues(Mirror * m * Mirror)).ToArray(), groups = groups.ToArray() };
        }
        private static Dependency[] Dependencies()
        {
            // Importing a material can upgrade its serialized shader properties. Hash the saved source.
            AssetDatabase.SaveAssets();
            var paths = new HashSet<string>(AssetDatabase.GetDependencies(new[] { CatalogPath, RigPath }, true));
            paths.Add(ModelPath); paths.Add(RulePath); paths.Add("Art/PawnCustomization/Integration/gear-manifest.json"); paths.Add("Assets/DynamicAsset/PawnCustomization/PawnGearFits.fbx"); paths.Add("Assets/GameFramework/Resources/CharacterAppearanceCatalog.json");
            paths.Add(DefaultsPath);
            foreach (string name in new[] { "EquipmentMotionModuleTable", "EquipmentMotionMatchTable", "EquipmentGripTable", "EquipmentHoldAdjustmentTable", "EquipmentPoseTable", "EquipmentWeaponTable", "EquipmentActionTable", "EquipmentSocketTable", "EquipmentItemTable" })
            { paths.Add("Config/Tables/Equipment/" + name + ".json"); paths.Add("Assets/GameFramework/Resources/_Gen/Config/" + name + ".bytes"); }
            paths.Add("Lua/Game/Equipment/EquipmentMotion.lua"); paths.Add("Lua/Game/Equipment/EquipmentRules.lua"); paths.Add("Tools/CharacterPreview/export_equipment.lua");
            foreach (var script in new[] { "PawnCustomizationAssets", "PawnCustomizationValidation", "PawnEquipmentWebExport" }) paths.Add("Assets/GameFramework/Editor/" + script + ".cs");
            paths.Add("Assets/GameFramework/Samples/Adventure/PawnAnimationView.cs");paths.Add("Assets/GameFramework/Samples/Adventure/PawnEquipmentView.cs");
            foreach (string p in paths.ToArray()) if (File.Exists(p + ".meta")) paths.Add(p + ".meta");
            using (var sha = SHA256.Create()) return paths.Where(File.Exists).OrderBy(p => p, StringComparer.Ordinal).Select(p => new Dependency { path = p,
                sha256 = BitConverter.ToString(sha.ComputeHash(File.ReadAllBytes(p))).Replace("-", "").ToLowerInvariant() }).ToArray();
        }

        [MenuItem("Project Y/角色/导出角色网页资源")]
        public static void ExportWeb()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("Edit Mode required.");
            var catalog = AssetDatabase.LoadAssetAtPath<PawnCustomizationCatalog>(CatalogPath);
            var scene = EditorSceneManager.NewPreviewScene();
            try
            {
                var pawn = UnityEngine.Object.Instantiate(AssetDatabase.LoadAssetAtPath<GameObject>(RigPath)); SceneManager.MoveGameObjectToScene(pawn, scene);
                var view = pawn.GetComponentInChildren<PawnCustomizationView>(true); view.gameObject.SetActive(true);
                var animator = view.GetComponent<Animator>(); var settings = AssetDatabase.LoadAssetAtPath<PawnAnimationSet>(PawnAnimationAssets.SetPath);
                animator.runtimeAnimatorController = settings.Controller; animator.applyRootMotion = false; animator.cullingMode = AnimatorCullingMode.AlwaysAnimate; animator.enabled = false;
                var states = new[] { "Idle", "Move", "Attack", "Cast", "Hit", "Death" };
                var labels = new[] { "待机", "行走", "挥砍", "施法", "受击", "倒地" };
                var clipNames = new[] { "Idle_Loop", "Walk_Loop", "Sword_Attack", "Spell_Simple_Shoot", "Hit_Chest", "Death01" };
                var animations = new List<WebAnimation>();
                for (int s = 0; s < states.Length; s++)
                {
                    var clip = Array.Find(settings.Controller.animationClips, c => c.name == clipNames[s]);
                    if (clip == null) throw new InvalidOperationException("Missing preview clip: " + clipNames[s]);
                    int count = Mathf.CeilToInt(clip.length * 30) + 1; var poses = new List<float>();
                    animator.Rebind(); animator.SetFloat("PlaybackSpeed", 1); animator.SetFloat("Speed", 0);
                    for (int frame = 0; frame < count; frame++)
                    {
                        float normalized = (float)frame / (count - 1);
                        animator.Play(states[s], 0, Mathf.Min(normalized, .999999f)); animator.Update(0);
                        foreach (var bone in view.Bones)
                        {
                            var matrix = Mirror * (view.transform.worldToLocalMatrix * bone.localToWorldMatrix) * Mirror;
                            var p = matrix.GetColumn(3); var q = matrix.rotation; var scale = matrix.lossyScale;
                            poses.AddRange(new[] { p.x, p.y, p.z, q.x, q.y, q.z, q.w, scale.x, scale.y, scale.z });
                        }
                    }
                    animations.Add(new WebAnimation { id = states[s], label = labels[s], duration = clip.length, loop = s < 2, frameCount = count, poses = poses.ToArray() });
                }
                var offset = view.transform.localPosition;
                var bundle = new WebBundle { exportedAt = DateTime.UtcNow.ToString("o"), unityVersion = Application.unityVersion, rules = catalog.Rules, bones = catalog.BoneNames,
                    rootOffset = new[] { offset.x, offset.y, -offset.z },
                    meshes = catalog.Parts.Concat(catalog.GearFits.Select(f => f.Part)).Concat(catalog.CoveredBodies.Select(c => new PawnCustomizationCatalog.Part { Id = c.Mesh.name, Mesh = c.Mesh, Materials = catalog.GetPart(c.Body).Materials, Roles = catalog.GetPart(c.Body).Roles })).Select(ExportMesh).ToArray(),
                    gearFits = catalog.GearFits.Select(f => new WebFit { id = f.Part.Id, sourcePath = f.SourcePath, body = f.Body, race = f.Race, slot = f.Slot, coverage = f.Coverage, hideHair = f.HideHair }).ToArray(),
                    coveredBodies = catalog.CoveredBodies.Select(c => new WebCovered { body = c.Body, mask = c.Mask, id = c.Mesh.name }).ToArray(),
                    animations = animations.ToArray(), loadouts = PawnEquipmentWebExport.Export(), dependencies = Dependencies(),
                    randomFixtures = new[] { 0, 1, 42, 20260927, int.MaxValue }.Select(seed => catalog.Rules.Randomize(seed)).ToArray() };
                const string folder = "Tools/CharacterPreview/public/data"; Directory.CreateDirectory(folder);
                var output = folder + "/characters.json"; var temporary = output + ".tmp";
                try
                {
                    File.WriteAllText(temporary, JsonUtility.ToJson(bundle));
                    if (File.Exists(output)) File.Replace(temporary, output, null); else File.Move(temporary, output);
                }
                finally { if (File.Exists(temporary)) File.Delete(temporary); }
                Debug.Log("Exported actual Unity meshes, palettes and six Humanoid animations for Character Lab.");
            }
            finally { EditorSceneManager.ClosePreviewScene(scene); }
        }
    }
}
