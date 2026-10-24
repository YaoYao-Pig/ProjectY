using TMPro;
using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.UI
{
    /// <summary>Serialized row template. Instantiation remaps every reference without hierarchy searches.</summary>
    [DisallowMultipleComponent]
    public sealed class SkillTooltipItemView : MonoBehaviour
    {
        public RectTransform Rect;
        public Image Background;
        public TMP_Text Caption;
        public TMP_Text Value;
        public TMP_Text Body;
        public RectTransform Mask;
    }
}
