using System;
using System.Collections.Generic;
using UnityEngine;

namespace ProjectY.Samples
{
    /// <summary>Display movement over real navigation edges; never decides destination or occupancy.</summary>
    public sealed class PawnMotion
    {
        private readonly List<int> path = new List<int>();
        private int cell, destination;
        private readonly MapAreaViewData layout;
        private readonly Transform target;
        public float Speed;
        private bool jumping;
        private Vector3 jumpStart,jumpEnd;
        private float jumpTime,jumpDuration;
        public bool Moving => jumping || path.Count > 0;
        public PawnMotion(Transform target, int cell, MapAreaViewData layout)
        {
            this.target = target; this.cell = destination = cell; this.layout = layout;
            target.position = layout.Cells[cell].Position + Vector3.up * .015f;
        }
        public void SetDestination(int value, HashSet<int> occupied, HashSet<int> allowed = null, string movement = null)
        {
            if (value == destination) return;
            if(movement=="leap" || movement=="pounce")
            {
                path.Clear();destination=value;jumpStart=target.position;jumpEnd=layout.Cells[value].Position+Vector3.up*.015f;
                jumpTime=0;jumpDuration=Mathf.Max(.25f,Vector3.Distance(jumpStart,jumpEnd)/Mathf.Max(.1f,Speed));jumping=true;return;
            }
            if(movement=="charge") {path.Clear();path.Add(value);destination=value;return;}
            int start = cell;
            if (path.Count > 0) { start = path[0]; path.RemoveRange(1, path.Count - 1); }
            var previous = new Dictionary<int, int> { { start, -1 } };
            var queue = new Queue<int>(); queue.Enqueue(start);
            while (queue.Count > 0 && !previous.ContainsKey(value))
            {
                int index = queue.Dequeue(); var row = layout.Cells[index];
                for (int d = 0; d < row.Neighbors.Length; d++)
                {
                    int next = row.Neighbors[d];
                    if (next < 0 || (row.WalkMask & (1 << d)) == 0 || layout.Cells[next].Blocked || previous.ContainsKey(next)) continue;
                    if ((next != value && occupied.Contains(next)) || (allowed != null && !allowed.Contains(next))) continue;
                    previous.Add(next, index); queue.Enqueue(next);
                }
            }
            if (!previous.ContainsKey(value)) throw new InvalidOperationException("No display route between pawn cells: " + start + " -> " + value);
            var route = new List<int>();
            for (int cursor = value; cursor != start; cursor = previous[cursor]) route.Add(cursor);
            route.Reverse(); path.AddRange(route); destination = value;
        }
        public float SecondsRemaining
        {
            get
            {
                float distance = 0; var from = target.position;
                if(jumping) return Mathf.Max(0,jumpDuration-jumpTime);
                foreach (int index in path) {var to = layout.Cells[index].Position; distance += Vector3.Distance(from, to); from = to;}
                return distance / Mathf.Max(.1f, Speed);
            }
        }
        public float Tick(float deltaTime)
        {
            if(jumping && deltaTime>0)
            {
                jumpTime=Mathf.Min(jumpDuration,jumpTime+deltaTime);float t=jumpTime/jumpDuration;
                target.position=Vector3.Lerp(jumpStart,jumpEnd,t)+Vector3.up*Mathf.Sin(t*Mathf.PI)*Mathf.Min(1.6f,Vector3.Distance(jumpStart,jumpEnd)*.35f);
                var direction=jumpEnd-jumpStart;direction.y=0;if(direction.sqrMagnitude>.001f)target.rotation=Quaternion.LookRotation(direction);
                if(t>=1) {jumping=false;cell=destination;target.position=jumpEnd;}
                return Vector3.Distance(jumpStart,jumpEnd)/jumpDuration;
            }
            if (deltaTime <= 0 || path.Count == 0) return 0;
            float distance = Speed * deltaTime, moved = 0;
            while (path.Count > 0 && distance > 0)
            {
                int next = path[0]; var to = layout.Cells[next].Position + Vector3.up * .015f;
                var from = target.position; var direction = to - from; direction.y = 0;
                float length = direction.magnitude, step = Mathf.Min(length, distance);
                if (length > .001f) target.rotation = Quaternion.Slerp(target.rotation, Quaternion.LookRotation(direction), 1 - Mathf.Exp(-deltaTime * 18));
                var point = length > .001f ? Vector3.Lerp(from, to, step / length) : to;
                target.position = layout.IsTown ? TownSurfaceRenderer.Ground(layout, cell, next, point) : point;
                moved += step; distance -= step;
                if (length > step + .001f) break;
                target.position = to; cell = next; path.RemoveAt(0);
            }
            return moved / deltaTime;
        }
        public void Skip() {jumping=false;path.Clear(); cell = destination; target.position = layout.Cells[cell].Position + Vector3.up * .015f;}
        public Vector3 ActionTarget(AdventureViewData.Actor actor)
        {
            // A following self-guard must not erase the attack's facing.
            for (int i = actor.Actions.Length - 1; i >= 0; i--)
            {
                var action = actor.Actions[i];
                if (action.TemplateId == 0) continue;
                foreach (var row in layout.Cells) if (row.Q == action.TargetQ && row.R == action.TargetR && row.Layer == layout.Cells[cell].Layer) return row.Position;
            }
            return target.position;
        }
    }
}
