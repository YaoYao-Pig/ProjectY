var source="D:/Program/Unity/Project Y/Art/AssetExpansion202610/Dungeon";
var dest="Assets/DynamicAsset/AssetExpansion202610/Dungeon";
var rows=Newtonsoft.Json.Linq.JArray.Parse(System.IO.File.ReadAllText(source+"/texture_manifest.json"));
System.IO.Directory.CreateDirectory(dest+"/Textures");
foreach(var row in rows){
    var name=(string)row["id"];
    System.IO.File.Copy(source+"/"+(string)row["file"],dest+"/Textures/"+name+".png",true);
}
UnityEditor.AssetDatabase.ImportAsset(dest+"/Textures",UnityEditor.ImportAssetOptions.ImportRecursive|UnityEditor.ImportAssetOptions.ForceSynchronousImport);
var results=new Newtonsoft.Json.Linq.JArray();
foreach(var row in rows){
    var name=(string)row["id"];var path=dest+"/Textures/"+name+".png";
    var importer=(UnityEditor.TextureImporter)UnityEditor.AssetImporter.GetAtPath(path);
    importer.textureType=UnityEditor.TextureImporterType.Default;importer.sRGBTexture=true;
    importer.wrapMode=UnityEngine.TextureWrapMode.Repeat;importer.filterMode=UnityEngine.FilterMode.Trilinear;
    importer.mipmapEnabled=true;importer.maxTextureSize=2048;importer.npotScale=UnityEditor.TextureImporterNPOTScale.None;
    importer.textureCompression=UnityEditor.TextureImporterCompression.Uncompressed;importer.SaveAndReimport();
    var matpath=dest+"/Materials/"+name+".mat";
    var mat=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Material>(matpath);
    if(mat==null){mat=new UnityEngine.Material(UnityEngine.Shader.Find("Universal Render Pipeline/Lit"));UnityEditor.AssetDatabase.CreateAsset(mat,matpath);}
    var texture=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Texture2D>(path);
    mat.SetTexture("_BaseMap",texture);mat.SetColor("_BaseColor",UnityEngine.Color.white);
    mat.SetFloat("_Metallic",0);mat.SetFloat("_Smoothness",.12f);UnityEditor.EditorUtility.SetDirty(mat);
    var result=new Newtonsoft.Json.Linq.JObject();result["name"]=name;result["width"]=texture.width;result["height"]=texture.height;
    result["material"]=matpath;result["sRGB"]=importer.sRGBTexture;result["wrap"]=importer.wrapMode.ToString();result["mipmaps"]=importer.mipmapEnabled;result["runtime_map_connected"]=false;
    results.Add(result);
}
UnityEditor.AssetDatabase.SaveAssets();System.IO.File.WriteAllText(source+"/unity_texture_validation.json",results.ToString());
return new {count=results.Count,results=results};
