if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
var scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
if(scene.path!="Assets/GameFramework/Samples/Adventure/AdventureDemo.unity")throw new System.Exception("AdventureDemo must be active");
ProjectY.Samples.AdventureRuntimeDemo demo=null;
foreach(var root in scene.GetRootGameObjects())foreach(var value in root.GetComponentsInChildren<ProjectY.Samples.AdventureRuntimeDemo>(true)){
 if(demo!=null)throw new System.Exception("Multiple adventure hosts");demo=value;
}
if(demo==null)throw new System.Exception("Adventure host missing");
var fields=new UnityEditor.SerializedObject(demo);
System.Action<string,int,string> bind=(field,id,name)=>{
 var rows=fields.FindProperty(field);UnityEditor.SerializedProperty entry=null;
 for(int i=0;i<rows.arraySize;i++)if(rows.GetArrayElementAtIndex(i).FindPropertyRelative("id").intValue==id)entry=rows.GetArrayElementAtIndex(i);
 if(entry==null){rows.arraySize++;entry=rows.GetArrayElementAtIndex(rows.arraySize-1);}
 var path="Assets/DynamicAsset/ForestAnimals/Models/"+name+".fbx";
 var asset=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(path);if(asset==null)throw new System.Exception("Missing "+path);
 entry.FindPropertyRelative("id").intValue=id;entry.FindPropertyRelative("path").stringValue=path;entry.FindPropertyRelative("prefab").objectReferenceValue=asset;
};
bind("pawnBindings",201,"Horse");bind("pawnBindings",202,"Chicken");bind("pawnBindings",203,"Rabbit");
bind("assetBindings",201,"ForestOak");bind("assetBindings",202,"ForestPine");bind("assetBindings",203,"ForestFern");bind("assetBindings",204,"ForestGround");
fields.ApplyModifiedPropertiesWithoutUndo();UnityEditor.SceneManagement.EditorSceneManager.MarkSceneDirty(scene);
if(!UnityEditor.SceneManagement.EditorSceneManager.SaveScene(scene))throw new System.Exception("Could not save forest model references");
var preview=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
try{
 foreach(var name in new[]{"Horse","Chicken","Rabbit"}){
  var model=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>("Assets/DynamicAsset/ForestAnimals/Models/"+name+".fbx");
  var instance=(UnityEngine.GameObject)UnityEditor.PrefabUtility.InstantiatePrefab(model,preview);
  UnityEditor.PrefabUtility.SaveAsPrefabAsset(instance,"Assets/DynamicAsset/ForestAnimals/Prefabs/"+name+".prefab");
 }
}finally{UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(preview);}
return new{scene=scene.path,pawnParts=fields.FindProperty("pawnBindings").arraySize,mapAssets=fields.FindProperty("assetBindings").arraySize};
