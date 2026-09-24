using System;
using UnityEngine;

namespace ProjectY.Samples
{
    public sealed class EquipmentAssetCatalog : ScriptableObject
    {
        [Serializable] public struct Entry { public int Id; public string Path; public GameObject Prefab; }
        [SerializeField] private Entry[] entries;
        [Serializable] public struct Icon { public int Id; public string Path; public Sprite Sprite; }
        [SerializeField] private Icon[] icons;
        public Sprite ItemIcon(int id,string path)
        {
            foreach(var icon in icons) if(icon.Id==id)
            {
                if(icon.Path!=path || path!=""&&icon.Sprite==null) throw new InvalidOperationException("物品图标配置未同步："+id);
                return icon.Sprite;
            }
            throw new InvalidOperationException("未绑定物品图标："+id);
        }
        public GameObject Resolve(EquipmentVisualData.Asset asset)
        {
            foreach (var entry in entries) if (entry.Id==asset.Id)
            {
                if (entry.Path!=asset.Path || entry.Prefab==null) throw new InvalidOperationException("装备资源与配置不一致："+asset.Id);
                return entry.Prefab;
            }
            throw new InvalidOperationException("未绑定装备资源："+asset.Id);
        }
#if UNITY_EDITOR
        public void SetEntries(Entry[] value) { entries=value; }
        public void SetIcons(Icon[] value) { icons=value; }
#endif
    }
}
