// 由 Unity MCP 执行的定向导入步骤；保留 GUID，资源映射通过 ModelImporter 完成。
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.InvalidOperationException("Edit Mode required");
var root=System.IO.Directory.GetParent(UnityEngine.Application.dataPath).FullName;
var report=Newtonsoft.Json.Linq.JArray.Parse(System.IO.File.ReadAllText(System.IO.Path.Combine(root,"Art/TownLowPoly/Integration/town-models.json")));
var target="Assets/DynamicAsset/TownLowPoly";
if(!UnityEditor.AssetDatabase.IsValidFolder(target+"/Materials"))UnityEditor.AssetDatabase.CreateFolder(target,"Materials");
var palette=new System.Collections.Generic.Dictionary<string,string>{{"ForgeGlow","#ed963e"},{"Iron","#394047"},{"Cloth","#527e86"},{"Herb","#779755"}};
var exemplar=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Material>("Assets/DynamicAsset/MapLowPoly/Materials/M_MapLP_Stone.mat");
foreach(var entry in palette){
 var path=target+"/Materials/M_MapLP_"+entry.Key+".mat";
 var mat=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Material>(path);
 if(mat==null){mat=new UnityEngine.Material(exemplar.shader);UnityEditor.AssetDatabase.CreateAsset(mat,path);}
 UnityEngine.Color color;if(!UnityEngine.ColorUtility.TryParseHtmlString(entry.Value,out color))throw new System.Exception("Invalid color");
 mat.color=color;mat.SetFloat("_Glossiness",.10f);mat.SetFloat("_Metallic",0);
 if(entry.Key=="ForgeGlow"){mat.EnableKeyword("_EMISSION");mat.SetColor("_EmissionColor",color*.7f);}
 UnityEditor.EditorUtility.SetDirty(mat);
}
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
System.IO.File.WriteAllText(System.IO.Path.Combine(root,"Art/TownLowPoly/Integration/unity-import.json"),Newtonsoft.Json.JsonConvert.SerializeObject(results,Newtonsoft.Json.Formatting.Indented));
return new {models=results.Count,playing=UnityEditor.EditorApplication.isPlaying};
