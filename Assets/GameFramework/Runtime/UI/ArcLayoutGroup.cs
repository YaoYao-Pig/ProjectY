using System;
using UnityEngine;
using UnityEngine.UI;

namespace ProjectY.UI
{
    /// <summary>Places upright status icons along the front arc of a ground HUD.</summary>
    [ExecuteAlways, DefaultExecutionOrder(1100), DisallowMultipleComponent]
    public sealed class ArcLayoutGroup : LayoutGroup
    {
        [SerializeField] private Canvas worldCanvas;
        [SerializeField, Min(1)] private int columns = 6;
        [SerializeField, Min(1)] private float radius = 1.9f;
        [SerializeField] private Vector2 cellSize = new Vector2(24, 22);
        [SerializeField] private Vector2 spacing = new Vector2(4, 6);
        private Quaternion previousFacing;
        private Vector2 previousSize;

        public override void CalculateLayoutInputHorizontal()
        {
            base.CalculateLayoutInputHorizontal();
            SetLayoutInputForAxis(0, 0, -1, 0);
        }

        public override void CalculateLayoutInputVertical() => SetLayoutInputForAxis(0, 0, -1, 1);
        public override void SetLayoutHorizontal() => Arrange();
        public override void SetLayoutVertical() => Arrange();

        private void LateUpdate()
        {
            if (rectChildren.Count == 0) return;
            var facing = Facing();
            if (facing != previousFacing || rectTransform.rect.size != previousSize) Arrange();
        }

        private Camera WorldCamera()
        {
            if (worldCanvas == null) throw new InvalidOperationException("ArcLayoutGroup requires its HUD Canvas binding.");
            return worldCanvas.renderMode == RenderMode.WorldSpace ? worldCanvas.worldCamera : null;
        }

        private Quaternion Facing()
        {
            var camera = WorldCamera();
            return camera != null ? Quaternion.Inverse(transform.rotation) * camera.transform.rotation : Quaternion.identity;
        }

        private void Arrange()
        {
            if (rectChildren.Count == 0) return;
            var camera = WorldCamera();
            var facing = Facing();
            var rect = rectTransform.rect;
            m_Tracker.Clear();
            float projection = camera != null ? Mathf.Max(.2f, Mathf.Abs(camera.transform.forward.y)) : 1;
            float rx = rect.width * .5f * radius, ry = rect.height * .5f * radius;
            for (int i = 0; i < rectChildren.Count; i++)
            {
                int row = i / columns, count = Mathf.Min(columns, rectChildren.Count - row * columns);
                float rowOffset = row * (cellSize.y + spacing.y) / projection;
                float angle = (i % columns - (count - 1) * .5f) * (cellSize.x + spacing.x) / (rx + rowOffset);
                var child = rectChildren[i];
                m_Tracker.Add(this, child, DrivenTransformProperties.All);
                child.anchorMin = child.anchorMax = child.pivot = new Vector2(.5f, .5f);
                child.sizeDelta = cellSize;
                child.localScale = Vector3.one;
                child.localRotation = facing;
                // Lift just enough to keep the billboard above the ground; row count never lifts the whole strip.
                child.localPosition = new Vector3(rect.center.x + Mathf.Sin(angle) * (rx + rowOffset),
                    rect.center.y - Mathf.Cos(angle) * (ry + rowOffset), camera != null ? -(cellSize.y * .5f + 3) : 0);
            }
            previousFacing = facing;
            previousSize = rect.size;
        }

#if UNITY_EDITOR
        public void SetEditorBindings(Canvas canvas) { worldCanvas = canvas; SetDirty(); }
#endif
    }
}
