using System;
using System.Collections.Generic;
using System.IO;
using ProjectY.Samples;
using UnityEditor;
using UnityEngine;

namespace ProjectY.Editor
{
    public static class ConstructionAssets
    {
        [Serializable]private sealed class AssetRows{public AssetRow[] rows;}
        [Serializable]private sealed class AssetRow{public int id;public string prefabPath;}
        public const string Root="Assets/DynamicAsset/Construction";
        [MenuItem("Project Y/营造/同步营造资源")]
        public static void Create()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode)throw new InvalidOperationException("请在 Edit Mode 同步营造资源。");
            Directory.CreateDirectory(Root+"/Models");Directory.CreateDirectory(Root+"/Materials");
            string[] names={"Craft_Wood","Craft_Plank","Craft_Rope","Craft_Iron"};string[] colors={"#66594a","#978066","#b29e74","#596366"};
            var materials=new Dictionary<string,Material>();
            var shader=Shader.Find("Universal Render Pipeline/Lit");if(shader==null)throw new InvalidOperationException("Missing URP Lit shader.");
            for(int i=0;i<names.Length;i++)
            {
                string path=Root+"/Materials/"+names[i]+".mat";var material=AssetDatabase.LoadAssetAtPath<Material>(path);
                if(material==null){material=new Material(shader);AssetDatabase.CreateAsset(material,path);}
                ColorUtility.TryParseHtmlString(colors[i],out var color);material.color=color;material.SetFloat("_Smoothness",.12f);material.SetFloat("_Metallic",0);EditorUtility.SetDirty(material);materials.Add(names[i],material);
            }
            string[] models={"Craft_Fence","Craft_Wall","Craft_Step","Craft_Platform","Craft_WoodBundle","Craft_RopeCoil","Craft_IronParts"};
            var bindings=new List<ConstructionAssetCatalog.Entry>();
            for(int i=0;i<models.Length;i++)
            {
                string path=Root+"/Models/"+models[i]+".fbx";
                if(!File.Exists(path))throw new FileNotFoundException("Export and copy construction FBX first.",path);
                AssetDatabase.ImportAsset(path,ImportAssetOptions.ForceSynchronousImport);
                var importer=(ModelImporter)AssetImporter.GetAtPath(path);importer.globalScale=1;importer.useFileScale=true;importer.bakeAxisConversion=true;
                importer.importAnimation=false;importer.animationType=ModelImporterAnimationType.None;importer.materialImportMode=ModelImporterMaterialImportMode.ImportStandard;
                foreach(var pair in materials)importer.AddRemap(new AssetImporter.SourceAssetIdentifier(typeof(Material),pair.Key),pair.Value);
                importer.SaveAndReimport();
                if(i<4)bindings.Add(new ConstructionAssetCatalog.Entry{SkillId=301+i,Prefab=AssetDatabase.LoadAssetAtPath<GameObject>(path)});
            }
            const string catalogPath="Assets/GameFramework/Resources/ConstructionAssets.asset";
            var catalog=AssetDatabase.LoadAssetAtPath<ConstructionAssetCatalog>(catalogPath);
            if(catalog==null){catalog=ScriptableObject.CreateInstance<ConstructionAssetCatalog>();AssetDatabase.CreateAsset(catalog,catalogPath);}
            catalog.Bind(bindings.ToArray());EditorUtility.SetDirty(catalog);AssetDatabase.SaveAssets();
            var equipment=AssetDatabase.LoadAssetAtPath<EquipmentAssetCatalog>(EquipmentAssets.CatalogPath);
            if(equipment==null)throw new InvalidOperationException("Missing equipment catalog.");
            var entries=new List<EquipmentAssetCatalog.Entry>();
            foreach(var row in JsonUtility.FromJson<AssetRows>(File.ReadAllText("Config/Tables/Equipment/EquipmentAssetTable.json")).rows)
            {
                var prefab=AssetDatabase.LoadAssetAtPath<GameObject>(row.prefabPath);if(prefab==null)throw new InvalidOperationException("Missing equipment asset: "+row.prefabPath);
                entries.Add(new EquipmentAssetCatalog.Entry{Id=row.id,Path=row.prefabPath,Prefab=prefab});
            }
            equipment.SetEntries(entries.ToArray());EditorUtility.SetDirty(equipment);AssetDatabase.SaveAssetIfDirty(equipment);
            EquipmentIconExporter.ExportItems(new[]{81,82,83});
            Debug.Log("Construction models, materials and inventory icons synchronized.");
        }
    }
}
