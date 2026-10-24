// Execute via Unity MCP in the existing idle Editor. No project Refresh or script compilation.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling || UnityEditor.EditorApplication.isUpdating)
    throw new System.Exception("Idle Edit Mode required");
const string root="Art/FactionLowPoly";
const string destination="Assets/DynamicAsset/FactionLowPoly";
var manifest=Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText(root+"/Integration/asset-manifest.json"));
var shader=Shader.Find("Universal Render Pipeline/Lit");
if(shader==null)throw new System.Exception("URP Lit is unavailable");
foreach(var folder in new[]{destination,destination+"/Models",destination+"/Materials"})
{
    if(!UnityEditor.AssetDatabase.IsValidFolder(folder))
    {
        int slash=folder.LastIndexOf('/');
        UnityEditor.AssetDatabase.CreateFolder(folder.Substring(0,slash),folder.Substring(slash+1));
    }
}
var materials=new System.Collections.Generic.Dictionary<string,Material>();
foreach(var entry in (Newtonsoft.Json.Linq.JObject)manifest["palette"])
{
    string path=destination+"/Materials/"+entry.Key+".mat";
    var mat=UnityEditor.AssetDatabase.LoadAssetAtPath<Material>(path);
    Color color;if(!ColorUtility.TryParseHtmlString((string)entry.Value,out color))throw new System.Exception("Invalid palette "+entry.Key);
    if(mat==null){mat=new Material(shader){name=entry.Key};UnityEditor.AssetDatabase.CreateAsset(mat,path);}
    mat.shader=shader;mat.color=color;mat.enableInstancing=true;mat.SetFloat("_Smoothness",.08f);mat.SetFloat("_Metallic",0);
    UnityEditor.EditorUtility.SetDirty(mat);materials.Add(entry.Key,mat);
}
// Copy the complete batch before directing Unity to import the affected models.
foreach(var row in manifest["models"])
{
    string name=(string)row["name"];
    System.IO.File.Copy(root+"/Staging/"+name+".fbx",destination+"/Models/"+name+".fbx",true);
}
var reports=new System.Collections.Generic.List<object>();
foreach(var row in manifest["models"])
{
    string name=(string)row["name"],path=destination+"/Models/"+name+".fbx";
    UnityEditor.AssetDatabase.ImportAsset(path,UnityEditor.ImportAssetOptions.ForceSynchronousImport);
    var importer=(UnityEditor.ModelImporter)UnityEditor.AssetImporter.GetAtPath(path);
    if(importer==null)throw new System.Exception("No ModelImporter: "+path);
    importer.globalScale=1;importer.useFileScale=true;importer.bakeAxisConversion=true;importer.importAnimation=false;
    importer.animationType=UnityEditor.ModelImporterAnimationType.None;importer.importNormals=UnityEditor.ModelImporterNormals.Import;
    importer.importTangents=UnityEditor.ModelImporterTangents.None;importer.materialImportMode=UnityEditor.ModelImporterMaterialImportMode.ImportStandard;
    foreach(var token in row["materials"])
    {
        string material=(string)token;
        importer.AddRemap(new UnityEditor.AssetImporter.SourceAssetIdentifier(typeof(Material),material),materials[material]);
    }
    importer.SaveAndReimport();
    var model=UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(path);
    if(model==null || model.transform.localRotation!=Quaternion.identity || model.transform.localScale!=Vector3.one || model.transform.localPosition!=Vector3.zero)
        throw new System.Exception("Invalid model root "+name);
    var renderers=model.GetComponentsInChildren<Renderer>(true);
    if(renderers.Length!=1)throw new System.Exception("Expected one merged renderer "+name);
    foreach(var renderer in renderers)foreach(var mat in renderer.sharedMaterials)
        if(mat==null || mat.shader!=shader || !UnityEditor.AssetDatabase.GetAssetPath(mat).StartsWith(destination+"/Materials/"))
            throw new System.Exception("Unmapped material "+name);
    var mesh=model.GetComponentInChildren<MeshFilter>().sharedMesh;
    var source=row["dimensions_blender"];
    var expected=new Vector3((float)source[0],(float)source[2],(float)source[1]);
    if((mesh.bounds.size-expected).sqrMagnitude>.000001f || Mathf.Abs(mesh.bounds.min.y)>.0001f)
        throw new System.Exception("Model bounds mismatch "+name+" "+mesh.bounds);
    reports.Add(new{name=name,path=path,dimensions=mesh.bounds.size.ToString("F4"),boundsMin=mesh.bounds.min.ToString("F4"),
        triangles=mesh.triangles.Length/3,materials=renderers[0].sharedMaterials.Length,bakeAxisConversion=importer.bakeAxisConversion,
        rotation=model.transform.localRotation.eulerAngles.ToString(),scale=model.transform.localScale.ToString(),
        paletteVerified=true});
}
var scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
if(scene.path!="Assets/GameFramework/Samples/Adventure/AdventureDemo.unity")throw new System.Exception("AdventureDemo must be active");
ProjectY.Samples.AdventureRuntimeDemo demo=null;
foreach(var obj in scene.GetRootGameObjects())foreach(var candidate in obj.GetComponentsInChildren<ProjectY.Samples.AdventureRuntimeDemo>(true))
{if(demo!=null)throw new System.Exception("Multiple adventure hosts");demo=candidate;}
if(demo==null)throw new System.Exception("Missing adventure host");
var fields=new UnityEditor.SerializedObject(demo);var bindings=fields.FindProperty("worldPartyBindings");
int oldCount=bindings.arraySize;
foreach(var row in manifest["models"])
{
    string path=destination+"/Models/"+(string)row["name"]+".fbx";
    int index=-1;
    for(int i=0;i<bindings.arraySize;i++)if(bindings.GetArrayElementAtIndex(i).FindPropertyRelative("path").stringValue==path)index=i;
    if(index<0){index=bindings.arraySize;bindings.arraySize++;}
    var item=bindings.GetArrayElementAtIndex(index);item.FindPropertyRelative("path").stringValue=path;
    item.FindPropertyRelative("prefab").objectReferenceValue=UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(path);
}
fields.ApplyModifiedPropertiesWithoutUndo();UnityEditor.SceneManagement.EditorSceneManager.MarkSceneDirty(scene);
if(!UnityEditor.SceneManagement.EditorSceneManager.SaveScene(scene))throw new System.Exception("Failed to save bindings");
UnityEditor.AssetDatabase.SaveAssets();
var result=new{models=reports,previousBindings=oldCount,bindings=bindings.arraySize,scene=scene.path};
var json=Newtonsoft.Json.JsonConvert.SerializeObject(result,Newtonsoft.Json.Formatting.Indented);
System.IO.File.WriteAllText(root+"/Integration/unity-import.json",json);return json;
