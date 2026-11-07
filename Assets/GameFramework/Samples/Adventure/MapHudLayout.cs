using System;
using UnityEngine;

namespace ProjectY.Samples
{
    /// <summary>Saved map HUD art and responsive cards; no gameplay state.</summary>
    [DisallowMultipleComponent, DefaultExecutionOrder(900)]
    public sealed class MapHudLayout : MonoBehaviour
    {
        [Serializable] public sealed class Obstacle { public RectTransform Rect; public CanvasGroup Group; }
        [SerializeField] private RectTransform root, title, filters, legend, help, actions, back;
        [SerializeField] private Sprite availableSprite, activeSprite, readySprite, partySprite;
        [SerializeField] private Obstacle[] mainObstacles = Array.Empty<Obstacle>();
        [SerializeField] private Obstacle[] mapObstacles = Array.Empty<Obstacle>();
        private Vector2 previousSize;
        public Sprite Available => availableSprite;
        public Sprite Active => activeSprite;
        public Sprite Ready => readySprite;
        public Sprite Party => partySprite;
        public Obstacle[] Obstacles(bool overview) => overview ? mapObstacles : mainObstacles;
        public void ApplyLayout()
        {
            var size = root.rect.size;
            if (size == previousSize) return;
            previousSize = size;
            float scale = Mathf.Min(1, size.x / 1000, size.y / 640);
            Place(title, 0, 1, 16, -16, 210, 76, scale);
            Place(filters, 0, 1, 16, -110, 208, 316, scale);
            Place(legend, 1, 1, -16, -152, 150, 190, scale);
            Place(back, 1, 1, -16, -16, 96, 36, scale);
            Place(help, 0, 0, 16, 16, 340, 38, scale);
            Place(actions, 1, 0, -16, 16, 276, 40, scale);
        }
        private static void Place(RectTransform rect, float x, float y, float dx, float dy, float width, float height, float scale)
        {
            rect.anchorMin = rect.anchorMax = rect.pivot = new Vector2(x, y);
            rect.anchoredPosition = new Vector2(dx, dy) * scale;
            rect.sizeDelta = new Vector2(width, height); rect.localScale = Vector3.one * scale;
        }
        private void OnEnable() { previousSize = new Vector2(-1, -1); }
        private void LateUpdate() => ApplyLayout();
    }
}
