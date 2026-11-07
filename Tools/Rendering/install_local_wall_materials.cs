// Native material remapping only: preserves FBX geometry/GUIDs and non-wall material slots.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.Exception("Edit Mode required");
var look=ProjectY.Samples.MapAreaPresentationSettings.Load();
Func<string,string,Vector4,float,Material> wallMaterial=(name,sourcePath,pattern,relief)=>{
    string path="Assets/DynamicAsset/TownInteriorLowPoly/Materials/"+name+".mat";
    var material=UnityEditor.AssetDatabase.LoadAssetAtPath<Material>(path);
    if(material==null)
    {
        var source=UnityEditor.AssetDatabase.LoadAssetAtPath<Material>(sourcePath);
        if(source==null)throw new System.Exception("Missing source material: "+sourcePath);
        material=new Material(source){name=name};UnityEditor.AssetDatabase.CreateAsset(material,path);
    }
    if(look.Detail(material)==null)
    {
        var rows=look.materials.ToList();rows.Add(new ProjectY.Samples.MapAreaPresentationSettings.MaterialDetail {material=material,pattern=pattern,relief=relief});
        look.materials=rows.ToArray();UnityEditor.EditorUtility.SetDirty(look);
    }
    return material;
};
var masonry=wallMaterial("M_MapLP_WallMasonry","Assets/DynamicAsset/MapLowPoly/Materials/M_MapLP_PlasterShade.mat",new Vector4(9,.64f,.24f,.045f),.035f);
var boards=wallMaterial("M_MapLP_WallBoards","Assets/DynamicAsset/MapLowPoly/Materials/M_MapLP_TimberLight.mat",new Vector4(5,.28f,.22f,.035f),.025f);
var targets=new List<KeyValuePair<string,Material>>();
foreach(var name in new [] {"Forge","Shop","Guild","Tavern"})foreach(var part in new [] {"Structure","Cover"})
    targets.Add(new KeyValuePair<string,Material>("Assets/DynamicAsset/TownInteriorLowPoly/Models/WalkTown_"+name+"_"+part+".fbx",name=="Tavern"?boards:masonry));
foreach(var name in new [] {"RowA","RowB","RowC"})
{
    targets.Add(new KeyValuePair<string,Material>("Assets/DynamicAsset/TownInteriorLowPoly/Models/WalkTown_"+name+".fbx",name=="RowC"?boards:masonry));
    targets.Add(new KeyValuePair<string,Material>("Assets/DynamicAsset/TownOpenBuildings/Models/WalkTown_"+name+"_Cover.fbx",name=="RowC"?boards:masonry));
}
int remapped=0;
foreach(var target in targets)
{
    var importer=UnityEditor.AssetImporter.GetAtPath(target.Key);
    if(importer==null)throw new System.Exception("Missing wall model: "+target.Key);
    var model=UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(target.Key);
    var mesh=model.GetComponent<MeshFilter>().sharedMesh;int vertices=mesh.vertexCount,submeshes=mesh.subMeshCount;var bounds=mesh.bounds;
    var guid=UnityEditor.AssetDatabase.AssetPathToGUID(target.Key);
    bool cover=target.Key.EndsWith("_Cover.fbx");bool changed=false;
    var mappings=importer.GetExternalObjectMap().ToArray();
    foreach(var entry in mappings)
    {
        // Structure Plaster is furniture/crockery, not wall; only the perimeter's Shade slot is remapped.
        if(entry.Key.type!=typeof(Material) || !(entry.Key.name=="M_MapLP_PlasterShade" || cover && entry.Key.name=="M_MapLP_Plaster"))continue;
        if(entry.Value==target.Value)continue;
        importer.AddRemap(entry.Key,target.Value);changed=true;remapped++;
    }
    if(changed)importer.SaveAndReimport();
    model=UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(target.Key);mesh=model.GetComponent<MeshFilter>().sharedMesh;
    if(guid!=UnityEditor.AssetDatabase.AssetPathToGUID(target.Key) || mesh.vertexCount!=vertices || mesh.subMeshCount!=submeshes || mesh.bounds!=bounds)
        throw new System.Exception("Material remap changed model identity or geometry");
}
UnityEditor.AssetDatabase.SaveAssetIfDirty(look);
return new {models=targets.Count,remappedSlots=remapped,materialBindings=look.materials.Length,geometryAndGuidsPreserved=true};
