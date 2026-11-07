// Reapply after rebuilding CharacterGrowthPanel. Adds a bound, scrollable memory area without changing existing text bindings.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode)throw new System.Exception("Edit Mode required");
const string path="Assets/DynamicAsset/UI/Prefabs/Adventure/CharacterGrowthPanel.prefab";
var root=UnityEditor.PrefabUtility.LoadPrefabContents(path);
try
{
    var reference=root.GetComponent<ProjectY.UI.LuaReference>();
    if(reference.GetEditorBindings().Any(entry=>entry.Key=="TraitDetailScroll"))return "Relationship detail scroll already bound";
    var text=reference.GetText("TraitDetail");var rect=text.rectTransform;var parent=rect.parent;
    var container=new GameObject("TraitDetailScroll",typeof(RectTransform),typeof(UnityEngine.UI.Image),typeof(UnityEngine.UI.ScrollRect));
    var area=(RectTransform)container.transform;area.SetParent(parent,false);
    area.anchorMin=rect.anchorMin;area.anchorMax=rect.anchorMax;area.pivot=rect.pivot;area.anchoredPosition=rect.anchoredPosition;area.sizeDelta=rect.sizeDelta;
    container.GetComponent<UnityEngine.UI.Image>().color=new Color(1,1,1,.015f);
    var viewport=new GameObject("Viewport",typeof(RectTransform),typeof(UnityEngine.UI.RectMask2D));
    var view=(RectTransform)viewport.transform;view.SetParent(area,false);view.anchorMin=Vector2.zero;view.anchorMax=Vector2.one;view.offsetMin=Vector2.zero;view.offsetMax=new Vector2(-9,0);
    rect.SetParent(view,false);rect.anchorMin=new Vector2(0,1);rect.anchorMax=new Vector2(1,1);rect.pivot=new Vector2(.5f,1);rect.anchoredPosition=Vector2.zero;rect.sizeDelta=new Vector2(0,area.sizeDelta.y);
    text.verticalOverflow=VerticalWrapMode.Overflow;text.raycastTarget=true;
    var fit=text.gameObject.AddComponent<UnityEngine.UI.ContentSizeFitter>();fit.verticalFit=UnityEngine.UI.ContentSizeFitter.FitMode.PreferredSize;
    var track=new GameObject("MemoryScrollbar",typeof(RectTransform),typeof(UnityEngine.UI.Image),typeof(UnityEngine.UI.Scrollbar));
    var trackRect=(RectTransform)track.transform;trackRect.SetParent(area,false);trackRect.anchorMin=new Vector2(1,0);trackRect.anchorMax=Vector2.one;trackRect.pivot=new Vector2(1,.5f);trackRect.sizeDelta=new Vector2(5,0);trackRect.anchoredPosition=Vector2.zero;
    track.GetComponent<UnityEngine.UI.Image>().color=new Color(.3f,.23f,.12f,.15f);
    var handle=new GameObject("Handle",typeof(RectTransform),typeof(UnityEngine.UI.Image));
    var handleRect=(RectTransform)handle.transform;handleRect.SetParent(trackRect,false);handleRect.anchorMin=Vector2.zero;handleRect.anchorMax=Vector2.one;handleRect.offsetMin=Vector2.zero;handleRect.offsetMax=Vector2.zero;
    var handleImage=handle.GetComponent<UnityEngine.UI.Image>();handleImage.color=new Color(.5f,.35f,.15f,.7f);
    var scrollbar=track.GetComponent<UnityEngine.UI.Scrollbar>();scrollbar.handleRect=handleRect;scrollbar.targetGraphic=handleImage;scrollbar.direction=UnityEngine.UI.Scrollbar.Direction.BottomToTop;
    var scroll=container.GetComponent<UnityEngine.UI.ScrollRect>();scroll.viewport=view;scroll.content=rect;scroll.horizontal=false;scroll.vertical=true;scroll.scrollSensitivity=30;scroll.movementType=UnityEngine.UI.ScrollRect.MovementType.Clamped;
    scroll.verticalScrollbar=scrollbar;scroll.verticalScrollbarVisibility=UnityEngine.UI.ScrollRect.ScrollbarVisibility.AutoHide;
    var bindings=reference.GetEditorBindings().ToList();bindings.Add(new ProjectY.UI.LuaReference.Entry("TraitDetailScroll",scroll));reference.SetEditorBindings(bindings.ToArray());reference.ValidateBindings();
    UnityEditor.PrefabUtility.SaveAsPrefabAsset(root,path);ProjectY.Editor.LuaViewHints.Export(reference,"CharacterGrowthPanelView");
    return new {saved=path,binding="TraitDetailScroll"};
}
finally{UnityEditor.PrefabUtility.UnloadPrefabContents(root);}
