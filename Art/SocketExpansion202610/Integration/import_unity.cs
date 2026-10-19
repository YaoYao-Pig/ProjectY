// Execute through Unity MCP after the consolidated project compile. Only this expansion's assets and sockets change.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Idle Edit Mode required");
var assetRows=(Newtonsoft.Json.Linq.JArray)Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Config/Tables/Equipment/EquipmentAssetTable.json"))["rows"];
var itemRows=(Newtonsoft.Json.Linq.JArray)Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Config/Tables/Equipment/EquipmentItemTable.json"))["rows"];
var weaponRows=(Newtonsoft.Json.Linq.JArray)Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Config/Tables/Equipment/EquipmentWeaponTable.json"))["rows"];
var socketRows=(Newtonsoft.Json.Linq.JArray)Newtonsoft.Json.Linq.JObject.Parse(System.IO.File.ReadAllText("Config/Tables/Equipment/EquipmentSocketTable.json"))["rows"];
var assets=new System.Collections.Generic.Dictionary<int,Newtonsoft.Json.Linq.JToken>();
var items=new System.Collections.Generic.Dictionary<int,Newtonsoft.Json.Linq.JToken>();
var sockets=new System.Collections.Generic.Dictionary<int,Newtonsoft.Json.Linq.JToken>();
foreach(var row in assetRows)assets.Add((int)row["id"],row);
foreach(var row in itemRows)items.Add((int)row["id"],row);
foreach(var row in socketRows)sockets.Add((int)row["id"],row);
UnityEditor.AssetDatabase.ImportAsset("Assets/DynamicAsset/SocketExpansion202610",UnityEditor.ImportAssetOptions.ImportRecursive|UnityEditor.ImportAssetOptions.ForceSynchronousImport);
var preview=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var modelChecks=new Newtonsoft.Json.Linq.JArray();int added=0,weaponCount=0;
try
{
    for(int id=730;id<=741;id++)
    {
        var asset=assets[id];var path=(string)asset["modelPath"];
        var importer=(UnityEditor.ModelImporter)UnityEditor.AssetImporter.GetAtPath(path);
        if(importer==null)throw new System.Exception("Missing model importer: "+id);
        importer.bakeAxisConversion=true;importer.globalScale=1;importer.useFileScale=true;
        importer.importAnimation=false;importer.importCameras=false;importer.importLights=false;
        importer.importNormals=UnityEditor.ModelImporterNormals.Import;
        var source=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(path);
        foreach(var renderer in source.GetComponentsInChildren<UnityEngine.Renderer>(true))foreach(var material in renderer.sharedMaterials)
        {
            if(material==null)throw new System.Exception("Missing imported material: "+id);
            var mapped=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Material>("Assets/DynamicAsset/EquipmentDemo/Materials/"+material.name+".mat");
            if(mapped==null)throw new System.Exception("Unknown attachment palette: "+material.name);
            importer.AddRemap(new UnityEditor.AssetImporter.SourceAssetIdentifier(typeof(UnityEngine.Material),material.name),mapped);
        }
        importer.SaveAndReimport();source=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(path);
        var instance=(UnityEngine.GameObject)UnityEditor.PrefabUtility.InstantiatePrefab(source,preview);
        try
        {
            instance.name="Socket_"+id;
            var renderers=instance.GetComponentsInChildren<UnityEngine.Renderer>(true);
            if(renderers.Length==0)throw new System.Exception("Attachment has no renderer: "+id);
            var bounds=renderers[0].bounds;
            foreach(var renderer in renderers){bounds.Encapsulate(renderer.bounds);foreach(var material in renderer.sharedMaterials)if(material==null)throw new System.Exception("Missing final material");}
            if(bounds.size.magnitude<.04f || bounds.size.magnitude>.5f)throw new System.Exception("Attachment metre scale differs: "+id);
            UnityEditor.PrefabUtility.SaveAsPrefabAsset(instance,(string)asset["prefabPath"]);
            modelChecks.Add(new Newtonsoft.Json.Linq.JObject{{"id",id},{"size",new Newtonsoft.Json.Linq.JArray(bounds.size.x,bounds.size.y,bounds.size.z)}});
        }
        finally{UnityEngine.Object.DestroyImmediate(instance);}
    }
    foreach(var weapon in weaponRows)
    {
        if((string)weapon["kind"]=="staff")continue;
        int id=(int)weapon["id"];var asset=assets[(int)items[id]["assetId"]];string path=(string)asset["prefabPath"];
        var root=UnityEditor.PrefabUtility.LoadPrefabContents(path);
        try
        {
            var view=root.GetComponent<ProjectY.Samples.WeaponModelView>();
            if(view==null)throw new System.Exception("Missing existing WeaponModelView: "+id);
            var old=(ProjectY.Samples.WeaponModelView.Mount[])typeof(ProjectY.Samples.WeaponModelView).GetField("mounts",System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic).GetValue(view);
            var next=new System.Collections.Generic.List<ProjectY.Samples.WeaponModelView.Mount>();
            foreach(var socketId in weapon["socketIds"])
            {
                int key=(int)socketId;var row=sockets[key];var mount=System.Array.Find(old,value=>value.Id==key);
                if(mount==null)
                {
                    if(key<201 || key>273)throw new System.Exception("Existing socket is missing: "+key);
                    var anchor=new UnityEngine.GameObject("Socket_"+key).transform;anchor.SetParent(root.transform,false);
                    mount=new ProjectY.Samples.WeaponModelView.Mount{Id=key,Anchor=anchor};added++;
                }
                if(key>=201 && key<=273)
                {
                    var p=row["position"];var r=row["rotation"];
                    mount.Anchor.localPosition=new UnityEngine.Vector3((float)p[0],(float)p[1],(float)p[2]);
                    mount.Anchor.localRotation=UnityEngine.Quaternion.Euler((float)r[0],(float)r[1],(float)r[2]);
                }
                next.Add(mount);
            }
            view.SetMounts(next.ToArray());UnityEditor.PrefabUtility.SaveAsPrefabAsset(root,path);weaponCount++;
        }
        finally{UnityEditor.PrefabUtility.UnloadPrefabContents(root);}
    }
}
finally{UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(preview);}
var catalog=UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.Samples.EquipmentAssetCatalog>(ProjectY.Editor.EquipmentAssets.CatalogPath);
var entries=new System.Collections.Generic.List<ProjectY.Samples.EquipmentAssetCatalog.Entry>();
foreach(var row in assetRows)
{
    var path=(string)row["prefabPath"];var prefab=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(path);
    if(prefab==null)throw new System.Exception("Missing catalog prefab: "+path);
    entries.Add(new ProjectY.Samples.EquipmentAssetCatalog.Entry{Id=(int)row["id"],Path=path,Prefab=prefab});
}
catalog.SetEntries(entries.ToArray());UnityEditor.EditorUtility.SetDirty(catalog);
ProjectY.Editor.EquipmentIconExporter.ExportItems(new[]{730,731,732,733,734,735,736,737,738,739,740,741});
ProjectY.Editor.EquipmentAssets.SyncWorkbenchSlots();
UnityEditor.AssetDatabase.SaveAssetIfDirty(catalog);
return new{weapons=weaponCount,newAnchors=added,models=modelChecks,icons=12,workbenchSlots=4};
