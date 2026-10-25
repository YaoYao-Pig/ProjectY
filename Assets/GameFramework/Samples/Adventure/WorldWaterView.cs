using System;
using System.Collections.Generic;
using UnityEngine;
using Object=UnityEngine.Object;

namespace ProjectY.Samples
{
    /// <summary>Small set of persistent docks and boats; state and routes remain in the expedition.</summary>
    internal sealed class WorldWaterView : IDisposable
    {
        private sealed class Piece { public string Path; public GameObject Object; }
        private readonly GameObject root;
        private readonly Dictionary<string,GameObject> models=new Dictionary<string,GameObject>();
        private readonly Dictionary<int,Piece> pieces=new Dictionary<int,Piece>();
        private readonly HashSet<int> current=new HashSet<int>();
        private readonly List<int> removed=new List<int>();
        private bool sailing;
        public WorldWaterView(Transform parent,WorldPartyView.Binding[] bindings)
        {
            root=new GameObject("WorldWaterTravel");root.transform.SetParent(parent,false);
            foreach(var binding in bindings)models.Add(binding.path,binding.prefab);
        }
        private GameObject Place(int id,string path,Vector3 position,float yaw,float scale)
        {
            if(pieces.TryGetValue(id,out var piece) && piece.Path!=path){Destroy(piece.Object);pieces.Remove(id);piece=null;}
            if(piece==null)
            {
                if(!models.TryGetValue(path,out var prefab) || prefab==null)throw new InvalidOperationException("Missing water model: "+path);
                piece=new Piece {Path=path,Object=Object.Instantiate(prefab,root.transform,false)};pieces.Add(id,piece);
            }
            piece.Object.transform.SetPositionAndRotation(position,Quaternion.Euler(0,yaw,0));piece.Object.transform.localScale=Vector3.one*scale;
            current.Add(id);return piece.Object;
        }
        public void Sync(AdventureViewData view)
        {
            root.SetActive(view.Phase=="map");current.Clear();var water=view.Water;
            foreach(var row in water.Rows)Place(row.Id,row.Path,row.Position,row.Yaw,row.Scale);
            sailing=water.ShowBoat;
            if(sailing && !pieces.ContainsKey(0))Place(0,water.BoatPath,water.BoatPosition,0,water.BoatScale);
            if(sailing)current.Add(0);
            removed.Clear();foreach(var pair in pieces)if(!current.Contains(pair.Key))removed.Add(pair.Key);
            foreach(var id in removed){Destroy(pieces[id].Object);pieces.Remove(id);}
        }
        public void Tick(Vector3 displayed)
        {
            if(!sailing || !pieces.TryGetValue(0,out var piece))return;
            var target=piece.Object.transform;var delta=displayed-target.position;delta.y=0;
            if(delta.sqrMagnitude>.00001f)target.rotation=Quaternion.LookRotation(delta,Vector3.up);
            target.position=displayed;
        }
        private static void Destroy(Object value){if(Application.isPlaying)Object.Destroy(value);else Object.DestroyImmediate(value);}
        public void Dispose(){Destroy(root);pieces.Clear();}
    }
}
