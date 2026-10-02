using System;
using System.Collections.Generic;
using UnityEngine;

namespace ProjectY.Samples
{
    public sealed class ConstructionRenderer:IDisposable
    {
        private readonly Transform root;
        private readonly ConstructionAssetCatalog catalog;
        private readonly Dictionary<int,GameObject> models=new Dictionary<int,GameObject>();
        private readonly HashSet<int> live=new HashSet<int>(),visible=new HashSet<int>();
        public ConstructionRenderer(Transform parent)
        {
            catalog=Resources.Load<ConstructionAssetCatalog>("ConstructionAssets");
            if(catalog==null)throw new InvalidOperationException("Missing construction catalog. Run Project Y/营造/同步营造资源.");
            root=new GameObject("BattleConstructions").transform;root.SetParent(parent,false);
        }
        public void Apply(MapAreaViewData.State state,MapAreaViewData map)
        {
            live.Clear();visible.Clear();foreach(int index in state.Visible)visible.Add(index);
            foreach(var row in state.Constructions)
            {
                if(row.Kind=="pit"||row.Kind=="trench")continue;
                live.Add(row.Id);
                if(!models.TryGetValue(row.Id,out var model)){model=UnityEngine.Object.Instantiate(catalog.Resolve(row.SkillId),root,false);models.Add(row.Id,model);}
                model.SetActive(visible.Contains(row.CellIndex));model.transform.position=map.Cells[row.CellIndex].BasePosition;
            }
            foreach(var pair in models)if(!live.Contains(pair.Key))pair.Value.SetActive(false);
        }
        public void Dispose(){if(root!=null)WeaponModelView.Remove(root.gameObject);}
    }
}
