// 只更新两个既有 Demo 的资源引用；地图场景以附加方式打开，保留当前编辑场景。
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode)throw new System.Exception("Edit Mode required");
var current=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
if(current.path!=ProjectY.Editor.AdventureDemoMenu.ScenePath)throw new System.Exception("Open AdventureDemo before binding");
ProjectY.Editor.AdventureDemoMenu.SyncAssets();
var world=UnityEngine.SceneManagement.SceneManager.GetSceneByPath(ProjectY.Editor.MapRuntimePreviewMenu.ScenePath);var owned=!world.IsValid() || !world.isLoaded;
if(owned)world=UnityEditor.SceneManagement.EditorSceneManager.OpenScene(ProjectY.Editor.MapRuntimePreviewMenu.ScenePath,UnityEditor.SceneManagement.OpenSceneMode.Additive);
try{
 UnityEngine.SceneManagement.SceneManager.SetActiveScene(world);ProjectY.Editor.MapRuntimePreviewMenu.SyncAssets();
}finally{UnityEngine.SceneManagement.SceneManager.SetActiveScene(current);if(owned)UnityEditor.SceneManagement.EditorSceneManager.CloseScene(world,true);}
var result=new System.Collections.Generic.List<object>();
foreach(var root in current.GetRootGameObjects())foreach(var demo in root.GetComponentsInChildren<ProjectY.Samples.AdventureRuntimeDemo>(true)){
 var fields=new UnityEditor.SerializedObject(demo);var bindings=fields.FindProperty("assetBindings");
 for(var i=0;i<bindings.arraySize;i++)if(bindings.GetArrayElementAtIndex(i).FindPropertyRelative("prefab").objectReferenceValue==null)throw new System.Exception("Missing scene model binding");
 result.Add(new{scene=current.path,mapBindings=bindings.arraySize,pawnBindings=fields.FindProperty("pawnBindings").arraySize});
}
return result;
