using UnityEngine;

namespace ProjectY.UI
{
    /// <summary>Reflection bridge; Lua owns terminology navigation and discovery projections.</summary>
    public static class SkillTooltipPresentation
    {
        public static void Begin(SkillTooltipView view, string title, string body) => view.Begin(title, body);
        public static void AddTag(SkillTooltipView view, string label, string foregroundHtml, string backgroundHtml)
            => view.AddTag(label, foregroundHtml, backgroundHtml);
        public static void AddStat(SkillTooltipView view, string label, string value, string valueColorHtml)
            => view.AddStat(label, value, valueColorHtml);
        public static void AddSynergy(SkillTooltipView view, string title, string description, bool discovered, bool active)
            => view.AddSynergy(title, description, discovered, active);
        public static void SetNavigation(SkillTooltipView view, bool backEnabled, string breadcrumb)
            => view.SetNavigation(backEnabled, breadcrumb);
        public static void Show(SkillTooltipView view, RectTransform anchor) => view.Show(anchor);
        public static void Hide(SkillTooltipView view) => view.Hide();
        public static bool ContainsPointer(SkillTooltipView view) => view.ContainsPointer();
        public static bool KeepOpen(SkillTooltipView view, bool anchorHovered = false) => view.KeepOpen(anchorHovered);
        public static string TakeLink(SkillTooltipView view) => view.TakeLink();
    }
}
