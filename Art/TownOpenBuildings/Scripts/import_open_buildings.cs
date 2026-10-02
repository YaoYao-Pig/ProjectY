// Unity MCP method body: import only this building batch. Never refresh scripts or enter Play.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.Exception("Edit Mode required");
const string root = "Art/TownOpenBuildings";
var models = Newtonsoft.Json.Linq.JArray.Parse(System.IO.File.ReadAllText(root + "/Integration/models.json"));
var palette = Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText(root + "/Integration/palette.json"));
var results = new System.Collections.Generic.List<object>();
System.IO.Directory.CreateDirectory("Assets/DynamicAsset/TownOpenBuildings/Models");
System.IO.Directory.CreateDirectory("Assets/DynamicAsset/TownOpenBuildings/Materials");
foreach (var row in models)
{
    var name = (string)row["name"];
    var folder = name.EndsWith("_Cover") ? "TownOpenBuildings" : name.StartsWith("WalkTown_Row") ? "TownInteriorLowPoly" : name.StartsWith("Royal_") ? "RoyalTownLowPoly" : "TownStylized";
    var path = "Assets/DynamicAsset/" + folder + "/Models/" + name + ".fbx";
    var oldGuid = UnityEditor.AssetDatabase.AssetPathToGUID(path);
    var staged = root + "/Staging/" + name + ".fbx";
    if (!System.IO.File.Exists(path) || !System.Linq.Enumerable.SequenceEqual(System.IO.File.ReadAllBytes(staged), System.IO.File.ReadAllBytes(path)))
    {
        if (System.IO.File.Exists(path))
        {
            // Unity may memory-map an FBX. Replace its directory entry without truncating that open file.
            var pending = root + "/Staging/" + name + ".import.fbx";
            System.IO.File.Copy(staged, pending, true); System.IO.File.Replace(pending, path, null);
        }
        else System.IO.File.Copy(staged, path);
    }
    UnityEditor.AssetDatabase.ImportAsset(path, UnityEditor.ImportAssetOptions.ForceSynchronousImport | UnityEditor.ImportAssetOptions.ForceUpdate);
    var importer = (UnityEditor.ModelImporter)UnityEditor.AssetImporter.GetAtPath(path);
    importer.globalScale = 1; importer.useFileScale = true; importer.bakeAxisConversion = true;
    importer.importAnimation = false; importer.animationType = UnityEditor.ModelImporterAnimationType.None;
    importer.importNormals = UnityEditor.ModelImporterNormals.Import; importer.importTangents = UnityEditor.ModelImporterTangents.None;
    importer.materialImportMode = UnityEditor.ModelImporterMaterialImportMode.ImportStandard; importer.isReadable = true;
    foreach (var item in row["materials"])
    {
        var materialName = (string)item;
        var matches = UnityEditor.AssetDatabase.FindAssets(materialName + " t:Material", new[] { "Assets/DynamicAsset" })
            .Select(UnityEditor.AssetDatabase.GUIDToAssetPath).Where(p => System.IO.Path.GetFileNameWithoutExtension(p) == materialName).ToArray();
        var material = matches.Length == 0 ? null : UnityEditor.AssetDatabase.LoadAssetAtPath<Material>(matches[0]);
        if (material == null)
        {
            Color color;
            if (!ColorUtility.TryParseHtmlString((string)palette[materialName], out color)) throw new System.Exception("Missing material palette: " + materialName);
            material = new Material(Shader.Find("Universal Render Pipeline/Lit")) { name = materialName, color = color, enableInstancing = true };
            material.SetFloat("_Smoothness", .1f);
            UnityEditor.AssetDatabase.CreateAsset(material, "Assets/DynamicAsset/TownOpenBuildings/Materials/" + materialName + ".mat");
        }
        if (material.shader.name != "Universal Render Pipeline/Lit") throw new System.Exception("Unexpected building shader: " + materialName);
        importer.AddRemap(new UnityEditor.AssetImporter.SourceAssetIdentifier(typeof(Material), materialName), material);
    }
    importer.SaveAndReimport();
    var model = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(path);
    var filter = model.GetComponent<MeshFilter>(); var renderer = model.GetComponent<MeshRenderer>();
    if (filter == null || renderer == null || model.transform.localRotation != Quaternion.identity || model.transform.localScale != Vector3.one)
        throw new System.Exception("Building needs a unit-scale mesh root: " + name);
    if (renderer.sharedMaterials.Length != filter.sharedMesh.subMeshCount || renderer.sharedMaterials.Any(m => m == null))
        throw new System.Exception("Invalid material slots: " + name);
    var guid = UnityEditor.AssetDatabase.AssetPathToGUID(path);
    if (oldGuid != "" && guid != oldGuid) throw new System.Exception("Existing model GUID changed: " + name);
    results.Add(new { name, path, guid, vertices = filter.sharedMesh.vertexCount, triangles = filter.sharedMesh.triangles.Length / 3, dimensions = filter.sharedMesh.bounds.size.ToString("F3") });
}
System.IO.File.WriteAllText(root + "/Integration/unity-import.json", Newtonsoft.Json.JsonConvert.SerializeObject(results, Newtonsoft.Json.Formatting.Indented));
return results;
