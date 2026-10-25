using System;
using System.Collections.Generic;
using System.IO;
using ProjectY.Samples;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using Object=UnityEngine.Object;

namespace ProjectY.Editor
{
    /// <summary>Compile generic equipment visual profiles into explicit prefab bindings.</summary>
    public static class LegendaryEquipmentVisualAssets
    {
        private const string MaterialRoot="Assets/DynamicAsset/EquipmentVisualProfiles/Materials";
        [Serializable] private sealed class ProfileRow
        {
            public int id,assetId,particleCount;
            public string name,color,accent,lightColor;
            public string[] glowMaterialNames;
            public float[] particleAnchors,lightAnchor;
            public float emission,pulseSpeed,pulseAmount,flowSpeed,flowScale,particleInterval,particleScale,lightIntensity,lightRange,maxVisibleDistance;
        }
        [Serializable] private sealed class ProfileTable {public ProfileRow[] rows;}
        [Serializable] private sealed class AssetRow {public int id;public string prefabPath;}
        [Serializable] private sealed class AssetTable {public AssetRow[] rows;}

        public static void SyncSelected(int[] assetIds)
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode) throw new InvalidOperationException("Equipment visual sync requires Edit Mode.");
            if(assetIds==null || assetIds.Length==0) throw new ArgumentException("Provide explicit equipment asset IDs.",nameof(assetIds));
            var profiles=JsonUtility.FromJson<ProfileTable>(File.ReadAllText("Config/Tables/Equipment/EquipmentVisualProfileTable.json")).rows;
            var assets=JsonUtility.FromJson<AssetTable>(File.ReadAllText("Config/Tables/Equipment/EquipmentAssetTable.json")).rows;
            var shader=AssetDatabase.LoadAssetAtPath<Shader>("Assets/GameFramework/Resources/EquipmentArcane.shader");
            if(shader==null || !shader.isSupported) throw new InvalidOperationException("Equipment Arcane shader is unavailable or unsupported.");
            Folder(MaterialRoot);
            var requested=new HashSet<int>(assetIds);var used=new HashSet<int>();var profileIds=new HashSet<int>();
            foreach(var row in profiles)
            {
                if(!profileIds.Add(row.id) || !used.Add(row.assetId)) throw new InvalidOperationException("Duplicate equipment visual profile or asset: "+row.id);
                if(!requested.Contains(row.assetId)) continue;
                Validate(row);
                var asset=Array.Find(assets,x=>x.id==row.assetId);
                if(asset==null || !asset.prefabPath.EndsWith(".prefab",StringComparison.OrdinalIgnoreCase))
                    throw new InvalidOperationException("Equipment visual profile requires an authored prefab: "+row.assetId);
                SyncPrefab(asset.prefabPath,row,shader);
            }
            foreach(var id in requested) if(!used.Contains(id)) throw new InvalidOperationException("Missing equipment visual profile for asset "+id);
        }
        private static void SyncPrefab(string path,ProfileRow row,Shader shader)
        {
            var root=PrefabUtility.LoadPrefabContents(path);
            try
            {
                var weapon=root.GetComponent<WeaponModelView>();
                if(weapon==null) throw new InvalidOperationException("Visual-profile prefab requires WeaponModelView: "+path);
                var view=root.GetComponent<EquipmentVisualProfileView>();
                if(view!=null)
                {
                    // Restore the recorded base materials before reapplying this profile.
                    foreach(var previous in view.MaterialBindings)
                    {
                        var materials=previous.Renderer.sharedMaterials;
                        materials[previous.MaterialIndex]=previous.OriginalMaterial;previous.Renderer.sharedMaterials=materials;
                    }
                    if(view.PointLight!=null) Object.DestroyImmediate(view.PointLight.gameObject);
                }
                else view=root.AddComponent<EquipmentVisualProfileView>();
                var bindings=new List<EquipmentVisualProfileView.MaterialBinding>();var matched=new HashSet<string>();
                foreach(var renderer in root.GetComponentsInChildren<Renderer>(true))
                {
                    if(renderer is ParticleSystemRenderer) continue;
                    var materials=renderer.sharedMaterials;
                    for(int i=0;i<materials.Length;i++)
                    {
                        var original=materials[i];
                        if(original==null) throw new InvalidOperationException("Equipment material is missing: "+path);
                        if(Array.IndexOf(row.glowMaterialNames,original.name)<0) continue;
                        matched.Add(original.name);materials[i]=BuildMaterial(row,original,shader);
                        bindings.Add(new EquipmentVisualProfileView.MaterialBinding {Renderer=renderer,MaterialIndex=i,OriginalMaterial=original});
                    }
                    renderer.sharedMaterials=materials;
                }
                foreach(var name in row.glowMaterialNames) if(!matched.Contains(name)) throw new InvalidOperationException("Glow material does not exist: "+row.id+" / "+name);
                Light light=null;
                if(row.lightIntensity>0)
                {
                    var obj=new GameObject("EquipmentAccentLight");obj.layer=root.layer;obj.transform.SetParent(root.transform,false);obj.transform.localPosition=Vector(row.lightAnchor,0);
                    light=obj.AddComponent<Light>();light.type=LightType.Point;light.color=ColorValue(row.lightColor);light.intensity=row.lightIntensity;
                    light.range=row.lightRange;light.shadows=LightShadows.None;light.renderMode=LightRenderMode.ForcePixel;
                    light.lightmapBakeType=LightmapBakeType.Realtime;light.enabled=false;
                }
                var anchors=new Vector3[row.particleAnchors.Length/3];
                for(int i=0;i<anchors.Length;i++) anchors[i]=Vector(row.particleAnchors,i*3);
                view.Bind(row.id,bindings.ToArray(),anchors,row.particleInterval,row.particleScale,row.particleCount,
                    ColorValue(row.color),ColorValue(row.accent),row.emission,light,row.lightIntensity,row.maxVisibleDistance,row.pulseSpeed,row.pulseAmount);
                weapon.SetVisualProfile(view);EditorUtility.SetDirty(view);EditorUtility.SetDirty(weapon);
                PrefabUtility.SaveAsPrefabAsset(root,path);
            }
            finally {PrefabUtility.UnloadPrefabContents(root);}
        }
        private static Material BuildMaterial(ProfileRow row,Material original,Shader shader)
        {
            string name="Visual_"+row.id+"_"+original.name,path=MaterialRoot+"/"+name+".mat";
            var material=AssetDatabase.LoadAssetAtPath<Material>(path);
            bool create=material==null;if(create) material=new Material(shader) {name=name};else material.shader=shader;
            if(!original.HasProperty("_BaseColor") || !original.HasProperty("_Metallic") || !original.HasProperty("_Smoothness"))
                throw new InvalidOperationException("Equipment glow requires a URP base material: "+original.name);
            material.SetColor("_BaseColor",original.GetColor("_BaseColor"));material.SetFloat("_Metallic",original.GetFloat("_Metallic"));material.SetFloat("_Smoothness",original.GetFloat("_Smoothness"));
            material.SetColor("_ArcaneColor",ColorValue(row.color));material.SetColor("_ArcaneAccent",ColorValue(row.accent));material.SetFloat("_ArcaneEmission",row.emission);
            material.SetFloat("_ArcanePulseSpeed",row.pulseSpeed);material.SetFloat("_ArcanePulseAmount",row.pulseAmount);
            material.SetFloat("_ArcaneFlowSpeed",row.flowSpeed);material.SetFloat("_ArcaneFlowScale",row.flowScale);material.SetFloat("_ArcaneTime",0);
            if(create) AssetDatabase.CreateAsset(material,path);else {EditorUtility.SetDirty(material);AssetDatabase.SaveAssetIfDirty(material);}
            return material;
        }
        private static void Validate(ProfileRow row)
        {
            if(row.id<=0 || row.assetId<=0 || row.glowMaterialNames==null || row.glowMaterialNames.Length==0 ||
               row.particleAnchors==null || row.particleAnchors.Length%3!=0 || row.particleAnchors.Length>12 || row.lightAnchor==null || row.lightAnchor.Length!=3)
                throw new InvalidOperationException("Invalid equipment visual profile shape: "+row.id);
            Range(row.emission,0,8);Range(row.pulseSpeed,0,12);Range(row.pulseAmount,0,1);Range(row.flowSpeed,-8,8);Range(row.flowScale,.1f,30);
            Range(row.particleInterval,.5f,10);Range(row.particleScale,.1f,2);Range(row.particleCount,1,8);
            Range(row.lightIntensity,0,2);Range(row.lightRange,.1f,3);Range(row.maxVisibleDistance,1,120);
            foreach(float v in row.particleAnchors) Range(v,-10,10);foreach(float v in row.lightAnchor) Range(v,-10,10);
            ColorValue(row.color);ColorValue(row.accent);ColorValue(row.lightColor);
        }
        private static void Range(float value,float min,float max)
        {if(float.IsNaN(value)||float.IsInfinity(value)||value<min||value>max) throw new InvalidOperationException("Equipment visual value outside range: "+value);}
        private static Color ColorValue(string value)
        {if(!ColorUtility.TryParseHtmlString(value,out var color)) throw new InvalidOperationException("Invalid equipment visual color: "+value);return color;}
        private static Vector3 Vector(float[] values,int start)=>new Vector3(values[start],values[start+1],values[start+2]);
        private static void Folder(string path)
        {
            if(AssetDatabase.IsValidFolder(path)) return;
            string parent=Path.GetDirectoryName(path).Replace('\\','/');Folder(parent);AssetDatabase.CreateFolder(parent,Path.GetFileName(path));
        }
    }
}
