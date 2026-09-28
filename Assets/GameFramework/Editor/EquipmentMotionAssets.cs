using System;
using System.Collections.Generic;
using System.IO;
using ProjectY.Samples;
using UnityEditor;
using UnityEngine;

namespace ProjectY.Editor
{
    public static class EquipmentMotionAssets
    {
        [Serializable] private sealed class Module { public int id, holdId, sourceHoldId; public string name; }
        [Serializable] private sealed class Table { public Module[] rows; }
        [Serializable] private sealed class AssetRow { public int id; public string modelPath,prefabPath; }
        [Serializable] private sealed class AssetRows { public AssetRow[] rows; }
        [Serializable] private sealed class ItemRow { public int id,assetId; public string kind,iconPath; }
        [Serializable] private sealed class ItemRows { public ItemRow[] rows; }
        [Serializable] private sealed class SocketRow { public int id,weaponItemId; public float[] position,rotation; }
        [Serializable] private sealed class SocketRows { public SocketRow[] rows; }
        [MenuItem("Project Y/角色/同步持武模组动画配置")]
        public static void Sync()
        {
            var set=AssetDatabase.LoadAssetAtPath<PawnAnimationSet>(PawnAnimationAssets.SetPath);
            if(set==null)throw new InvalidOperationException("Sync Humanoid animation assets first.");
            var modules=JsonUtility.FromJson<Table>(File.ReadAllText("Config/Tables/Equipment/EquipmentMotionModuleTable.json"));
            var holds=new List<PawnAnimationSet.Hold>(set.Holds);
            foreach(var module in modules.rows)
            {
                if(holds.Exists(h=>h.PoseId==module.holdId))continue;
                var source=holds.Find(h=>h.PoseId==module.sourceHoldId) ?? throw new InvalidOperationException("Missing source hold for "+module.name);
                var copy=JsonUtility.FromJson<PawnAnimationSet.Hold>(JsonUtility.ToJson(source));copy.PoseId=module.holdId;holds.Add(copy);
            }
            set.Holds=holds.ToArray();EditorUtility.SetDirty(set);
            var assets=JsonUtility.FromJson<AssetRows>(File.ReadAllText("Config/Tables/Equipment/EquipmentAssetTable.json")).rows;
            var items=JsonUtility.FromJson<ItemRows>(File.ReadAllText("Config/Tables/Equipment/EquipmentItemTable.json")).rows;
            var sockets=JsonUtility.FromJson<SocketRows>(File.ReadAllText("Config/Tables/Equipment/EquipmentSocketTable.json")).rows;
            var entries=new List<EquipmentAssetCatalog.Entry>();
            foreach(var asset in assets)
            {
                var prefab=AssetDatabase.LoadAssetAtPath<GameObject>(asset.prefabPath);
                if(prefab==null)
                {
                    var item=Array.Find(items,i=>i.assetId==asset.id&&i.kind=="weapon");
                    if(item==null)throw new InvalidOperationException("Missing equipment prefab: "+asset.prefabPath);
                    var root=new GameObject("Weapon_"+item.id);
                    try
                    {
                        var model=UnityEngine.Object.Instantiate(AssetDatabase.LoadAssetAtPath<GameObject>(asset.modelPath));model.transform.SetParent(root.transform,false);
                        var mounts=new List<WeaponModelView.Mount>();
                        foreach(var socket in sockets)if(socket.weaponItemId==item.id)
                        {
                            var anchor=new GameObject("Socket_"+socket.id).transform;anchor.SetParent(root.transform,false);
                            anchor.localPosition=new Vector3(socket.position[0],socket.position[1],socket.position[2]);anchor.localRotation=Quaternion.Euler(socket.rotation[0],socket.rotation[1],socket.rotation[2]);
                            mounts.Add(new WeaponModelView.Mount {Id=socket.id,Anchor=anchor});
                        }
                        root.AddComponent<WeaponModelView>().SetMounts(mounts.ToArray());
                        PrefabUtility.SaveAsPrefabAsset(root,asset.prefabPath);
                    }
                    finally{UnityEngine.Object.DestroyImmediate(root);}
                    prefab=AssetDatabase.LoadAssetAtPath<GameObject>(asset.prefabPath);
                }
                entries.Add(new EquipmentAssetCatalog.Entry {Id=asset.id,Path=asset.prefabPath,Prefab=prefab});
            }
            var catalog=AssetDatabase.LoadAssetAtPath<EquipmentAssetCatalog>(EquipmentAssets.CatalogPath);catalog.SetEntries(entries.ToArray());
            var icons=new List<EquipmentAssetCatalog.Icon>();foreach(var item in items)icons.Add(new EquipmentAssetCatalog.Icon {Id=item.id,Path=item.iconPath,Sprite=item.iconPath==""?null:AssetDatabase.LoadAssetAtPath<Sprite>(item.iconPath)});
            catalog.SetIcons(icons.ToArray());EditorUtility.SetDirty(catalog);AssetDatabase.SaveAssets();
        }
    }
}
