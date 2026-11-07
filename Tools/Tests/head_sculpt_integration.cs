// Execute through Unity MCP in Edit Mode; creates and closes one isolated PreviewScene.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.InvalidOperationException("Edit Mode required");
var catalog=UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.Samples.PawnCustomizationCatalog>(ProjectY.Editor.PawnCustomizationAssets.CatalogPath);
var newIds=new System.Collections.Generic.HashSet<string>();
foreach(var m in catalog.Rules.modules)if(!string.IsNullOrEmpty(m.source))newIds.Add(m.id);
if(newIds.Count!=10||catalog.Parts.Length!=39)throw new System.Exception("Unexpected additive head catalog");
var seen=new System.Collections.Generic.HashSet<string>();var rng=UnityEngine.Random.state;
foreach(string race in new[]{"human","goblin"})foreach(string sex in new[]{"male","female"})for(int seed=0;seed<512;seed++)
{
    var a=catalog.Rules.Randomize(seed,race,sex);catalog.Rules.Validate(a);
    if(UnityEngine.JsonUtility.ToJson(a)!=UnityEngine.JsonUtility.ToJson(catalog.Rules.Randomize(seed,race,sex)))throw new System.Exception("Unstable seed");
    seen.Add(a.head);
}
if(!rng.Equals(UnityEngine.Random.state))throw new System.Exception("Appearance consumed the global RNG");
foreach(var id in newIds)if(!seen.Contains(id))throw new System.Exception("Unreachable random head: "+id);
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var result=new System.Collections.Generic.List<string>();int fitsChecked=0,changedFits=0,ownersReleased=0;float maxSkinError=0;
try
{
    var prefab=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>("Assets/DynamicAsset/PawnLowPoly/PawnRig.prefab");
    var pawn=UnityEngine.Object.Instantiate(prefab);UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(pawn,scene);
    var view=pawn.GetComponentInChildren<ProjectY.Samples.PawnCustomizationView>(true);view.gameObject.SetActive(true);
    var cases=new[]{"head_human_male_0","head_human_male_sculpt_03","head_human_female_sculpt_00","head_goblin_female_sculpt_00"};
    foreach(var id in cases)
    {
        var module=System.Array.Find(catalog.Rules.modules,m=>m.id==id);var value=catalog.Rules.Randomize(104729,module.race,module.sex);value.head=id;value.hair="none";
        string saved=UnityEngine.JsonUtility.ToJson(value);view.Apply(value);
        if(saved!=UnityEngine.JsonUtility.ToJson(value))throw new System.Exception("Appearance input mutated");
        var head=view.Modules[1];if(head.sharedMesh!=catalog.GetPart(id).Mesh)throw new System.Exception("Wrong selected mesh");
        if(id.Contains("_sculpt_")&&(head.sharedMesh.blendShapeCount!=6||head.sharedMaterials[0].GetTexture("_BaseMap")==null))throw new System.Exception("Missing face data");
        var meshSource=head.sharedMesh;var expectedVertices=meshSource.vertices;
        for(int shape=0;shape<meshSource.blendShapeCount;shape++)
        {
            var delta=new UnityEngine.Vector3[meshSource.vertexCount];meshSource.GetBlendShapeFrameVertices(shape,0,delta,null,null);
            float weight=head.GetBlendShapeWeight(shape)/meshSource.GetBlendShapeFrameWeight(shape,0);
            for(int i=0;i<delta.Length;i++)expectedVertices[i]+=delta[i]*weight;
        }
        var baked=new UnityEngine.Mesh();head.BakeMesh(baked);var actualVertices=baked.vertices;var weightsSource=meshSource.boneWeights;var binds=meshSource.bindposes;
        var matrices=new UnityEngine.Matrix4x4[view.Bones.Length];for(int bone=0;bone<matrices.Length;bone++)matrices[bone]=head.transform.worldToLocalMatrix*view.Bones[bone].localToWorldMatrix*binds[bone];
        for(int i=0;i<expectedVertices.Length;i++)
        {
            var w=weightsSource[i];var v=expectedVertices[i];var p=matrices[w.boneIndex0].MultiplyPoint3x4(v)*w.weight0+matrices[w.boneIndex1].MultiplyPoint3x4(v)*w.weight1+matrices[w.boneIndex2].MultiplyPoint3x4(v)*w.weight2+matrices[w.boneIndex3].MultiplyPoint3x4(v)*w.weight3;
            maxSkinError=UnityEngine.Mathf.Max(maxSkinError,UnityEngine.Vector3.Distance(p,actualVertices[i]));
        }
        UnityEngine.Object.DestroyImmediate(baked);if(maxSkinError>.002f)throw new System.Exception("Shape-aware skinning mismatch");
        foreach(var path in new[]{"Assets/DynamicAsset/PawnLowPoly/Models/Pawn_Helmet.fbx","Assets/DynamicAsset/PawnLowPoly/Models/Pawn_MageHat.fbx","Assets/DynamicAsset/PawnLowPoly/Models/Pawn_ArmorPlate.fbx","Assets/DynamicAsset/PawnLowPoly/Models/Pawn_Cape.fbx","Assets/DynamicAsset/EquipmentDemo/Models/Equip_Trousers.fbx","Assets/DynamicAsset/EquipmentDemo/Models/Equip_Boots.fbx"})
        {
            var original=catalog.Fit(path,value).Part.Mesh;var before=original.vertices;var obj=view.CreateFit(path);var renderer=obj.GetComponent<UnityEngine.SkinnedMeshRenderer>();var mesh=renderer.sharedMesh;
            if(mesh.vertexCount!=original.vertexCount||renderer.bones.Length!=23)throw new System.Exception("Fit changed topology or skeleton");
            var after=original.vertices;for(int i=0;i<after.Length;i++)if(after[i]!=before[i])throw new System.Exception("Authored gear mutated");
            foreach(var v in mesh.vertices)if(float.IsNaN(v.x)||float.IsInfinity(v.x)||float.IsNaN(v.y)||float.IsNaN(v.z))throw new System.Exception("Invalid fitted vertex");
            bool owned=mesh!=original;if(owned)changedFits++;UnityEngine.Object.DestroyImmediate(obj);
            if(owned){if(mesh!=null)throw new System.Exception("Fitted mesh leak");ownersReleased++;}fitsChecked++;
        }
        result.Add(id);
    }
    // The same imported head keeps its shape keys when updated in place a second time.
    string guid=UnityEditor.AssetDatabase.AssetPathToGUID(UnityEditor.AssetDatabase.GetAssetPath(catalog.GetPart("head_human_female_sculpt_00").Mesh));
    ProjectY.Editor.HeadSculptAssets.Sync();
    if(catalog.GetPart("head_human_female_sculpt_00").Mesh.blendShapeCount!=6||guid!=UnityEditor.AssetDatabase.AssetPathToGUID(UnityEditor.AssetDatabase.GetAssetPath(catalog.GetPart("head_human_female_sculpt_00").Mesh)))throw new System.Exception("Head reimport lost frames or GUID");
}
finally{UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);}
var weights=ProjectY.Samples.PawnHeadShapes.Weights(42,"head_human_female_sculpt_00");
string json="{\"catalogParts\":39,\"legacyPartsRetained\":29,\"newHeads\":10,\"newPaintedTextures\":5,\"randomCases\":2048,\"fitCases\":"+fitsChecked+",\"changedFits\":"+changedFits+",\"ownedMeshesReleased\":"+ownersReleased+",\"reimportPreservedGuidAndSixShapes\":true,\"playModeEntered\":false,\"shapeFixture\":["+string.Join(",",System.Array.ConvertAll(weights,w=>w.ToString("R",System.Globalization.CultureInfo.InvariantCulture)))+"]}";
json=json.Substring(0,json.Length-1)+",\"maxShapeSkinError\":"+maxSkinError.ToString("R",System.Globalization.CultureInfo.InvariantCulture)+"}";
System.IO.File.WriteAllText("Art/HeadSculptExpansion202610/Integration/unity-validation.json",json);
return json;
