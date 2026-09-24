using System;
using System.Collections.Generic;
using UnityEngine;

namespace ProjectY.Samples
{
    public sealed class AreaLootRenderer : IDisposable
    {
        private readonly Transform root;
        private readonly EquipmentAssetCatalog catalog;
        private readonly Dictionary<int,GameObject> objects=new Dictionary<int,GameObject>();
        private readonly Dictionary<int,int> assets=new Dictionary<int,int>();
        public AreaLootRenderer(Transform parent,EquipmentAssetCatalog catalog)
        { this.catalog=catalog;root=new GameObject("AreaLoot").transform;root.SetParent(parent,false); }
        public void Apply(MapAreaViewData.State state,MapAreaViewData layout)
        {
            var live=new HashSet<int>();
            foreach(var loot in state.Loots)
            {
                live.Add(loot.Id);
                if(!assets.TryGetValue(loot.Id,out var id)||id!=loot.Asset.Id)
                {
                    if(objects.TryGetValue(loot.Id,out var old)) WeaponModelView.Remove(old);
                    objects[loot.Id]=UnityEngine.Object.Instantiate(catalog.Resolve(loot.Asset),root,false);assets[loot.Id]=loot.Asset.Id;
                }
                var obj=objects[loot.Id];obj.SetActive(true);obj.transform.position=layout.Cells[loot.CellIndex].Position+Vector3.up*.07f;
            }
            foreach(var pair in objects) if(!live.Contains(pair.Key)) pair.Value.SetActive(false);
        }
        public void Dispose() { if(root!=null) WeaponModelView.Remove(root.gameObject); }
    }
}
