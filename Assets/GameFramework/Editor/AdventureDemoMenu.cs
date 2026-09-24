using System;
using ProjectY.Samples;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.SceneManagement;

namespace ProjectY.Editor
{
    public static class AdventureDemoMenu
    {
        public const string ScenePath = "Assets/GameFramework/Samples/Adventure/AdventureDemo.unity";
        // MapArea 复用远征的真实大地图交互点与队伍，不创建另一份玩法会话。
        [MenuItem("Project Y/地图/打开 MapArea 地牢测试")]
        [MenuItem("Project Y/地图/打开城镇漫游测试")]
        [MenuItem("Project Y/地图/打开王城漫游测试")]
        public static void OpenArea() => Open();
        [MenuItem("Project Y/远征/打开战斗与事件 Demo")]
        public static void Open()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("请先退出 Play。");
            if (!EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) return;
            CreateMissingScene(); EditorSceneManager.OpenScene(ScenePath, OpenSceneMode.Single);
        }
        [MenuItem("Project Y/远征/同步地图资源引用")]
        public static void SyncAssets()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("请先退出 Play。");
            var scene = SceneManager.GetActiveScene();
            if (scene.path != ScenePath) throw new InvalidOperationException("请先打开远征 Demo。");
            AdventureRuntimeDemo target = null;
            foreach (var root in scene.GetRootGameObjects()) foreach (var demo in root.GetComponentsInChildren<AdventureRuntimeDemo>(true))
            {
                if (target != null) throw new InvalidOperationException("存在多个远征 Demo。");
                target = demo;
            }
            if (target == null) throw new InvalidOperationException("场景缺少远征 Demo。");
            var fields = new SerializedObject(target); MapRuntimePreviewMenu.BindAssets(fields); fields.ApplyModifiedPropertiesWithoutUndo();
            EditorSceneManager.MarkSceneDirty(scene);
            if (!EditorSceneManager.SaveScene(scene)) throw new InvalidOperationException("保存远征场景失败。");
        }
        public static void CreateMissingScene()
        {
            if (AssetDatabase.LoadAssetAtPath<SceneAsset>(ScenePath) != null) return;
            var previous = SceneManager.GetActiveScene();
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Additive);
            SceneManager.SetActiveScene(scene);
            try
            {
                var bootstrap = new GameObject("GameBootstrap").AddComponent<GameBootstrap>();
                var hostFields = new SerializedObject(bootstrap); hostFields.FindProperty("openDemo").boolValue = false; hostFields.ApplyModifiedPropertiesWithoutUndo();
                var cameraObject = new GameObject("AdventureCamera", typeof(Camera), typeof(AudioListener));
                var camera = cameraObject.GetComponent<Camera>(); camera.tag = "MainCamera";
                camera.orthographic = true; camera.clearFlags = CameraClearFlags.SolidColor;
                camera.backgroundColor = new Color(.13f, .20f, .22f); camera.nearClipPlane = .1f; camera.farClipPlane = 2000;
                var light = new GameObject("AdventureSun").AddComponent<Light>(); light.type = LightType.Directional;
                light.intensity = 1.1f; light.color = new Color(1, .96f, .88f); light.transform.rotation = Quaternion.Euler(48, -35, 0);
                RenderSettings.ambientMode = AmbientMode.Trilight;
                RenderSettings.ambientSkyColor = new Color(.65f, .7f, .76f); RenderSettings.ambientEquatorColor = new Color(.52f, .55f, .5f);
                RenderSettings.ambientGroundColor = new Color(.33f, .30f, .25f); RenderSettings.reflectionIntensity = 0;
                var demo = new GameObject("AdventureDemo").AddComponent<AdventureRuntimeDemo>();
                var fields = new SerializedObject(demo);
                fields.FindProperty("bootstrap").objectReferenceValue = bootstrap;
                fields.FindProperty("mapCamera").objectReferenceValue = camera;
                fields.FindProperty("environmentSun").objectReferenceValue = light;
                var shader = AssetDatabase.LoadAssetAtPath<Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
                if (shader == null) throw new InvalidOperationException("地图预览 Shader 缺失。");
                fields.FindProperty("previewShader").objectReferenceValue = shader;
                PawnAssetMenu.BuildPrefabs(); PawnAssetMenu.Bind(fields);
                MapRuntimePreviewMenu.BindAssets(fields); fields.ApplyModifiedPropertiesWithoutUndo();
                if (!EditorSceneManager.SaveScene(scene, ScenePath)) throw new InvalidOperationException("远征 Demo 保存失败。");
            }
            finally { SceneManager.SetActiveScene(previous); EditorSceneManager.CloseScene(scene, true); }
        }
    }
}
