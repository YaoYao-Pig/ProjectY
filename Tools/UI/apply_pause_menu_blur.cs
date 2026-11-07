// Unity MCP, idle Edit Mode. Preserve the saved menu layout while adding its snapshot backdrop.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode||UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Idle Edit Mode required");
var path="Assets/DynamicAsset/UI/Prefabs/Adventure/PauseMenuPanel.prefab";
var root=UnityEditor.PrefabUtility.LoadPrefabContents(path);
try{
    var node=root.transform.Find("BlurBackground");bool created=node==null;
    if(created){
        node=new GameObject("BlurBackground",typeof(RectTransform),typeof(UnityEngine.UI.Image)).transform;
        node.SetParent(root.transform,false);node.SetAsFirstSibling();
        var rect=(RectTransform)node;rect.anchorMin=Vector2.zero;rect.anchorMax=Vector2.one;rect.offsetMin=rect.offsetMax=Vector2.zero;
        var image=node.GetComponent<UnityEngine.UI.Image>();image.raycastTarget=false;image.color=new Color(.72f,.76f,.74f,1);
    }
    var blur=node.GetComponent<ProjectY.UI.Blur>();
    if(blur==null)blur=node.gameObject.AddComponent<ProjectY.UI.Blur>();
    var serialized=new UnityEditor.SerializedObject(blur);
    serialized.FindProperty("captureGroup").objectReferenceValue=root.GetComponent<CanvasGroup>();
    serialized.ApplyModifiedPropertiesWithoutUndo();
    if(created){
        var page=(RectTransform)root.GetComponent<ProjectY.UI.LuaReference>().Get("Page");
        var image=page.GetComponent<UnityEngine.UI.Image>();var color=image.color;color.a=.91f;image.color=color;
    }
    root.GetComponent<ProjectY.UI.LuaReference>().ValidateBindings();
    UnityEditor.PrefabUtility.SaveAsPrefabAsset(root,path);
}finally{UnityEditor.PrefabUtility.UnloadPrefabContents(root);}
return "PauseMenu now contains Image + Blur, with the whole menu excluded from its opening snapshot.";
