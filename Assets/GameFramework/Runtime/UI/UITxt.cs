using ProjectY.Data;
using TMPro;
using UnityEngine;
using XLua;

namespace ProjectY.UI
{
    [AddComponentMenu("Project Y/UI/UITxt"), DisallowMultipleComponent, LuaCallCSharp]
    public sealed class UITxt : TextMeshProUGUI
    {
        [SerializeField, Tooltip("PrefabTxt.id; independent of the GameObject name.")]
        private string localizationId = string.Empty;
        [SerializeField, TextArea, Tooltip("Shown when PrefabTxt has no matching id, including edit mode.")]
        private string defaultText = string.Empty;

        public string LocalizationId { get => localizationId; set { localizationId = value; RefreshText(); } }
        public string DefaultText { get => defaultText; set { defaultText = value; RefreshText(); } }

        protected override void OnEnable()
        {
            base.OnEnable();
            LocalizationService.Shared.Changed += RefreshText;
            RefreshText();
        }
        protected override void OnDisable()
        {
            LocalizationService.Shared.Changed -= RefreshText;
            base.OnDisable();
        }
        public void RefreshText()
        {
            text = Application.isPlaying ? LocalizationService.Shared.Resolve("PrefabTxt", localizationId, defaultText) : defaultText;
        }
#if UNITY_EDITOR
        protected override void OnValidate() { base.OnValidate(); RefreshText(); }
#endif
    }
}
