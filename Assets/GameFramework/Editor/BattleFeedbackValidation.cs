using System;
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
    public static class BattleFeedbackValidation
    {
        private static void Check(bool value, string message) { if (!value) throw new InvalidOperationException(message); }
        private static void Near(float actual, float expected, string message) => Check(Mathf.Abs(actual - expected) < .001f, message + ": " + actual);
        private static object Call(object target, string method, params object[] args) => target.GetType().GetMethod(method, BindingFlags.Instance | BindingFlags.NonPublic).Invoke(target, args);
        private static void Advance(HealthBarAnimation bar, float dt) => Call(bar, "Advance", dt);
        private static int Pending(BattleFeedbackSystem feedback) => ((System.Collections.ICollection)typeof(BattleFeedbackSystem).GetField("impacts", BindingFlags.Instance | BindingFlags.NonPublic).GetValue(feedback)).Count;
        private static void Near(Vector2 actual, Vector2 expected, string message) => Check((actual - expected).magnitude < .001f, message);

        [MenuItem("Project Y/UI/验证战斗受击与双层血条")]
        public static void Run()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("Feedback checks require Edit Mode.");
            var scene = EditorSceneManager.NewPreviewScene();
            var owner = new GameObject("BattleFeedbackValidation"); SceneManager.MoveGameObjectToScene(owner, scene);
            var normal = new AnimationClip { name = "pulse" };
            var legacy = new AnimationClip { name = "legacy", legacy = true };
            AnimationWrap wrap = null;
            try
            {
                var config = AssetDatabase.LoadAssetAtPath<PanelConfig>(PanelConfig.AssetPath);
                foreach (var name in new[] { "HudHealth", "HudParty" })
                {
                    var root = Object.Instantiate(config.Get(name).Prefab, owner.transform);
                    BattleFeedbackAssets.SetupHealth(root); BattleFeedbackAssets.SetupHealth(root);
                    var reference = root.GetComponent<LuaReference>(); reference.ValidateBindings();
                    var front = reference.GetImage("Health"); var trail = reference.GetImage("HealthTrail");
                    Check(front.transform.parent == trail.transform.parent && trail.transform.GetSiblingIndex() < front.transform.GetSiblingIndex(), "Trail must render below foreground");
                    Check(!trail.raycastTarget && trail.color.r > front.color.r, "Trail must be pale and not intercept input");
                    var bar = (HealthBarAnimation)reference.Get("HealthAnimation");
                    bar.SetValue(1, 1, 0); bar.SetValue(1, .4f, .2f);
                    Advance(bar, .1f); Near(bar.ForegroundFraction, 1, "Hold until impact");
                    Advance(bar, .1f + .055f); Check(bar.ForegroundFraction < 1 && bar.ForegroundFraction > .85f, "Nonlinear foreground easing");
                    Near(bar.TrailFraction, 1, "Trail waits for foreground");
                    Advance(bar, .165f); Near(bar.ForegroundFraction, .4f, "Foreground reaches target first"); Near(bar.TrailFraction, 1, "Trail has only just started");
                    Advance(bar, .19f); Check(bar.TrailFraction < 1 && bar.TrailFraction > .4f, "Trail drains second");
                    float before = bar.ForegroundFraction, back = bar.TrailFraction;
                    bar.SetValue(1, .2f, 0); Near(bar.ForegroundFraction, before, "Consecutive hit keeps displayed health"); Near(bar.TrailFraction, back, "Consecutive hit keeps displayed trail");
                    Advance(bar, 1); Near(bar.ForegroundFraction, .2f, "Front completes"); Near(bar.TrailFraction, .2f, "Trail completes"); Check(!bar.IsAnimating, "Animation completes");
                    bar.SetValue(1, .1f, 0); Advance(bar, .05f); bar.SetValue(1, .8f, 0);
                    Near(bar.TrailFraction, .8f, "Healing clears stale damage"); Check(!bar.IsAnimating, "Healing stops previous coroutine");
                    bar.SetValue(1, 0, 0); bar.SetValue(2, .6f, 0); Near(bar.ForegroundFraction, .6f, "Rebinding cannot inherit prior actor damage");
                    bar.SetValue(2, 0, 0); Advance(bar, 2); Near(bar.TrailFraction, 0, "Lethal damage drains both bars");
                    bar.SetValue(2, 1, 0); bar.SetValue(2, .2f, 0); Advance(bar, 0); Near(bar.ForegroundFraction, 1, "Pause does not advance");
                    // Ordinary MonoBehaviours do not receive Play lifecycle messages in a PreviewScene.
                    root.SetActive(false); Call(bar, "OnDisable"); Check(!bar.IsAnimating, "Disable handler cancels coroutine"); root.SetActive(true);

                    var feedback = owner.AddComponent<BattleFeedbackSystem>();
                    // Exercise overlapping hits independently of the authored/default burst interval.
                    var feedbackSettings = new SerializedObject(feedback);
                    feedbackSettings.FindProperty("burstHitInterval").floatValue = .07f;
                    feedbackSettings.ApplyModifiedPropertiesWithoutUndo();
                    feedback.BindHealth(bar, 7, 2, 1); feedback.QueueHealth(7, 2, .5f); feedback.QueueImpact(1, false, false); Call(feedback, "Commit", .3f);
                    feedback.BindHealth(bar, 7, 2, .5f); Advance(bar, .2f); Near(bar.ForegroundFraction, 1, "HUD refresh preserves impact wait");
                    Call(feedback, "Tick", .2f); Check(feedback.ScreenOffset == Vector2.zero, "Shake waits for impact");
                    Call(feedback, "Tick", .11f); Check(feedback.ScreenOffset.sqrMagnitude > 0, "Hit shakes screen");
                    feedback.Skip(); Near(bar.TrailFraction, .5f, "Skipping completes damage trail"); Check(feedback.ScreenOffset == Vector2.zero, "Skipping clears shake");
                    feedback.QueueHealth(7, 2, .4f); Call(feedback, "Commit", 0f); Call(feedback, "Tick", .05f);
                    Check(feedback.ScreenOffset == Vector2.zero, "Periodic damage does not shake");
                    feedback.Skip();
                    feedback.QueueImpact(1, false, false); feedback.QueueImpact(2, false, false); feedback.QueueImpact(3, false, false);
                    Call(feedback, "Commit", .2f); Check(Pending(feedback) == 3, "Each bullet keeps a separate impact");
                    Call(feedback, "Tick", .21f); var first = feedback.ScreenOffset;
                    Check(first.sqrMagnitude > 0 && Pending(feedback) == 2, "First bullet fires once");
                    Call(feedback, "Tick", .07f); Near(feedback.ScreenOffset, first, "Second bullet interrupts and restarts the first shake"); Check(Pending(feedback) == 1, "Second bullet fires once");
                    Call(feedback, "Tick", .07f); Near(feedback.ScreenOffset, first, "Third bullet interrupts and restarts the second shake"); Check(Pending(feedback) == 0, "Third bullet fires once");
                    Call(feedback, "Tick", .2f); Check(feedback.ScreenOffset == Vector2.zero, "No repeated impacts after the burst");
                    feedback.QueueImpact(1, false, false); feedback.QueueImpact(3, false, false); Call(feedback, "Commit", .2f);
                    Call(feedback, "Tick", .21f); Call(feedback, "Tick", .07f);
                    Check((feedback.ScreenOffset - first).magnitude > .1f && Pending(feedback) == 1, "Missing second shot does not invent a shake");
                    Call(feedback, "Tick", .07f); Near(feedback.ScreenOffset, first, "Third shot retains its original timing after a miss");
                    feedback.Skip();
                    feedback.QueueImpact(1, true, false); Call(feedback, "Commit", 0f); Call(feedback, "Tick", .01f);
                    Near(feedback.ScreenOffset, first * 1.7f, "Critical hit has stronger amplitude");
                    feedback.QueueImpact(1, false, false); Call(feedback, "Commit", 0f); Call(feedback, "Tick", .01f);
                    Near(feedback.ScreenOffset, first, "New normal hit replaces even a critical shake");
                    feedback.QueueImpact(1, true, true); Call(feedback, "Commit", 0f); Call(feedback, "Tick", .01f);
                    Near(feedback.ScreenOffset, first * 2.5f, "Critical lethal hit uses death strength once, without stacking");
                    feedback.Skip(); feedback.QueueImpact(1, false, false); feedback.QueueImpact(2, true, false); feedback.QueueImpact(3, false, true);
                    Call(feedback, "Commit", 0f); Call(feedback, "Tick", .15f);
                    Near(feedback.ScreenOffset, first * 2.5f, "Low frame rates preserve chronological interruption");
                    feedback.Skip(); feedback.QueueImpact(3, false, true); Call(feedback, "Commit", 0f); Call(feedback, "Tick", 0f);
                    Check(Pending(feedback) == 1 && feedback.ScreenOffset == Vector2.zero, "Pause keeps pending hits waiting");
                    feedback.Skip(); Call(feedback, "Tick", 1f); Check(Pending(feedback) == 0 && feedback.ScreenOffset == Vector2.zero, "Skip clears the entire burst");
                    feedback.Clear(); Object.DestroyImmediate(feedback);
                }

                var animationRoot = new GameObject("AnimationWrapCheck", typeof(RectTransform), typeof(AnimationWrap));
                animationRoot.transform.SetParent(owner.transform, false);
                normal.SetCurve("", typeof(Transform), "m_LocalScale.x", AnimationCurve.Linear(0, 1, 1, 2));
                legacy.SetCurve("", typeof(Transform), "m_LocalScale.x", AnimationCurve.Linear(0, 2, 1, 3));
                wrap = animationRoot.GetComponent<AnimationWrap>();
                var serialized = new SerializedObject(wrap);
                serialized.FindProperty("inClip").objectReferenceValue = normal;
                serialized.FindProperty("outClip").objectReferenceValue = legacy;
                serialized.FindProperty("clips").arraySize = 1;
                serialized.FindProperty("clips").GetArrayElementAtIndex(0).objectReferenceValue = normal;
                serialized.ApplyModifiedPropertiesWithoutUndo();
                Check(wrap.HasClip("in") && wrap.HasClip("out") && wrap.HasClip("pulse") && !wrap.HasClip("missing"), "Named clip lookup");
                wrap.PlayIn(); Call(wrap, "Sample", .5f); Near(animationRoot.transform.localScale.x, 1.5f, "Animator clips play without a controller");
                wrap.PlayOut(); Call(wrap, "Sample", .5f); Near(animationRoot.transform.localScale.x, 2.5f, "Legacy Animation playback");
                wrap.Play("pulse"); wrap.Stop(); Check(!wrap.IsPlaying && animationRoot.GetComponent<Animator>().enabled, "Stop restores animator after legacy clips");
                bool rejected = false; try { wrap.Play("missing"); } catch (ArgumentException) { rejected = true; }
                Check(rejected, "Unknown clip names must fail clearly");
                wrap.PlayIn(); animationRoot.SetActive(false); Call(wrap, "OnDisable"); Check(!wrap.IsPlaying, "Disable handler stops playback"); animationRoot.SetActive(true);
                using (var lua = new LuaEnv())
                {
                    lua.Global.Set("wrap", wrap);
                    lua.DoString("assert(wrap:HasClip('pulse')); wrap:Play('pulse'); assert(wrap.IsPlaying); wrap:Stop()");
                    lua.Global.Set<string, object>("wrap", null);
                }
                Debug.Log("BattleFeedback PASS: sequential health, per-damage burst/restart/miss timing, critical/death strength, pause/skip/low-FPS ordering, Animator/legacy/name playback and real xLua bridge.");
            }
            finally
            {
                if (wrap != null) wrap.Stop();
                foreach (var bar in owner.GetComponentsInChildren<HealthBarAnimation>(true)) bar.Complete();
                EditorSceneManager.ClosePreviewScene(scene); Object.DestroyImmediate(normal); Object.DestroyImmediate(legacy);
            }
        }
    }
}
