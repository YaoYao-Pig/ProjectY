using UnityEngine;
using XLua;

namespace ProjectY.UI
{
    [LuaCallCSharp, DisallowMultipleComponent]
    public sealed class HudModeTransition : MonoBehaviour
    {
        [SerializeField] private AnimationWrap animation;
        [SerializeField] private CanvasGroup[] mainGroups;
        [SerializeField] private CanvasGroup[] mapGroups;
        private float previous = -1;
        public void SetProgress(float progress)
        {
            // UIHost binds and hides cached widgets while their root is inactive.
            // The saved baseline remains visible until the first active Tick samples it.
            if (!isActiveAndEnabled) { previous = -1; return; }
            progress = Mathf.Clamp01(progress);
            if (previous == progress && animation.CurrentName == "map-overview") return;
            previous = progress;
            animation.SampleNormalized("map-overview", progress);
            foreach (var group in mainGroups) group.interactable = group.blocksRaycasts = progress == 0;
            foreach (var group in mapGroups) group.interactable = group.blocksRaycasts = progress == 1;
        }
        private void OnEnable() { previous = -1; }
    }
}
