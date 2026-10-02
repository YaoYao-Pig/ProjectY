using System;
using System.Collections.Generic;
using UnityEngine;

namespace ProjectY.Samples
{
    public sealed class AreaObstacleRenderer : IDisposable
    {
        private readonly Transform root;
        private readonly EquipmentAssetCatalog catalog;
        private readonly Dictionary<long,GameObject> objects=new Dictionary<long,GameObject>();
        private readonly HashSet<long> live=new HashSet<long>();
        public AreaObstacleRenderer(Transform parent,EquipmentAssetCatalog catalog)
        {this.catalog=catalog;root=new GameObject("AreaObstacles").transform;root.SetParent(parent,false);}
        public void Apply(MapAreaViewData.State state,MapAreaViewData layout)
        {
            live.Clear();
            foreach(var obstacle in state.Obstacles)foreach(var index in obstacle.Cells)
            {
                long key=((long)obstacle.Id<<32)|(uint)index;live.Add(key);
                if(!objects.TryGetValue(key,out var obj))
                {obj=UnityEngine.Object.Instantiate(catalog.Resolve(obstacle.Asset),root,false);objects.Add(key,obj);}
                obj.SetActive(true);obj.transform.position=layout.Cells[index].Position+Vector3.up*.02f;
            }
            foreach(var pair in objects)if(!live.Contains(pair.Key))pair.Value.SetActive(false);
        }
        public void Dispose() {if(root!=null)WeaponModelView.Remove(root.gameObject);}
    }
}
