using System;
using UnityEngine;
using XLua;

namespace ProjectY.UI
{
    /// <summary>Follows a target in screen or world UI. Never changes target/gameplay state.</summary>
    [LuaCallCSharp, DisallowMultipleComponent]
    public sealed class UIFollower : MonoBehaviour
    {
        [SerializeField] private RectTransform content;
        [SerializeField] private CanvasGroup visibility;
        [SerializeField] private bool interactiveChildren;
        [SerializeField] private Vector3 worldOffset=new Vector3(0,.32f,0);
        [SerializeField] private Vector2 screenOffset=new Vector2(0,4);
        [SerializeField] private float referenceDistance=18,referenceOrthoSize=12,minScale=.75f,maxScale=1;
        [Header("Ground footprint (optional)")]
        [SerializeField] private bool groundPlane;
        [SerializeField, Min(.01f)] private float groundRadius=.8f;
        [SerializeField] private Canvas worldCanvas;
        [Header("Zoom fade (CanvasGroup alpha)")]
        [Tooltip("正交相机尺寸：X 开始淡出，Y 完全隐藏。与相机的世界坐标距离无关。")]
        [SerializeField] private Vector2 orthographicFade=new Vector2(12,20);
        [Tooltip("透视相机在 60 度 FOV 下的等效深度：X 开始淡出，Y 完全隐藏。")]
        [SerializeField] private Vector2 perspectiveFade=new Vector2(18,30);
        private Camera worldCamera;
        private Transform target;
        private Canvas canvas;
        private RectTransform container;
        private Vector2 projected;
        private bool screenMode;
        private Vector2 screenPoint;
        private bool retainPosition;
        private Vector3 lastTargetPosition;
        private Transform worldParent;
        public bool ProjectedVisible { get; private set; }
        public float Depth { get; private set; }
        public Rect Bounds => new Rect((Vector2)content.localPosition-Vector2.Scale(content.pivot,content.rect.size)*content.localScale.x,content.rect.size*content.localScale.x);
        public void Bind(Camera camera,Transform anchor,Canvas overlay)
        {
            if(camera==null||anchor==null||overlay==null) throw new ArgumentException("UIFollower requires camera, target and screen canvas.");
            if(orthographicFade.x<=0||orthographicFade.y<=orthographicFade.x||perspectiveFade.x<=0||perspectiveFade.y<=perspectiveFade.x)
                throw new InvalidOperationException("UIFollower fade ranges require 0 < start < end.");
            worldCamera=camera;target=anchor;canvas=overlay.rootCanvas;
            SetCanvasMode(false,overlay);container=(RectTransform)content.parent;
            screenMode=false;retainPosition=false;lastTargetPosition=anchor.position;
            if(canvas.renderMode==RenderMode.WorldSpace) throw new InvalidOperationException("UIFollower requires a screen-space Canvas.");
        }
        public void BindScreen(Canvas overlay,Vector2 point)
        {
            if(overlay==null||overlay.rootCanvas.renderMode==RenderMode.WorldSpace) throw new ArgumentException("Screen point requires screen Canvas.");
            canvas=overlay.rootCanvas;SetCanvasMode(true,overlay);container=(RectTransform)content.parent;screenPoint=point;screenMode=true;target=null;worldCamera=null;retainPosition=false;
        }
        internal void BindPoint(Camera camera,Vector3 point,Canvas overlay)
        {
            if(camera==null || overlay==null || overlay.rootCanvas.renderMode==RenderMode.WorldSpace)throw new ArgumentException("World point requires camera and screen Canvas.");
            if(orthographicFade.x<=0 || orthographicFade.y<=orthographicFade.x || perspectiveFade.x<=0 || perspectiveFade.y<=perspectiveFade.x)
                throw new InvalidOperationException("UIFollower fade ranges require 0 < start < end.");
            worldCamera=camera;canvas=overlay.rootCanvas;container=(RectTransform)content.parent;target=null;
            screenMode=false;retainPosition=true;lastTargetPosition=point;
        }
        public void SetScreenPoint(Vector2 point) {screenPoint=point;}
        public void SetGroundRadius(float radius)
        {if(radius<=0 || float.IsNaN(radius) || float.IsInfinity(radius))throw new ArgumentOutOfRangeException(nameof(radius));groundRadius=radius;}
        public void Clear() {target=null;worldCamera=null;canvas=null;screenMode=false;retainPosition=false;SetVisible(false);}
        // A retiring presentation can finish after its world object has been released.
        public void RetainLastWorldPosition()
        {if(target!=null)lastTargetPosition=target.position;retainPosition=true;}
        private void SetCanvasMode(bool screen,Canvas overlay)
        {
            if(worldCanvas==null)return;
            if(worldCanvas.transform==content)
            {
                if(worldParent==null)worldParent=content.parent;
                content.SetParent(screen?overlay.transform:worldParent,false);
                worldCanvas.renderMode=screen?RenderMode.ScreenSpaceOverlay:RenderMode.WorldSpace;
            }
            worldCanvas.worldCamera=screen?null:worldCamera;
        }
        public bool Project()
        {
            if(screenMode&&canvas!=null)
            {
                var screenCanvasCamera=canvas.renderMode==RenderMode.ScreenSpaceOverlay?null:canvas.worldCamera;
                if(!new Rect(0,0,Screen.width,Screen.height).Contains(screenPoint)||!RectTransformUtility.ScreenPointToLocalPointInRectangle(container,screenPoint,screenCanvasCamera,out projected))
                {SetVisible(false);return false;}
                projected+=screenOffset;content.localScale=Vector3.one*CanvasRelativeScale();content.localRotation=Quaternion.identity;content.localPosition=new Vector3(projected.x,projected.y,0);
                if(groundPlane)content.sizeDelta=new Vector2(128,82);
                Depth=0;SetVisible(true);return true;
            }
            if((target==null&&!retainPosition)||worldCamera==null||canvas==null) {SetVisible(false);return false;}
            if(target!=null)lastTargetPosition=target.position;
            var screen=worldCamera.WorldToScreenPoint(lastTargetPosition+worldOffset);Depth=screen.z;
            var rect=worldCamera.pixelRect;
            if(screen.z<=worldCamera.nearClipPlane||screen.z>=worldCamera.farClipPlane||!rect.Contains(new Vector2(screen.x,screen.y)))
            {SetVisible(false);return false;}
            var range=worldCamera.orthographic?orthographicFade:perspectiveFade;
            var zoom=worldCamera.orthographic?worldCamera.orthographicSize:
                screen.z*Mathf.Tan(worldCamera.fieldOfView*.5f*Mathf.Deg2Rad)/Mathf.Tan(30*Mathf.Deg2Rad);
            var alpha=1-Mathf.SmoothStep(0,1,Mathf.InverseLerp(range.x,range.y,zoom));
            if(alpha<=0) {SetVisible(false);return false;}
            if(worldCanvas!=null)
            {
                ProjectWorld();SetAlpha(alpha);return true;
            }
            var camera=canvas.renderMode==RenderMode.ScreenSpaceOverlay?null:canvas.worldCamera;
            if(!RectTransformUtility.ScreenPointToLocalPointInRectangle(container,screen,camera,out projected)) {SetVisible(false);return false;}
            projected+=screenOffset;
            var scale=worldCamera.orthographic?referenceOrthoSize/worldCamera.orthographicSize:
                referenceDistance/screen.z*Mathf.Tan(30*Mathf.Deg2Rad)/Mathf.Tan(worldCamera.fieldOfView*.5f*Mathf.Deg2Rad);
            if(groundPlane)
            {
                // Camera-relative ground axes keep the ellipse centred on the feet when orbiting.
                var right=Vector3.Cross(Vector3.up,worldCamera.transform.forward).normalized;
                if(right.sqrMagnitude<.01f)right=worldCamera.transform.right;
                var edge=worldCamera.WorldToScreenPoint(lastTargetPosition+worldOffset+right*groundRadius);
                if(!RectTransformUtility.ScreenPointToLocalPointInRectangle(container,edge,camera,out var localEdge)){SetVisible(false);return false;}
                scale=Vector2.Distance(localEdge,projected-screenOffset)/64;
                content.sizeDelta=new Vector2(128,128*Mathf.Clamp(Mathf.Abs(worldCamera.transform.forward.y),.2f,1));
                content.localScale=Vector3.one*scale;
            }
            else content.localScale=Vector3.one*Mathf.Clamp(scale,minScale,maxScale)*CanvasRelativeScale();
            content.localRotation=Quaternion.identity;
            // ScreenPointToLocalPoint returns parent-local coordinates, not anchor-relative coordinates.
            content.localPosition=new Vector3(projected.x,projected.y,0);SetAlpha(alpha);return true;
        }
        private void ProjectWorld()
        {
            float unitScale;
            if(groundPlane)
            {
                var forward=Vector3.ProjectOnPlane(worldCamera.transform.forward,Vector3.up).normalized;
                if(forward.sqrMagnitude<.01f)forward=Vector3.ProjectOnPlane(worldCamera.transform.up,Vector3.up).normalized;
                unitScale=groundRadius/64;
                content.sizeDelta=new Vector2(128,128);
                content.SetPositionAndRotation(lastTargetPosition+worldOffset,Quaternion.LookRotation(Vector3.down,forward));
                SetWorldScale(unitScale);
            }
            else
            {
                var zoomScale=worldCamera.orthographic?referenceOrthoSize/worldCamera.orthographicSize:
                    referenceDistance/Depth*Mathf.Tan(30*Mathf.Deg2Rad)/Mathf.Tan(worldCamera.fieldOfView*.5f*Mathf.Deg2Rad);
                var unitsPerPixel=(worldCamera.orthographic?2*worldCamera.orthographicSize:2*Depth*Mathf.Tan(worldCamera.fieldOfView*.5f*Mathf.Deg2Rad))/worldCamera.pixelHeight;
                unitScale=unitsPerPixel*canvas.scaleFactor*Mathf.Clamp(zoomScale,minScale,maxScale);
                content.SetPositionAndRotation(lastTargetPosition+worldOffset+(worldCamera.transform.right*screenOffset.x+worldCamera.transform.up*screenOffset.y)*unitScale,worldCamera.transform.rotation);
                SetWorldScale(unitScale);
            }
        }
        private void SetWorldScale(float size)
        {var parentScale=content.parent.lossyScale;content.localScale=new Vector3(size/parentScale.x,size/parentScale.y,size/parentScale.z);}
        public void Lift(float amount)
        {
            var half=content.rect.height*content.localScale.y*.5f;
            content.localPosition=new Vector3(projected.x,Mathf.Min(projected.y+amount,container.rect.yMax-half),0);
        }
        private void SetVisible(bool value)
        {SetAlpha(value?1:0);}
        private float CanvasRelativeScale() => canvas.transform.lossyScale.x/container.lossyScale.x;
        private void SetAlpha(float alpha)
        {ProjectedVisible=alpha>0;visibility.alpha=alpha;visibility.interactable=interactiveChildren&&ProjectedVisible;visibility.blocksRaycasts=interactiveChildren&&ProjectedVisible;}
#if UNITY_EDITOR
        [BlackList] public void SetEditorBindings(RectTransform rect,CanvasGroup group) {content=rect;visibility=group;}
#endif
    }
}
