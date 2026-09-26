using System;
using System.Collections.Generic;
using System.IO;
using ProjectY.Samples;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;
using Object=UnityEngine.Object;

namespace ProjectY.Editor
{
    /// <summary>Deterministic model-to-Sprite export. No scene edits or Play Mode required.</summary>
    public static class EquipmentIconExporter
    {
        [Serializable] private sealed class Item {public int id,assetId,width,height;public string iconMode,iconPath;public float[] iconRotation;public float iconPadding;}
        [Serializable] private sealed class Items {public Item[] rows;}
        [Serializable] private sealed class Asset {public int id;public string modelPath,prefabPath;}
        [Serializable] private sealed class Assets {public Asset[] rows;}
        private static T Read<T>(string table) => JsonUtility.FromJson<T>(File.ReadAllText("Config/Tables/Equipment/"+table+".json"));
        [MenuItem("Project Y/装备/导出物品模型图标并同步背包")]
        public static void ExportAndSync()
        {
            ExportAll();InventoryAssets.Sync();
            Debug.Log("Model icons, inventory slots and character preview bindings saved.");
        }
        [MenuItem("Project Y/装备/仅导出物品模型图标")]
        public static void ExportAll()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("模型图标导出需要 Edit Mode。");
            var assets=Read<Assets>("EquipmentAssetTable").rows;
            var items=Read<Items>("EquipmentItemTable").rows;
            // Validate every row before writing any output. File icons remain artist-authored.
            foreach(var item in items)
            {
                if(item.iconMode=="none") {if(item.iconPath!="") throw new InvalidOperationException("none 图标必须留空路径: "+item.id);continue;}
                if(item.iconMode=="file") {if(AssetDatabase.LoadAssetAtPath<Sprite>(item.iconPath)==null) throw new InvalidOperationException("Missing authored Sprite: "+item.iconPath);continue;}
                if(item.iconMode!="model"||item.iconRotation==null||item.iconRotation.Length!=3||item.iconPadding<1||item.iconPadding>2)
                    throw new InvalidOperationException("Invalid model icon settings: "+item.id);
                var path=Path.GetFullPath(item.iconPath);var assetRoot=Path.GetFullPath(Application.dataPath)+Path.DirectorySeparatorChar;
                if(!path.StartsWith(assetRoot,StringComparison.OrdinalIgnoreCase)||!path.EndsWith(".png",StringComparison.OrdinalIgnoreCase))
                    throw new InvalidOperationException("图标必须输出到 Assets 内的 PNG: "+item.iconPath);
                var asset=Array.Find(assets,x=>x.id==item.assetId);
                if(asset==null||!File.Exists(asset.prefabPath)) throw new InvalidOperationException("Missing item model: "+item.id);
            }
            SyncModels(assets);
            int count=0;
            foreach(var item in items) if(item.iconMode=="model")
            {
                var asset=Array.Find(assets,x=>x.id==item.assetId);
                Export(item,AssetDatabase.LoadAssetAtPath<GameObject>(asset.prefabPath));count++;
            }
            EquipmentAssets.SyncItemIcons();AssetDatabase.SaveAssets();
            Debug.Log("Exported "+count+" model icons (transparent Sprite, long side 512 px, aspect matches inventory footprint).");
        }
        private static void SyncModels(Asset[] assets)
        {
            var entries=new List<EquipmentAssetCatalog.Entry>();
            foreach(var asset in assets)
            {
                // Standalone wearable/attachment FBX uses the same explicit axis and palette contract as weapons.
                // Weapon prefabs already contain authored sockets; never rebuild them during icon export.
                if(asset.modelPath==asset.prefabPath && !asset.modelPath.EndsWith(".prefab",StringComparison.OrdinalIgnoreCase))
                {
                    AssetDatabase.ImportAsset(asset.modelPath,ImportAssetOptions.ForceSynchronousImport);
                    var importer=AssetImporter.GetAtPath(asset.modelPath) as ModelImporter;
                    if(importer==null) throw new InvalidOperationException("Expected equipment model: "+asset.modelPath);
                    bool changed=!importer.bakeAxisConversion||importer.globalScale!=1||importer.importAnimation||importer.importCameras||importer.importLights;
                    importer.bakeAxisConversion=true;importer.globalScale=1;importer.importAnimation=false;importer.importCameras=false;importer.importLights=false;
                    var model=AssetDatabase.LoadAssetAtPath<GameObject>(asset.modelPath);var remaps=importer.GetExternalObjectMap();
                    foreach(var renderer in model.GetComponentsInChildren<Renderer>(true)) foreach(var material in renderer.sharedMaterials)
                    {
                        if(material==null) throw new InvalidOperationException("Missing model material: "+asset.modelPath);
                        var name=material.name;
                        var mapped=AssetDatabase.LoadAssetAtPath<Material>("Assets/DynamicAsset/EquipmentDemo/Materials/"+name+".mat")??AssetDatabase.LoadAssetAtPath<Material>("Assets/DynamicAsset/MapLowPoly/Materials/"+name+".mat");
                        if(mapped==null) throw new InvalidOperationException("Unknown equipment palette: "+name);
                        var key=new AssetImporter.SourceAssetIdentifier(typeof(Material),name);
                        if(!remaps.TryGetValue(key,out var old)||old!=mapped) {importer.AddRemap(key,mapped);changed=true;}
                    }
                    if(changed) importer.SaveAndReimport();
                }
                var prefab=AssetDatabase.LoadAssetAtPath<GameObject>(asset.prefabPath);
                if(prefab==null) throw new InvalidOperationException("Equipment model not imported: "+asset.prefabPath);
                entries.Add(new EquipmentAssetCatalog.Entry {Id=asset.id,Path=asset.prefabPath,Prefab=prefab});
            }
            var catalog=AssetDatabase.LoadAssetAtPath<EquipmentAssetCatalog>(EquipmentAssets.CatalogPath);
            if(catalog==null) throw new InvalidOperationException("请先同步装备基础资源。");
            catalog.SetEntries(entries.ToArray());EditorUtility.SetDirty(catalog);
        }
        private static void Export(Item item,GameObject prefab)
        {
            var scene=EditorSceneManager.NewPreviewScene();var previous=RenderTexture.active;
            RenderTexture target=null;Texture2D image=null;
            try
            {
                var model=(GameObject)PrefabUtility.InstantiatePrefab(prefab,scene);
                model.transform.position=Vector3.zero;model.transform.rotation=Quaternion.Euler(item.iconRotation[0],item.iconRotation[1],item.iconRotation[2]);
                var renderers=model.GetComponentsInChildren<Renderer>();
                if(renderers.Length==0) throw new InvalidOperationException("Model has no visible geometry: "+item.id);
                var bounds=renderers[0].bounds;foreach(var renderer in renderers) bounds.Encapsulate(renderer.bounds);
                if(bounds.size.sqrMagnitude<.000001f) throw new InvalidOperationException("Empty model bounds: "+item.id);
                var camera=new GameObject("IconCamera").AddComponent<Camera>();SceneManager.MoveGameObjectToScene(camera.gameObject,scene);
                camera.enabled=false;camera.scene=scene;camera.orthographic=true;camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=Color.clear;
                int width=Mathf.Max(32,Mathf.RoundToInt(512f*item.width/Mathf.Max(item.width,item.height)));
                int height=Mathf.Max(32,Mathf.RoundToInt(512f*item.height/Mathf.Max(item.width,item.height)));
                camera.allowHDR=false;camera.aspect=(float)width/height;camera.orthographicSize=Mathf.Max(bounds.extents.x/camera.aspect,bounds.extents.y)*item.iconPadding;
                var distance=Mathf.Max(2,bounds.size.magnitude*2);
                camera.transform.position=bounds.center+Vector3.back*distance;camera.transform.LookAt(bounds.center);
                camera.nearClipPlane=.01f;camera.farClipPlane=distance+bounds.size.magnitude+2;
                Light(scene,"Key",new Color(1,.92f,.8f),1.3f,new Vector3(28,-32,0));
                Light(scene,"Fill",new Color(.65f,.80f,1),.7f,new Vector3(15,145,0));
                target=new RenderTexture(width,height,24,RenderTextureFormat.ARGB32);target.Create();camera.targetTexture=target;camera.Render();
                RenderTexture.active=target;image=new Texture2D(width,height,TextureFormat.RGBA32,false);
                image.ReadPixels(new Rect(0,0,width,height),0,0);image.Apply();
                Directory.CreateDirectory(Path.GetDirectoryName(item.iconPath));File.WriteAllBytes(item.iconPath,image.EncodeToPNG());
                camera.targetTexture=null;
                AssetDatabase.ImportAsset(item.iconPath,ImportAssetOptions.ForceSynchronousImport);
                var importer=(TextureImporter)AssetImporter.GetAtPath(item.iconPath);
                importer.textureType=TextureImporterType.Sprite;importer.spriteImportMode=SpriteImportMode.Single;importer.alphaIsTransparency=true;
                importer.mipmapEnabled=false;importer.sRGBTexture=true;importer.textureCompression=TextureImporterCompression.Uncompressed;
                importer.maxTextureSize=512;importer.SaveAndReimport();
            }
            finally
            {
                RenderTexture.active=previous;
                if(image!=null) Object.DestroyImmediate(image);
                if(target!=null) {target.Release();Object.DestroyImmediate(target);}
                EditorSceneManager.ClosePreviewScene(scene);
            }
        }
        private static void Light(Scene scene,string name,Color color,float intensity,Vector3 angles)
        {
            var light=new GameObject(name).AddComponent<Light>();SceneManager.MoveGameObjectToScene(light.gameObject,scene);
            light.type=LightType.Directional;light.intensity=intensity;light.color=color;light.transform.rotation=Quaternion.Euler(angles);
        }
    }
}
