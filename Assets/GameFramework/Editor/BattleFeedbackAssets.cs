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
            LuaViewHints.Register(typeof(DamageNumberAnimation), "CS.ProjectY.UI.DamageNumberAnimation");
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
            if (root.GetComponent<UIFollower>() != null) SetupDamageNumbers(root);
        }

        public static void SetupDamageNumbers(GameObject root)
        {
            var reference = root.GetComponent<LuaReference>();
            var numbers = root.GetComponent<DamageNumberAnimation>();
            if (numbers == null)
            {
                numbers = root.AddComponent<DamageNumberAnimation>();
                var rect = DamageRect("DamageNumberTemplate", root.transform, new Vector2(320, 94));
                rect.anchorMin = rect.anchorMax = new Vector2(.5f, 1);
                var group = rect.gameObject.AddComponent<CanvasGroup>(); group.blocksRaycasts = false; group.interactable = false;
                var popup = rect.gameObject.AddComponent<DamageNumberPopup>();
                var flash = DamageRect("CriticalBurst", rect, new Vector2(140, 80));
                var burst = flash.gameObject.AddComponent<CanvasGroup>(); burst.blocksRaycasts = false; burst.interactable = false;
                for (int i = 0; i < 8; i++)
                {
                    float angle = i * 45;
                    var ray = DamageRect("Ray" + i, flash, new Vector2(i % 2 == 0 ? 24 : 15, 3));
                    ray.anchoredPosition = new Vector2(Mathf.Cos(angle * Mathf.Deg2Rad) * 55, Mathf.Sin(angle * Mathf.Deg2Rad) * 29);
                    ray.localRotation = Quaternion.Euler(0, 0, angle);
                    var image = ray.gameObject.AddComponent<Image>(); image.color = new Color(1, .72f, .16f); image.raycastTarget = false;
                }
                var amount = DamageText("Amount", rect, 40, new Vector2(320, 82));
                var glow = amount.gameObject.AddComponent<DamageNumberGlow>();
                var label = DamageText("Critical", rect, 17, new Vector2(180, 26));
                label.text = "暴击!"; label.color = new Color(1, .75f, .18f); label.rectTransform.anchoredPosition = new Vector2(0, 45);
                var outline = label.gameObject.AddComponent<Outline>(); outline.effectColor = new Color(.2f, .04f, 0, 1); outline.effectDistance = new Vector2(1, -1);
                popup.SetEditorBindings(rect, group, amount, label, glow, burst);
                numbers.SetEditorBindings(popup, root.GetComponent<UIFollower>()); rect.gameObject.SetActive(false);
            }
            Bind(reference, "DamageNumbers", numbers);
        }

        private static RectTransform DamageRect(string name, Transform parent, Vector2 size)
        {
            var rect = (RectTransform)new GameObject(name, typeof(RectTransform)).transform;
            rect.SetParent(parent, false); rect.anchorMin = rect.anchorMax = rect.pivot = new Vector2(.5f, .5f);
            rect.sizeDelta = size; return rect;
        }

        private static Text DamageText(string name, Transform parent, int size, Vector2 bounds)
        {
            var rect = DamageRect(name, parent, bounds);
            var text = rect.gameObject.AddComponent<Text>();
            text.font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf"); text.fontSize = size; text.fontStyle = FontStyle.Bold;
            text.alignment = TextAnchor.MiddleCenter; text.horizontalOverflow = HorizontalWrapMode.Overflow; text.verticalOverflow = VerticalWrapMode.Overflow;
            text.supportRichText = false; text.raycastTarget = false; return text;
        }

        private static void Bind(LuaReference reference, string key, Component target)
        {
            var entries = reference.GetEditorBindings().Where(entry => entry.Key != key).ToList();
            entries.Add(new LuaReference.Entry(key, target)); reference.SetEditorBindings(entries.ToArray());
        }
    }
}
