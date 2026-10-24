using UnityEngine;

namespace ProjectY.Samples
{
    /// <summary>Orthographic camera presentation shared by travel, exploration and battle.</summary>
    public sealed class StrategyCameraRig
    {
        private Vector3 focus;
        private float zoom = 20, yaw = -25, pitch = 52;
        private bool zoomAnchored;
        private Vector3 zoomAnchor;
        private Vector2 zoomPointer;
        private Rect zoomViewport;

        public Vector3 Focus { get => focus; set { focus = value; zoomAnchored = false; } }
        public float Zoom { get => zoom; set { zoom = value; zoomAnchored = false; } }
        public float Yaw { get => yaw; set { yaw = value; zoomAnchored = false; } }
        public float Pitch { get => pitch; set { pitch = value; zoomAnchored = false; } }
        public Vector3 RenderFocus { get; private set; }
        public float RenderZoom { get; private set; } = 20;
        public float RenderYaw { get; private set; } = -25;
        public float RenderPitch { get; private set; } = 52;

        public void Snap()
        {
            RenderFocus = focus; RenderZoom = zoom; RenderYaw = yaw; RenderPitch = pitch;
            zoomAnchored = false;
        }

        // Freeze at the displayed pose when another camera or a manual drag takes ownership.
        public void Stop()
        {
            focus = RenderFocus; zoom = RenderZoom; yaw = RenderYaw; pitch = RenderPitch;
            zoomAnchored = false;
        }

        public void Tick(float deltaTime)
        {
            if (deltaTime <= 0) return;
            RenderFocus = Vector3.Lerp(RenderFocus, focus, 1 - Mathf.Exp(-deltaTime / .10f));
            float rotationBlend = 1 - Mathf.Exp(-deltaTime / .035f);
            RenderYaw = Mathf.LerpAngle(RenderYaw, yaw, rotationBlend);
            RenderPitch = Mathf.Lerp(RenderPitch, pitch, rotationBlend);
            // Log space preserves the same proportional response at every map scale.
            RenderZoom = Mathf.Exp(Mathf.Lerp(Mathf.Log(RenderZoom), Mathf.Log(zoom), 1 - Mathf.Exp(-deltaTime / .075f)));
            bool zoomComplete = Mathf.Abs(RenderZoom - zoom) <= zoom * .0001f;
            if (zoomComplete) RenderZoom = zoom;
            if (zoomAnchored)
            {
                RenderFocus = zoomAnchor - GroundOffset(zoomPointer - zoomViewport.center, zoomViewport.height, RenderZoom, RenderYaw, RenderPitch);
                focus = RenderFocus;
                if (zoomComplete) zoomAnchored = false;
            }
        }

        public void Rotate(Vector2 pixels)
        {
            zoomAnchored = false;
            yaw = Mathf.Repeat(yaw + pixels.x * .25f + 180, 360) - 180;
            pitch = Mathf.Clamp(pitch - pixels.y * .20f, 20, 85);
        }

        public void Pan(Vector2 screenPixels, float viewportHeight)
        {
            // Direct manipulation must not chase an older follow/recenter/zoom target.
            Stop();
            focus += GroundOffset(screenPixels, viewportHeight, RenderZoom, RenderYaw, RenderPitch);
            RenderFocus = focus;
        }

        public void PanKeyboard(Vector2 input, float viewportHeight, float deltaTime)
        {
            Pan(Vector2.ClampMagnitude(input, 1) * (viewportHeight * .55f * deltaTime), viewportHeight);
        }

        public void Scroll(float steps, Vector2 pointer, Rect viewport, float minZoom, float maxZoom)
        {
            float target = Mathf.Clamp(zoom * Mathf.Exp(-steps * .12f), minZoom, maxZoom);
            if (Mathf.Approximately(target, zoom)) return;
            focus = RenderFocus; yaw = RenderYaw; pitch = RenderPitch;
            zoom = target; zoomPointer = pointer; zoomViewport = viewport;
            zoomAnchor = RenderFocus + GroundOffset(pointer - viewport.center, viewport.height, RenderZoom, RenderYaw, RenderPitch);
            zoomAnchored = true;
        }

        // Intersection with the horizontal plane through the focus. Compensating for
        // pitch makes one screen pixel of dragging remain one pixel at any view angle.
        public static Vector3 GroundOffset(Vector2 pixels, float viewportHeight, float size, float yaw, float pitch)
        {
            var planar = new Vector3(pixels.x, 0, pixels.y / Mathf.Sin(pitch * Mathf.Deg2Rad));
            return Quaternion.Euler(0, yaw, 0) * planar * (2 * size / viewportHeight);
        }

        public static float FitSize(Bounds bounds, float yaw, float pitch, float aspect, float minimum)
        {
            var rotation = Quaternion.Euler(pitch, yaw, 0);
            var right = rotation * Vector3.right; var up = rotation * Vector3.up;
            var extent = bounds.extents;
            float horizontal = Mathf.Abs(right.x) * extent.x + Mathf.Abs(right.y) * extent.y + Mathf.Abs(right.z) * extent.z;
            float vertical = Mathf.Abs(up.x) * extent.x + Mathf.Abs(up.y) * extent.y + Mathf.Abs(up.z) * extent.z;
            return Mathf.Max(minimum, Mathf.Max(vertical, horizontal / aspect) * 1.18f);
        }
    }
}
