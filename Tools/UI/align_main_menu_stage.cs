// Native resource adjustment; preserves the saved menu's explicit LuaReference bindings.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode)throw new System.InvalidOperationException("Edit Mode required.");
var stagePath="Assets/DynamicAsset/MainMenu/MainMenuStage.prefab";
var stageRoot=UnityEditor.PrefabUtility.LoadPrefabContents(stagePath);
try
{
    var stage=stageRoot.GetComponent<ProjectY.UI.StartMenuStage>();var serialized=new UnityEditor.SerializedObject(stage);
    var sign=(UnityEngine.Transform)serialized.FindProperty("signpost").objectReferenceValue;
    var map=(UnityEngine.Transform)serialized.FindProperty("mapRoot").objectReferenceValue;
    sign.localPosition=new UnityEngine.Vector3(3.1f,-.18f,5.5f);sign.localScale=UnityEngine.Vector3.one*1.18f;sign.localRotation=UnityEngine.Quaternion.Euler(0,20,0);
    map.parent.localPosition=new UnityEngine.Vector3(-4,.3f,-2);
    serialized.FindProperty("homePosition").vector3Value=new UnityEngine.Vector3(0,5.2f,13.5f);
    serialized.FindProperty("homeTarget").vector3Value=new UnityEngine.Vector3(-1.2f,2,-.5f);
    serialized.FindProperty("homeFieldOfView").floatValue=44;serialized.ApplyModifiedPropertiesWithoutUndo();
    int i=0;foreach(UnityEngine.Transform child in stageRoot.transform)if(child.name=="Tree_Conifer"){child.localScale=UnityEngine.Vector3.one*(1.1f+UnityEngine.Mathf.Abs(UnityEngine.Mathf.Sin(i))*.935f);i++;}
    stage.MapCamera.orthographicSize=2.7f;stage.Pose(0,0,16f/9);
    UnityEditor.PrefabUtility.SaveAsPrefabAsset(stageRoot,stagePath);
}
finally{UnityEditor.PrefabUtility.UnloadPrefabContents(stageRoot);}
var entry=UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.UI.PanelConfig>(ProjectY.UI.PanelConfig.AssetPath).Get("StartMenu");
var root=UnityEditor.PrefabUtility.LoadPrefabContents(entry.PrefabPath);
try
{
    var reference=root.GetComponent<ProjectY.UI.LuaReference>();var home=reference.Get("HomePage").transform;home.Find("HomeHint").gameObject.SetActive(false);
    foreach(string key in new[]{"Start","Load","Settings","About","Quit"})reference.Get(key).GetComponentInChildren<UnityEngine.UI.Text>(true).fontSize=34;
    foreach(string name in new[]{"Brand","Strapline"})
    {
        var text=home.Find(name).GetComponent<UnityEngine.UI.Text>();var rect=text.rectTransform;
        rect.anchorMin=rect.anchorMax=new UnityEngine.Vector2(.63f,1);rect.pivot=new UnityEngine.Vector2(.5f,1);rect.anchoredPosition=new UnityEngine.Vector2(0,name=="Brand"?-40:-100);rect.sizeDelta=new UnityEngine.Vector2(550,name=="Brand"?56:30);text.alignment=UnityEngine.TextAnchor.MiddleCenter;
    }
    foreach(string name in new[]{"Brand","Strapline","PreviewTitle","PreviewCaption"})
    {var node=home.Find(name);var shadow=node.GetComponent<UnityEngine.UI.Shadow>()??node.gameObject.AddComponent<UnityEngine.UI.Shadow>();shadow.effectColor=new UnityEngine.Color(.05f,.09f,.05f,.65f);shadow.effectDistance=new UnityEngine.Vector2(1,-2);}
    reference.ValidateBindings();UnityEditor.PrefabUtility.SaveAsPrefabAsset(root,entry.PrefabPath);
}
finally{UnityEditor.PrefabUtility.UnloadPrefabContents(root);}
UnityEditor.AssetDatabase.SaveAssets();return "Saved left signpost / right miniature layout and upright label projection resources.";
