using System;
using System.Collections.Generic;
using UnityEngine;

namespace ProjectY.Samples
{
    public sealed class AreaLootRenderer : IDisposable
    {
        private readonly Transform root;
        private readonly EquipmentAssetCatalog catalog;
        private readonly Func<int,bool> isCellShown;
        private readonly Dictionary<int,GameObject> objects=new Dictionary<int,GameObject>();
        private readonly Dictionary<int,int> assets=new Dictionary<int,int>();
        private readonly Dictionary<int,Renderer[]> renderers=new Dictionary<int,Renderer[]>();
        private readonly Dictionary<int,Vector3> scales=new Dictionary<int,Vector3>();
        private readonly Dictionary<int,Dictionary<int,GameObject>> contents=new Dictionary<int,Dictionary<int,GameObject>>();
        public AreaLootRenderer(Transform parent,EquipmentAssetCatalog catalog,Func<int,bool> isCellShown=null)
        { this.catalog=catalog;this.isCellShown=isCellShown;root=new GameObject("AreaLoot").transform;root.SetParent(parent,false); }
        public void Apply(MapAreaViewData.State state,MapAreaViewData layout)
        {
            var live=new HashSet<int>();
            var cellCounts=new Dictionary<int,int>();
            foreach(var loot in state.Loots)
            {
                live.Add(loot.Id);
                if(!assets.TryGetValue(loot.Id,out var id)||id!=loot.Asset.Id)
                {
                    if(objects.TryGetValue(loot.Id,out var old)) WeaponModelView.Remove(old);
                    objects[loot.Id]=UnityEngine.Object.Instantiate(catalog.Resolve(loot.Asset),root,false);assets[loot.Id]=loot.Asset.Id;
                    renderers[loot.Id]=objects[loot.Id].GetComponentsInChildren<Renderer>();
                    scales[loot.Id]=objects[loot.Id].transform.localScale;
                    contents[loot.Id]=new Dictionary<int,GameObject>();
                }
                int offset;cellCounts.TryGetValue(loot.CellIndex,out offset);cellCounts[loot.CellIndex]=offset+1;
                var spread=offset==0?Vector3.zero:new Vector3(Mathf.Cos(offset*2.4f),0,Mathf.Sin(offset*2.4f))*.42f;
                var obj=objects[loot.Id];obj.SetActive(isCellShown==null||isCellShown(loot.CellIndex));
                var anchor=layout.Cells[loot.CellIndex].Position;anchor.y=loot.Height;
                obj.transform.position=anchor+new Vector3(loot.OffsetX,.07f,loot.OffsetZ)+spread;
                obj.transform.localScale=Vector3.Scale(scales[loot.Id],loot.Scale3);obj.transform.rotation=Quaternion.Euler(0,loot.Rotation,0);
                var displayed=contents[loot.Id];var remaining=new HashSet<int>();
                foreach(var item in loot.Items)
                {
                    remaining.Add(item.Index);
                    if(!displayed.TryGetValue(item.Index,out var visual))
                    {
                        visual=UnityEngine.Object.Instantiate(catalog.Resolve(item.Asset),obj.transform,false);
                        visual.transform.localScale*=loot.DisplayItemScale;displayed.Add(item.Index,visual);
                    }
                    visual.SetActive(true);
                    visual.transform.localPosition=new Vector3((item.Index%3-1)*.42f,loot.DisplayHeight,(item.Index/3)*.3f);
                    visual.transform.localRotation=Quaternion.Euler(loot.DisplayContents=="surface"?90:0,0,0);
                }
                foreach(var pair in displayed)if(!remaining.Contains(pair.Key))pair.Value.SetActive(false);
            }
            foreach(var pair in objects) if(!live.Contains(pair.Key)) pair.Value.SetActive(false);
        }
        public int Pick(Ray ray)
        {
            int selected=0;float distance=float.PositiveInfinity;
            foreach(var pair in objects)if(pair.Value.activeInHierarchy)foreach(var renderer in renderers[pair.Key])
                if(renderer.enabled && renderer.bounds.IntersectRay(ray,out var hit) && hit<distance){selected=pair.Key;distance=hit;}
            return selected;
        }
        public void Dispose() { if(root!=null) WeaponModelView.Remove(root.gameObject); }
    }
}
