using ProjectY.UI;
using TMPro;
using TMPro.EditorUtilities;
using UnityEditor;
using UnityEngine;

namespace ProjectY.Editor
{
    [CustomEditor(typeof(UITxt)), CanEditMultipleObjects]
    public sealed class UITxtEditor : TMP_EditorPanelUI
    {
        public override void OnInspectorGUI()
        {
            serializedObject.Update();
            EditorGUILayout.LabelField("PrefabTxt 本地化", EditorStyles.boldLabel);
            EditorGUILayout.PropertyField(serializedObject.FindProperty("localizationId"), new GUIContent("文本 ID"));
            EditorGUILayout.PropertyField(serializedObject.FindProperty("defaultText"), new GUIContent("默认文本"));
            EditorGUILayout.HelpBox("运行时优先查 PrefabTxt；缺失时使用默认文本。统一 i18n 导出尚未启用。", MessageType.Info);
            serializedObject.ApplyModifiedProperties();
            base.OnInspectorGUI();
        }

        [MenuItem("GameObject/UI/Project Y UITxt", false, 2031)]
        private static void Create(MenuCommand command)
        {
            var go = new GameObject("UITxt", typeof(RectTransform));
            GameObjectUtility.SetParentAndAlign(go, command.context as GameObject);
            var text = go.AddComponent<UITxt>();
            text.font = TMP_Settings.defaultFontAsset;
            text.DefaultText = "Text";
            text.raycastTarget = false;
            Undo.RegisterCreatedObjectUndo(go, "Create UITxt");
            Selection.activeGameObject = go;
        }
    }
}
