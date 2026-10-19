using System;
using System.Collections.Generic;
using UnityEngine;

namespace ProjectY.Samples
{
    /// <summary>Authored single-cell miniatures; gameplay state stays in the adventure snapshot.</summary>
    internal sealed class WorldPartyView : IDisposable
    {
        [Serializable] public sealed class Binding { public string path; public GameObject prefab; }
        private readonly GameObject root;
        private readonly Dictionary<string,GameObject> prefabs=new Dictionary<string,GameObject>();
        private readonly Dictionary<int,GameObject> pieces=new Dictionary<int,GameObject>();
        private readonly HashSet<int> alive=new HashSet<int>();
        private readonly List<int> removed=new List<int>();
        private AdventureViewData.WorldPartyState snapshot;
        private GameObject player;
        private readonly float radius;
        public WorldPartyView(Transform parent,Binding[] bindings,float cellRadius)
        {
            if(bindings==null || bindings.Length==0)throw new InvalidOperationException("请同步大地图队伍模型引用。");
            foreach(var binding in bindings)
            {
                if(binding==null || string.IsNullOrEmpty(binding.path) || binding.prefab==null)throw new InvalidOperationException("大地图队伍资源绑定缺失。");
                prefabs.Add(binding.path,binding.prefab);
            }
            radius=cellRadius;root=new GameObject("WorldPartyPieces");root.transform.SetParent(parent,false);
        }
        private GameObject Create(string path,string name,Vector3 position)
        {
            if(!prefabs.TryGetValue(path,out var prefab))throw new InvalidOperationException("未绑定大地图棋子："+path);
            var instance=UnityEngine.Object.Instantiate(prefab,root.transform,false);instance.name=name;
            instance.transform.localScale=Vector3.one*radius;instance.transform.position=position+Vector3.up*.025f;
            return instance;
        }
        public void Sync(AdventureViewData view)
        {
            root.SetActive(view.Phase=="map");snapshot=view.WorldParties;
            if(player==null)player=Create(snapshot.PlayerModelPath,"PlayerFlag",view.Travel.Position);
            alive.Clear();
            foreach(var party in snapshot.Rows)
            {
                alive.Add(party.Id);
                if(!pieces.ContainsKey(party.Id))pieces.Add(party.Id,Create(party.ModelPath,party.Name+"_"+party.Id,party.Position));
            }
            removed.Clear();foreach(var pair in pieces)if(!alive.Contains(pair.Key)){Destroy(pair.Value);removed.Add(pair.Key);}
            foreach(int id in removed)pieces.Remove(id);
        }
        private static void Move(GameObject piece,Vector3 target,float t)
        {
            var previous=piece.transform.position;var next=Vector3.Lerp(previous,target+Vector3.up*.025f,t);
            var direction=next-previous;direction.y=0;
            if(direction.sqrMagnitude>.00001f)piece.transform.rotation=Quaternion.Slerp(piece.transform.rotation,Quaternion.LookRotation(direction),t);
            piece.transform.position=next;
        }
        public void Tick(Vector3 playerPosition,float dt)
        {
            if(!root.activeSelf || snapshot==null)return;
            float t=1-Mathf.Exp(-dt*20);Move(player,playerPosition,1);
            foreach(var party in snapshot.Rows)Move(pieces[party.Id],party.Position,t);
        }
        public int Pick(Camera camera,Vector2 pointer)
        {
            if(!root.activeSelf || snapshot==null)return 0;
            int selected=0;float best=26*26;
            foreach(var party in snapshot.Rows)
            {
                var screen=camera.WorldToScreenPoint(pieces[party.Id].transform.position+Vector3.up*radius*.65f);
                if(screen.z<=0)continue;float distance=((Vector2)screen-pointer).sqrMagnitude;
                if(distance<best){best=distance;selected=party.Id;}
            }
            return selected;
        }
        public void DrawHover(Camera camera,GUIStyle style)
        {
            int id=Pick(camera,Input.mousePosition);if(id==0)return;
            var row=Array.Find(snapshot.Rows,p=>p.Id==id);
            var point=camera.WorldToScreenPoint(pieces[id].transform.position+Vector3.up*radius*1.8f);
            var content=new GUIContent(row.Name+" · "+row.Status+"\n点击追赶"+(row.Kind=="caravan"?" · 可交易 / 攻击":""));
            var size=style.CalcSize(content);var box=new Rect(Mathf.Clamp(point.x-size.x*.5f-8,0,Screen.width-size.x-16),Screen.height-point.y-size.y-12,size.x+16,size.y+8);
            var color=GUI.color;GUI.color=new Color(.08f,.12f,.11f,.94f);GUI.DrawTexture(box,Texture2D.whiteTexture);
            GUI.color=row.Kind=="caravan"?new Color(.93f,.79f,.48f):new Color(.98f,.68f,.57f);GUI.Label(new Rect(box.x+8,box.y+4,size.x,size.y),content,style);GUI.color=color;
        }
        private static void Destroy(GameObject value){if(Application.isPlaying)UnityEngine.Object.Destroy(value);else UnityEngine.Object.DestroyImmediate(value);}
        public void Dispose()=>Destroy(root);
    }
}
