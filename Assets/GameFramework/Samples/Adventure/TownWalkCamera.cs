using System.Collections.Generic;
using UnityEngine;

namespace ProjectY.Samples
{
    /// <summary>城镇第三人称镜头与键盘方向投影；只发方向命令，不修改玩法位置。</summary>
    public sealed class TownWalkCamera
    {
        private readonly IList<Bounds> obstacles;
        private readonly System.Func<Ray, float, float> terrainDistance;
        private float yaw, pitch = 25, distance = 8;
        private Vector3 desired, lastInput;
        private bool steering;
        public bool Walking { get; private set; }
        public TownWalkCamera(MapAreaViewData layout, MapAreaViewData.State state, IList<Bounds> obstacles, System.Func<Ray, float, float> terrainDistance = null)
        {
            this.obstacles = obstacles; this.terrainDistance = terrainDistance;
            var forward = layout.Cells[state.GoalIndex].Position - layout.Cells[state.CellIndex].Position;
            yaw = Mathf.Atan2(forward.x, forward.z) * Mathf.Rad2Deg;
        }
        public void ResetSteering() { steering = false; Walking = false; }
        public void Orbit()
        {
            if (Input.GetMouseButton(1)) { yaw += Input.GetAxis("Mouse X") * 3; pitch = Mathf.Clamp(pitch - Input.GetAxis("Mouse Y") * 2, 10, 55); }
            distance = Mathf.Clamp(distance - Input.mouseScrollDelta.y * .65f, 3, 14);
        }
        public int Direction(MapAreaViewData layout, MapAreaViewData.State state, float dt)
        {
            var input = new Vector3(Input.GetAxisRaw("Horizontal"), 0, Input.GetAxisRaw("Vertical")).normalized;
            Walking = input.sqrMagnitude > .1f;
            if (!Walking) { steering = false; return 0; }
            input = Quaternion.Euler(0, yaw, 0) * input;
            var origin = layout.Cells[state.CellIndex]; var spacing = layout.Radius * 1.7320508f;
            if (!steering || Vector3.Dot(lastInput, input) < .7f) desired = origin.Position + input * spacing;
            steering = true; lastInput = input;
            desired += input * (spacing / layout.MoveStepSeconds * dt);
            desired = origin.Position + Vector3.ClampMagnitude(desired - origin.Position, spacing * 1.6f);
            if (state.Route.Length > 0) return 0;
            var best = float.PositiveInfinity; var direction = 0;
            for (var d = 0; d < 6; d++)
            {
                if ((origin.WalkMask & (1 << d)) == 0) continue;
                var index = origin.Neighbors[d]; if (index < 0) continue;
                var target = layout.Cells[index];
                if (target.Blocked || Vector3.Dot((target.Position - origin.Position).normalized, input) < .2f) continue;
                var occupied = false; foreach (var npc in state.Npcs) if (npc.CellIndex == index) { occupied = true; break; }
                if (occupied) continue;
                var score = (target.Position - desired).sqrMagnitude;
                if (score < best) { best = score; direction = d + 1; }
            }
            return direction;
        }
        public void Apply(Camera camera, Vector3 leader)
        {
            var focus = leader + Vector3.up * 1.25f;
            var rotation = Quaternion.Euler(pitch, yaw, 0); var backward = -(rotation * Vector3.forward);
            var actualDistance = distance;
            var ray = new Ray(focus, backward);
            foreach (var obstacle in obstacles)
                if (obstacle.IntersectRay(ray, out var hit) && hit >= 0 && hit < actualDistance) actualDistance = Mathf.Max(.35f, hit - .2f);
            if (terrainDistance != null) actualDistance = Mathf.Max(.35f, terrainDistance(ray, actualDistance) - .15f);
            var position = focus + backward * actualDistance; position.y = Mathf.Max(leader.y + .35f, position.y);
            camera.orthographic = false; camera.rect = new Rect(0, 0, 1, 1); camera.fieldOfView = 58;
            camera.nearClipPlane = .08f; camera.farClipPlane = 400;
            camera.transform.SetPositionAndRotation(position, Quaternion.LookRotation(focus - position));
        }
    }
}
