using System;
using System.Collections.Generic;
using ProjectY.UI;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;
using Object=UnityEngine.Object;

namespace ProjectY.Editor
{
    /// <summary>Adds decoration and explicit references without rebuilding existing layouts.</summary>
    public static class LegendaryEquipmentUIAssets
    {
        public const string MaterialPath="Assets/DynamicAsset/UI/EquipmentRarity/LegendaryFrame.mat";
        private static Material FrameMaterial()
        {
            var material=AssetDatabase.LoadAssetAtPath<Material>(MaterialPath);
            if(material!=null)return material;
            if(!AssetDatabase.IsValidFolder("Assets/DynamicAsset/UI/EquipmentRarity"))
                AssetDatabase.CreateFolder("Assets/DynamicAsset/UI","EquipmentRarity");
            var shader=Shader.Find("ProjectY/UI/EquipmentRarityFrame");
            if(shader==null)throw new InvalidOperationException("Equipment frame shader is not imported.");
            material=new Material(shader){name="LegendaryFrame"};AssetDatabase.CreateAsset(material,MaterialPath);return material;
        }
        private static EquipmentRarityFrame Frame(Transform parent,string name,float inset)
        {
            var existing=parent.Find(name);
            var node=existing==null?new GameObject(name,typeof(RectTransform),typeof(CanvasRenderer),typeof(EquipmentRarityFrame)):existing.gameObject;
            if(existing==null)node.transform.SetParent(parent,false);
            var rect=(RectTransform)node.transform;rect.anchorMin=Vector2.zero;rect.anchorMax=Vector2.one;
            rect.offsetMin=Vector2.one*inset;rect.offsetMax=Vector2.one*-inset;
            var frame=node.GetComponent<EquipmentRarityFrame>();
            if(frame==null)throw new InvalidOperationException("Unexpected decoration node: "+name);
            frame.material=FrameMaterial();frame.raycastTarget=false;frame.maskable=true;
            frame.color=new Color(.94f,.77f,.43f);node.transform.SetAsLastSibling();node.SetActive(false);return frame;
        }
        public static void BindTile(InventoryItemView tile)
        {tile.BindRarity(Frame(tile.transform,"RarityFrame",0));}
        public static void BindRow(GameObject root)
        {
            var reference=root.GetComponent<LuaReference>();
            Bind(reference,"RarityFrame",Frame(root.transform,"RarityFrame",0));
        }
        public static void BindPanel(GameObject root,string titleKey)
        {
            var reference=root.GetComponent<LuaReference>();
            var title=reference.GetText(titleKey);
            Bind(reference,"DetailsRarityFrame",Frame(title.transform.parent,"DetailsRarityFrame",3));
        }
        private static void Bind(LuaReference reference,string key,Component value)
        {
            var bindings=new List<LuaReference.Entry>(reference.GetEditorBindings());
            bindings.RemoveAll(entry=>entry.Key==key);bindings.Add(new LuaReference.Entry(key,value));
            reference.SetEditorBindings(bindings.ToArray());reference.ValidateBindings();
        }
        [MenuItem("Project Y/装备/同步传奇装备外框")]
        public static void Sync()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode)throw new InvalidOperationException("Equipment frame sync requires Edit Mode.");
            string[] paths={"Assets/DynamicAsset/UI/Prefabs/Equipment/InventoryPanel.prefab","Assets/DynamicAsset/UI/Prefabs/Equipment/LootPanel.prefab",
                "Assets/DynamicAsset/UI/Prefabs/Equipment/EquipmentRowWidget.prefab","Assets/DynamicAsset/UI/Prefabs/Equipment/EquipmentWorkbenchPanel.prefab"};
            foreach(var path in paths)
            {
                var root=PrefabUtility.LoadPrefabContents(path);
                try
                {
                    foreach(var tile in root.GetComponentsInChildren<InventoryItemView>(true))BindTile(tile);
                    if(path.EndsWith("EquipmentRowWidget.prefab",StringComparison.Ordinal))BindRow(root);
                    else BindPanel(root,path.EndsWith("EquipmentWorkbenchPanel.prefab",StringComparison.Ordinal)?"Title":"ItemName");
                    PrefabUtility.SaveAsPrefabAsset(root,path);
                }
                finally{PrefabUtility.UnloadPrefabContents(root);}
            }
        }
    }
}
