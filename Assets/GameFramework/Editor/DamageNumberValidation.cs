using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using ProjectY.UI;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;
using XLua;
using Object = UnityEngine.Object;

namespace ProjectY.Editor
{
    public static class DamageNumberValidation
    {
        private static void Check(bool value, string message) { if (!value) throw new InvalidOperationException(message); }
        private static object Call(object target, string method, params object[] args) => target.GetType().GetMethod(method, BindingFlags.Instance | BindingFlags.NonPublic).Invoke(target, args);
        private static T Field<T>(object target, string name) => (T)target.GetType().GetField(name, BindingFlags.Instance | BindingFlags.NonPublic).GetValue(target);
        private static List<DamageNumberPopup> Pool(DamageNumberAnimation numbers) => Field<List<DamageNumberPopup>>(numbers, "pool");
        private static int Visible(DamageNumberAnimation numbers) => Pool(numbers).Count(item => item.gameObject.activeSelf);
        private static void Tick(BattleFeedbackSystem feedback, float dt) => Call(feedback, "Tick", dt);

        [MenuItem("Project Y/UI/验证伤害数字")]
        public static void Run()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("Damage number checks require Edit Mode.");
            var scene = EditorSceneManager.NewPreviewScene();
            var owner = new GameObject("DamageNumberValidation"); SceneManager.MoveGameObjectToScene(owner, scene);
            var font = Font.CreateDynamicFontFromOSFont(new[] { "Microsoft YaHei", "Arial" }, 32);
            try
            {
                var prefab = AssetDatabase.LoadAssetAtPath<PanelConfig>(PanelConfig.AssetPath).Get("HudHealth").Prefab;
                Check(prefab.GetComponent<DamageNumberAnimation>() != null, "Save HudHealth through the battle feedback migration first.");
                var root = Object.Instantiate(prefab, owner.transform);
                var reference = root.GetComponent<LuaReference>(); reference.ValidateBindings();
                var numbers = (DamageNumberAnimation)reference.Get("DamageNumbers");
                int children = root.transform.childCount;
                BattleFeedbackAssets.SetupDamageNumbers(root); BattleFeedbackAssets.SetupDamageNumbers(root);
                Check(root.transform.childCount == children, "Migration must keep one template and preserve settings.");
                // Deterministic fixture values; the saved prefab's Inspector tuning stays untouched.
                var settings = new SerializedObject(numbers);
                settings.FindProperty("minimumFontSize").intValue = 27; settings.FindProperty("maximumFontSize").intValue = 54;
                settings.FindProperty("damageSizeReference").floatValue = 100; settings.FindProperty("criticalSizeMultiplier").floatValue = 1.22f;
                settings.FindProperty("normalSeconds").floatValue = .95f; settings.FindProperty("criticalSeconds").floatValue = 1.2f;
                settings.ApplyModifiedPropertiesWithoutUndo();
                var feedback = owner.AddComponent<BattleFeedbackSystem>();
                feedback.BindDamageNumbers(numbers, 7, 90, font);
                Check((int)Call(numbers, "FontSize", 4, false) < (int)Call(numbers, "FontSize", 40, false), "More damage must be larger.");
                Check((int)Call(numbers, "FontSize", 40, true) > (int)Call(numbers, "FontSize", 40, false), "Critical size bonus.");
                Check((int)Call(numbers, "FontSize", int.MaxValue, false) <= 54, "Extreme damage remains readable.");
                feedback.QueueDamage(7, 8, 1, false); feedback.QueueDamage(7, 48, 3, true); Call(feedback, "Commit", .2f);
                Check(numbers.IsAnimating && Visible(numbers) == 0 && Pool(numbers).Count == 2, "Every delayed hit reserves its own popup.");
                feedback.BindDamageNumbers(numbers, 7, 90, font);
                Tick(feedback, 0); Check(Visible(numbers) == 0, "Pause preserves the delay.");
                Tick(feedback, .21f); Check(Visible(numbers) == 1, "First hit appears at impact.");
                Tick(feedback, .2f); Check(Visible(numbers) == 1, "Missed second bullet leaves a gap.");
                Tick(feedback, .2f); Check(Visible(numbers) == 2, "Third bullet retains original timing.");
                var critical = Pool(numbers)[1];
                Check(Field<Text>(critical, "criticalLabel").gameObject.activeSelf && Field<CanvasGroup>(critical, "burst").gameObject.activeSelf, "Critical label and burst are visible.");
                var normalPosition = Field<RectTransform>(Pool(numbers)[0], "root").anchoredPosition;
                Check(normalPosition != Field<RectTransform>(critical, "root").anchoredPosition, "Consecutive numbers separate.");
                feedback.BindDamageNumbers(numbers, 7, 7, font); Check(numbers.IsAnimating, "Dismount preserves already committed damage.");
                feedback.Skip(); Check(!numbers.IsAnimating && Visible(numbers) == 0, "Skip cancels both pending and active numbers.");
                feedback.BindDamageNumbers(numbers, 7, 90, font);
                feedback.QueueDamage(90, 3, 1, false); Call(feedback, "Commit", 0f); Tick(feedback, .1f);
                Check(Visible(numbers) == 1, "Mount periodic damage reaches the rider head bar.");
                feedback.BindDamageNumbers(numbers, 8, 8, font); Check(!numbers.IsAnimating, "Actor reuse clears old damage.");
                feedback.QueueDamage(7, 9, 1, false); Call(feedback, "Commit", 0f); Check(!numbers.IsAnimating, "Old actor cannot target a reused widget.");
                feedback.QueueDamage(8, 18, 1, false); Call(feedback, "Commit", 0f); Tick(feedback, .08f);
                Check(Field<RectTransform>(Pool(numbers)[0], "root").localScale.x > 1.2f, "Impact has a pronounced scale punch.");
                Tick(feedback, .68f); Check(Field<CanvasGroup>(Pool(numbers)[0], "group").alpha < 1, "Numbers fade after holding.");
                Tick(feedback, 1); Check(!numbers.IsAnimating, "Low frame rates finish numbers without replay.");
                Check(Pool(numbers).Count == 2, "Finished popups are reused.");
                feedback.QueueDamage(8, 20, 1, true); Call(feedback, "Commit", 0f); feedback.UnbindDamageNumbers(numbers);
                Check(!numbers.IsAnimating, "Unbind clears live numbers.");
                feedback.BindDamageNumbers(numbers,8,8,font);
                StatusFeedback.Queue(feedback,8,"燃烧","#F4A160",1);StatusFeedback.Queue(feedback,8,"潮湿","#74CBE8",1);
                Call(feedback,"Commit",0f);Check(Visible(numbers)==0,"Statuses wait for the hit timing.");
                Tick(feedback,.21f);Check(Visible(numbers)==1,"Only the first status starts immediately.");
                Check(Field<Text>(Pool(numbers)[0],"number").text=="燃烧","Status text replaces the numeric payload.");
                ColorUtility.TryParseHtmlString("#F4A160",out var burningColor);
                Check(Field<Text>(Pool(numbers)[0],"number").color==burningColor,"Status uses its configured color.");
                Tick(feedback,.55f);Check(Visible(numbers)==2 && Field<Text>(Pool(numbers)[1],"number").text=="潮湿","Statuses appear in application order.");
                Check(!Field<Text>(Pool(numbers)[0],"criticalLabel").gameObject.activeSelf,"Statuses do not invent critical hits.");
                feedback.Skip();Check(!numbers.IsAnimating,"Skip cancels queued status text.");
                DamageFeedback.Queue(feedback,8,6,1,false,"#FF3B42");DamageFeedback.Queue(feedback,8,4,2,true,"#6FCF45");
                Call(feedback,"Commit",0f);Tick(feedback,.21f);
                ColorUtility.TryParseHtmlString("#FF3B42",out var bleedColor);ColorUtility.TryParseHtmlString("#6FCF45",out var poisonColor);
                Check(Field<Text>(Pool(numbers)[0],"number").color==bleedColor && Field<Text>(Pool(numbers)[1],"number").color==poisonColor,"Each queued hit keeps its own damage color.");
                Check(Field<Text>(Pool(numbers)[1],"criticalLabel").gameObject.activeSelf,"Typed damage retains critical presentation without changing its color.");
                feedback.Skip();feedback.QueueDamage(8,8,1,false);Call(feedback,"Commit",0f);
                Check(Field<Text>(Pool(numbers)[0],"number").color==new Color(1,.95f,.86f),"Pool reuse restores the normal damage color.");
                feedback.Skip();
                using (var lua = new LuaEnv())
                {
                    lua.Global.Set("feedback", feedback); lua.Global.Set("numbers", numbers); lua.Global.Set("font", font);
                    lua.DoString("feedback:BindDamageNumbers(numbers,8,8,font);feedback:QueueDamage(8,20,1,true);assert(not numbers.IsAnimating)");
                    Call(feedback, "Commit", 0f); lua.DoString("assert(numbers.IsAnimating);feedback:Skip();assert(not numbers.IsAnimating)");
                    lua.DoString("CS.ProjectY.UI.StatusFeedback.Queue(feedback,8,'再生','#79D9A7',1)");
                    Call(feedback,"Commit",0f);Tick(feedback,.25f);
                    Check(Visible(numbers)==1 && Field<Text>(Pool(numbers)[0],"number").text=="再生","Typed Lua status bridge reaches the existing popup pool.");
                    feedback.Skip();
                    lua.DoString("CS.ProjectY.UI.DamageFeedback.Queue(feedback,8,3,1,false,'#FF3B42')");
                    Call(feedback,"Commit",0f);
                    Check(Visible(numbers)==1 && Field<Text>(Pool(numbers)[0],"number").text=="3" && Field<Text>(Pool(numbers)[0],"number").color==bleedColor,"Real xLua damage bridge preserves the settled amount and color.");
                    feedback.Skip();
                    lua.Global.Set<string, object>("feedback", null); lua.Global.Set<string, object>("numbers", null); lua.Global.Set<string, object>("font", null);
                }
                feedback.Clear(); root.SetActive(false);
                Capture(owner, scene, prefab, font);
                Debug.Log("DamageNumber PASS: damage colors/critical color/pool reset, saved bindings, actual hit timing/miss gap, pool reuse, amount scaling, critical burst, pause/skip/low-FPS, mount identity, actor reuse, real xLua bridge, retained death anchor; preview Docs/Previews/DamageNumbers.png");
            }
            finally { EditorSceneManager.ClosePreviewScene(scene); Object.DestroyImmediate(font); }
        }

        private static void Capture(GameObject owner, Scene scene, GameObject prefab, Font font)
        {
            var cameraRoot = new GameObject("PreviewCamera"); cameraRoot.transform.SetParent(owner.transform, false);
            var camera = cameraRoot.AddComponent<Camera>(); camera.enabled = false; camera.orthographic = true; camera.orthographicSize = 5;
            camera.scene = scene; camera.overrideSceneCullingMask = EditorSceneManager.GetSceneCullingMask(scene);
            camera.clearFlags = CameraClearFlags.SolidColor; camera.backgroundColor = new Color(.055f, .075f, .09f);
            var canvasRoot = new GameObject("PreviewCanvas", typeof(RectTransform), typeof(Canvas)); canvasRoot.transform.SetParent(owner.transform, false);
            var canvas = canvasRoot.GetComponent<Canvas>(); canvas.renderMode = RenderMode.ScreenSpaceCamera; canvas.worldCamera = camera; canvas.planeDistance = 1;
            var amount = new[] { 8, 48, 96, 6, 4, 4 }; var samples = new[] { .08f, .3f, .76f };
            var labels = new[] { "普通命中", "大伤害", "暴击", "流血", "中毒", "燃烧" };
            var colors = new Color?[] { null, null, null, new Color32(255,59,66,255), new Color32(111,207,69,255), new Color32(244,161,96,255) };
            for (int row = 0; row < samples.Length; row++) for (int column = 0; column < amount.Length; column++)
            {
                var root = Object.Instantiate(prefab, canvasRoot.transform);
                var rect = (RectTransform)root.transform; rect.anchorMin = rect.anchorMax = new Vector2(.5f, .5f);
                rect.anchoredPosition = new Vector2((column - 2.5f) * 260, 145 - row * 210); rect.localScale = Vector3.one;
                root.GetComponent<CanvasGroup>().alpha = 1;
                var reference = root.GetComponent<LuaReference>();
                var name = (Text)reference.Get("Name"); name.font = font; name.text = labels[column];
                var hp = (Text)reference.Get("HealthText"); hp.font = font; hp.text = "52 / 100";
                var ap = (Text)reference.Get("APText"); ap.font = font;
                var numbers = (DamageNumberAnimation)reference.Get("DamageNumbers");
                Call(numbers, "Prepare", font); Call(numbers, "Queue", amount[column], column == 2, 0f,colors[column]); Call(numbers, "Advance", samples[row]);
                Check(Visible(numbers) == 1, "Preview popup must actually be active.");
            }
            var rt = new RenderTexture(1600, 760, 24); var previous = RenderTexture.active; Texture2D image = null;
            try
            {
                camera.targetTexture = rt; Canvas.ForceUpdateCanvases();
                ProjectY.Rendering.UrpCameraRendering.Render(camera); RenderTexture.active = rt;
                image = new Texture2D(rt.width, rt.height, TextureFormat.RGB24, false); image.ReadPixels(new Rect(0, 0, rt.width, rt.height), 0, 0); image.Apply();
                Directory.CreateDirectory("Docs/Previews"); File.WriteAllBytes("Docs/Previews/DamageNumbers.png", image.EncodeToPNG());
                var fixture = Object.Instantiate(prefab, canvasRoot.transform);
                var anchor = new GameObject("RetiringAnchor"); anchor.transform.SetParent(owner.transform, false); anchor.transform.position = new Vector3(0, 0, 5);
                var follower = fixture.GetComponent<UIFollower>(); follower.Bind(camera, anchor.transform, canvas);
                Check(follower.Project(), "Death anchor starts visible.");
                fixture.GetComponent<DamageNumberAnimation>().Retire(); Object.DestroyImmediate(anchor);
                Check(follower.Project(), "Retiring numbers keep their last world position after target destruction.");
                follower.Clear(); Check(!follower.Project(), "Clear releases the retained world point.");
            }
            finally { RenderTexture.active = previous; camera.targetTexture = null; if (image != null) Object.DestroyImmediate(image); Object.DestroyImmediate(rt); }
        }
    }
}
