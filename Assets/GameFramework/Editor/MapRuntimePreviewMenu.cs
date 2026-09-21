using System;
using System.IO;
using System.Collections.Generic;
using ProjectY.Samples;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.SceneManagement;

namespace ProjectY.Editor
{
    // 创建持久测试场景并序列化真实引用；以后可直接打开场景并按 Play。
    public static class MapRuntimePreviewMenu
    {
        public const string ScenePath = "Assets/GameFramework/Samples/Map/MapRuntimePreview.unity";
        [Serializable] private sealed class AssetRow { public int id = 0; public string prefabPath = null; }
        [Serializable] private sealed class AssetTable { public AssetRow[] rows = null; }

        [MenuItem("Project Y/地图/打开运行测试场景")]
        public static void Open()
        {
            OpenInternal();
        }

        private static bool OpenInternal()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("请先退出 Play 再切换测试场景。");
            if (!EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) return false;
            CreateMissingScene();
            EditorSceneManager.OpenScene(ScenePath, OpenSceneMode.Single);
            SyncAssets();
            return true;
        }

        [MenuItem("Project Y/地图/运行地图测试")]
        public static void Run()
        {
            if (OpenInternal()) EditorApplication.isPlaying = true;
        }

        private static void BindAssets(SerializedObject fields)
        {
            var path = Path.Combine(Directory.GetParent(Application.dataPath).FullName, "Config/Tables/Map/MapAssetTable.json");
            var table = JsonUtility.FromJson<AssetTable>(File.ReadAllText(path));
            if (table == null || table.rows == null || table.rows.Length == 0) throw new InvalidOperationException("地图资源表为空。");
            var bindings = fields.FindProperty("assetBindings");
            bindings.arraySize = table.rows.Length;
            var ids = new HashSet<int>();
            for (var i = 0; i < table.rows.Length; i++)
            {
                var row = table.rows[i];
                if (!ids.Add(row.id)) throw new InvalidOperationException("重复的地图资源 ID: " + row.id);
                var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(row.prefabPath);
                if (prefab == null) throw new InvalidOperationException("缺少配置模型: " + row.prefabPath);
                var binding = bindings.GetArrayElementAtIndex(i);
                binding.FindPropertyRelative("id").intValue = row.id;
                binding.FindPropertyRelative("path").stringValue = row.prefabPath;
                binding.FindPropertyRelative("prefab").objectReferenceValue = prefab;
            }
        }

        [MenuItem("Project Y/地图/同步配置资源引用")]
        public static void SyncAssets()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("请退出 Play 后同步场景绑定。");
            var scene = SceneManager.GetActiveScene();
            if (scene.path != ScenePath) throw new InvalidOperationException("请先打开地图运行测试场景。");
            // 只在指定测试场景的 Editor 工具中查找目标组件；不侵入运行时业务绑定。
            MapRuntimeDemo demo = null;
            foreach (var root in scene.GetRootGameObjects())
                foreach (var item in root.GetComponentsInChildren<MapRuntimeDemo>(true))
                {
                    if (demo != null) throw new InvalidOperationException("测试场景存在多个地图观察器。");
                    demo = item;
                }
            if (demo == null) throw new InvalidOperationException("测试场景缺少地图观察器。");
            var fields = new SerializedObject(demo);
            BindAssets(fields); fields.ApplyModifiedPropertiesWithoutUndo();
            EditorSceneManager.MarkSceneDirty(scene);
            if (!EditorSceneManager.SaveScene(scene)) throw new InvalidOperationException("地图场景保存失败。");
        }

        public static void CreateMissingScene()
        {
            if (AssetDatabase.LoadAssetAtPath<SceneAsset>(ScenePath) != null) return;
            var shader = AssetDatabase.LoadAssetAtPath<Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
            if (shader == null) throw new InvalidOperationException("地图预览 Shader 尚未导入。");
            var previous = SceneManager.GetActiveScene();
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Additive);
            SceneManager.SetActiveScene(scene);
            try
            {
                var bootstrap = new GameObject("GameBootstrap").AddComponent<GameBootstrap>();
                var bootstrapFields = new SerializedObject(bootstrap);
                bootstrapFields.FindProperty("openDemo").boolValue = false;
                bootstrapFields.ApplyModifiedPropertiesWithoutUndo();
                var camera = new GameObject("MapRuntimeCamera", typeof(Camera), typeof(AudioListener)).GetComponent<Camera>();
                camera.tag = "MainCamera"; camera.orthographic = true; camera.orthographicSize = 40;
                camera.clearFlags = CameraClearFlags.SolidColor; camera.backgroundColor = new Color(.18f, .23f, .25f);
                camera.nearClipPlane = .1f; camera.farClipPlane = 2000;
                var light = new GameObject("MapRuntimeSun").AddComponent<Light>();
                light.type = LightType.Directional; light.intensity = 1.1f;
                light.color = new Color(1, .96f, .88f); light.shadows = LightShadows.Soft;
                light.transform.rotation = Quaternion.Euler(48, -35, 0);
                RenderSettings.ambientMode = AmbientMode.Trilight;
                RenderSettings.ambientSkyColor = new Color(.65f, .7f, .76f);
                RenderSettings.ambientEquatorColor = new Color(.52f, .55f, .5f);
                RenderSettings.ambientGroundColor = new Color(.33f, .30f, .25f);
                RenderSettings.reflectionIntensity = 0;
                var demo = new GameObject("MapRuntimeDemo").AddComponent<MapRuntimeDemo>();
                var fields = new SerializedObject(demo);
                fields.FindProperty("bootstrap").objectReferenceValue = bootstrap;
                fields.FindProperty("mapCamera").objectReferenceValue = camera;
                fields.FindProperty("previewShader").objectReferenceValue = shader;
                BindAssets(fields);
                fields.ApplyModifiedPropertiesWithoutUndo();
                if (!EditorSceneManager.SaveScene(scene, ScenePath)) throw new InvalidOperationException("地图测试场景保存失败。");
            }
            finally
            {
                SceneManager.SetActiveScene(previous);
                EditorSceneManager.CloseScene(scene, true);
            }
        }
    }
}
