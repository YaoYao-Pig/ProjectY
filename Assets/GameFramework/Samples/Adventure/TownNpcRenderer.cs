using System;
using System.Collections.Generic;
using UnityEngine;

namespace ProjectY.Samples
{
    /// <summary>居民与工匠复用棋子挂点；仅平滑显示真实 NPC 占格，不持有巡游规则。</summary>
    public sealed class TownNpcRenderer : IDisposable
    {
        private sealed class Item
        {
            public PawnView View;
            public Transform Head;
            public MeshRenderer Marker;
            public Vector3 Target;
            public float Speed;
            public int Cell = -1, FromCell = -1, MarkerState;
            public bool Decorative, ShowName;
            public GUIContent NameLabel;
        }
        private readonly GameObject root;
        private readonly Dictionary<int, Item> items = new Dictionary<int, Item>();
        private readonly MapAreaViewData terrain;
        private readonly MeshRenderer markerPrefab;
        private readonly Material readyMaterial;
        public TownNpcRenderer(Transform parent, PawnView rig, MapAreaViewData layout, Func<PawnAppearanceData.Part, GameObject> resolve,
            MeshRenderer missionMarkerPrefab = null, Material missionReadyMaterial = null)
        {
            terrain = layout;
            markerPrefab = missionMarkerPrefab;
            readyMaterial = missionReadyMaterial;
            root = new GameObject("TownResidents"); root.transform.SetParent(parent, false);
            foreach (var npc in layout.Npcs)
            {
                var pawn = UnityEngine.Object.Instantiate(rig, root.transform, false); pawn.name = npc.Name + "_" + npc.Id;
                pawn.ApplyAppearance(npc.Appearance, resolve); pawn.gameObject.SetActive(false);
                var item = new Item { View = pawn, Head = pawn.HealthTarget, Speed = layout.Radius * 1.7320508f / npc.StepSeconds,
                    Decorative = npc.Decorative, ShowName = npc.ShowName };
                if (npc.Decorative)
                {
                    if (npc.Id >= 0 || npc.SpawnIndex < 0 || npc.SpawnIndex >= layout.Cells.Length || !layout.Cells[npc.SpawnIndex].Blocked || npc.Scale <= 0)
                        throw new InvalidOperationException("Decorative NPC must use an isolated display ID and blocked scenery cell.");
                    item.Cell = item.FromCell = npc.SpawnIndex; item.Target = npc.Position;
                    if (npc.ShowName) item.NameLabel = new GUIContent(npc.Name);
                    pawn.transform.SetPositionAndRotation(npc.Position, Quaternion.Euler(0, npc.Yaw, 0));
                    pawn.transform.localScale = Vector3.one * npc.Scale;
                    foreach (var collider in pawn.GetComponentsInChildren<Collider>(true)) collider.enabled = false;
                    pawn.gameObject.SetActive(true);
                }
                items.Add(npc.Id, item);
            }
        }
        public void SetState(MapAreaViewData.State state, MapAreaViewData layout)
        {
            foreach (var npc in state.Npcs)
            {
                var item = items[npc.Id];
                if (item.Decorative) throw new InvalidOperationException("Decorative NPC must not enter persistent NPC state.");
                SetMarker(item, npc.Present ? npc.MissionMarker : 0);
                if(!npc.Present){item.View.gameObject.SetActive(false);continue;}
                if (item.Cell != npc.CellIndex)
                {
                    if (item.Cell >= 0) item.View.transform.position = TownSurfaceRenderer.Ground(layout, item.Cell, item.Cell, item.Target);
                    item.FromCell = item.Cell < 0 ? npc.CellIndex : item.Cell; item.Cell = npc.CellIndex;
                }
                item.Target = layout.Cells[npc.CellIndex].Position + Vector3.up * .015f;
                if (!item.View.gameObject.activeSelf) { item.View.transform.position = item.Target; item.View.gameObject.SetActive(true); }
            }
        }
        private void SetMarker(Item item, int state)
        {
            if (state < 0 || state > 2) throw new InvalidOperationException("Unknown NPC mission marker state: " + state);
            if (state == 0)
            {
                if (item.Marker != null) item.Marker.gameObject.SetActive(false);
                item.MarkerState = 0;
                return;
            }
            if (item.Marker == null)
            {
                if (markerPrefab == null || markerPrefab.sharedMaterial == null || readyMaterial == null)
                    throw new InvalidOperationException("NPC mission marker prefab and gold/green materials must be bound.");
                item.Marker = UnityEngine.Object.Instantiate(markerPrefab, root.transform, false);
                item.Marker.name = item.View.name + "_MissionMarker";
            }
            if (item.MarkerState != state)
                item.Marker.sharedMaterial = state == 2 ? readyMaterial : markerPrefab.sharedMaterial;
            item.MarkerState = state;
            item.Marker.gameObject.SetActive(true);
        }
        public void Tick(float dt)
        {
            foreach (var item in items.Values)
            {
                if(!item.View.gameObject.activeSelf)continue;
                if(item.Decorative){item.View.TickPresentation(dt);continue;}
                var target = item.View.transform; var delta = item.Target - target.position; delta.y = 0;
                if (delta.sqrMagnitude > .01f) target.rotation = Quaternion.Slerp(target.rotation, Quaternion.LookRotation(delta), 1 - Mathf.Exp(-dt * 10));
                var from = target.position; var to = item.Target; from.y = to.y = 0;
                var next = Vector3.MoveTowards(from, to, item.Speed * dt);
                target.position = TownSurfaceRenderer.Ground(terrain, item.FromCell, item.Cell, next);
                item.View.TickPresentation(dt, dt > 0 ? Vector3.Distance(from, next) / dt : 0);
            }
        }
        // Called after the final exploration/dialogue camera pose and character animation.
        // The prefab keeps its authored FBX axis conversion; the visible face follows the camera.
        public void LateTick(Camera camera)
        {
            foreach (var item in items.Values)
            {
                if (item.MarkerState == 0) continue;
                item.Marker.transform.SetPositionAndRotation(item.Head.position + Vector3.up * .32f,
                    camera.transform.rotation * markerPrefab.transform.localRotation);
            }
        }
        public Vector3 Position(int id) => items[id].View.transform.position;
        public void DrawNames(Camera camera, GUIStyle style)
        {
            foreach (var item in items.Values)
            {
                if (!item.Decorative || !item.ShowName || !item.View.gameObject.activeSelf) continue;
                var point = camera.WorldToScreenPoint(item.Head.position + Vector3.up * .65f);
                if (point.z <= 0 || !camera.pixelRect.Contains(point)) continue;
                var size = style.CalcSize(item.NameLabel);
                GUI.Label(new Rect(point.x - size.x * .5f, Screen.height - point.y - size.y, size.x + 4, size.y), item.NameLabel, style);
            }
        }
        public void Dispose()
        {
            root.SetActive(false);
            if (Application.isPlaying) UnityEngine.Object.Destroy(root); else UnityEngine.Object.DestroyImmediate(root);
            items.Clear();
        }
    }
}
