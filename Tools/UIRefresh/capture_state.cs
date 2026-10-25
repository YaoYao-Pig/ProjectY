// Execute through Unity MCP execute_code. Read-only asset inspection; writes the audit artifact only.
var auditRoot = "Art/UIRefresh/2026-10-25";
System.IO.Directory.CreateDirectory(auditRoot);
var assetPaths = new[] {
    "Assets/DynamicAsset/UI/Prefabs/Equipment/InventoryPanel.prefab",
    "Assets/DynamicAsset/UI/Prefabs/Adventure/CharacterGrowthPanel.prefab",
    "Assets/DynamicAsset/UI/Prefabs/Narrative/MissionJournalPanel.prefab",
    "Assets/DynamicAsset/UI/Prefabs/Narrative/DialoguePanel.prefab",
    "Assets/DynamicAsset/UI/Prefabs/Adventure/StoryEventPanel.prefab",
    "Assets/DynamicAsset/UI/Prefabs/Narrative/DialogueEntryWidget.prefab",
    "Assets/DynamicAsset/UI/Prefabs/Adventure/StoryChoiceWidget.prefab",
    "Assets/DynamicAsset/UI/Prefabs/Narrative/MissionRewardWidget.prefab"
};
System.Func<UnityEngine.Object,string> stableId = value => value == null ? "null" : UnityEditor.GlobalObjectId.GetGlobalObjectIdSlow(value).ToString();
System.Func<UnityEngine.Object,object> serialized = value => {
    var rows = new System.Collections.Generic.List<object>();
    var iterator = new UnityEditor.SerializedObject(value).GetIterator();
    while(iterator.Next(true)) {
        object item;
        switch(iterator.propertyType) {
            case UnityEditor.SerializedPropertyType.ObjectReference: item=stableId(iterator.objectReferenceValue); break;
            case UnityEditor.SerializedPropertyType.Integer: item=iterator.longValue; break;
            case UnityEditor.SerializedPropertyType.Boolean: item=iterator.boolValue; break;
            case UnityEditor.SerializedPropertyType.Float: item=iterator.doubleValue; break;
            case UnityEditor.SerializedPropertyType.String: item=iterator.stringValue; break;
            case UnityEditor.SerializedPropertyType.Color: item=iterator.colorValue.ToString("R"); break;
            case UnityEditor.SerializedPropertyType.Vector2: item=iterator.vector2Value.ToString("R"); break;
            case UnityEditor.SerializedPropertyType.Vector3: item=iterator.vector3Value.ToString("R"); break;
            case UnityEditor.SerializedPropertyType.Vector4: item=iterator.vector4Value.ToString("R"); break;
            case UnityEditor.SerializedPropertyType.Quaternion: item=iterator.quaternionValue.ToString("R"); break;
            case UnityEditor.SerializedPropertyType.Enum: item=iterator.intValue; break;
            default: item=iterator.propertyType.ToString(); break;
        }
        rows.Add(new {property=iterator.propertyPath,value=item});
    }
    return rows;
};
var assets = new System.Collections.Generic.List<object>();
foreach(var path in assetPaths) {
    var root = UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(path);
    if(root==null) throw new System.Exception("Missing prefab: "+path);
    var reference=root.GetComponent<ProjectY.UI.LuaReference>();
    reference.ValidateBindings();
    assets.Add(new {
        path=path,
        bindings=reference.GetEditorBindings().Select(e=>new {key=e.Key,target=stableId(e.Target),type=e.Target.GetType().FullName,path=UnityEditor.AnimationUtility.CalculateTransformPath(e.Target.transform,root.transform)}).ToArray(),
        localized=reference.GetEditorLocalizations().Select(e=>new {id=e.Id,target=stableId(e.Target)}).ToArray(),
        protectedViews=root.GetComponentsInChildren<ProjectY.UI.InventoryCharacterView>(true).Select(view=>new {
            id=stableId(view),path=UnityEditor.AnimationUtility.CalculateTransformPath(view.transform,root.transform),fields=serialized(view),raw=serialized(view.GetComponent<UnityEngine.UI.RawImage>()),
            structure=view.GetComponentsInChildren<UnityEngine.Transform>(true).Select(t=>new {path=UnityEditor.AnimationUtility.CalculateTransformPath(t,root.transform),id=stableId(t),rect=serialized(t),components=t.GetComponents<UnityEngine.Component>().Select(c=>new {type=c.GetType().FullName,id=stableId(c)}).ToArray()}).ToArray()
        }).ToArray(),
        rects=root.GetComponentsInChildren<UnityEngine.RectTransform>(true).Select(t=>new {path=UnityEditor.AnimationUtility.CalculateTransformPath(t,root.transform),size=t.sizeDelta.ToString("R"),pos=t.anchoredPosition.ToString("R"),anchorMin=t.anchorMin.ToString("R"),anchorMax=t.anchorMax.ToString("R"),components=t.GetComponents<UnityEngine.Component>().Select(c=>c.GetType().Name).ToArray()}).ToArray()
    });
}
var snapshotPath=auditRoot+"/state-current.json";
System.IO.File.WriteAllText(snapshotPath,Newtonsoft.Json.JsonConvert.SerializeObject(assets,Newtonsoft.Json.Formatting.Indented));
return new {path=snapshotPath,prefabs=assets.Count,protectedPreviewCount=2};
