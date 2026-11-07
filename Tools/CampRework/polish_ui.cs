// Native art/layout pass after CampAssets.Sync. No project compilation or Play.
var path="Assets/DynamicAsset/UI/Prefabs/Camp/CampPanel.prefab";
var root=PrefabUtility.LoadPrefabContents(path);
try
{
    var view=root.GetComponent<ProjectY.UI.CampPanelView>();var l=view.EditorLayout;
    var ink=new Color(.20f,.23f,.19f);var muted=new Color(.39f,.43f,.35f);var accent=new Color(.40f,.30f,.15f);var paper=new Color(.93f,.89f,.77f);
    l.PanelTitle.color=accent;l.PanelSubtitle.color=muted;l.DetailTitle.color=accent;l.DetailText.color=ink;l.Cost.color=accent;l.Reason.color=new Color(.52f,.27f,.16f);
    l.StorageName.color=accent;l.StorageDetail.color=ink;
    var template=l.EntryTemplate;template.GetComponent<UnityEngine.UI.Image>().sprite=null;template.GetComponent<UnityEngine.UI.Image>().color=new Color(.12f,.18f,.15f);
    template.Title.color=paper;template.Title.fontSize=17;template.Title.rectTransform.sizeDelta=new Vector2(155,40);
    template.Subtitle.color=new Color(.68f,.74f,.64f);template.Subtitle.fontSize=12;
    var stripe=template.Selection;stripe.sprite=null;stripe.type=UnityEngine.UI.Image.Type.Simple;stripe.color=new Color(.84f,.72f,.45f);
    stripe.rectTransform.anchorMin=Vector2.zero;stripe.rectTransform.anchorMax=new Vector2(0,1);stripe.rectTransform.pivot=new Vector2(0,.5f);stripe.rectTransform.offsetMin=Vector2.zero;stripe.rectTransform.offsetMax=new Vector2(3,0);
    var m=l.MaterialTemplate;m.GetComponent<UnityEngine.UI.Image>().sprite=null;m.GetComponent<UnityEngine.UI.Image>().color=new Color(.84f,.80f,.67f);
    m.Button.transition=UnityEngine.UI.Selectable.Transition.None;m.Title.color=ink;m.Subtitle.color=muted;
    var previewSurface=root.transform.Find("Overlay/Workshop/ModelFrame").GetComponent<UnityEngine.UI.Image>();previewSurface.color=new Color(.57f,.62f,.54f);
    root.transform.Find("Overlay/Workshop/ModelFrame/ModelLabel").GetComponent<TMPro.TMP_Text>().color=ink;
    var white=AssetDatabase.GetBuiltinExtraResource<Sprite>("UI/Skin/UISprite.psd");
    var cell=l.Inventory.EditorLayout.CellTemplate;cell.sprite=null;cell.type=UnityEngine.UI.Image.Type.Simple;cell.color=new Color(.19f,.25f,.20f);
    var slot=l.Inventory.EditorLayout.Template.GetComponent<UnityEngine.UI.Image>();slot.sprite=null;slot.type=UnityEngine.UI.Image.Type.Simple;
    var warehouse=new SerializedObject(l.Warehouse);var grid=(RectTransform)warehouse.FindProperty("grid").objectReferenceValue;
    grid.anchorMin=grid.anchorMax=grid.pivot=new Vector2(0,1);grid.anchoredPosition=Vector2.zero;grid.sizeDelta=new Vector2(432,360);
    var warehouseScroll=(UnityEngine.UI.ScrollRect)warehouse.FindProperty("scroll").objectReferenceValue;warehouseScroll.viewport.sizeDelta=new Vector2(432,360);warehouseScroll.viewport.anchoredPosition=new Vector2(672,-173);
    // Match cell sizes without stretching a grid twice through its anchors.
    var bag=l.Inventory.EditorLayout.Grid;bag.anchoredPosition=new Vector2(90,-173);
    var storage=(RectTransform)l.Storage.transform;
    var bagSurface=(RectTransform)storage.Find("BagSurface");var storeSurface=(RectTransform)storage.Find("WarehouseSurface");
    bagSurface.sizeDelta=new Vector2(566,458);storeSurface.sizeDelta=new Vector2(566,458);
    l.Inventory.EditorLayout.GridSize=new Vector2(520,360);
    for(int i=0;i<l.Facilities.Length;i++)
    {
        var button=l.Facilities[i];var image=button.GetComponent<UnityEngine.UI.Image>();button.targetGraphic=null;
        if(image!=null)UnityEngine.Object.DestroyImmediate(image);
        var tag=button.GetComponent<ProjectY.UI.CampFacilityTagGraphic>();if(tag==null)tag=button.gameObject.AddComponent<ProjectY.UI.CampFacilityTagGraphic>();
        tag.Bind(l.Scene,new[]{1,4,3,2}[i]);button.targetGraphic=tag;button.transition=UnityEngine.UI.Selectable.Transition.None;
        var rect=(RectTransform)button.transform;rect.sizeDelta=new Vector2(176,66);
        l.FacilityTitles[i].fontSize=19;l.FacilityTitles[i].rectTransform.anchoredPosition=new Vector2(17,-8);l.FacilityTitles[i].rectTransform.sizeDelta=new Vector2(142,25);l.FacilityTitles[i].color=new Color(.91f,.79f,.53f);
        l.FacilityStates[i].fontSize=11;l.FacilityStates[i].rectTransform.anchoredPosition=new Vector2(15,-35);l.FacilityStates[i].rectTransform.sizeDelta=new Vector2(146,18);l.FacilityStates[i].color=new Color(.76f,.79f,.67f);
    }
    var reference=root.GetComponent<ProjectY.UI.LuaReference>();var refs=new System.Collections.Generic.List<ProjectY.UI.LuaReference.Entry>(reference.GetEditorBindings());
    refs.RemoveAll(e=>e.Key=="Header");refs.Add(new ProjectY.UI.LuaReference.Entry("Header",(RectTransform)root.transform.Find("Header")));reference.SetEditorBindings(refs.ToArray());reference.ValidateBindings();
    PrefabUtility.SaveAsPrefabAsset(root,path);ProjectY.Editor.LuaViewHints.Export(reference,"CampPanelView");
    return "Camp typography contrast, restrained row styling, grid anchors and header binding saved.";
}
finally{PrefabUtility.UnloadPrefabContents(root);}
