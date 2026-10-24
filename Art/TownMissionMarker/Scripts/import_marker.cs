// Execute through Unity MCP in the already-open project. Imports only this model.
var folder = "Assets/DynamicAsset/TownMissionMarker";
foreach (var child in new[] { "Materials", "Prefabs" })
    if (!UnityEditor.AssetDatabase.IsValidFolder(folder + "/" + child))
        UnityEditor.AssetDatabase.CreateFolder(folder, child);
var shader = Shader.Find("Universal Render Pipeline/Lit");
if (shader == null) throw new System.InvalidOperationException("URP Lit shader missing.");
var colors = new[] { new Color(1f, .67f, .075f, 1f), new Color(.22f, .94f, .38f, 1f) };
var names = new[] { "TownMissionMarker_Gold", "TownMissionMarker_Green" };
var materials = new Material[2];
for (var i = 0; i < materials.Length; i++)
{
    var path = folder + "/Materials/" + names[i] + ".mat";
    var material = UnityEditor.AssetDatabase.LoadAssetAtPath<Material>(path);
    if (material == null)
    {
        material = new Material(shader) { name = names[i] };
        UnityEditor.AssetDatabase.CreateAsset(material, path);
    }
    material.SetColor("_BaseColor", colors[i]);
    material.SetFloat("_Metallic", .12f);
    material.SetFloat("_Smoothness", .38f);
    material.EnableKeyword("_EMISSION");
    material.SetColor("_EmissionColor", colors[i] * .28f);
    UnityEditor.EditorUtility.SetDirty(material);
    materials[i] = material;
}
var modelPath = folder + "/Models/TownMissionMarker.fbx";
var importer = (UnityEditor.ModelImporter)UnityEditor.AssetImporter.GetAtPath(modelPath);
importer.globalScale = 1;
importer.useFileScale = true;
importer.bakeAxisConversion = true;
importer.importAnimation = false;
importer.animationType = UnityEditor.ModelImporterAnimationType.None;
importer.importCameras = false;
importer.importLights = false;
importer.importBlendShapes = false;
importer.isReadable = false;
importer.importNormals = UnityEditor.ModelImporterNormals.Import;
importer.importTangents = UnityEditor.ModelImporterTangents.None;
importer.AddRemap(new UnityEditor.AssetImporter.SourceAssetIdentifier(typeof(Material), names[0]), materials[0]);
importer.SaveAndReimport();
var model = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(modelPath);
var imported = model.GetComponentInChildren<MeshFilter>();
var bounds = imported.GetComponent<MeshRenderer>().bounds;
if (bounds.size.y < .78f || bounds.size.y > .81f || bounds.size.z > .14f)
    throw new System.InvalidOperationException("Marker model must have upright metre geometry: " + bounds);
var temporary = new GameObject("TownMissionMarker");
try
{
    temporary.transform.rotation = imported.transform.rotation;
    temporary.transform.localScale = imported.transform.lossyScale;
    temporary.AddComponent<MeshFilter>().sharedMesh = imported.sharedMesh;
    var renderer = temporary.AddComponent<MeshRenderer>();
    renderer.sharedMaterial = materials[0];
    renderer.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
    renderer.receiveShadows = false;
    renderer.lightProbeUsage = UnityEngine.Rendering.LightProbeUsage.Off;
    renderer.reflectionProbeUsage = UnityEngine.Rendering.ReflectionProbeUsage.Off;
    UnityEditor.PrefabUtility.SaveAsPrefabAsset(temporary, folder + "/Prefabs/TownMissionMarker.prefab");
}
finally { UnityEngine.Object.DestroyImmediate(temporary); }
UnityEditor.AssetDatabase.SaveAssets();
return "Marker imported: " + bounds + "; triangles=" + imported.sharedMesh.triangles.Length / 3 + "; static model, gold/green URP materials, prefab saved.";
