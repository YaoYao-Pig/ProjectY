using System;
using System.Collections.Generic;
using UnityEngine;

namespace ProjectY.Samples
{
    /// <summary>小队模型与平滑显示；目标格来自 C# 权威快照，不参与寻路或决定占格。</summary>
    public sealed class SquadPawnRenderer : IDisposable
    {
        private sealed class Pawn { public int ActorId, FromCell, Cell; public PawnView View; public Vector3 Target; }
        private readonly List<Pawn> pawns = new List<Pawn>(4);
        private readonly GameObject root;
        private readonly PawnView prefab;
        private readonly Func<PawnAppearanceData.Part, GameObject> resolve;
        private float walkSpeed;
        private MapAreaViewData terrain;
        public SquadPawnRenderer(Transform parent, PawnView prefab, Func<PawnAppearanceData.Part, GameObject> resolve)
        {
            if (prefab == null) throw new InvalidOperationException("小队棋子 Prefab 尚未绑定。");
            this.prefab = prefab; this.resolve = resolve;
            root = new GameObject("MapAreaSquad"); root.transform.SetParent(parent, false);
        }
        public void SetState(MapAreaViewData.State state, AdventureViewData.Actor[] party, MapAreaViewData layout, bool inBattle = false)
        {
            walkSpeed = layout.IsTown ? layout.Radius * 1.7320508f / layout.MoveStepSeconds : 0;
            terrain = layout;
            if (state.Members.Length < 1 || state.Members.Length > 4) throw new InvalidOperationException("小队成员数量应为 1–4。");
            foreach (var member in state.Members)
            {
                var actor = Array.Find(party, value => value.Id == member.ActorId);
                if (actor == null || actor.HP <= 0) throw new InvalidOperationException("探索成员与存活队伍不一致。");
                var pawn = pawns.Find(value => value.ActorId == member.ActorId);
                var position = layout.Cells[member.CellIndex].Position + Vector3.up * .015f;
                if (pawn == null)
                {
                    pawn = new Pawn { ActorId = actor.Id, FromCell = member.CellIndex, Cell = member.CellIndex, View = UnityEngine.Object.Instantiate(prefab, root.transform, false) };
                    pawn.View.name = actor.Name; pawn.View.transform.position = position; pawns.Add(pawn);
                }
                if (pawn.Cell != member.CellIndex)
                {
                    // 快照轮询可能略早于显示插值完成；先收束上一段，避免转角切出真实导航边。
                    if (layout.IsTown) pawn.View.transform.position = TownSurfaceRenderer.Ground(layout, pawn.Cell, pawn.Cell, pawn.Target);
                    pawn.FromCell = pawn.Cell; pawn.Cell = member.CellIndex;
                }
                pawn.Target = position; pawn.View.ApplyAppearance(actor.Appearance, resolve);
                // 静态战棋先直接落到结算后的格子，避免跨多格插值穿过墙壁。
                if (inBattle) pawn.View.transform.position = position;
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
                if (walkSpeed > 0)
                {
                    var from = transform.position; var target = pawn.Target; from.y = target.y = 0;
                    transform.position = TownSurfaceRenderer.Ground(terrain, pawn.FromCell, pawn.Cell, Vector3.MoveTowards(from, target, walkSpeed * deltaTime));
                }
                else transform.position = Vector3.Lerp(transform.position, pawn.Target, factor);
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
