// Bind through the existing Editor helper, saving only clean scenes changed by this operation.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.Exception("Edit Mode required");
var original = UnityEngine.SceneManagement.SceneManager.GetActiveScene();
if (original.path != ProjectY.Editor.AdventureDemoMenu.ScenePath || original.isDirty)
    throw new System.Exception("Open the saved Adventure scene before binding building assets; preserve unsaved edits first.");
foreach (var name in new[] { "MapAreaPropTable", "MapAreaTownInteriorTable", "MapAreaTownLotTable", "MapAssetTable" })
    UnityEditor.AssetDatabase.ImportAsset("Assets/GameFramework/Resources/_Gen/Config/" + name + ".bytes", UnityEditor.ImportAssetOptions.ForceSynchronousImport | UnityEditor.ImportAssetOptions.ForceUpdate);
var rows = Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Config/Tables/Map/MapAssetTable.json"))["rows"];
foreach (var row in rows)
    if (UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>((string)row["prefabPath"]) == null)
        throw new System.Exception("Missing configured asset before changing bindings: " + (string)row["prefabPath"]);
var mapPath = ProjectY.Editor.MapRuntimePreviewMenu.ScenePath;
var mapScene = UnityEngine.SceneManagement.SceneManager.GetSceneByPath(mapPath);
bool wasLoaded = mapScene.IsValid() && mapScene.isLoaded;
if (wasLoaded && mapScene.isDirty) throw new System.Exception("Map preview has unsaved edits; bindings were not changed.");
ProjectY.Editor.AdventureDemoMenu.SyncAssets();
try
{
    if (!wasLoaded) mapScene = UnityEditor.SceneManagement.EditorSceneManager.OpenScene(mapPath, UnityEditor.SceneManagement.OpenSceneMode.Additive);
    var method = typeof(ProjectY.Editor.MapRuntimePreviewMenu).GetMethod("BindAssets", System.Reflection.BindingFlags.Static | System.Reflection.BindingFlags.NonPublic);
    ProjectY.Samples.MapRuntimeDemo host = null;
    foreach (var root in mapScene.GetRootGameObjects()) foreach (var item in root.GetComponentsInChildren<ProjectY.Samples.MapRuntimeDemo>(true))
    { if (host != null) throw new System.Exception("Duplicate MapRuntimeDemo"); host = item; }
    if (host == null || method == null) throw new System.Exception("Map preview binding entry is missing");
    var fields = new UnityEditor.SerializedObject(host); method.Invoke(null, new object[] { fields }); fields.ApplyModifiedPropertiesWithoutUndo();
    UnityEditor.SceneManagement.EditorSceneManager.MarkSceneDirty(mapScene);
    if (!UnityEditor.SceneManagement.EditorSceneManager.SaveScene(mapScene)) throw new System.Exception("Map preview scene could not be saved");
    return new { boundAssets = rows.Count(), scenes = new[] { original.path, mapPath }, playMode = false };
}
finally
{
    if (!wasLoaded && mapScene.IsValid()) UnityEditor.SceneManagement.EditorSceneManager.CloseScene(mapScene, true);
    if (UnityEngine.SceneManagement.SceneManager.GetActiveScene() != original) UnityEngine.SceneManagement.SceneManager.SetActiveScene(original);
}
