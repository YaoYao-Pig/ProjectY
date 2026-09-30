using System;
using UnityEngine;
using XLua;

namespace ProjectY.UI
{
    /// <summary>Projects a target into a screen canvas. Never changes target/gameplay state.</summary>
    [LuaCallCSharp, DisallowMultipleComponent]
    public sealed class UIFollower : MonoBehaviour
    {
        [SerializeField] private RectTransform content;
        [SerializeField] private CanvasGroup visibility;
        [SerializeField] private bool interactiveChildren;
        [SerializeField] private Vector3 worldOffset=new Vector3(0,.32f,0);
        [SerializeField] private Vector2 screenOffset=new Vector2(0,4);
        [SerializeField] private float referenceDistance=18,referenceOrthoSize=12,minScale=.75f,maxScale=1;
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
        public bool ProjectedVisible { get; private set; }
        public float Depth { get; private set; }
        public Rect Bounds => new Rect((Vector2)content.localPosition-Vector2.Scale(content.pivot,content.rect.size)*content.localScale.x,content.rect.size*content.localScale.x);
        public void Bind(Camera camera,Transform anchor,Canvas overlay)
        {
            if(camera==null||anchor==null||overlay==null) throw new ArgumentException("UIFollower requires camera, target and screen canvas.");
            if(orthographicFade.x<=0||orthographicFade.y<=orthographicFade.x||perspectiveFade.x<=0||perspectiveFade.y<=perspectiveFade.x)
                throw new InvalidOperationException("UIFollower fade ranges require 0 < start < end.");
            worldCamera=camera;target=anchor;canvas=overlay.rootCanvas;container=(RectTransform)content.parent;
            screenMode=false;
            if(canvas.renderMode==RenderMode.WorldSpace) throw new InvalidOperationException("UIFollower requires a screen-space Canvas.");
        }
        public void BindScreen(Canvas overlay,Vector2 point)
        {
            if(overlay==null||overlay.rootCanvas.renderMode==RenderMode.WorldSpace) throw new ArgumentException("Screen point requires screen Canvas.");
            canvas=overlay.rootCanvas;container=(RectTransform)content.parent;screenPoint=point;screenMode=true;target=null;worldCamera=null;
        }
        public void SetScreenPoint(Vector2 point) {screenPoint=point;}
        public void Clear() {target=null;worldCamera=null;canvas=null;screenMode=false;SetVisible(false);}
        public bool Project()
        {
            if(screenMode&&canvas!=null)
            {
                var screenCanvasCamera=canvas.renderMode==RenderMode.ScreenSpaceOverlay?null:canvas.worldCamera;
                if(!new Rect(0,0,Screen.width,Screen.height).Contains(screenPoint)||!RectTransformUtility.ScreenPointToLocalPointInRectangle(container,screenPoint,screenCanvasCamera,out projected))
                {SetVisible(false);return false;}
                projected+=screenOffset;content.localScale=Vector3.one;content.localRotation=Quaternion.identity;content.localPosition=new Vector3(projected.x,projected.y,0);Depth=0;SetVisible(true);return true;
            }
            if(target==null||worldCamera==null||canvas==null) {SetVisible(false);return false;}
            var screen=worldCamera.WorldToScreenPoint(target.position+worldOffset);Depth=screen.z;
            var rect=worldCamera.pixelRect;
            if(screen.z<=worldCamera.nearClipPlane||screen.z>=worldCamera.farClipPlane||!rect.Contains(new Vector2(screen.x,screen.y)))
            {SetVisible(false);return false;}
            var range=worldCamera.orthographic?orthographicFade:perspectiveFade;
            var zoom=worldCamera.orthographic?worldCamera.orthographicSize:
                screen.z*Mathf.Tan(worldCamera.fieldOfView*.5f*Mathf.Deg2Rad)/Mathf.Tan(30*Mathf.Deg2Rad);
            var alpha=1-Mathf.SmoothStep(0,1,Mathf.InverseLerp(range.x,range.y,zoom));
            if(alpha<=0) {SetVisible(false);return false;}
            var camera=canvas.renderMode==RenderMode.ScreenSpaceOverlay?null:canvas.worldCamera;
            if(!RectTransformUtility.ScreenPointToLocalPointInRectangle(container,screen,camera,out projected)) {SetVisible(false);return false;}
            projected+=screenOffset;
            var scale=worldCamera.orthographic?referenceOrthoSize/worldCamera.orthographicSize:
                referenceDistance/screen.z*Mathf.Tan(30*Mathf.Deg2Rad)/Mathf.Tan(worldCamera.fieldOfView*.5f*Mathf.Deg2Rad);
            content.localScale=Vector3.one*Mathf.Clamp(scale,minScale,maxScale);
            content.localRotation=Quaternion.identity;
            // ScreenPointToLocalPoint returns parent-local coordinates, not anchor-relative coordinates.
            content.localPosition=new Vector3(projected.x,projected.y,0);SetAlpha(alpha);return true;
        }
        public void Lift(float amount)
        {
            var half=content.rect.height*content.localScale.y*.5f;
            content.localPosition=new Vector3(projected.x,Mathf.Min(projected.y+amount,container.rect.yMax-half),0);
        }
        private void SetVisible(bool value)
        {SetAlpha(value?1:0);}
        private void SetAlpha(float alpha)
        {ProjectedVisible=alpha>0;visibility.alpha=alpha;visibility.interactable=interactiveChildren&&ProjectedVisible;visibility.blocksRaycasts=interactiveChildren&&ProjectedVisible;}
#if UNITY_EDITOR
        [BlackList] public void SetEditorBindings(RectTransform rect,CanvasGroup group) {content=rect;visibility=group;}
#endif
    }
}
