using UnityEngine;
using UnityEngine.EventSystems;
using XLua;

namespace ProjectY.UI
{
    /// <summary>Allows a controller to show a tooltip even when its Button is disabled.</summary>
    [LuaCallCSharp, DisallowMultipleComponent]
    public sealed class UIPointerState : MonoBehaviour, IPointerEnterHandler, IPointerExitHandler
    {
        public bool Hovered { get; private set; }
        public void OnPointerEnter(PointerEventData eventData) => Hovered = true;
        public void OnPointerExit(PointerEventData eventData) => Hovered = false;
        private void OnDisable() => Hovered = false;
    }
}
