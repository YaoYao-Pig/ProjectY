using System;
using System.Collections.Generic;
using System.IO;
using ProjectY.Rendering;
using ProjectY.Samples;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering.Universal;

namespace ProjectY.Editor
{
    /// <summary>Isolated, manually advanced preview of the source visual-effect catalog.</summary>
    public sealed class BlockEffectPreviewWindow : EditorWindow
    {
        private const string SourcePath = "Config/Tables/Adventure/VisualEffectTable.json";
        private static readonly Vector3 Origin = new Vector3(-1f, 0f, 0f);
        private static readonly Vector3 Target = new Vector3(1f, 0f, 0f);

        [Serializable] private sealed class RawTable { public RawProfile[] rows; }
        [Serializable] private sealed class RawProfile
        {
            public int id, count;
            public string name, pattern, color, accent;
            public float lifetime, size, radius, height, emission, speed, gravity;
        }

        [SerializeField] private int selectedId;
        [SerializeField] private bool loop = true;
        [SerializeField] private float zoom = 1f;
        private BlockEffectProfile[] profiles = Array.Empty<BlockEffectProfile>();
        private string[] labels = Array.Empty<string>();
        private int selectedIndex;
        private PreviewRenderUtility preview;
        private GameObject previewRoot;
        private BlockParticleEffects particles;
        private readonly UniversalRenderPipeline.SingleCameraRequest renderRequest = new UniversalRenderPipeline.SingleCameraRequest();
        private double lastUpdate;
        private float elapsed;
        private bool paused;
        private string error;

        [MenuItem("Project Y/特效/方块特效预览")]
        public static void Open()
        {
            var window = GetWindow<BlockEffectPreviewWindow>();
            window.titleContent = new GUIContent("方块特效预览");
            window.minSize = new Vector2(520f, 460f);
            window.Show();
        }

        private void OnEnable()
        {
            lastUpdate = EditorApplication.timeSinceStartup;
            EditorApplication.update += UpdatePreview;
            LoadProfiles();
        }

        private void OnDisable()
        {
            EditorApplication.update -= UpdatePreview;
            DisposePreview();
        }

        private void LoadProfiles()
        {
            error = null;
            try
            {
                var table = JsonUtility.FromJson<RawTable>(File.ReadAllText(FullSourcePath()));
                if (table == null || table.rows == null || table.rows.Length == 0)
                    throw new InvalidDataException("VisualEffectTable.rows 不能为空。");
                var loaded = new BlockEffectProfile[table.rows.Length];
                var loadedLabels = new string[loaded.Length];
                var ids = new HashSet<int>();
                int selection = 0;
                for (int i = 0; i < loaded.Length; i++)
                {
                    var row = table.rows[i];
                    if (row == null || row.id <= 0 || !ids.Add(row.id) || string.IsNullOrEmpty(row.name))
                        throw new InvalidDataException("VisualEffectTable 中存在无效或重复的效果 ID。");
                    if (!ColorUtility.TryParseHtmlString(row.color, out Color color)
                        || !ColorUtility.TryParseHtmlString(row.accent, out Color accent))
                        throw new InvalidDataException("效果 " + row.id + " 的主色或点缀色无效。");
                    loaded[i] = new BlockEffectProfile
                    {
                        Id = row.id, Name = row.name, Pattern = row.pattern, Count = row.count,
                        Color = color, Accent = accent, Lifetime = row.lifetime, Size = row.size,
                        Radius = row.radius, Height = row.height, Emission = row.emission,
                        Speed = row.speed, Gravity = row.gravity
                    };
                    loadedLabels[i] = row.id + " · " + row.name;
                    if (row.id == selectedId) selection = i;
                }
                profiles = loaded;
                labels = loadedLabels;
                selectedIndex = selection;
                selectedId = profiles[selectedIndex].Id;
                EnsurePreview();
                Replay();
            }
            catch (Exception exception)
            {
                error = exception.Message;
                DisposePreview();
                Debug.LogException(exception);
            }
            Repaint();
        }

        private static string FullSourcePath()
        {
            return Path.GetFullPath(Path.Combine(Application.dataPath, "..", SourcePath));
        }

        private void EnsurePreview()
        {
            if (preview != null) return;
            preview = new PreviewRenderUtility();
            preview.camera.enabled = false;
            preview.camera.clearFlags = CameraClearFlags.SolidColor;
            preview.camera.backgroundColor = new Color(.045f, .055f, .075f, 1f);
            preview.camera.allowHDR = true;
            preview.camera.orthographic = true;
            preview.camera.nearClipPlane = .05f;
            preview.camera.farClipPlane = 80f;
            UrpCameraRendering.ConfigurePreview(preview.camera);
            previewRoot = new GameObject("Block effect isolated preview") { hideFlags = HideFlags.HideAndDontSave };
            preview.AddSingleGO(previewRoot);
            particles = new BlockParticleEffects(previewRoot.transform);
        }

        private void Replay()
        {
            particles.Clear();
            particles.Play(profiles[selectedIndex], Origin, Target, 20261023);
            elapsed = 0f;
            lastUpdate = EditorApplication.timeSinceStartup;
            Repaint();
        }

        private void UpdatePreview()
        {
            double now = EditorApplication.timeSinceStartup;
            float delta = Mathf.Clamp((float)(now - lastUpdate), 0f, .1f);
            lastUpdate = now;
            if (particles == null || paused || error != null) return;
            bool wasBusy = particles.Busy;
            particles.Tick(delta);
            elapsed += delta;
            if (loop && !particles.Busy && elapsed >= profiles[selectedIndex].Lifetime + .35f) Replay();
            else if (wasBusy) Repaint();
        }

        private void OnGUI()
        {
            using (new EditorGUILayout.HorizontalScope(EditorStyles.toolbar))
            {
                if (GUILayout.Button("重读配置", EditorStyles.toolbarButton, GUILayout.Width(76f))) LoadProfiles();
                if (GUILayout.Button("打开源配置", EditorStyles.toolbarButton, GUILayout.Width(88f)))
                    EditorUtility.OpenWithDefaultApp(FullSourcePath());
                GUILayout.FlexibleSpace();
                GUILayout.Label(profiles.Length + " 个效果", EditorStyles.miniLabel);
            }
            if (error != null)
            {
                EditorGUILayout.HelpBox(error, MessageType.Error);
                return;
            }
            if (profiles.Length == 0 || particles == null) return;

            EditorGUI.BeginChangeCheck();
            int next = EditorGUILayout.Popup("效果", selectedIndex, labels);
            if (EditorGUI.EndChangeCheck())
            {
                selectedIndex = next;
                selectedId = profiles[next].Id;
                Replay();
            }
            var profile = profiles[selectedIndex];
            EditorGUILayout.LabelField(profile.Name + "  (" + profile.Id + ")", EditorStyles.boldLabel);
            EditorGUILayout.LabelField($"构图 {profile.Pattern}    粒子 {profile.Count}    生命 {profile.Lifetime:0.##} 秒    HDR 发光 {profile.Emission:0.##}", EditorStyles.wordWrappedMiniLabel);
            EditorGUILayout.LabelField($"边长 {profile.Size:0.###}m    半径 {profile.Radius:0.##}m    高度 {profile.Height:0.##}m    速度 {profile.Speed:0.##}m/s    重力 {profile.Gravity:0.##}m/s²", EditorStyles.wordWrappedMiniLabel);
            using (new EditorGUI.DisabledScope(true))
            using (new EditorGUILayout.HorizontalScope())
            {
                EditorGUILayout.ColorField("主色", profile.Color);
                EditorGUILayout.ColorField("点缀", profile.Accent);
            }
            EditorGUILayout.HelpBox("独立预览使用 HDR 方块材质，专用预览渲染器不启用 Bloom。实际世界中的 Bloom 遵循当前渲染风格配置。", MessageType.Info);
            using (new EditorGUILayout.HorizontalScope())
            {
                if (GUILayout.Button("重播", GUILayout.Width(64f))) Replay();
                if (GUILayout.Button(paused ? "继续" : "暂停", GUILayout.Width(64f))) paused = !paused;
                loop = GUILayout.Toggle(loop, "循环", GUILayout.Width(60f));
                GUILayout.FlexibleSpace();
                GUILayout.Label($"{elapsed:0.00}s · {particles.ActiveParticleCount} 粒子", EditorStyles.miniLabel);
            }
            zoom = EditorGUILayout.Slider("视野缩放", zoom, .5f, 2.5f);
            Rect bounds = GUILayoutUtility.GetRect(160f, 10000f, 180f, 10000f, GUILayout.ExpandWidth(true), GUILayout.ExpandHeight(true));
            if (Event.current.type == EventType.Repaint) RenderPreview(bounds, profile);
            GUILayout.Label("施放点 (-1, 0, 0) → 落点 (1, 0, 0) · 切换效果自动清空并重播", EditorStyles.centeredGreyMiniLabel);
        }

        private void RenderPreview(Rect bounds, BlockEffectProfile profile)
        {
            var camera = preview.camera;
            Vector3 focus = new Vector3(.4f, profile.Height * .35f, 0f);
            camera.transform.position = focus + new Vector3(5f, 6f, -8f);
            camera.transform.LookAt(focus);
            camera.aspect = bounds.width / Mathf.Max(1f, bounds.height);
            float extent = Mathf.Max(2f, profile.Radius + profile.Speed * profile.Lifetime * .65f, profile.Height * .8f);
            camera.orthographicSize = extent * zoom / Mathf.Min(1f, camera.aspect);
            var previousTarget = camera.targetTexture;
            Texture texture = null;
            preview.BeginPreview(bounds, GUIStyle.none);
            try
            {
                UrpCameraRendering.Render(camera, renderRequest);
            }
            catch (Exception exception)
            {
                error = exception.Message;
                Debug.LogException(exception);
            }
            finally
            {
                texture = preview.EndPreview();
                camera.targetTexture = previousTarget;
            }
            if (texture != null) GUI.DrawTexture(bounds, texture, ScaleMode.StretchToFill, false);
        }

        private void DisposePreview()
        {
            particles?.Dispose();
            particles = null;
            if (previewRoot != null) DestroyImmediate(previewRoot);
            previewRoot = null;
            preview?.Cleanup();
            preview = null;
        }
    }
}
