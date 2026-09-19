using System;
using System.Linq;
using ProjectY.UI;
using UnityEditor;
using UnityEngine;

namespace ProjectY.Editor
{
    public sealed class PanelGenerator : EditorWindow
    {
        private PanelConfig config;
        private PanelDefinition draft = new PanelDefinition();
        private string originalName;
        private string search = "";
        private Vector2 listScroll, editScroll;
        private string status;
        private bool failed;
        private static readonly string[] Layers = { "Background", "Main", "Popup", "Overlay" };

        [MenuItem("Project Y/UI/Panel Generator")]
        public static void Open()
        {
            var window = GetWindow<PanelGenerator>(true, "Panel Generator", true);
            window.minSize = new Vector2(760, 590);
            window.Show();
        }
        private void OnEnable() => config = PanelAssets.LoadOrCreate();
        private void Select(PanelDefinition entry)
        {
            draft = JsonUtility.FromJson<PanelDefinition>(JsonUtility.ToJson(entry));
            originalName = entry.Name; status = null;
            GUI.FocusControl(null);
        }
        private void Perform(Action action)
        {
            try { action(); failed = false; }
            catch (Exception error) { failed = true; status = error.Message; Debug.LogException(error); }
        }

        private void OnGUI()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode)
            {
                EditorGUILayout.HelpBox("退出 Play Mode 后可编辑配置和生成资产。", MessageType.Info);
                return;
            }
            if (config == null) { OnEnable(); return; }
            using (new EditorGUILayout.HorizontalScope(EditorStyles.toolbar))
            {
                GUILayout.Label("UI 配置与生成", EditorStyles.boldLabel);
                GUILayout.FlexibleSpace();
                if (GUILayout.Button("定位 PanelConfig", EditorStyles.toolbarButton)) EditorGUIUtility.PingObject(config);
                if (GUILayout.Button("导出全部提示", EditorStyles.toolbarButton)) Perform(() => { PanelAssets.ExportAllHints(); status = "已更新全部 View 提示。"; });
            }
            using (new EditorGUILayout.HorizontalScope())
            {
                using (new EditorGUILayout.VerticalScope(GUILayout.Width(230)))
                {
                    search = EditorGUILayout.TextField(search, EditorStyles.toolbarSearchField);
                    listScroll = EditorGUILayout.BeginScrollView(listScroll);
                    foreach (var entry in config.Entries.OrderBy(x => x.Module).ThenBy(x => x.Name))
                    {
                        if ((entry.Module + "/" + entry.Name + " " + entry.Kind).IndexOf(search, StringComparison.OrdinalIgnoreCase) < 0) continue;
                        var label = entry.Module + "/" + entry.Name + "  [" + entry.Kind + "]";
                        if (GUILayout.Toggle(originalName == entry.Name, label, "Button") && originalName != entry.Name) Select(entry);
                    }
                    EditorGUILayout.EndScrollView();
                    if (GUILayout.Button("+ 新建配置")) { originalName = null; draft = new PanelDefinition(); status = null; GUI.FocusControl(null); }
                }
                using (new EditorGUILayout.VerticalScope())
                {
                    editScroll = EditorGUILayout.BeginScrollView(editScroll);
                    using (new EditorGUI.DisabledScope(originalName != null))
                    {
                        draft.Name = EditorGUILayout.TextField("配置名", draft.Name);
                        draft.Kind = (UIKind)EditorGUILayout.EnumPopup("类型", draft.Kind);
                    }
                    draft.Module = EditorGUILayout.TextField("模块目录", draft.Module);
                    EditorGUILayout.Space();
                    using (new EditorGUI.DisabledScope(draft.IsWidget))
                    {
                        draft.Layer = Layers[EditorGUILayout.Popup("层级", Math.Max(0, Array.IndexOf(Layers, draft.Layer)), Layers)];
                        draft.Modal = EditorGUILayout.Toggle("模态遮挡", draft.Modal);
                        draft.Cache = EditorGUILayout.Toggle("关闭后缓存", draft.Cache);
                        draft.CloseOnBack = EditorGUILayout.Toggle("允许返回关闭", draft.CloseOnBack);
                        EditorGUILayout.Space();
                        draft.IsWorldUI = EditorGUILayout.Toggle("是否为 World UI", draft.IsWorldUI);
                        draft.SupportsHotSwitch = EditorGUILayout.Toggle("是否支持热切（预留）", draft.SupportsHotSwitch);
                        draft.PauseWorldOnOpen = EditorGUILayout.Toggle("打开时暂停世界", draft.PauseWorldOnOpen);
                        draft.CloseOnSceneChange = EditorGUILayout.Toggle("切换场景时关闭", draft.CloseOnSceneChange);
                    }
                    EditorGUILayout.Space();
                    EditorGUILayout.HelpBox(draft.IsWidget ? "Widget 随父 Ctrl 管理。窗口策略仅对 Panel 生效。" : "热切当前只保存标记。世界暂停使用 Time.timeScale；UI 仍可接收 unscaledDt。", MessageType.Info);
                    EditorGUILayout.LabelField("Prefab", EditorStyles.boldLabel);
                    EditorGUILayout.SelectableLabel(draft.PrefabPath, EditorStyles.wordWrappedLabel, GUILayout.Height(42));
                    EditorGUILayout.LabelField("Lua 控制器", EditorStyles.boldLabel);
                    EditorGUILayout.SelectableLabel("Lua/" + draft.ControllerModule.Replace('.', '/') + ".lua", GUILayout.Height(22));
                    EditorGUILayout.HelpBox("生成会补齐基础组件并导出 EmmyLua 提示，保留已有控制器和绑定。修改模块时自动移动 Prefab 并保留 GUID。", MessageType.None);
                    if (status != null) EditorGUILayout.HelpBox(status, failed ? MessageType.Error : MessageType.Info);
                    EditorGUILayout.EndScrollView();
                    using (new EditorGUILayout.HorizontalScope())
                    {
                        if (GUILayout.Button("保存配置", GUILayout.Height(32))) Perform(() => { Select(PanelAssets.Save(draft, originalName)); status = "配置已保存；新配置请继续生成。"; });
                        if (GUILayout.Button("保存并生成 / 更新", GUILayout.Height(32))) Perform(() =>
                        {
                            var entry = PanelAssets.Save(draft, originalName); originalName = entry.Name;
                            PanelAssets.Generate(entry); Select(entry); status = "Prefab、控制器和 View 提示已就绪。";
                            EditorGUIUtility.PingObject(entry.Prefab);
                        });
                    }
                    using (new EditorGUI.DisabledScope(draft.Prefab == null))
                    {
                        if (GUILayout.Button("打开 Prefab")) AssetDatabase.OpenAsset(draft.Prefab);
                    }
                }
            }
        }
    }

    [CustomEditor(typeof(PanelConfig))]
    public sealed class PanelConfigEditor : UnityEditor.Editor
    {
        public override void OnInspectorGUI()
        {
            EditorGUILayout.HelpBox("PanelConfig 是运行时 UI 注册入口。使用生成器编辑配置和管理资产路径。", MessageType.Info);
            if (GUILayout.Button("打开 Panel Generator")) PanelGenerator.Open();
            using (new EditorGUI.DisabledScope(true)) DrawDefaultInspector();
        }
    }
}
