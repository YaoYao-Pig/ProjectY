using System;
using System.Diagnostics;
using System.Globalization;
using System.Collections.Generic;
using UnityEngine;
using Debug = UnityEngine.Debug;

namespace ProjectY.Samples
{
    // 独立的运行时地图观察器；引用在测试场景中绑定，不搜索场景中的对象。
    public sealed class MapRuntimeDemo : MonoBehaviour
    {
        [SerializeField] private GameBootstrap bootstrap;
        [SerializeField] private Camera mapCamera;
        [SerializeField] private Shader previewShader;
        [Serializable]
        public sealed class AssetBinding { public int id; public string path; public GameObject prefab; }
        // Editor 根据资源表绑定真实引用；运行时不搜索场景或依赖 AssetDatabase。
        [SerializeField] private AssetBinding[] assetBindings;
        private readonly Dictionary<int, AssetBinding> assets = new Dictionary<int, AssetBinding>();
        [SerializeField] private string seedText = "20260921";
        [SerializeField] private string recipeText = "1,2,3,4,5,6,1,4,5,6";
        private MapPreviewData map;
        private MapPreviewRenderer mapRenderer;
        private Vector3 focus;
        private float yaw = -25, pitch = 52, zoom = 35;
        private bool showWater = true, showBuildings = true, showRoads = true, showDecorations = true;
        private string error, timing;
        private Vector2 townScroll;
        private Font font;
        private GUIStyle labelStyle, titleStyle, buttonStyle, fieldStyle, toggleStyle, errorStyle;
        private const float PanelWidth = 294;

        public int CellCount => map == null ? 0 : map.Cells.Length;
        public int BuildingCount => map == null ? 0 : map.Buildings.Length;
        public string LastError => error;

        private void Start()
        {
            if (bootstrap == null || mapCamera == null) throw new InvalidOperationException("地图测试场景未绑定运行时或相机。");
            if (assetBindings == null || assetBindings.Length == 0) throw new InvalidOperationException("请用地图菜单同步配置资源引用。");
            foreach (var binding in assetBindings) assets.Add(binding.id, binding);
            font = Font.CreateDynamicFontFromOSFont(new[] { "Microsoft YaHei", "Noto Sans CJK SC", "Arial" }, 16);
            mapRenderer = new MapPreviewRenderer(previewShader, transform);
            Generate();
        }

        public void Generate()
        {
            try
            {
                if (!uint.TryParse(seedText, NumberStyles.None, CultureInfo.InvariantCulture, out var seed))
                    throw new ArgumentException("种子必须为 0～4294967295 的整数。");
                // 外部文本先校验，实际配方合法性仍交给工程生成器。
                var parts = recipeText.Split(',');
                foreach (var part in parts)
                    if (!int.TryParse(part.Trim(), out var id) || id <= 0) throw new ArgumentException("Region 配方请填写逗号分隔的正整数 ID。");
                var watch = Stopwatch.StartNew();
                var next = MapPreviewData.Generate(bootstrap, seed, recipeText);
                var generatedMs = watch.ElapsedMilliseconds;
                Build(next);
                map = next;
                timing = "生成与读取 " + generatedMs + " ms · 渲染准备 " + (watch.ElapsedMilliseconds - generatedMs) + " ms";
                error = null; FitMap();
                Debug.Log("地图运行测试：seed=" + map.Seed + "，格子=" + map.Cells.Length + "，城镇=" + map.Towns.Length + "，建筑=" + map.Buildings.Length + "，" + timing, this);
            }
            catch (Exception exception)
            {
                error = exception.Message;
                Debug.LogException(exception, this);
            }
        }

        private void Build(MapPreviewData next)
        {
            mapRenderer.Build(next, asset => {
                if (!assets.TryGetValue(asset.Id, out var binding) || binding.path != asset.Path || binding.prefab == null)
                    throw new InvalidOperationException("资源表与场景绑定不一致，请先导表并执行同步配置资源引用：" + asset.Id);
                return binding.prefab;
            });
        }

        public void FitMap()
        {
            if (map == null) return;
            var bounds = mapRenderer.Bounds;
            focus = bounds.center;
            var inverse = Quaternion.Inverse(Quaternion.Euler(pitch, yaw, 0));
            var extent = Vector2.zero;
            for (var x = -1; x <= 1; x += 2)
                for (var y = -1; y <= 1; y += 2)
                    for (var z = -1; z <= 1; z += 2)
                    {
                        var corner = inverse * Vector3.Scale(bounds.extents, new Vector3(x, y, z));
                        extent.x = Mathf.Max(extent.x, Mathf.Abs(corner.x)); extent.y = Mathf.Max(extent.y, Mathf.Abs(corner.y));
                    }
            var aspect = Mathf.Max(.2f, (Screen.width - PanelWidth) / Mathf.Max(1f, Screen.height));
            zoom = Mathf.Max(5, Mathf.Max(extent.y, extent.x / aspect) * 1.12f);
        }

        private void Update()
        {
            if (map == null) return;
            if (Input.GetKeyDown(KeyCode.F)) FitMap();
            if (Input.GetKeyDown(KeyCode.R)) Generate();
            if (Input.mousePosition.x <= PanelWidth) return;
            zoom = Mathf.Clamp(zoom * Mathf.Exp(-Input.mouseScrollDelta.y * .12f), 3f, 2000f);
            if (Input.GetMouseButton(1))
            {
                yaw += Input.GetAxis("Mouse X") * 3;
                pitch = Mathf.Clamp(pitch - Input.GetAxis("Mouse Y") * 2, 20, 85);
            }
            var rotation = Quaternion.Euler(0, yaw, 0);
            var step = new Vector3(Input.GetAxisRaw("Horizontal"), 0, Input.GetAxisRaw("Vertical")) * (zoom * Time.unscaledDeltaTime);
            if (Input.GetMouseButton(2)) step += new Vector3(-Input.GetAxis("Mouse X"), 0, -Input.GetAxis("Mouse Y")) * zoom * .035f;
            focus += rotation * step;
            if (Input.GetKey(KeyCode.Q)) yaw -= 55 * Time.unscaledDeltaTime;
            if (Input.GetKey(KeyCode.E)) yaw += 55 * Time.unscaledDeltaTime;
        }

        private void LateUpdate()
        {
            if (map == null) return;
            var panelFraction = Mathf.Min(.7f, PanelWidth / Mathf.Max(1f, Screen.width));
            mapCamera.rect = new Rect(panelFraction, 0, 1 - panelFraction, 1);
            var rotation = Quaternion.Euler(pitch, yaw, 0);
            var distance = mapRenderer.Bounds.size.magnitude + zoom + 40;
            mapCamera.transform.SetPositionAndRotation(focus - rotation * Vector3.forward * distance, rotation);
            mapCamera.orthographicSize = zoom;
            mapCamera.farClipPlane = distance * 2 + 100;
            mapRenderer.Draw(mapCamera, showWater, showBuildings, showRoads, showDecorations);
        }

        private void EnsureStyles()
        {
            if (labelStyle != null) return;
            labelStyle = new GUIStyle(GUI.skin.label) { font = font, fontSize = 14, wordWrap = true };
            titleStyle = new GUIStyle(labelStyle) { fontSize = 21, fontStyle = FontStyle.Bold };
            buttonStyle = new GUIStyle(GUI.skin.button) { font = font, fontSize = 14, fixedHeight = 29 };
            fieldStyle = new GUIStyle(GUI.skin.textField) { font = font, fontSize = 15, fixedHeight = 27 };
            toggleStyle = new GUIStyle(GUI.skin.toggle) { font = font, fontSize = 14, fixedHeight = 24 };
            errorStyle = new GUIStyle(labelStyle); errorStyle.normal.textColor = new Color(1, .55f, .4f);
        }

        private void OnGUI()
        {
            if (mapRenderer == null) return;
            EnsureStyles();
            var saved = GUI.color;
            GUI.color = new Color(.07f, .095f, .09f, .98f);
            GUI.DrawTexture(new Rect(0, 0, PanelWidth, Screen.height), Texture2D.whiteTexture);
            GUI.color = saved;
            GUILayout.BeginArea(new Rect(14, 14, PanelWidth - 28, Screen.height - 28));
            GUILayout.Label("大地图 · 运行测试", titleStyle);
            GUILayout.Label("工程 Lua 生成器 / 已导出的工程配表", labelStyle);
            GUILayout.Space(12);
            GUILayout.Label("种子", labelStyle); seedText = GUILayout.TextField(seedText, fieldStyle);
            GUILayout.Label("Region 配方（配置 ID）", labelStyle); recipeText = GUILayout.TextField(recipeText, fieldStyle);
            GUILayout.BeginHorizontal();
            if (GUILayout.Button("生成地图", buttonStyle)) Generate();
            if (GUILayout.Button("下一个种子", buttonStyle))
            {
                if (uint.TryParse(seedText, out var seed)) seedText = unchecked(seed + 1).ToString(CultureInfo.InvariantCulture);
                Generate();
            }
            GUILayout.EndHorizontal();
            GUILayout.Space(8);
            showWater = GUILayout.Toggle(showWater, "显示水面", toggleStyle);
            showBuildings = GUILayout.Toggle(showBuildings, "显示建筑", toggleStyle);
            showRoads = GUILayout.Toggle(showRoads, "显示道路", toggleStyle);
            showDecorations = GUILayout.Toggle(showDecorations, "显示森林与地貌装饰", toggleStyle);
            if (GUILayout.Button("适应整张地图  [F]", buttonStyle)) FitMap();
            GUILayout.Label("滚轮缩放 · 中键拖动 / WASD 平移\n右键拖动旋转 · Q/E 转向 · R 重新生成", labelStyle);
            GUILayout.Space(8);
            if (map != null)
            {
                GUILayout.Label(map.Cells.Length + " 格 · " + map.RegionCount + " 区域 · 算法 v" + map.GenerationVersion + "\n" +
                    map.Towns.Length + " 城镇 · " + map.Buildings.Length + " 建筑 · " + map.Roads.Length + " 道路/街道", labelStyle);
                GUILayout.Label(timing, labelStyle);
                GUILayout.Label(map.RiverCount + " 段主河/支流 · " + map.Waterfalls.Length + " 处瀑布 · " + map.Decorations.Length + " 个地貌装饰", labelStyle);
                for (var i = 0; i < map.Waterfalls.Length; i++)
                    if (GUILayout.Button("瀑布 " + (i + 1) + " · 落差 " + map.Waterfalls[i].Drop.ToString("F2"), buttonStyle))
                    { focus = map.Cells[map.Waterfalls[i].To].Position; zoom = 8 * map.Radius; }
                GUILayout.Space(6); GUILayout.Label("定位城镇", labelStyle);
                townScroll = GUILayout.BeginScrollView(townScroll);
                for (var i = 0; i < map.Towns.Length; i++)
                    if (GUILayout.Button((i + 1) + " · " + map.Towns[i].Name, buttonStyle))
                    { focus = map.Cells[map.Towns[i].Center].Position; zoom = 13 * map.Radius; }
                GUILayout.EndScrollView();
            }
            if (!string.IsNullOrEmpty(error)) GUILayout.Label(error, errorStyle);
            GUILayout.EndArea();
        }

        private void OnDestroy()
        {
            mapRenderer?.Dispose(); mapRenderer = null;
            if (font != null) Destroy(font);
        }
    }
}
