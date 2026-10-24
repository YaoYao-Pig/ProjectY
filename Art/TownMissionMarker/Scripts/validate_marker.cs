// Minimal native presentation check, after the coordinated compile. Does not enter Play.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode)
    throw new System.InvalidOperationException("Marker check requires Edit Mode.");
var originalScene = UnityEngine.SceneManagement.SceneManager.GetActiveScene();
var wasDirty = originalScene.isDirty;
var scene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
try
{
    var host = new GameObject("MissionMarkerValidation");
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(host, scene);
    var camera = new GameObject("MissionMarkerCamera").AddComponent<Camera>();
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(camera.gameObject, scene);
    camera.transform.rotation = Quaternion.Euler(38, 122, 0);
    var rig = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/PawnLowPoly/PawnRig.prefab").GetComponent<ProjectY.Samples.PawnView>();
    var prefab = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/TownMissionMarker/Prefabs/TownMissionMarker.prefab").GetComponent<MeshRenderer>();
    var green = UnityEditor.AssetDatabase.LoadAssetAtPath<Material>("Assets/DynamicAsset/TownMissionMarker/Materials/TownMissionMarker_Green.mat");
    var appearance = new ProjectY.Samples.PawnAppearanceData { TemplateId = 17, Parts = new[] {
        new ProjectY.Samples.PawnAppearanceData.Part { Id = 17, Slot = "body", Path = "Assets/DynamicAsset/TownLowPoly/Models/NPC_Resident.fbx" },
        new ProjectY.Samples.PawnAppearanceData.Part { Id = 2, Slot = "base", Path = "Assets/DynamicAsset/PawnLowPoly/Models/Pawn_Base.fbx" }
    }};
    var layout = new ProjectY.Samples.MapAreaViewData { AreaType = 2, Radius = 1.5f,
        Cells = new[] { new ProjectY.Samples.MapAreaViewData.Cell { Position = new Vector3(3, 2, 5), Corners = new float[] { 2, 2, 2, 2, 2, 2 } } },
        Npcs = new[] { new ProjectY.Samples.MapAreaViewData.Npc { Id = 71, Name = "MarkerNpc", StepSeconds = 1, Appearance = appearance } }
    };
    var npc = new ProjectY.Samples.MapAreaViewData.NpcState { Id = 71, CellIndex = 0, Present = true, MissionMarker = 0 };
    var state = new ProjectY.Samples.MapAreaViewData.State { Npcs = new[] { npc } };
    System.Func<ProjectY.Samples.PawnAppearanceData.Part, GameObject> resolve = part => UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(part.Path);
    using (var town = new ProjectY.Samples.TownNpcRenderer(host.transform, rig, layout, resolve, prefab, green))
    {
        town.SetState(state, layout);
        npc.MissionMarker = 1; town.SetState(state, layout); town.LateTick(camera);
        var marker = host.GetComponentsInChildren<MeshRenderer>(true).Single(value => value.name == "MarkerNpc_71_MissionMarker");
        var pawn = host.GetComponentInChildren<ProjectY.Samples.PawnView>(true);
        if (!marker.gameObject.activeInHierarchy || marker.sharedMaterial != prefab.sharedMaterial)
            throw new System.Exception("Available commission must be gold.");
        if (Vector3.Distance(marker.transform.position, pawn.HealthTarget.position + Vector3.up * .32f) > .001f ||
            Quaternion.Angle(marker.transform.rotation, camera.transform.rotation * prefab.transform.localRotation) > .001f)
            throw new System.Exception("Marker did not follow the explicit head anchor and final camera orientation.");
        npc.MissionMarker = 2; town.SetState(state, layout);
        if (marker.sharedMaterial != green) throw new System.Exception("Ready commission must be green.");
        npc.MissionMarker = 0; town.SetState(state, layout);
        if (marker.gameObject.activeInHierarchy) throw new System.Exception("In-progress-only commission marker must hide.");
        npc.MissionMarker = 1; town.SetState(state, layout);
        if (!marker.gameObject.activeInHierarchy || marker.sharedMaterial != prefab.sharedMaterial ||
            host.GetComponentsInChildren<MeshRenderer>(true).Count(value => value.name == "MarkerNpc_71_MissionMarker") != 1)
            throw new System.Exception("Hidden marker must be reused with the current state material.");
        npc.Present = false; town.SetState(state, layout);
        if (marker.gameObject.activeInHierarchy || pawn.gameObject.activeInHierarchy)
            throw new System.Exception("Absent NPC and marker must both hide.");
    }
    if (host.transform.childCount != 0) throw new System.Exception("Town disposal leaked NPC or mission marker objects.");
    if (UnityEngine.SceneManagement.SceneManager.GetActiveScene() != originalScene || originalScene.isDirty != wasDirty)
        throw new System.Exception("Marker check changed the user's scene.");
    return "PASS: gold/green/hidden transitions, explicit head following, camera-facing orientation, instance reuse, absent NPC, disposal, scene preservation.";
}
finally { UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene); }
