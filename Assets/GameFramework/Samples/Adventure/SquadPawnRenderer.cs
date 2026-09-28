using System;
using System.Collections.Generic;
using UnityEngine;

namespace ProjectY.Samples
{
    /// <summary>Scene squad presentation. Destination and HP come from detached snapshots.</summary>
    public sealed class SquadPawnRenderer : IDisposable
    {
        private sealed class Pawn
        {
            public int ActorId, Sequence, MovementSequence;
            public PawnView View;
            public PawnMotion Motion;
            public AdventureViewData.Actor Actor;
            public bool Retiring;
        }
        private readonly List<Pawn> pawns = new List<Pawn>(4);
        private readonly GameObject root;
        private readonly PawnView prefab;
        private readonly Func<PawnAppearanceData.Part, GameObject> resolve;
        public bool Busy => pawns.Exists(p => p.Motion.Moving || p.View.PresentationBusy);
        public bool ActionBusy => pawns.Exists(p => p.View.PresentationBusy);
        public SquadPawnRenderer(Transform parent, PawnView prefab, Func<PawnAppearanceData.Part, GameObject> resolve)
        {
            if (prefab == null) throw new InvalidOperationException("小队棋子 Prefab 尚未绑定。");
            this.prefab = prefab; this.resolve = resolve;
            root = new GameObject("MapAreaSquad"); root.transform.SetParent(parent, false);
        }
        public void SetState(MapAreaViewData.State state, AdventureViewData.Actor[] party, MapAreaViewData layout, bool inBattle = false)
        {
            var occupied = new HashSet<int>();
            foreach (var member in state.Members) occupied.Add(member.CellIndex);
            foreach (var actor in state.Enemies) occupied.Add(actor.CellIndex);
            var allowed = inBattle ? new HashSet<int>(state.Known) : null;
            foreach (var member in state.Members)
            {
                var actor = Array.Find(party, value => value.Id == member.ActorId);
                if (actor == null || actor.HP <= 0) throw new InvalidOperationException("探索成员与存活队伍不一致。");
                var pawn = pawns.Find(value => value.ActorId == member.ActorId);
                if (pawn == null)
                {
                    pawn = new Pawn { ActorId = actor.Id, Sequence = actor.ActionSequence, MovementSequence=actor.MovementSequence, View = UnityEngine.Object.Instantiate(prefab, root.transform, false) };
                    pawn.View.name = actor.Name; pawn.View.ApplyAppearance(actor.Appearance, resolve);
                    pawn.Motion = new PawnMotion(pawn.View.transform, member.CellIndex, layout);
                    pawn.View.Capture(actor, pawn.View.transform.position, 0); pawns.Add(pawn);
                }
                pawn.Actor = actor; pawn.View.ApplyAppearance(actor.Appearance, resolve);
                pawn.Motion.Speed = inBattle ? pawn.View.BattleMoveSpeed : layout.Radius * 1.7320508f / layout.MoveStepSeconds;
                pawn.Motion.SetDestination(member.CellIndex, occupied, allowed,pawn.MovementSequence!=actor.MovementSequence?actor.MovementStyle:null);
                pawn.MovementSequence=actor.MovementSequence;
            }
            foreach (var pawn in pawns)
                if (!Array.Exists(state.Members, member => member.ActorId == pawn.ActorId))
                {
                    var actor = Array.Find(party, value => value.Id == pawn.ActorId);
                    if (actor == null || actor.HP > 0) throw new InvalidOperationException("Missing living squad member.");
                    pawn.Actor = actor; pawn.Retiring = true; pawn.Motion.Skip();
                }
        }
        public float ImpactDelay()
        {
            float delay = 0;
            foreach (var pawn in pawns)
                if (pawn.Actor.ActionSequence != pawn.Sequence)
                    delay = Mathf.Max(delay, pawn.Motion.SecondsRemaining + pawn.View.ImpactTime(pawn.Actor, pawn.Sequence));
            return delay;
        }
        public void Capture(float impactDelay)
        {
            foreach (var pawn in pawns)
            {
                pawn.View.Capture(pawn.Actor, pawn.Motion.ActionTarget(pawn.Actor), impactDelay);
                pawn.Sequence = pawn.Actor.ActionSequence;
            }
        }
        public void CaptureExit(AdventureViewData.Actor[] party)
        {
            foreach (var pawn in pawns)
            {
                pawn.Actor = Array.Find(party, value => value.Id == pawn.ActorId);
                pawn.View.Capture(pawn.Actor, pawn.View.transform.position, 0);
            }
        }
        public void Tick(float deltaTime)
        {
            for (int i = pawns.Count - 1; i >= 0; i--)
            {
                var pawn = pawns[i];
                float speed = pawn.Retiring ? 0 : pawn.Motion.Tick(deltaTime);
                pawn.View.TickPresentation(deltaTime, speed);
                if (pawn.Retiring && pawn.View.DeathFinished) {Destroy(pawn.View.gameObject); pawns.RemoveAt(i);}
            }
        }
        public void Skip() {foreach (var pawn in pawns) {pawn.Motion.Skip(); pawn.View.SkipPresentation();}}
        public int PickActor(Ray ray,out float distance)
        {
            int actorId=0;distance=float.PositiveInfinity;
            foreach(var pawn in pawns)
                if(!pawn.Retiring && pawn.Actor.HP>0 && pawn.View.Raycast(ray,out var hit) && hit<distance)
                {actorId=pawn.ActorId;distance=hit;}
            return actorId;
        }
        public void Interact(int actorId,bool talking) {pawns.Find(p=>p.ActorId==actorId).View.PlayInteraction(talking);}
        public Vector3 Position(int actorId) => Target(actorId).position;
        public Transform HealthTarget(int actorId)
        {
            var pawn=pawns.Find(value=>value.ActorId==actorId);
            if(pawn==null)throw new InvalidOperationException("Missing health target: "+actorId);
            return pawn.View.HealthTarget;
        }
        public Transform Target(int actorId)
        {
            var pawn = pawns.Find(value => value.ActorId == actorId);
            if (pawn == null) throw new InvalidOperationException("Missing squad pawn: " + actorId);
            return pawn.View.transform;
        }
        private static void Destroy(GameObject value)
        { value.SetActive(false); if (Application.isPlaying) UnityEngine.Object.Destroy(value); else UnityEngine.Object.DestroyImmediate(value); }
        public void Dispose() { Destroy(root); pawns.Clear(); }
    }
}
