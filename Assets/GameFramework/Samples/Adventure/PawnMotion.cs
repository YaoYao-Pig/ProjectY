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
            target.position = Position(cell);
        }
        private Vector3 Position(int index) => layout.IsTown || layout.Cells[index].UsesSurfaceMesh
            ? TownSurfaceRenderer.Ground(layout, index, index, layout.Cells[index].Position)
            : layout.Cells[index].Position + Vector3.up * .015f;
        public void SetDestination(int value, HashSet<int> occupied, HashSet<int> allowed = null, string movement = null)
        {
            if (value == destination)
            {
                // A platform can disappear while its occupant keeps the same cell identity.
                if(!Moving)target.position=Position(cell);
                return;
            }
            if(movement=="leap" || movement=="pounce")
            {
                path.Clear();destination=value;jumpStart=target.position;jumpEnd=Position(value);
                jumpTime=0;jumpDuration=Mathf.Max(.25f,Vector3.Distance(jumpStart,jumpEnd)/Mathf.Max(.1f,Speed));jumping=true;return;
            }
            if(movement=="charge") {ChargeRoute(value);destination=value;return;}
            int start = cell;
            if (path.Count > 0) { start = path[0]; path.RemoveRange(1, path.Count - 1); }
            var previous = new Dictionary<int, int> { { start, -1 } };
            var distance=new Dictionary<int,int>{{start,0}};
            var queue=new SortedSet<KeyValuePair<int,int>>(Comparer<KeyValuePair<int,int>>.Create((a,b)=>a.Key==b.Key?a.Value.CompareTo(b.Value):a.Key.CompareTo(b.Key)));
            queue.Add(new KeyValuePair<int,int>(0,start));
            while (queue.Count > 0)
            {
                var first=queue.Min;queue.Remove(first);int index=first.Value;if(index==value)break;var row = layout.Cells[index];
                for (int d = 0; d < row.Neighbors.Length; d++)
                {
                    int next = row.Neighbors[d];
                    if (next < 0 || (row.WalkMask & (1 << d)) == 0 || layout.Cells[next].Blocked) continue;
                    if ((next != value && occupied.Contains(next)) || (allowed != null && !allowed.Contains(next))) continue;
                    var targetCell=layout.Cells[next];bool climb=Mathf.Abs(row.Position.y-targetCell.Position.y)>.05f;
                    int extra=row.ConstructionKind=="platform"&&climb?row.ConstructionMoveExtra:0;
                    if(targetCell.ConstructionKind!="platform"||climb)extra=Mathf.Max(extra,targetCell.ConstructionMoveExtra);
                    int cost=distance[index]+1+extra;
                    if(distance.TryGetValue(next,out var old)) {if(old<=cost)continue;queue.Remove(new KeyValuePair<int,int>(old,next));}
                    distance[next]=cost;previous[next]=index;queue.Add(new KeyValuePair<int,int>(cost,next));
                }
            }
            if (!previous.ContainsKey(value)) throw new InvalidOperationException("No display route between pawn cells: " + start + " -> " + value);
            var route = new List<int>();
            for (int cursor = value; cursor != start; cursor = previous[cursor]) route.Add(cursor);
            route.Reverse(); path.AddRange(route); destination = value;
        }
        private void ChargeRoute(int value)
        {
            path.Clear(); var origin = layout.Cells[cell]; var goal = layout.Cells[value];
            int q = goal.Q - origin.Q, r = goal.R - origin.R;
            int steps = (Mathf.Abs(q) + Mathf.Abs(r) + Mathf.Abs(q + r)) / 2;
            for (int d = 0; d < 6; d++)
            {
                int first = origin.Neighbors[d]; if (first < 0) continue;
                var neighbor = layout.Cells[first];
                if ((neighbor.Q - origin.Q) * steps != q || (neighbor.R - origin.R) * steps != r) continue;
                int cursor = cell;
                for (int step = 0; step < steps; step++)
                {
                    var from = layout.Cells[cursor]; int next = from.Neighbors[d];
                    if (next < 0 || (from.WalkMask & (1 << d)) == 0 || layout.Cells[next].Blocked)
                        throw new InvalidOperationException("Charge presentation left its traversable straight route.");
                    path.Add(next); cursor = next;
                }
                if (cursor != value) throw new InvalidOperationException("Charge presentation ended on another floor.");
                return;
            }
            throw new InvalidOperationException("Charge presentation requires a hex straight line.");
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
                int next = path[0]; var to = Position(next);
                var from = target.position; var direction = to - from; direction.y = 0;
                float length = direction.magnitude, step = Mathf.Min(length, distance);
                if (length > .001f) target.rotation = Quaternion.Slerp(target.rotation, Quaternion.LookRotation(direction), 1 - Mathf.Exp(-deltaTime * 18));
                var point = length > .001f ? Vector3.Lerp(from, to, step / length) : to;
                target.position = layout.IsTown || layout.Cells[cell].UsesSurfaceMesh || layout.Cells[next].UsesSurfaceMesh
                    ? TownSurfaceRenderer.Ground(layout, cell, next, point) : point;
                moved += step; distance -= step;
                if (length > step + .001f) break;
                target.position = to; cell = next; path.RemoveAt(0);
            }
            return moved / deltaTime;
        }
        public void Skip() {jumping=false;path.Clear(); cell = destination; target.position = Position(cell);}
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
