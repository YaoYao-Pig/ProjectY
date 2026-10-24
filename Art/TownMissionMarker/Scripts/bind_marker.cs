// Run after the coordinated C# compilation; uses Unity serialization, never scene YAML.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode)
    throw new System.InvalidOperationException("Bind NPC mission marker in Edit Mode.");
var scene = UnityEngine.SceneManagement.SceneManager.GetActiveScene();
if (scene.path != "Assets/GameFramework/Samples/Adventure/AdventureDemo.unity")
    throw new System.InvalidOperationException("Expected the existing AdventureDemo scene.");
var demos = scene.GetRootGameObjects().SelectMany(root => root.GetComponentsInChildren<ProjectY.Samples.AdventureRuntimeDemo>(true)).ToArray();
if (demos.Length != 1) throw new System.InvalidOperationException("Expected one AdventureRuntimeDemo.");
var prefab = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/TownMissionMarker/Prefabs/TownMissionMarker.prefab");
var green = UnityEditor.AssetDatabase.LoadAssetAtPath<Material>("Assets/DynamicAsset/TownMissionMarker/Materials/TownMissionMarker_Green.mat");
if (prefab == null || green == null) throw new System.InvalidOperationException("Marker assets are missing.");
var serialized = new UnityEditor.SerializedObject(demos[0]);
var markerProperty = serialized.FindProperty("townMissionMarkerPrefab");
var materialProperty = serialized.FindProperty("townMissionReadyMaterial");
if (markerProperty == null || materialProperty == null)
    throw new System.InvalidOperationException("Compile the completed C# changes before binding the new fields.");
markerProperty.objectReferenceValue = prefab.GetComponent<MeshRenderer>();
materialProperty.objectReferenceValue = green;
serialized.ApplyModifiedPropertiesWithoutUndo();
UnityEditor.EditorUtility.SetDirty(demos[0]);
UnityEditor.SceneManagement.EditorSceneManager.MarkSceneDirty(scene);
if (!UnityEditor.SceneManagement.EditorSceneManager.SaveScene(scene))
    throw new System.InvalidOperationException("Could not save AdventureDemo marker references.");
return "Bound NPC mission marker prefab and ready material on " + demos[0].name + ".";
