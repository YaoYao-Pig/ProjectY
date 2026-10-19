// Execute through Unity MCP in the existing idle Editor. Only these assets and bindings are changed.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode)throw new System.Exception("Edit Mode required");
const string root="Art/WorldPartyLowPoly";
const string destination="Assets/DynamicAsset/WorldPartyLowPoly";
var manifest=Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText(root+"/Integration/asset-manifest.json"));
System.IO.Directory.CreateDirectory(destination+"/Models");System.IO.Directory.CreateDirectory(destination+"/Materials");
var materials=new System.Collections.Generic.Dictionary<string,Material>();
foreach(var entry in (Newtonsoft.Json.Linq.JObject)manifest["palette"])
{
    string path=destination+"/Materials/"+entry.Key+".mat";
    var mat=UnityEditor.AssetDatabase.LoadAssetAtPath<Material>(path);
    if(mat==null)
    {
        Color color;if(!ColorUtility.TryParseHtmlString((string)entry.Value,out color))throw new System.Exception("Invalid palette "+entry.Key);
        mat=new Material(Shader.Find("Universal Render Pipeline/Lit")){name=entry.Key,color=color,enableInstancing=true};mat.SetFloat("_Smoothness",.08f);
        UnityEditor.AssetDatabase.CreateAsset(mat,path);
    }
    materials.Add(entry.Key,mat);
}
var reports=new System.Collections.Generic.List<object>();
foreach(var row in manifest["models"])
{
    string name=(string)row["name"],path=destination+"/Models/"+name+".fbx";
    System.IO.File.Copy(root+"/Staging/"+name+".fbx",path,true);
    UnityEditor.AssetDatabase.ImportAsset(path,UnityEditor.ImportAssetOptions.ForceSynchronousImport);
    var importer=(UnityEditor.ModelImporter)UnityEditor.AssetImporter.GetAtPath(path);
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
    if(model==null || model.transform.localRotation!=Quaternion.identity || model.transform.localScale!=Vector3.one)throw new System.Exception("Invalid model root "+name);
    var renderers=model.GetComponentsInChildren<Renderer>(true);
    if(renderers.Length==0)throw new System.Exception("Empty model "+name);
    foreach(var renderer in renderers)foreach(var mat in renderer.sharedMaterials)
        if(mat==null || mat.shader.name!="Universal Render Pipeline/Lit")throw new System.Exception("Invalid material "+name);
    var mesh=model.GetComponentInChildren<MeshFilter>().sharedMesh;
    reports.Add(new{name=name,path=path,dimensions=mesh.bounds.size.ToString("F3"),triangles=mesh.triangles.Length/3,materials=renderers[0].sharedMaterials.Length});
}
var scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
if(scene.path!="Assets/GameFramework/Samples/Adventure/AdventureDemo.unity")throw new System.Exception("AdventureDemo must be the active scene");
ProjectY.Samples.AdventureRuntimeDemo demo=null;
foreach(var obj in scene.GetRootGameObjects())foreach(var candidate in obj.GetComponentsInChildren<ProjectY.Samples.AdventureRuntimeDemo>(true))
{if(demo!=null)throw new System.Exception("Multiple adventure hosts");demo=candidate;}
if(demo==null)throw new System.Exception("Missing adventure host");
var fields=new UnityEditor.SerializedObject(demo);var bindings=fields.FindProperty("worldPartyBindings");
var names=new[]{"Flag","Caravan","Bandits","Goblins","Orcs","Direwolves","Stonebeast"};bindings.arraySize=names.Length;
for(int i=0;i<names.Length;i++)
{
    string path=destination+"/Models/WorldParty_"+names[i]+".fbx";var item=bindings.GetArrayElementAtIndex(i);
    item.FindPropertyRelative("path").stringValue=path;item.FindPropertyRelative("prefab").objectReferenceValue=UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(path);
}
var pawnBindings=fields.FindProperty("pawnBindings");
foreach(int id in new[]{401,402})
{
    int index=-1;for(int i=0;i<pawnBindings.arraySize;i++)if(pawnBindings.GetArrayElementAtIndex(i).FindPropertyRelative("id").intValue==id)index=i;
    if(index<0){index=pawnBindings.arraySize;pawnBindings.arraySize++;}
    string path=destination+"/Models/Monster_"+(id==401?"Direwolf":"Stonebeast")+".fbx";var item=pawnBindings.GetArrayElementAtIndex(index);
    item.FindPropertyRelative("id").intValue=id;item.FindPropertyRelative("path").stringValue=path;
    item.FindPropertyRelative("prefab").objectReferenceValue=UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(path);
}
fields.ApplyModifiedPropertiesWithoutUndo();UnityEditor.SceneManagement.EditorSceneManager.MarkSceneDirty(scene);
if(!UnityEditor.SceneManagement.EditorSceneManager.SaveScene(scene))throw new System.Exception("Could not save party bindings");
ProjectY.Editor.NarrativeAssets.CreateWorldParty();UnityEditor.AssetDatabase.SaveAssets();
var json=Newtonsoft.Json.JsonConvert.SerializeObject(reports,Newtonsoft.Json.Formatting.Indented);
System.IO.File.WriteAllText(root+"/Integration/unity-import.json",json);return json;
