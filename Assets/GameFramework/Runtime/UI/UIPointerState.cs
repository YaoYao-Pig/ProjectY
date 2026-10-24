using UnityEngine;
using UnityEngine.EventSystems;
using XLua;

namespace ProjectY.UI
{
    /// <summary>Allows a controller to show a tooltip even when its Button is disabled.</summary>
    [LuaCallCSharp, DisallowMultipleComponent]
    public sealed class UIPointerState : MonoBehaviour, IPointerEnterHandler, IPointerExitHandler
    {
        private bool hovered;
        private PointerEventData pointer;

        public bool Hovered
        {
            get
            {
                // InputModule reuses this event data and updates its hit before dispatching hover events.
                // Never let an old enter keep a tooltip alive after that hit has left the widget.
                if (hovered && pointer != null && !HasCurrentHit(pointer, transform)) Clear();
                return hovered;
            }
        }

        internal static bool HasCurrentHit(PointerEventData data, Transform root)
        {
            var hit = data.pointerCurrentRaycast.gameObject;
            return hit != null && hit.activeInHierarchy && hit.transform.IsChildOf(root);
        }

        public void OnPointerEnter(PointerEventData eventData) { pointer = eventData; hovered = true; }
        public void OnPointerExit(PointerEventData eventData) => Clear();
        private void Clear() { hovered = false; pointer = null; }
        private void OnDisable() => Clear();
    }
}
