// Focused native update of the four existing facility buttons. No scene rebuild.
var path="Assets/DynamicAsset/UI/Prefabs/Camp/CampPanel.prefab";
var root=PrefabUtility.LoadPrefabContents(path);
try
{
    var l=root.GetComponent<ProjectY.UI.CampPanelView>().EditorLayout;
    int[] ids={1,4,3,2};
    for(int i=0;i<l.Facilities.Length;i++)
    {
        var button=l.Facilities[i];var image=button.GetComponent<UnityEngine.UI.Image>();button.targetGraphic=null;
        if(image!=null)UnityEngine.Object.DestroyImmediate(image);
        var tag=button.GetComponent<ProjectY.UI.CampFacilityTagGraphic>();if(tag==null)tag=button.gameObject.AddComponent<ProjectY.UI.CampFacilityTagGraphic>();
        tag.Bind(l.Scene,ids[i]);button.targetGraphic=tag;button.transition=UnityEngine.UI.Selectable.Transition.None;
        var rect=(RectTransform)button.transform;rect.sizeDelta=new Vector2(176,66);
        l.FacilityTitles[i].fontSize=19;l.FacilityTitles[i].rectTransform.anchoredPosition=new Vector2(17,-8);l.FacilityTitles[i].rectTransform.sizeDelta=new Vector2(142,25);l.FacilityTitles[i].color=new Color(.91f,.79f,.53f);
        l.FacilityStates[i].fontSize=11;l.FacilityStates[i].rectTransform.anchoredPosition=new Vector2(15,-35);l.FacilityStates[i].rectTransform.sizeDelta=new Vector2(146,18);l.FacilityStates[i].color=new Color(.76f,.79f,.67f);
    }
    root.GetComponent<ProjectY.UI.LuaReference>().ValidateBindings();PrefabUtility.SaveAsPrefabAsset(root,path);
    return "Four facility nameplates updated: leather face, brass rim, stitching, rivets, pointer and interaction states.";
}
finally{PrefabUtility.UnloadPrefabContents(root);}
