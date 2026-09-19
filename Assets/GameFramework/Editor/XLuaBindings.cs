using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Events;
using UnityEngine.UI;
using XLua;

namespace ProjectY.Editor
{
    public static class XLuaBindings
    {
        // This Unity method exists only in the Editor and must never appear in player wrappers.
        [BlackList]
        public static List<List<string>> EditorOnlyMembers = new List<List<string>>
        {
            new List<string> { "UnityEngine.UI.Text", "OnRebuildRequested" }
        };

        [CSharpCallLua]
        public static List<Type> Delegates = new List<Type>
        {
            typeof(Action), typeof(Action<float>), typeof(Action<float, float>), typeof(Action<bool>),
            typeof(UnityAction), typeof(UnityAction<bool>), typeof(UnityAction<float>), typeof(UnityAction<string>), typeof(UnityAction<int>), typeof(UnityAction<Vector2>)
        };

        [LuaCallCSharp]
        public static List<Type> UnityTypes = new List<Type>
        {
            typeof(UnityEngine.Object), typeof(GameObject), typeof(Component), typeof(Behaviour),
            typeof(Transform), typeof(RectTransform), typeof(Vector2), typeof(Vector3), typeof(Color),
            typeof(Canvas), typeof(CanvasGroup), typeof(Camera), typeof(CanvasScaler), typeof(GraphicRaycaster),
            typeof(Button), typeof(Button.ButtonClickedEvent), typeof(Text), typeof(Image),
            typeof(Toggle), typeof(Toggle.ToggleEvent), typeof(Slider), typeof(Slider.SliderEvent),
            typeof(InputField), typeof(InputField.OnChangeEvent), typeof(UnityEvent),
            typeof(RawImage), typeof(ScrollRect), typeof(ScrollRect.ScrollRectEvent),
            typeof(Scrollbar), typeof(Scrollbar.ScrollEvent), typeof(Dropdown), typeof(Dropdown.DropdownEvent),
            typeof(UnityEvent<bool>), typeof(UnityEvent<float>), typeof(UnityEvent<string>), typeof(UnityEvent<int>), typeof(UnityEvent<Vector2>)
        };
    }
}
