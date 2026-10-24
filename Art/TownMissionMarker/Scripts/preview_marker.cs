var scene = UnityEngine.SceneManagement.SceneManager.GetActiveScene();
var dirty = scene.isDirty;
var preview = new UnityEditor.PreviewRenderUtility();
Texture2D image = null;
try
{
    var prefab = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/TownMissionMarker/Prefabs/TownMissionMarker.prefab");
    var green = UnityEditor.AssetDatabase.LoadAssetAtPath<Material>("Assets/DynamicAsset/TownMissionMarker/Materials/TownMissionMarker_Green.mat");
    var goldObject = preview.InstantiatePrefabInScene(prefab);
    var greenObject = preview.InstantiatePrefabInScene(prefab);
    goldObject.transform.position = new Vector3(-.36f, 0, 0);
    greenObject.transform.position = new Vector3(.36f, 0, 0);
    greenObject.GetComponent<MeshRenderer>().sharedMaterial = green;
    preview.camera.orthographic = true;
    preview.camera.orthographicSize = .59f;
    preview.camera.nearClipPlane = .05f;
    preview.camera.farClipPlane = 20;
    preview.camera.transform.position = new Vector3(.75f, .72f, -3f);
    preview.camera.transform.LookAt(new Vector3(0, .4f, 0));
    preview.camera.clearFlags = CameraClearFlags.SolidColor;
    preview.camera.backgroundColor = new Color(.045f, .064f, .08f, 1);
    preview.ambientColor = new Color(.35f, .35f, .35f, 1);
    preview.lights[0].intensity = 1.3f;
    preview.lights[0].transform.rotation = Quaternion.Euler(35, -30, 0);
    preview.lights[1].intensity = .7f;
    preview.lights[1].transform.rotation = Quaternion.Euler(330, 150, 0);
    preview.BeginStaticPreview(new Rect(0, 0, 800, 600));
    preview.Render(true);
    image = preview.EndStaticPreview();
    System.IO.File.WriteAllBytes("D:/Program/Unity/Project Y/Art/TownMissionMarker/Previews/mission-markers.png", image.EncodeToPNG());
    return "Saved native Unity marker preview; source scene preserved=" + (scene.isDirty == dirty);
}
finally
{
    if (image != null) UnityEngine.Object.DestroyImmediate(image);
    preview.Cleanup();
}
