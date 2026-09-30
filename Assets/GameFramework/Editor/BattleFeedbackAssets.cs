using System;
using System.Linq;
using ProjectY.UI;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.Editor
{
    /// <summary>Idempotent, targeted migration; keeps existing health layout and prefab bindings.</summary>
    [InitializeOnLoad]
    public static class BattleFeedbackAssets
    {
        static BattleFeedbackAssets()
        {
            LuaViewHints.Register(typeof(AnimationWrap), "CS.ProjectY.UI.AnimationWrap");
            LuaViewHints.Register(typeof(HealthBarAnimation), "CS.ProjectY.UI.HealthBarAnimation");
            LuaViewHints.Register(typeof(BattleFeedbackSystem), "CS.ProjectY.UI.BattleFeedbackSystem");
        }

        [MenuItem("Project Y/UI/同步战斗受击与双层血条")]
        public static void Sync()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("Battle feedback migration requires Edit Mode.");
            var config = AssetDatabase.LoadAssetAtPath<PanelConfig>(PanelConfig.AssetPath);
            if (config == null) throw new InvalidOperationException("UI registry is missing.");
            foreach (var name in new[] { "MainHud", "HudHealth", "HudParty" })
            {
                var entry = config.Get(name);
                var root = PrefabUtility.LoadPrefabContents(entry.PrefabPath);
                try
                {
                    if (name == "MainHud") SetupMain(root); else SetupHealth(root);
                    var reference = root.GetComponent<LuaReference>();
                    reference.ValidateBindings();
                    PrefabUtility.SaveAsPrefabAsset(root, entry.PrefabPath);
                    LuaViewHints.Export(reference, entry.ViewType);
                }
                finally { PrefabUtility.UnloadPrefabContents(root); }
            }
            AssetDatabase.SaveAssets();
            Debug.Log("Battle feedback and two-stage health bar bindings saved.");
        }

        public static void SetupMain(GameObject root)
        {
            var feedback = root.GetComponent<BattleFeedbackSystem>();
            if (feedback == null) feedback = root.AddComponent<BattleFeedbackSystem>();
            var view = new SerializedObject(root.GetComponent<MainHudView>());
            view.FindProperty("battleFeedback").objectReferenceValue = feedback;
            view.ApplyModifiedPropertiesWithoutUndo();
            Bind(root.GetComponent<LuaReference>(), "BattleFeedback", feedback);
        }

        public static void SetupHealth(GameObject root)
        {
            var reference = root.GetComponent<LuaReference>();
            var front = reference.GetImage("Health");
            var back = reference.GetEditorBindings().FirstOrDefault(entry => entry.Key == "HealthTrail").Target as Image;
            if (back == null)
            {
                var rect = (RectTransform)new GameObject("HealthTrail", typeof(RectTransform), typeof(Image)).transform;
                rect.SetParent(front.transform.parent, false);
                rect.anchorMin = front.rectTransform.anchorMin; rect.anchorMax = front.rectTransform.anchorMax;
                rect.pivot = front.rectTransform.pivot; rect.offsetMin = front.rectTransform.offsetMin; rect.offsetMax = front.rectTransform.offsetMax;
                back = rect.GetComponent<Image>();
                back.sprite = front.sprite; back.type = front.type;
                back.color = Color.Lerp(front.color, Color.white, .62f);
            }
            back.raycastTarget = false;
            if (back.transform.GetSiblingIndex() > front.transform.GetSiblingIndex())
                back.transform.SetSiblingIndex(front.transform.GetSiblingIndex());
            var animation = root.GetComponent<HealthBarAnimation>();
            if (animation == null) animation = root.AddComponent<HealthBarAnimation>();
            animation.SetEditorBindings(front, back);
            Bind(reference, "HealthTrail", back); Bind(reference, "HealthAnimation", animation);
        }

        private static void Bind(LuaReference reference, string key, Component target)
        {
            var entries = reference.GetEditorBindings().Where(entry => entry.Key != key).ToList();
            entries.Add(new LuaReference.Entry(key, target)); reference.SetEditorBindings(entries.ToArray());
        }
    }
}
