using ProjectY.Data;
using System;
using System.Collections.Generic;
using System.IO;
using ProjectY.Samples;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace ProjectY.Editor
{
    public static class PawnCustomizationValidation
    {
        [Serializable] private sealed class Report { public int modules, bones, appearances, sampledPoses; public float maxSkinError; public bool validAvatar, unchangedScene; }
        [MenuItem("Project Y/角色/验证模块化角色与网页蒙皮")]
        public static void Validate()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("Edit Mode required.");
            var active = SceneManager.GetActiveScene(); bool dirty = active.isDirty;
            var scene = EditorSceneManager.NewPreviewScene();
            var report = new Report();
            var baked = new Mesh();
            Texture2D sheet = null;
            try
            {
                var pawn = UnityEngine.Object.Instantiate(AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/PawnLowPoly/PawnRig.prefab"));
                SceneManager.MoveGameObjectToScene(pawn, scene);
                var view = pawn.GetComponentInChildren<PawnCustomizationView>(true); view.gameObject.SetActive(true);
                var catalog = view.Catalog; var animator = view.GetComponent<Animator>();
                animator.runtimeAnimatorController = AssetDatabase.LoadAssetAtPath<PawnAnimationSet>(PawnAnimationAssets.SetPath).Controller;
                animator.applyRootMotion = false; animator.cullingMode = AnimatorCullingMode.AlwaysAnimate; animator.enabled = false;
                report.validAvatar = animator.avatar != null && animator.avatar.isValid && animator.avatar.isHuman;
                if (!report.validAvatar) throw new InvalidOperationException("Invalid Humanoid avatar.");
                report.modules = catalog.Parts.Length; report.bones = view.Bones.Length;
                foreach (int seed in new[] { 0, 1, 42, 20260927, int.MaxValue })
                {
                    string first = JsonUtility.ToJson(catalog.Rules.Randomize(seed));
                    if (first != JsonUtility.ToJson(catalog.Rules.Randomize(seed))) throw new InvalidOperationException("Unstable random seed.");
                }
                var rootPosition = pawn.transform.position;
                foreach (var race in catalog.Rules.races) foreach (string sex in new[] { "male", "female" })
                {
                    foreach (var body in catalog.Rules.Options("body", race.id, sex)) foreach (var head in catalog.Rules.Options("head", race.id, sex))
                    {
                        var value = catalog.Rules.Randomize(42, race.id, sex); value.body = body.id; value.head = head.id;
                        view.Apply(value); animator.Rebind(); animator.Play("Idle", 0, .35f); animator.Update(0);
                        CompareSkin(view, baked, report); report.appearances++;
                    }
                    foreach (string state in new[] { "Idle", "Move", "Attack", "Cast", "Hit", "Death" }) foreach (float time in new[] { .1f, .5f, .9f })
                    {
                        animator.Rebind(); animator.SetFloat("PlaybackSpeed", 1); animator.SetFloat("Speed", 0);
                        animator.Play(state, 0, time); animator.Update(0); CompareSkin(view, baked, report); report.sampledPoses++;
                    }
                }
                if (pawn.transform.position != rootPosition) throw new InvalidOperationException("Animation changed pawn root.");
                var camObj = new GameObject("CharacterSheetCamera"); SceneManager.MoveGameObjectToScene(camObj, scene);
                var camera = camObj.AddComponent<Camera>(); camera.scene = scene; camera.clearFlags = CameraClearFlags.SolidColor;
                camera.backgroundColor = new Color(.10f, .13f, .13f); camera.orthographic = true; camera.orthographicSize = 1.03f;
                camera.transform.position = new Vector3(2.3f, 1.85f, 4.8f); camera.transform.LookAt(new Vector3(0, 1.02f, 0));
                foreach (var tuple in new[] { new Vector3(35, -28, 0), new Vector3(30, 155, 0) })
                {
                    var obj = new GameObject("CharacterSheetLight"); SceneManager.MoveGameObjectToScene(obj, scene);
                    var light = obj.AddComponent<Light>(); light.type = LightType.Directional; light.intensity = tuple.y < 0 ? 1.2f : .65f; obj.transform.rotation = Quaternion.Euler(tuple);
                }
                const int width = 360, height = 460; sheet = new Texture2D(width * 5, height * 2, TextureFormat.RGB24, false);
                int index = 0;
                foreach (string sex in new[] { "male", "female" }) foreach (var race in catalog.Rules.races)
                {
                    var value = catalog.Rules.Randomize(42, race.id, sex); value.body = "body_" + sex + "_1"; value.head = "head_" + race.id + "_" + sex + "_1";
                    value.hair = race.id == "dragon" ? "none" : "hair_1"; value.skin = 0; value.hairColor = sex == "male" ? 0 : 1; value.clothColor = 0;
                    view.Apply(value); animator.Rebind(); animator.Play("Idle", 0, .2f); animator.Update(0);
                    var image = Capture(camera, view, width, height);
                    sheet.SetPixels(index % 5 * width, (1 - index / 5) * height, width, height, image.GetPixels());
                    UnityEngine.Object.DestroyImmediate(image); index++;
                }
                sheet.Apply(); Directory.CreateDirectory("Art/PawnCustomization/Previews");
                File.WriteAllBytes("Art/PawnCustomization/Previews/unity-races.png", sheet.EncodeToPNG());
                report.unchangedScene = SceneManager.GetActiveScene() == active && active.isDirty == dirty;
                if (!report.unchangedScene) throw new InvalidOperationException("Preview changed the active scene.");
                Directory.CreateDirectory("Art/PawnCustomization/Integration");
                File.WriteAllText("Art/PawnCustomization/Integration/unity-validation.json", JsonUtility.ToJson(report, true));
                Debug.Log(JsonUtility.ToJson(report));
            }
            finally { if (sheet != null) UnityEngine.Object.DestroyImmediate(sheet); UnityEngine.Object.DestroyImmediate(baked); EditorSceneManager.ClosePreviewScene(scene); }
        }

        private static void CompareSkin(PawnCustomizationView view, Mesh baked, Report report)
        {
            foreach (var renderer in view.Modules)
            {
                if (!renderer.enabled) continue;
                var mesh = renderer.sharedMesh; renderer.BakeMesh(baked); var vertices = mesh.vertices; var actual = baked.vertices; var weights = mesh.boneWeights; var binds = mesh.bindposes;
                var matrices = new Matrix4x4[view.Bones.Length];
                for (int b = 0; b < matrices.Length; b++) matrices[b] = renderer.transform.worldToLocalMatrix * view.Bones[b].localToWorldMatrix * binds[b];
                for (int i = 0; i < vertices.Length; i++)
                {
                    var w = weights[i]; var v = vertices[i];
                    var expected = matrices[w.boneIndex0].MultiplyPoint3x4(v) * w.weight0 + matrices[w.boneIndex1].MultiplyPoint3x4(v) * w.weight1 +
                        matrices[w.boneIndex2].MultiplyPoint3x4(v) * w.weight2 + matrices[w.boneIndex3].MultiplyPoint3x4(v) * w.weight3;
                    float error = Vector3.Distance(expected, actual[i]);
                    if (float.IsNaN(error) || float.IsInfinity(error) || error > .002f || actual[i].magnitude > 4) throw new InvalidOperationException("Invalid deformation: " + renderer.sharedMesh.name);
                    report.maxSkinError = Mathf.Max(report.maxSkinError, error);
                }
            }
        }
        internal static Texture2D Capture(Camera camera, PawnCustomizationView view, int width, int height)
        {
            var copies = new List<GameObject>(); var meshes = new List<Mesh>(); var disabled = new List<SkinnedMeshRenderer>();
            var rt = new RenderTexture(width, height, 24); var previous = RenderTexture.active;
            try
            {
                foreach (var skin in view.GetComponentsInChildren<SkinnedMeshRenderer>())
                {
                    if (!skin.enabled) continue;
                    var mesh = new Mesh(); skin.BakeMesh(mesh); meshes.Add(mesh);
                    var copy = new GameObject("BakedCharacter"); copy.transform.SetParent(skin.transform, false); copies.Add(copy);
                    copy.AddComponent<MeshFilter>().sharedMesh = mesh; var renderer = copy.AddComponent<MeshRenderer>(); renderer.sharedMaterials = skin.sharedMaterials;
                    var block = new MaterialPropertyBlock();
                    for (int i = 0; i < skin.sharedMaterials.Length; i++) { skin.GetPropertyBlock(block, i); renderer.SetPropertyBlock(block, i); }
                    skin.enabled = false; disabled.Add(skin);
                }
                camera.targetTexture = rt; ProjectY.Rendering.UrpCameraRendering.Render(camera); RenderTexture.active = rt;
                var result = new Texture2D(width, height, TextureFormat.RGB24, false); result.ReadPixels(new Rect(0, 0, width, height), 0, 0); result.Apply(); return result;
            }
            finally
            {
                foreach (var s in disabled) s.enabled = true; foreach (var o in copies) UnityEngine.Object.DestroyImmediate(o); foreach (var m in meshes) UnityEngine.Object.DestroyImmediate(m);
                camera.targetTexture = null; RenderTexture.active = previous; UnityEngine.Object.DestroyImmediate(rt);
            }
        }
    }
}
