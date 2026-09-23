using System;
using System.Collections.Generic;
using UnityEngine;

namespace ProjectY.Samples
{
    /// <summary>居民与工匠复用棋子挂点；仅平滑显示真实 NPC 占格，不持有巡游规则。</summary>
    public sealed class TownNpcRenderer : IDisposable
    {
        private sealed class Item { public PawnView View; public Vector3 Target; public float Speed; }
        private readonly GameObject root;
        private readonly Dictionary<int, Item> items = new Dictionary<int, Item>();
        public TownNpcRenderer(Transform parent, PawnView rig, MapAreaViewData layout, Func<PawnAppearanceData.Part, GameObject> resolve)
        {
            root = new GameObject("TownResidents"); root.transform.SetParent(parent, false);
            foreach (var npc in layout.Npcs)
            {
                var pawn = UnityEngine.Object.Instantiate(rig, root.transform, false); pawn.name = npc.Name + "_" + npc.Id;
                pawn.ApplyAppearance(npc.Appearance, resolve); pawn.gameObject.SetActive(false);
                items.Add(npc.Id, new Item { View = pawn, Speed = layout.Radius * 1.7320508f / npc.StepSeconds });
            }
        }
        public void SetState(MapAreaViewData.State state, MapAreaViewData layout)
        {
            foreach (var npc in state.Npcs)
            {
                var item = items[npc.Id]; item.Target = layout.Cells[npc.CellIndex].Position + Vector3.up * .015f;
                if (!item.View.gameObject.activeSelf) { item.View.transform.position = item.Target; item.View.gameObject.SetActive(true); }
            }
        }
        public void Tick(float dt)
        {
            foreach (var item in items.Values)
            {
                var target = item.View.transform; var delta = item.Target - target.position; delta.y = 0;
                if (delta.sqrMagnitude > .01f) target.rotation = Quaternion.Slerp(target.rotation, Quaternion.LookRotation(delta), 1 - Mathf.Exp(-dt * 10));
                target.position = Vector3.MoveTowards(target.position, item.Target, item.Speed * dt);
            }
        }
        public Vector3 Position(int id) => items[id].View.transform.position;
        public void Dispose()
        {
            root.SetActive(false);
            if (Application.isPlaying) UnityEngine.Object.Destroy(root); else UnityEngine.Object.DestroyImmediate(root);
            items.Clear();
        }
    }
}
