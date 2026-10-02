// Unity MCP, Edit Mode. Copies final staged models, retaining all existing GUIDs.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.Exception("Edit Mode required");
const string root = "Art/TownStylized";
System.IO.Directory.CreateDirectory("Assets/DynamicAsset/TownStylized/Models");
System.IO.Directory.CreateDirectory("Assets/DynamicAsset/TownStylized/Materials");
var models = Newtonsoft.Json.Linq.JArray.Parse(System.IO.File.ReadAllText(root + "/Integration/models.json"));
var palette = Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText(root + "/Integration/palette.json"));
var results = new System.Collections.Generic.List<object>();
foreach (var row in models)
{
    string name = (string)row["name"];
    string folder = name.StartsWith("WalkTown_") ? "TownInteriorLowPoly" : name == "Building_Castle" ? "MapLowPoly" : "TownStylized";
    string path = "Assets/DynamicAsset/" + folder + "/Models/" + name + ".fbx";
    string oldGuid = UnityEditor.AssetDatabase.AssetPathToGUID(path);
    System.IO.File.Copy(root + "/Staging/" + name + ".fbx", path, true);
    UnityEditor.AssetDatabase.ImportAsset(path, UnityEditor.ImportAssetOptions.ForceUpdate | UnityEditor.ImportAssetOptions.ForceSynchronousImport);
    var importer = (UnityEditor.ModelImporter)UnityEditor.AssetImporter.GetAtPath(path);
    importer.globalScale = 1; importer.useFileScale = true; importer.bakeAxisConversion = true;
    importer.importAnimation = false; importer.animationType = UnityEditor.ModelImporterAnimationType.None;
    importer.importNormals = UnityEditor.ModelImporterNormals.Import; importer.importTangents = UnityEditor.ModelImporterTangents.None;
    importer.materialImportMode = UnityEditor.ModelImporterMaterialImportMode.ImportStandard;
    importer.isReadable = true;
    foreach (var token in row["materials"])
    {
        string materialName = (string)token;
        var paths = UnityEditor.AssetDatabase.FindAssets(materialName + " t:Material", new[] { "Assets/DynamicAsset" })
            .Select(UnityEditor.AssetDatabase.GUIDToAssetPath).Where(p => System.IO.Path.GetFileNameWithoutExtension(p) == materialName).ToArray();
        Material material = paths.Length > 0 ? UnityEditor.AssetDatabase.LoadAssetAtPath<Material>(paths[0]) : null;
        if (material == null)
        {
            Color color;
            if (!ColorUtility.TryParseHtmlString((string)palette[materialName], out color)) throw new System.Exception("Missing palette " + materialName);
            material = new Material(Shader.Find("Universal Render Pipeline/Lit")) { name = materialName, color = color, enableInstancing = true };
            material.SetFloat("_Smoothness", .1f);
            UnityEditor.AssetDatabase.CreateAsset(material, "Assets/DynamicAsset/TownStylized/Materials/" + materialName + ".mat");
        }
        if (material.shader.name != "Universal Render Pipeline/Lit") throw new System.Exception("Expected URP material " + materialName);
        importer.AddRemap(new UnityEditor.AssetImporter.SourceAssetIdentifier(typeof(Material), materialName), material);
    }
    importer.SaveAndReimport();
    var model = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(path);
    var meshes = model.GetComponentsInChildren<MeshFilter>(true);
    if (meshes.Length != 1 || model.transform.localRotation != Quaternion.identity || model.transform.localScale != Vector3.one) throw new System.Exception("Invalid static root " + name);
    var mesh = meshes[0].sharedMesh;
    foreach (var renderer in model.GetComponentsInChildren<Renderer>(true))
        if (renderer.sharedMaterials.Any(m => m == null || m.shader.name != "Universal Render Pipeline/Lit")) throw new System.Exception("Invalid material " + name);
    if (oldGuid != "" && oldGuid != UnityEditor.AssetDatabase.AssetPathToGUID(path)) throw new System.Exception("Changed GUID " + name);
    results.Add(new { name, path, guid = UnityEditor.AssetDatabase.AssetPathToGUID(path), vertices = mesh.vertexCount, triangles = mesh.triangles.Length / 3, dimensions = mesh.bounds.size.ToString("F3") });
}
System.IO.File.WriteAllText(root + "/Integration/unity-import.json", Newtonsoft.Json.JsonConvert.SerializeObject(results, Newtonsoft.Json.Formatting.Indented));
return results;
