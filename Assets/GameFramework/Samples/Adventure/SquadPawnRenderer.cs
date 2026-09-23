using System;
using System.Collections.Generic;
using UnityEngine;

namespace ProjectY.Samples
{
    /// <summary>小队模型与平滑显示；目标格来自 C# 权威快照，不参与寻路或决定占格。</summary>
    public sealed class SquadPawnRenderer : IDisposable
    {
        private sealed class Pawn { public int ActorId; public PawnView View; public Vector3 Target; }
        private readonly List<Pawn> pawns = new List<Pawn>(4);
        private readonly GameObject root;
        private readonly PawnView prefab;
        private readonly Func<PawnAppearanceData.Part, GameObject> resolve;
        private float walkSpeed;
        public SquadPawnRenderer(Transform parent, PawnView prefab, Func<PawnAppearanceData.Part, GameObject> resolve)
        {
            if (prefab == null) throw new InvalidOperationException("小队棋子 Prefab 尚未绑定。");
            this.prefab = prefab; this.resolve = resolve;
            root = new GameObject("MapAreaSquad"); root.transform.SetParent(parent, false);
        }
        public void SetState(MapAreaViewData.State state, AdventureViewData.Actor[] party, MapAreaViewData layout)
        {
            walkSpeed = layout.IsTown ? layout.Radius * 1.7320508f / layout.MoveStepSeconds : 0;
            if (state.Members.Length < 1 || state.Members.Length > 4) throw new InvalidOperationException("小队成员数量应为 1–4。");
            foreach (var member in state.Members)
            {
                var actor = Array.Find(party, value => value.Id == member.ActorId);
                if (actor == null || actor.HP <= 0) throw new InvalidOperationException("探索成员与存活队伍不一致。");
                var pawn = pawns.Find(value => value.ActorId == member.ActorId);
                var position = layout.Cells[member.CellIndex].Position + Vector3.up * .015f;
                if (pawn == null)
                {
                    pawn = new Pawn { ActorId = actor.Id, View = UnityEngine.Object.Instantiate(prefab, root.transform, false) };
                    pawn.View.name = actor.Name; pawn.View.transform.position = position; pawns.Add(pawn);
                }
                pawn.Target = position; pawn.View.ApplyAppearance(actor.Appearance, resolve);
            }
            for (var i = pawns.Count - 1; i >= 0; i--)
                if (!Array.Exists(state.Members, member => member.ActorId == pawns[i].ActorId))
                { Destroy(pawns[i].View.gameObject); pawns.RemoveAt(i); }
        }
        public void Tick(float deltaTime)
        {
            var factor = 1 - Mathf.Exp(-deltaTime * 18);
            foreach (var pawn in pawns)
            {
                var transform = pawn.View.transform; var direction = pawn.Target - transform.position; direction.y = 0;
                if (direction.sqrMagnitude > .01f) transform.rotation = Quaternion.Slerp(transform.rotation, Quaternion.LookRotation(direction), factor);
                transform.position = walkSpeed > 0 ? Vector3.MoveTowards(transform.position, pawn.Target, walkSpeed * deltaTime)
                    : Vector3.Lerp(transform.position, pawn.Target, factor);
            }
        }
        public Vector3 Position(int actorId)
        {
            var pawn = pawns.Find(value => value.ActorId == actorId);
            if (pawn == null) throw new InvalidOperationException("未找到探索棋子：" + actorId);
            return pawn.View.transform.position;
        }
        private static void Destroy(GameObject value)
        { value.SetActive(false); if (Application.isPlaying) UnityEngine.Object.Destroy(value); else UnityEngine.Object.DestroyImmediate(value); }
        public void Dispose() { Destroy(root); pawns.Clear(); }
    }
}
