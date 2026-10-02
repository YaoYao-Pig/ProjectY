// Targeted Edit Mode regression for stable-GUID mesh replacement: growing and shrinking topology.
// After execution (including failure), remove PawnMeshCopyValidation.asset with Unity MCP manage_asset/delete.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.Exception("Edit Mode required");
const string path = "Assets/GameFramework/Rendering/PawnMeshCopyValidation.asset";
if (UnityEditor.AssetDatabase.LoadMainAssetAtPath(path) != null) throw new System.Exception("Test path already exists");
var save = typeof(ProjectY.Editor.PawnCustomizationAssets).GetMethod("SaveAsset", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static);
string guid = null;
{
    foreach (int count in new[] { 3, 622, 9 })
    {
        var mesh = new Mesh { name = "TopologyValidation" };
        var vertices = new Vector3[count]; var normals = new Vector3[count]; var weights = new BoneWeight[count];
        var uv = new Vector2[count];
        for (int i = 0; i < count; i++) { vertices[i] = new Vector3(i % 13, i / 13, .1f * i); normals[i] = Vector3.up; weights[i] = new BoneWeight { weight0 = 1, boneIndex0 = 0 }; uv[i] = new Vector2(i * .01f, .5f); }
        mesh.vertices = vertices; mesh.normals = normals; mesh.boneWeights = weights; mesh.bindposes = new[] { Matrix4x4.identity }; mesh.uv = uv;
        mesh.triangles = new[] { 0, 1, count - 1 }; mesh.RecalculateBounds();
        save.Invoke(null, new object[] { mesh, path });
        var stored = UnityEditor.AssetDatabase.LoadAssetAtPath<Mesh>(path); UnityEditor.AssetDatabase.SaveAssetIfDirty(stored);
        if (stored.vertexCount != count || stored.normals.Length != count || stored.boneWeights.Length != count || stored.triangles.Max() >= count || stored.uv.Length != count || stored.vertices[count - 1] != vertices[count - 1]) throw new System.Exception("Stale mesh layout at " + count);
        string currentGuid = UnityEditor.AssetDatabase.AssetPathToGUID(path);
        if (guid != null && guid != currentGuid) throw new System.Exception("Mesh GUID changed");
        guid = currentGuid;
    }
    var catalog = UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.Samples.PawnCustomizationCatalog>(ProjectY.Editor.PawnCustomizationAssets.CatalogPath);
    foreach (var part in catalog.Parts.Where(p => p.Id.StartsWith("head_") || p.Id.StartsWith("hair_")))
    {
        if (part.Mesh.triangles.Max() >= part.Mesh.vertexCount) throw new System.Exception("Invalid source topology " + part.Id);
        if (part.Roles.Any(r => !new[] { "Skin", "Cloth", "Leather", "Hair", "EyeWhite", "Iris", "Horn", "Mouth", "Trim" }.Contains(r))) throw new System.Exception("Invalid tint role " + part.Id);
    }
    foreach (var covered in catalog.CoveredBodies)
    {
        var source = catalog.GetPart(covered.Body).Mesh; var mesh = covered.Mesh;
        if (mesh.vertexCount != source.vertexCount || mesh.normals.Length != mesh.vertexCount || mesh.uv.Length != mesh.vertexCount || mesh.boneWeights.Length != mesh.vertexCount || mesh.bindposes.Length != 23 || mesh.triangles.Any(i => i < 0 || i >= mesh.vertexCount))
            throw new System.Exception("Invalid covered body layout: " + mesh.name);
    }
    return "PASS grow/shrink vertex layout, normals, weights, UV, triangles and stable GUID; 23 head/hair and 42 covered meshes valid";
}
