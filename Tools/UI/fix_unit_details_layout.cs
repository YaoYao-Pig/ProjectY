// Precise correction for the freshly generated UnitDetails assets: measured Noto Sans CJK TMP line heights.
// No runtime source change, compilation, Refresh, Play transition or unrelated prefab modification.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode||UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Idle Edit Mode required");
var config=UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.UI.PanelConfig>(ProjectY.UI.PanelConfig.AssetPath);
var definition=config.Get("UnitDetails");var root=UnityEditor.PrefabUtility.LoadPrefabContents(definition.PrefabPath);
try{
    var reference=root.GetComponent<ProjectY.UI.LuaReference>();
    System.Action<string,float,float> fit=(key,y,height)=>{
        var r=reference.GetUITxt(key).rectTransform;
        r.SetSizeWithCurrentAnchors(RectTransform.Axis.Vertical,height);
        r.anchoredPosition=new Vector2(r.anchoredPosition.x,-y);
    };
    fit("Title",14,46);fit("TargetTitle",102,30);fit("TargetName",98,40);
    fit("AttributeTitle",143,30);fit("TraitTitle",143,30);fit("Cost",516,28);fit("Result",547,28);
    reference.ValidateBindings();UnityEditor.PrefabUtility.SaveAsPrefabAsset(root,definition.PrefabPath);
}finally{UnityEditor.PrefabUtility.UnloadPrefabContents(root);}
// Long localized names increase a target row's height instead of clipping its title or subtitle.
var target=config.Get("InspectionTarget");root=UnityEditor.PrefabUtility.LoadPrefabContents(target.PrefabPath);
try{
    var reference=root.GetComponent<ProjectY.UI.LuaReference>();
    var element=root.GetComponent<UnityEngine.UI.LayoutElement>();if(element==null)element=root.AddComponent<UnityEngine.UI.LayoutElement>();
    element.minHeight=66;element.preferredHeight=-1;
    var layout=root.GetComponent<UnityEngine.UI.VerticalLayoutGroup>();if(layout==null)layout=root.AddComponent<UnityEngine.UI.VerticalLayoutGroup>();
    layout.padding=new RectOffset(14,10,6,6);layout.spacing=2;layout.childControlWidth=true;layout.childControlHeight=true;
    layout.childForceExpandWidth=true;layout.childForceExpandHeight=false;
    var selected=reference.Get("Selected");var ignored=selected.GetComponent<UnityEngine.UI.LayoutElement>();
    if(ignored==null)ignored=selected.gameObject.AddComponent<UnityEngine.UI.LayoutElement>();ignored.ignoreLayout=true;
    reference.ValidateBindings();UnityEditor.PrefabUtility.SaveAsPrefabAsset(root,target.PrefabPath);
}finally{UnityEditor.PrefabUtility.UnloadPrefabContents(root);}
return "Raised the seven measured text rectangles without reducing fonts; target rows now grow with long titles. Saved only UnitDetails and InspectionTarget.";
