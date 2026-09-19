using ProjectY.UI;
using UnityEditor;
using UnityEngine;
using System.Linq;

namespace ProjectY.Editor
{
    [CustomPropertyDrawer(typeof(LuaReference.Entry))]
    public sealed class LuaReferenceEntryDrawer : PropertyDrawer
    {
        public override float GetPropertyHeight(SerializedProperty property, GUIContent label) => EditorGUIUtility.singleLineHeight * 2 + 6;
        public override void OnGUI(Rect position, SerializedProperty property, GUIContent label)
        {
            EditorGUI.BeginProperty(position, label, property);
            var key = property.FindPropertyRelative("Key");
            var target = property.FindPropertyRelative("Target");
            var row = new Rect(position.x, position.y, position.width, EditorGUIUtility.singleLineHeight);
            var keyRect = new Rect(row.x, row.y, row.width * 0.36f, row.height);
            key.stringValue = EditorGUI.TextField(keyRect, key.stringValue);
            var valueRect = new Rect(keyRect.xMax + 6, row.y, row.width - keyRect.width - 6, row.height);
            target.objectReferenceValue = EditorGUI.ObjectField(valueRect, target.objectReferenceValue, typeof(Component), true);
            row.y += row.height + 3;
            var component = target.objectReferenceValue as Component;
            if (component != null)
            {
                var components = component.GetComponents<Component>().Where(x => x != null).ToArray();
                var names = components.Select((x, i) => x.GetType().Name + " (" + i + ")").ToArray();
                var index = System.Array.IndexOf(components, component);
                var selected = EditorGUI.Popup(row, "组件类型", index, names);
                if (selected >= 0) target.objectReferenceValue = components[selected];
            }
            else EditorGUI.LabelField(row, "先拖入组件，再选择具体组件类型", EditorStyles.miniLabel);
            EditorGUI.EndProperty();
        }
    }

    [CustomEditor(typeof(LuaReference))]
    public sealed class LuaReferenceEditor : UnityEditor.Editor
    {
        public override void OnInspectorGUI()
        {
            EditorGUILayout.HelpBox("自定义 Key → Component，Lua 使用 self.view.Key。Key 必须是 Lua 标识符且不可重复。", MessageType.Info);
            DrawDefaultInspector();
            if (GUILayout.Button("Validate Bindings"))
            {
                try { ((LuaReference)target).ValidateBindings(); Debug.Log("LuaReference bindings valid.", target); }
                catch (System.Exception error) { Debug.LogException(error, target); }
            }
            if (GUILayout.Button("Export EmmyLua View Hints"))
            {
                try
                {
                    var view = (LuaReference)target;
                    var sourcePath = PrefabUtility.GetPrefabAssetPathOfNearestInstanceRoot(view.gameObject);
                    if (string.IsNullOrEmpty(sourcePath)) sourcePath = AssetDatabase.GetAssetPath(view.gameObject);
                    var stage = UnityEditor.SceneManagement.PrefabStageUtility.GetCurrentPrefabStage();
                    if (string.IsNullOrEmpty(sourcePath) && stage != null) sourcePath = stage.assetPath;
                    var entry = PanelAssets.LoadOrCreate().Entries.FirstOrDefault(x => x.PrefabPath == sourcePath);
                    bool isRoot = view.transform.parent == null || PrefabUtility.GetNearestPrefabInstanceRoot(view.gameObject) == view.gameObject || (stage != null && stage.prefabContentsRoot == view.gameObject);
                    var type = entry != null && isRoot ? entry.ViewType : view.name + "View";
                    Debug.Log("View hints: " + LuaViewHints.Export(view, type), view);
                }
                catch (System.Exception error) { Debug.LogException(error, target); }
            }
        }
    }
}
