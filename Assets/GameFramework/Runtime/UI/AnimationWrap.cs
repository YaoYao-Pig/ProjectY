using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Animations;
using UnityEngine.Playables;
using XLua;

namespace ProjectY.UI
{
    /// <summary>Named UI clips. Animator clips need no controller; legacy clips use Animation.</summary>
    [LuaCallCSharp, DisallowMultipleComponent, RequireComponent(typeof(Animator))]
    public sealed class AnimationWrap : MonoBehaviour
    {
        [SerializeField] private AnimationClip inClip;
        [SerializeField] private AnimationClip outClip;
        [SerializeField] private AnimationClip[] clips = Array.Empty<AnimationClip>();
        [SerializeField] private bool useUnscaledTime = true;
        private Dictionary<string, AnimationClip> lookup;
        private Animator animator;
        private Animation legacy;
        private AnimationState legacyState;
        private PlayableGraph graph;
        private AnimationClipPlayable playable;
        private AnimationClip current;
        private float elapsed;
        private bool restoreAnimator;

        public bool IsPlaying { get; private set; }
        public string CurrentName { get; private set; }

        public bool HasClip(string clipName)
        {
            EnsureClips();
            return clipName != null && lookup.ContainsKey(clipName);
        }

        public void PlayIn() => Play("in");
        public void PlayOut() => Play("out");
        public void Play(string clipName)
        {
            EnsureClips();
            if (clipName == null || !lookup.TryGetValue(clipName, out var clip))
                throw new ArgumentException($"{name}: AnimationWrap has no clip '{clipName}'.", nameof(clipName));
            if (!isActiveAndEnabled) throw new InvalidOperationException($"{name}: AnimationWrap must be active to play.");
            Stop();
            if (animator == null) animator = GetComponent<Animator>();
            current = clip; CurrentName = clipName; elapsed = 0;
            if (clip.legacy)
            {
                if (legacy == null) legacy = GetComponent<Animation>();
                if (legacy == null) legacy = gameObject.AddComponent<Animation>();
                restoreAnimator = animator.enabled; animator.enabled = false;
                legacy.playAutomatically = false;
                legacy.AddClip(clip, clipName);
                legacyState = legacy[clipName];
                legacyState.enabled = true; legacyState.weight = 1; legacyState.speed = 0;
                legacyState.wrapMode = clip.isLooping ? WrapMode.Loop : WrapMode.ClampForever;
            }
            else
            {
                if (!animator.enabled) throw new InvalidOperationException($"{name}: Animator is disabled.");
                graph = PlayableGraph.Create(name + ".UIAnimation");
                graph.SetTimeUpdateMode(DirectorUpdateMode.Manual);
                playable = AnimationClipPlayable.Create(graph, clip);
                playable.SetApplyFootIK(false); playable.SetApplyPlayableIK(false);
                var output = AnimationPlayableOutput.Create(graph, "UI", animator);
                output.SetSourcePlayable(playable); graph.Play();
            }
            IsPlaying = true;
            Sample(0);
        }

        private void Update()
        {
            if (!IsPlaying) return;
            elapsed += useUnscaledTime ? Time.unscaledDeltaTime : Time.deltaTime;
            var loop = current.isLooping && current.length > 0;
            Sample(loop ? elapsed % current.length : Mathf.Min(elapsed, current.length));
            if (!loop && elapsed >= current.length) IsPlaying = false; // Hold the last authored pose until Stop/next Play.
        }

        private void Sample(float time)
        {
            if (legacyState != null) { legacyState.time = time; legacy.Sample(); }
            else { playable.SetTime(time); graph.Evaluate(0); }
        }

        public void Stop()
        {
            IsPlaying = false; CurrentName = null; current = null;
            if (graph.IsValid()) graph.Destroy();
            if (legacyState != null)
            {
                legacyState.enabled = false; legacy.Stop(); legacyState = null;
                animator.enabled = restoreAnimator;
            }
        }

        private void EnsureClips()
        {
            if (lookup != null) return;
            var next = new Dictionary<string, AnimationClip>(StringComparer.Ordinal);
            if (inClip != null) next.Add("in", inClip);
            if (outClip != null) next.Add("out", outClip);
            foreach (var clip in clips)
            {
                if (clip == null || string.IsNullOrEmpty(clip.name) || clip.name == "in" || clip.name == "out" || next.ContainsKey(clip.name))
                    throw new InvalidOperationException($"{name}: additional animation clips need unique, non-reserved names.");
                next.Add(clip.name, clip);
            }
            lookup = next;
        }

        private void OnDisable() => Stop();
        private void OnDestroy() => Stop();
#if UNITY_EDITOR
        private void OnValidate() => lookup = null;
#endif
    }
}
