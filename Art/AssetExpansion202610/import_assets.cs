// Run through Unity MCP execute_code. In-memory editor action; no project compilation.
var group = "Items";
var onlyNames = new System.Collections.Generic.HashSet<string>();
var source = "D:/Program/Unity/Project Y/Art/AssetExpansion202610/" + group;
var dest = "Assets/DynamicAsset/AssetExpansion202610/" + group;
if (UnityEditor.EditorApplication.isPlaying) throw new System.Exception("Asset import requires Edit Mode");
var rows = Newtonsoft.Json.Linq.JArray.Parse(System.IO.File.ReadAllText(source + "/manifest.json"));
if(onlyNames.Count>0){var selected=new Newtonsoft.Json.Linq.JArray();foreach(var row in rows)if(onlyNames.Contains((string)row["name"]))selected.Add(row);rows=selected;}
var palette = Newtonsoft.Json.Linq.JArray.Parse(System.IO.File.ReadAllText(source + "/materials.json"));
foreach (var folder in new [] {"Models", "Materials", "Prefabs"})
    System.IO.Directory.CreateDirectory(dest + "/" + folder);
foreach (var row in rows) {
    var name = (string)row["name"];
    var from = source + "/Staging/" + name + ".fbx";
    if (!System.IO.File.Exists(from)) throw new System.Exception("Missing " + from);
    System.IO.File.Copy(from,dest + "/Models/" + name + ".fbx",true);
}
UnityEditor.AssetDatabase.ImportAsset("Assets/DynamicAsset/AssetExpansion202610", UnityEditor.ImportAssetOptions.ImportRecursive | UnityEditor.ImportAssetOptions.ForceSynchronousImport);
var shader=UnityEngine.Shader.Find("Universal Render Pipeline/Lit");
if (shader==null) throw new System.Exception("URP Lit missing");
var mats=new System.Collections.Generic.Dictionary<string,UnityEngine.Material>();
foreach (var entry in palette) {
    var name=(string)entry["name"];
    var path=dest+"/Materials/"+name+".mat";
    var mat=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Material>(path);
    if(mat==null){mat=new UnityEngine.Material(shader);mat.name=name;UnityEditor.AssetDatabase.CreateAsset(mat,path);}
    var c=entry["color_linear"];
    mat.SetColor("_BaseColor",new UnityEngine.Color((float)c[0],(float)c[1],(float)c[2],(float)c[3]).gamma);
    mat.SetFloat("_Smoothness",1f-(float)entry["roughness"]);
    mat.SetFloat("_Metallic",(float)entry["metallic"]);
    UnityEditor.EditorUtility.SetDirty(mat);mats.Add(name,mat);
}
var result=new Newtonsoft.Json.Linq.JArray();
var preview=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
try {
foreach(var row in rows){
    var name=(string)row["name"];var path=dest+"/Models/"+name+".fbx";
    var importer=(UnityEditor.ModelImporter)UnityEditor.AssetImporter.GetAtPath(path);
    if(importer==null)throw new System.Exception("Importer missing: "+path);
    importer.globalScale=1;importer.useFileScale=true;importer.bakeAxisConversion=true;
    importer.importAnimation=false;importer.animationType=UnityEditor.ModelImporterAnimationType.None;
    importer.importNormals=UnityEditor.ModelImporterNormals.Import;
    importer.materialImportMode=UnityEditor.ModelImporterMaterialImportMode.ImportStandard;
    foreach(var m in row["materials"]){var key=(string)m;importer.AddRemap(new UnityEditor.AssetImporter.SourceAssetIdentifier(typeof(UnityEngine.Material),key),mats[key]);}
    importer.SaveAndReimport();
    var model=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(path);
    var instance=(UnityEngine.GameObject)UnityEditor.PrefabUtility.InstantiatePrefab(model,preview);
    instance.name=name;
    var renderers=instance.GetComponentsInChildren<UnityEngine.Renderer>();
    if(renderers.Length==0)throw new System.Exception("No renderer: "+name);
    var bounds=renderers[0].bounds;var badMaterials=0;
    foreach(var r in renderers){bounds.Encapsulate(r.bounds);foreach(var m in r.sharedMaterials)if(m==null||m.shader!=shader)badMaterials++;}
    var prefabPath=dest+"/Prefabs/"+name+".prefab";
    UnityEditor.PrefabUtility.SaveAsPrefabAsset(instance,prefabPath);
    var d=row["dimensions_blender_xyz"];
    var expected=new UnityEngine.Vector3((float)d[0],(float)d[2],(float)d[1]);
    var error=(bounds.size-expected).magnitude;
    var rotation=instance.transform.localEulerAngles;
    var scale=instance.transform.localScale;
    var check=new Newtonsoft.Json.Linq.JObject();
    check["name"]=name;check["prefab"]=prefabPath;
    check["bounds_unity_xyz"]=new Newtonsoft.Json.Linq.JArray(bounds.size.x,bounds.size.y,bounds.size.z);
    check["expected_dimensions_error"]=error;
    check["root_euler"]=new Newtonsoft.Json.Linq.JArray(rotation.x,rotation.y,rotation.z);
    check["root_scale"]=new Newtonsoft.Json.Linq.JArray(scale.x,scale.y,scale.z);
    check["bad_material_slots"]=badMaterials;
    check["pass"]=error<0.002f && badMaterials==0 && UnityEngine.Quaternion.Angle(instance.transform.localRotation,UnityEngine.Quaternion.identity)<0.01f && (scale-UnityEngine.Vector3.one).magnitude<0.001f;
    result.Add(check);
    UnityEngine.Object.DestroyImmediate(instance);
}
} finally {UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(preview);}
UnityEditor.AssetDatabase.SaveAssets();
if(onlyNames.Count>0 && System.IO.File.Exists(source+"/unity_validation.json")){
    var old=Newtonsoft.Json.Linq.JArray.Parse(System.IO.File.ReadAllText(source+"/unity_validation.json"));
    foreach(var entry in old)if(!onlyNames.Contains((string)entry["name"]))result.Add(entry);
}
System.IO.File.WriteAllText(source+"/unity_validation.json",result.ToString());
return new {group=group,count=result.Count,validation=source+"/unity_validation.json"};
