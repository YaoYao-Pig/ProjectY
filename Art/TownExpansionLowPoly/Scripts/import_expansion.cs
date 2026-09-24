// 由 Unity MCP 定向导入可步行建筑，并同步真实 Demo 的资源引用；不进入 Play。
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode)throw new System.InvalidOperationException("Edit Mode required");
var root=System.IO.Directory.GetParent(UnityEngine.Application.dataPath).FullName;
var report=Newtonsoft.Json.Linq.JArray.Parse(System.IO.File.ReadAllText(System.IO.Path.Combine(root,"Art/TownExpansionLowPoly/Integration/models.json")));
var palette=Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText(System.IO.Path.Combine(root,"Art/TownExpansionLowPoly/Integration/palette.json")));
var target="Assets/DynamicAsset/TownExpansionLowPoly";
// 源表字段变化时同步导出的 TextAsset，避免 Editor 内仍缓存旧二进制结构。
foreach(var name in new[]{"MapAreaSurfaceTable","MapAreaTownSurfaceTable","MapAreaTownThemeTable","MapEnvironmentTable","MapLightKeyTable","MapWeatherTable","MapAreaTownInteriorTable","MapAreaTownBlockTable","MapAreaRoyalDistrictTable","MapAreaEntranceTable","MapAreaRoyalPlacementTable","MapAreaRoyalTable","MapAreaTable","MapAreaTownFacilityTable","MapAreaTownLotTable","MapAreaTownTable","MapAssetTable","MapTownTable"})
 UnityEditor.AssetDatabase.ImportAsset("Assets/GameFramework/Resources/_Gen/Config/"+name+".bytes",UnityEditor.ImportAssetOptions.ForceUpdate);
var results=new System.Collections.Generic.List<object>();
foreach(var row in report){
 var name=(string)row["name"];var path=target+"/Models/"+name+".fbx";
 UnityEditor.AssetDatabase.ImportAsset(path,UnityEditor.ImportAssetOptions.ForceUpdate);
 var importer=(UnityEditor.ModelImporter)UnityEditor.AssetImporter.GetAtPath(path);
 importer.globalScale=1;importer.useFileScale=true;importer.bakeAxisConversion=true;
 importer.importNormals=UnityEditor.ModelImporterNormals.Import;importer.importAnimation=false;importer.animationType=UnityEditor.ModelImporterAnimationType.None;
 foreach(var token in row["materials"]){
  var materialName=(string)token;var material=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Material>("Assets/DynamicAsset/MapLowPoly/Materials/"+materialName+".mat");
  if(material==null) material=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Material>("Assets/DynamicAsset/RoyalTownLowPoly/Materials/"+materialName+".mat");
  if(material==null) material=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Material>("Assets/DynamicAsset/TownInteriorLowPoly/Materials/"+materialName+".mat");
 if(material==null){
   var materialPath=target+"/Materials/"+materialName+".mat";material=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Material>(materialPath);
   if(material==null){
    UnityEngine.Color color;if(!UnityEngine.ColorUtility.TryParseHtmlString((string)palette[materialName],out color))throw new System.Exception("Palette missing "+materialName);
    material=new UnityEngine.Material(UnityEngine.Shader.Find("Standard"));material.name=materialName;material.color=color;material.SetFloat("_Glossiness",.12f);material.SetFloat("_Metallic",0);material.enableInstancing=true;
    UnityEditor.AssetDatabase.CreateAsset(material,materialPath);
   }
  }
  importer.AddRemap(new UnityEditor.AssetImporter.SourceAssetIdentifier(typeof(UnityEngine.Material),materialName),material);
 }
 importer.SaveAndReimport();var model=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(path);
 var mesh=model.GetComponent<UnityEngine.MeshFilter>().sharedMesh;var renderer=model.GetComponent<UnityEngine.MeshRenderer>();
 if(model.transform.localRotation!=UnityEngine.Quaternion.identity || model.transform.localScale!=UnityEngine.Vector3.one)throw new System.Exception("Model transform "+name);
 if(mesh.subMeshCount!=renderer.sharedMaterials.Length)throw new System.Exception("Material slots "+name);
 foreach(var material in renderer.sharedMaterials)if(material==null || material.shader.name!="Standard")throw new System.Exception("Material import "+name);
 results.Add(new{name=name,guid=UnityEditor.AssetDatabase.AssetPathToGUID(path),dimensions=mesh.bounds.size.ToString("F3"),materials=renderer.sharedMaterials.Length});
}
UnityEditor.AssetDatabase.SaveAssets();
var scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
if(scene.path!=ProjectY.Editor.AdventureDemoMenu.ScenePath)throw new System.Exception("Open AdventureDemo before binding");
ProjectY.Samples.AdventureRuntimeDemo demo=null;UnityEngine.Light sun=null;
foreach(var rootObject in scene.GetRootGameObjects()){
 foreach(var item in rootObject.GetComponentsInChildren<ProjectY.Samples.AdventureRuntimeDemo>(true)){if(demo!=null)throw new System.Exception("Duplicate demo");demo=item;}
 foreach(var item in rootObject.GetComponentsInChildren<UnityEngine.Light>(true))if(item.type==UnityEngine.LightType.Directional){if(sun!=null)throw new System.Exception("Multiple directional lights");sun=item;}
}
if(demo==null||sun==null)throw new System.Exception("Missing demo or main light");
var fields=new UnityEditor.SerializedObject(demo);fields.FindProperty("environmentSun").objectReferenceValue=sun;fields.ApplyModifiedPropertiesWithoutUndo();
ProjectY.Editor.AdventureDemoMenu.SyncAssets();
System.IO.File.WriteAllText(System.IO.Path.Combine(root,"Art/TownExpansionLowPoly/Integration/unity-import.json"),Newtonsoft.Json.JsonConvert.SerializeObject(results,Newtonsoft.Json.Formatting.Indented));
return results;
