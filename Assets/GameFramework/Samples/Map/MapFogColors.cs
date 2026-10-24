using UnityEngine;

namespace ProjectY.Samples
{
    internal static class MapFogColors
    {
        // Memory remains legible even for dark original materials; only current sight retains color.
        internal static Color Remembered(Color color, bool linearInput = false)
        {
            if (linearInput) color = color.gamma;
            float value = .38f + Mathf.Clamp01(color.grayscale) * .28f;
            var gray = new Color(value, value, value, 1);
            return linearInput ? gray.linear : gray;
        }
    }
}
