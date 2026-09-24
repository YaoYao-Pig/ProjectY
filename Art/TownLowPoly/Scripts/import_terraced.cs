// 由 Unity MCP 执行的定向导入步骤；保留 GUID，资源映射通过 ModelImporter 完成。
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.InvalidOperationException("Edit Mode required");
var root=System.IO.Directory.GetParent(UnityEngine.Application.dataPath).FullName;
var report=Newtonsoft.Json.Linq.JArray.Parse(System.IO.File.ReadAllText(System.IO.Path.Combine(root,"Art/TownLowPoly/Integration/terraced-models.json")));
var target="Assets/DynamicAsset/TownLowPoly";
// 新模型仅引用现有共享材质；导入不改动上一版铁匠铺和摊位的材质参数。
var results=new System.Collections.Generic.List<object>();
foreach(var row in report){
 var name=(string)row["name"];var path=target+"/Models/"+name+".fbx";
 UnityEditor.AssetDatabase.ImportAsset(path,UnityEditor.ImportAssetOptions.ForceUpdate);
 var importer=(UnityEditor.ModelImporter)UnityEditor.AssetImporter.GetAtPath(path);
 importer.globalScale=1;importer.useFileScale=true;importer.bakeAxisConversion=true;
 importer.importNormals=UnityEditor.ModelImporterNormals.Import;importer.importAnimation=false;
 importer.animationType=UnityEditor.ModelImporterAnimationType.None;
 foreach(var token in row["materials"]){
  var materialName=(string)token;
  var material=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Material>("Assets/DynamicAsset/MapLowPoly/Materials/"+materialName+".mat");
  if(material==null)material=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Material>(target+"/Materials/"+materialName+".mat");
  if(material==null)throw new System.Exception("Missing shared material "+materialName);
  importer.AddRemap(new UnityEditor.AssetImporter.SourceAssetIdentifier(typeof(UnityEngine.Material),materialName),material);
 }
 importer.SaveAndReimport();
 var obj=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(path);
 var filter=obj.GetComponent<UnityEngine.MeshFilter>();var renderer=obj.GetComponent<UnityEngine.MeshRenderer>();
 if(filter==null || renderer==null || obj.transform.localScale!=UnityEngine.Vector3.one || obj.transform.localRotation!=UnityEngine.Quaternion.identity)throw new System.Exception("Invalid root mesh "+name);
 foreach(var mat in renderer.sharedMaterials)if(mat==null || mat.shader==null || mat.shader.name=="Hidden/InternalErrorShader")throw new System.Exception("Invalid material "+name);
 var size=filter.sharedMesh.bounds.size;
 results.Add(new {name=name,size=new[]{size.x,size.y,size.z},materials=renderer.sharedMaterials.Length,guid=UnityEditor.AssetDatabase.AssetPathToGUID(path)});
}
UnityEditor.AssetDatabase.SaveAssets();
System.IO.File.WriteAllText(System.IO.Path.Combine(root,"Art/TownLowPoly/Integration/terraced-unity-import.json"),Newtonsoft.Json.JsonConvert.SerializeObject(results,Newtonsoft.Json.Formatting.Indented));
return new {models=results.Count,playing=UnityEditor.EditorApplication.isPlaying};
