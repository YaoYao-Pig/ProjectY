using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace ProjectY.Samples
{
    /// <summary>Camera-local pooled detail; picking always uses authoritative snapshot positions.</summary>
    internal sealed class WorldPartyView : IDisposable
    {
        [Serializable] public sealed class Binding { public string path; public GameObject prefab; }
        private sealed class Model { public GameObject Prefab; public float Envelope; public readonly Stack<GameObject> Pool = new Stack<GameObject>(); }
        private sealed class Piece { public GameObject Object; public Model Model; }
        private struct Candidate { public int Id; public string Name; public Model Model; public Vector3 Position; public float Distance; public Color Color; }
        private struct Marker { public Vector3 Position; public Color Color; }
        private readonly GameObject root;
        private readonly Dictionary<string, Model> models = new Dictionary<string, Model>();
        private readonly Dictionary<int, Piece> pieces = new Dictionary<int, Piece>();
        private readonly Dictionary<int, AdventureViewData.WorldParty> rows = new Dictionary<int, AdventureViewData.WorldParty>();
        private readonly Dictionary<int, MapRenderLod.Tier> tiers = new Dictionary<int, MapRenderLod.Tier>();
        private readonly HashSet<int> wanted = new HashSet<int>(), visible = new HashSet<int>();
        private readonly List<int> removed = new List<int>();
        private readonly List<Candidate> candidates = new List<Candidate>();
        private readonly List<Marker> markers = new List<Marker>();
        private readonly MapRenderLod.View lod = new MapRenderLod.View();
        private readonly MapRenderLod.Settings settings;
        private readonly Mesh markerMesh;
        private readonly Material markerMaterial;
        private readonly Matrix4x4[] markerMatrices = new Matrix4x4[1023];
        private readonly Vector4[] markerColors = new Vector4[1023];
        private readonly MaterialPropertyBlock markerProperties = new MaterialPropertyBlock();
        private AdventureViewData.WorldPartyState snapshot;
        private Vector3 playerPosition;
        private readonly float radius;
        private bool shown;
        private bool playerOnWater;
        private int creationFrame = -1;
        public int CreatedThisFrame { get; private set; }
        public int ActivatedThisFrame { get; private set; }
        public int EvictedThisFrame { get; private set; }
        public int CreatedModelCount { get; private set; }
        public int ActiveModelCount => pieces.Count;
        public int PooledModelCount => CreatedModelCount - pieces.Count;
        public int MarkerCount => markers.Count;
        public int OutsideDetailCount { get; private set; }

        public WorldPartyView(Transform parent, Binding[] bindings, float cellRadius, Shader shader, MapRenderLod.Settings lodSettings)
        {
            if (bindings == null || bindings.Length == 0 || shader == null) throw new InvalidOperationException("大地图队伍资源绑定缺失。");
            settings = lodSettings ?? throw new ArgumentNullException(nameof(lodSettings)); settings.Validate();
            radius = cellRadius; root = new GameObject("WorldPartyPieces"); root.transform.SetParent(parent, false);
            foreach (var binding in bindings)
            {
                if (binding == null || string.IsNullOrEmpty(binding.path) || binding.prefab == null) throw new InvalidOperationException("大地图队伍资源绑定缺失。");
                float envelope = 1;
                foreach (var renderer in binding.prefab.GetComponentsInChildren<Renderer>(true))
                {
                    var bounds = MapRenderLod.TransformBounds(renderer.localBounds,
                        binding.prefab.transform.worldToLocalMatrix * renderer.transform.localToWorldMatrix);
                    envelope = Mathf.Max(envelope, bounds.center.magnitude + bounds.extents.magnitude);
                }
                models.Add(binding.path, new Model { Prefab = binding.prefab, Envelope = envelope });
            }
            markerMesh = CreateMarker();
            markerMaterial = new Material(shader) { name = "大地图远景标记", enableInstancing = true };
        }
        private static Mesh CreateMarker()
        {
            var vertices = new[] { new Vector3(0,.85f,0), new Vector3(-.28f,.22f,0), new Vector3(0,.22f,.28f),
                new Vector3(.28f,.22f,0), new Vector3(0,.22f,-.28f), Vector3.zero };
            var indices = new[] {0,2,1,0,3,2,0,4,3,0,1,4,5,1,2,5,2,3,5,3,4,5,4,1};
            var mesh = new Mesh { name = "大地图轻量定位标记", vertices = vertices, triangles = indices };
            mesh.RecalculateNormals(); mesh.RecalculateBounds(); return mesh;
        }
        public void Sync(AdventureViewData view)
        {
            shown = view.Phase == "map"; root.SetActive(shown); snapshot = view.WorldParties; playerPosition = view.Travel.Position;
            playerOnWater=view.Water.Mode!="walk";
            rows.Clear(); foreach (var row in snapshot.Rows) rows.Add(row.Id, row);
            removed.Clear(); foreach (var pair in pieces) if (!shown || pair.Key != 0 && !rows.ContainsKey(pair.Key)) removed.Add(pair.Key);
            foreach (var id in removed) Retire(id);
            if (!shown) { visible.Clear(); markers.Clear(); }
            removed.Clear(); foreach (var pair in tiers) if (pair.Key != 0 && !rows.ContainsKey(pair.Key)) removed.Add(pair.Key);
            foreach (var id in removed) tiers.Remove(id);
        }
        private void Retire(int id)
        {
            var piece = pieces[id]; piece.Object.SetActive(false); piece.Model.Pool.Push(piece.Object); pieces.Remove(id);
        }
        private bool ReserveModelSlot(Model requested)
        {
            if (CreatedModelCount < settings.maximumDetailedObjects) return true;
            if (EvictedThisFrame >= settings.creationsPerFrame) return false;
            // Only replace an idle model, and only inside the caller's creation/activation budget.
            // A pool full of other prefabs must not permanently starve newly visible model types.
            foreach (var model in models.Values)
                if (model != requested && model.Pool.Count > 0)
                {
                    Destroy(model.Pool.Pop()); CreatedModelCount--; EvictedThisFrame++;
                    return CreatedModelCount < settings.maximumDetailedObjects;
                }
            return false;
        }
        private void Consider(int id, string path, string name, Vector3 position, bool place, Color color)
        {
            if (!models.TryGetValue(path, out var model)) throw new InvalidOperationException("未绑定大地图棋子：" + path);
            var bounds = new Bounds(position, Vector3.one * (model.Envelope * radius * 2));
            tiers.TryGetValue(id, out var previous); var tier = lod.Classify(bounds, previous); tiers[id] = tier;
            if (tier == MapRenderLod.Tier.Hidden || tier == MapRenderLod.Tier.Far && !place) return;
            visible.Add(id);
            if (tier != MapRenderLod.Tier.Near) { markers.Add(new Marker { Position = position, Color = color }); return; }
            wanted.Add(id); candidates.Add(new Candidate { Id = id, Name = name, Model = model, Position = position,
                Distance = id == 0 ? -1 : lod.Distance(bounds), Color = color });
        }
        // Separate CPU visibility/update from draw submission for deterministic in-memory verification.
        internal void UpdateVisibility(Camera camera)
        {
            if (!shown || snapshot == null) return;
            if (creationFrame != Time.frameCount) { creationFrame = Time.frameCount; CreatedThisFrame = ActivatedThisFrame = EvictedThisFrame = 0; }
            lod.Update(camera, playerPosition.y, radius, settings);
            wanted.Clear(); visible.Clear(); candidates.Clear(); markers.Clear();
            if(!playerOnWater)Consider(0, snapshot.PlayerModelPath, "PlayerFlag", playerPosition, true, new Color(.38f,.84f,.63f));
            foreach (var row in snapshot.Rows)
                Consider(row.Id, row.ModelPath, row.Name, row.Position, row.Kind == "stronghold",
                    row.Kind == "caravan" ? new Color(.93f,.79f,.48f) : new Color(.70f,.77f,.81f));
            removed.Clear(); foreach (var pair in pieces) if (!wanted.Contains(pair.Key)) removed.Add(pair.Key);
            foreach (var id in removed) Retire(id);
            candidates.Sort((a,b) => { var order = a.Distance.CompareTo(b.Distance); return order != 0 ? order : a.Id.CompareTo(b.Id); });
            foreach (var candidate in candidates)
            {
                if (pieces.TryGetValue(candidate.Id, out var existing))
                {
                    if (!lod.Visible(new Bounds(existing.Object.transform.position, Vector3.one * existing.Model.Envelope * radius * 2)))
                        existing.Object.transform.position = candidate.Position + Vector3.up * .025f;
                    continue;
                }
                GameObject instance = null;
                if (ActivatedThisFrame < settings.activationsPerFrame && candidate.Model.Pool.Count > 0) instance = candidate.Model.Pool.Pop();
                else if (ActivatedThisFrame < settings.activationsPerFrame && CreatedThisFrame < settings.creationsPerFrame && ReserveModelSlot(candidate.Model))
                {
                    instance = UnityEngine.Object.Instantiate(candidate.Model.Prefab, root.transform, false);
                    CreatedThisFrame++; CreatedModelCount++;
                }
                if (instance == null) { markers.Add(new Marker { Position = candidate.Position, Color = candidate.Color }); continue; }
                instance.name = candidate.Name; instance.transform.localScale = Vector3.one * radius;
                instance.transform.SetPositionAndRotation(candidate.Position + Vector3.up * .025f, Quaternion.identity); instance.SetActive(true);
                ActivatedThisFrame++;
                pieces.Add(candidate.Id, new Piece { Object = instance, Model = candidate.Model });
            }
            OutsideDetailCount = 0;
            foreach (var piece in pieces.Values)
                if (!lod.Visible(new Bounds(piece.Object.transform.position, Vector3.one * piece.Model.Envelope * radius * 2))) OutsideDetailCount++;
        }
        public void Render(Camera camera)
        {
            UpdateVisibility(camera);
            if (!shown) return;
            for (var offset = 0; offset < markers.Count; offset += 1023)
            {
                var count = Mathf.Min(1023, markers.Count - offset);
                for (var i = 0; i < count; i++)
                {
                    var row = markers[offset+i]; markerMatrices[i] = Matrix4x4.TRS(row.Position, Quaternion.identity, Vector3.one * radius);
                    markerColors[i] = QualitySettings.activeColorSpace == ColorSpace.Linear ? row.Color.linear : row.Color;
                }
                markerProperties.SetVectorArray("_Color", markerColors);
                Graphics.DrawMeshInstanced(markerMesh, 0, markerMaterial, markerMatrices, count, markerProperties,
                    ShadowCastingMode.Off, false, 0, camera, LightProbeUsage.Off);
            }
        }
        private static void Move(GameObject piece, Vector3 target, float t)
        {
            var previous = piece.transform.position; var next = Vector3.Lerp(previous, target + Vector3.up * .025f, t);
            var direction = next - previous; direction.y = 0;
            if (direction.sqrMagnitude > .00001f) piece.transform.rotation = Quaternion.Slerp(piece.transform.rotation, Quaternion.LookRotation(direction), t);
            if ((next-previous).sqrMagnitude > .0000001f) piece.transform.position = next;
        }
        public void Tick(Vector3 position, float dt)
        {
            playerPosition = position;
            if (!shown || snapshot == null) return;
            float t = 1 - Mathf.Exp(-dt * 20);
            foreach (var pair in pieces)
                Move(pair.Value.Object, pair.Key == 0 ? playerPosition : rows[pair.Key].Position, pair.Key == 0 ? 1 : t);
        }
        public int Pick(Camera camera, Vector2 pointer)
        {
            if (!shown || snapshot == null) return 0;
            int selected = 0; float best = 26 * 26;
            foreach (var row in snapshot.Rows)
            {
                if (!visible.Contains(row.Id)) continue;
                var screen = camera.WorldToScreenPoint(row.Position + Vector3.up * radius * .65f);
                if (screen.z <= 0) continue; float distance = ((Vector2)screen - pointer).sqrMagnitude;
                if (distance < best) { best = distance; selected = row.Id; }
            }
            return selected;
        }
        public void DrawHover(Camera camera, GUIStyle style)
        {
            int id = Pick(camera, Input.mousePosition); if (id == 0) return;
            var row = rows[id]; var point = camera.WorldToScreenPoint(row.Position + Vector3.up * radius * 1.8f);
            var content = new GUIContent(row.Name + " · " + row.Status + ProjectY.UI.LuaLanguage.Get(row.Kind == "stronghold" ? "WorldPartyHoverVisit" : "WorldPartyHoverFollow") + (row.Kind == "caravan" ? ProjectY.UI.LuaLanguage.Get("WorldPartyHoverTrade") : ""));
            var size = style.CalcSize(content); var box = new Rect(Mathf.Clamp(point.x-size.x*.5f-8,0,Screen.width-size.x-16),Screen.height-point.y-size.y-12,size.x+16,size.y+8);
            var color = GUI.color; GUI.color = new Color(.08f,.12f,.11f,.94f); GUI.DrawTexture(box,Texture2D.whiteTexture);
            GUI.color = row.Kind == "caravan" ? new Color(.93f,.79f,.48f) : new Color(.98f,.68f,.57f);
            GUI.Label(new Rect(box.x+8,box.y+4,size.x,size.y),content,style); GUI.color = color;
        }
        private static void Destroy(UnityEngine.Object value)
        { if (Application.isPlaying) UnityEngine.Object.Destroy(value); else UnityEngine.Object.DestroyImmediate(value); }
        public void Dispose() { Destroy(root); Destroy(markerMesh); Destroy(markerMaterial); pieces.Clear(); models.Clear(); }
    }
}
