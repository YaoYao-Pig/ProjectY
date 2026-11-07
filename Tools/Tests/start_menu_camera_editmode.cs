// Isolated lifecycle regression for the world camera lease; no bootstrap, game world or Play.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode)throw new System.InvalidOperationException("Edit Mode required.");
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
try
{
    var owner=new UnityEngine.GameObject("Menu camera fixture");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(owner,scene);
    var demo=owner.AddComponent<ProjectY.Samples.AdventureRuntimeDemo>();
    var cameraObject=new UnityEngine.GameObject("World camera fixture");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);var camera=cameraObject.AddComponent<UnityEngine.Camera>();
    typeof(ProjectY.Samples.AdventureRuntimeDemo).GetField("mapCamera",System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Instance).SetValue(demo,camera);
    camera.cullingMask=17;camera.clearFlags=UnityEngine.CameraClearFlags.Skybox;
    ProjectY.Samples.CampaignMenu.OnOpen(demo);ProjectY.Samples.CampaignMenu.OnOpen(demo);
    if(!camera.enabled||camera.cullingMask!=0||camera.clearFlags!=UnityEngine.CameraClearFlags.SolidColor)throw new System.Exception("Menu requires an active display camera with gameplay rendering excluded.");
    ProjectY.Samples.CampaignMenu.OnClose(demo);if(!camera.enabled||camera.cullingMask!=17||camera.clearFlags!=UnityEngine.CameraClearFlags.Skybox)throw new System.Exception("Original camera state was not restored.");
    camera.enabled=false;ProjectY.Samples.CampaignMenu.OnOpen(demo);ProjectY.Samples.CampaignMenu.OnClose(demo);if(camera.enabled)throw new System.Exception("Originally disabled camera was enabled.");
    ProjectY.Samples.CampaignMenu.OnOpen(demo);UnityEngine.Object.DestroyImmediate(cameraObject);ProjectY.Samples.CampaignMenu.OnClose(demo);
}
finally{UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);}
return new {passed=true,checks="active display camera with zero gameplay culling, mask/clear/enabled restoration, repeated open, originally disabled camera, destroyed camera cleanup",playMode=false};
