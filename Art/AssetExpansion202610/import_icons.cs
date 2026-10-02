var group="Items";
var source="D:/Program/Unity/Project Y/Art/AssetExpansion202610/"+group;
var dest="Assets/DynamicAsset/AssetExpansion202610/"+group+"/Icons";
var rows=Newtonsoft.Json.Linq.JArray.Parse(System.IO.File.ReadAllText(source+"/manifest.json"));
System.IO.Directory.CreateDirectory(dest);
foreach(var row in rows){var name=(string)row["name"];var path=dest+"/"+name+".png";var temporary=path+".new";System.IO.File.Copy(source+"/UnityPreviews/"+name+".png",temporary,true);if(System.IO.File.Exists(path))System.IO.File.Replace(temporary,path,null);else System.IO.File.Move(temporary,path);}
UnityEditor.AssetDatabase.ImportAsset(dest,UnityEditor.ImportAssetOptions.ImportRecursive|UnityEditor.ImportAssetOptions.ForceSynchronousImport);
foreach(var row in rows){
    var name=(string)row["name"];var importer=(UnityEditor.TextureImporter)UnityEditor.AssetImporter.GetAtPath(dest+"/"+name+".png");
    importer.textureType=UnityEditor.TextureImporterType.Sprite;importer.spriteImportMode=UnityEditor.SpriteImportMode.Single;
    importer.sRGBTexture=true;importer.alphaIsTransparency=true;importer.mipmapEnabled=false;importer.maxTextureSize=512;
    importer.textureCompression=UnityEditor.TextureImporterCompression.Uncompressed;importer.SaveAndReimport();
}
return new {group=group,icons=rows.Count};
