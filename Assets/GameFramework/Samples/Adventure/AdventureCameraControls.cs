using UnityEngine;
using UnityEngine.EventSystems;

namespace ProjectY.Samples
{
    public sealed partial class AdventureRuntimeDemo
    {
        private readonly StrategyCameraRig cameraRig = new StrategyCameraRig();
        private int cameraDragButton = -1;
        private Vector2 cameraPointer;
        private bool cameraInputProcessed;
        private Vector3 focus { get => cameraRig.Focus; set => cameraRig.Focus = value; }
        private float zoom { get => cameraRig.Zoom; set => cameraRig.Zoom = value; }
        private float yaw { get => cameraRig.Yaw; set => cameraRig.Yaw = value; }
        private float pitch { get => cameraRig.Pitch; set => cameraRig.Pitch = value; }

        private Rect CameraViewport
        {
            get
            {
                float inset = view.Phase == "battle" ? 0 : Mathf.Min(Screen.width * .7f, mainHud != null ? mainHud.WorldLeftInset : 0);
                return new Rect(inset, 0, Screen.width - inset, Screen.height);
            }
        }

        private bool PointerOverInterface()
        {
            if (!CameraViewport.Contains(Input.mousePosition)) return true;
            if (EventSystem.current != null && EventSystem.current.IsPointerOverGameObject()) return true;
            return showEnvironment && new Rect(Screen.width - 308, 106, 290, 236)
                .Contains(new Vector2(Input.mousePosition.x, Screen.height - Input.mousePosition.y));
        }

        private static bool CameraTextInputFocused()
        {
            var selected = EventSystem.current != null ? EventSystem.current.currentSelectedGameObject : null;
            return selected != null && (selected.TryGetComponent<UnityEngine.UI.InputField>(out var input) && input.isFocused ||
                selected.TryGetComponent<TMPro.TMP_InputField>(out var tmpInput) && tmpInput.isFocused);
        }

        private void ReleaseCameraFollow() { followTravel = false; followParty = false; }

        private void UpdateCameraInput()
        {
            cameraInputProcessed = true;
            var pointer = (Vector2)Input.mousePosition;
            var viewport = CameraViewport;
            if (!new Rect(0, 0, Screen.width, Screen.height).Contains(pointer) || !Application.isFocused)
            { cameraDragButton = -1; return; }
            if (cameraDragButton >= 0 && !Input.GetMouseButton(cameraDragButton)) cameraDragButton = -1;
            bool pointerBlocked = PointerOverInterface();
            if (cameraDragButton < 0 && !pointerBlocked)
            {
                if (Input.GetMouseButtonDown(2)) cameraDragButton = 2;
                else if (Input.GetMouseButtonDown(1)) cameraDragButton = 1;
                if (cameraDragButton >= 0)
                {
                    cameraPointer = pointer; cameraRig.Stop();
                    if (cameraDragButton == 2) ReleaseCameraFollow();
                }
            }
            if (cameraDragButton >= 0)
            {
                var delta = pointer - cameraPointer;
                if (cameraDragButton == 2 && delta.sqrMagnitude > 0)
                { ReleaseCameraFollow(); cameraRig.Pan(-delta, viewport.height); }
                else if (cameraDragButton == 1) cameraRig.Rotate(delta);
                cameraPointer = pointer;
            }
            else if (!pointerBlocked && Input.mouseScrollDelta.y != 0)
            {
                var bounds = HasArea ? areaRenderer.Bounds : mapRenderer.Bounds;
                float maxZoom = StrategyCameraRig.FitSize(bounds, yaw, pitch, viewport.width / viewport.height, 8) * 1.25f;
                ReleaseCameraFollow();
                cameraRig.Scroll(Input.mouseScrollDelta.y, pointer, viewport, 3, maxZoom);
            }
            if (!CameraTextInputFocused() && cameraDragButton < 0)
            {
                if (Input.GetKeyDown(KeyCode.F)) FitMap();
                var input = new Vector2(Input.GetAxisRaw("Horizontal"), Input.GetAxisRaw("Vertical"));
                if (input.sqrMagnitude > 0) { ReleaseCameraFollow(); cameraRig.PanKeyboard(input, viewport.height, Time.unscaledDeltaTime); }
            }
        }

        private void OnApplicationFocus(bool hasFocus)
        {
            if (hasFocus) return;
            cameraDragButton = -1; cameraRig.Stop();
        }
    }
}
