using UnityEngine;
using UnityEngine.UI;
using XLua;

namespace ProjectY.UI
{
    /// <summary>Unity panel state; business logic and controller lifecycle remain in Lua.</summary>
    [LuaCallCSharp, DisallowMultipleComponent]
    [RequireComponent(typeof(LuaReference), typeof(Canvas), typeof(CanvasGroup))]
    [RequireComponent(typeof(CanvasScaler), typeof(GraphicRaycaster))]
    public sealed class LuaPanel : MonoBehaviour
    {
        private UIHost owner;
        public PanelDefinition Config { get; private set; }
        public LuaReference View => GetComponent<LuaReference>();
        public Canvas Canvas => GetComponent<Canvas>();
        public bool IsVisible => gameObject.activeInHierarchy;

        internal void Initialize(UIHost host, PanelDefinition config)
        {
            owner = host; Config = config;
            Canvas.renderMode = config.IsWorldUI ? RenderMode.WorldSpace : RenderMode.ScreenSpaceOverlay;
            Canvas.overrideSorting = true;
            if (config.IsWorldUI) Canvas.worldCamera = Camera.main;
            else
            {
                // Screen panels are full-size child canvases; UIRoot owns resolution scaling.
                var rect = (RectTransform)transform;
                rect.anchorMin = Vector2.zero; rect.anchorMax = Vector2.one;
                rect.offsetMin = rect.offsetMax = Vector2.zero;
                rect.localRotation = Quaternion.identity;
                rect.localScale = Vector3.one;
                var position = rect.anchoredPosition3D; position.z = 0; rect.anchoredPosition3D = position;
            }
            if (config.Modal)
            {
                var blocker = new GameObject("ModalBlocker", typeof(RectTransform), typeof(Image));
                blocker.transform.SetParent(transform, false);
                blocker.transform.SetAsFirstSibling();
                var rect = (RectTransform)blocker.transform;
                rect.anchorMin = Vector2.zero; rect.anchorMax = Vector2.one;
                rect.offsetMin = rect.offsetMax = Vector2.zero;
                blocker.GetComponent<Image>().color = new Color(0, 0, 0, 0.65f);
            }
        }

        public void SetWorldCamera(Camera camera) => Canvas.worldCamera = camera;
        internal void SetVisible(bool value)
        {
            gameObject.SetActive(value);
            RefreshPauseLease();
        }
        internal void SetOrder(int order) => Canvas.sortingOrder = order;
        internal void SetInteractable(bool value)
        {
            var group = GetComponent<CanvasGroup>();
            group.interactable = value; group.blocksRaycasts = value;
        }
        private void RefreshPauseLease()
        {
            if (owner != null) owner.SetPauseLease(this, IsVisible && Config != null && Config.PauseWorldOnOpen);
        }
        private void OnEnable() => RefreshPauseLease();
        private void OnDisable() { if (owner != null) owner.SetPauseLease(this, false); }
    }
}
