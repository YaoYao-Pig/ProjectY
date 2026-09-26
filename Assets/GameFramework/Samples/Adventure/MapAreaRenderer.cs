using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using Object = UnityEngine.Object;

namespace ProjectY.Samples
{
    /// <summary>复用配表指定的柱模型；按实例更新探索明暗，未知地块不泄露墙体形状。</summary>
    public sealed class MapAreaRenderer : IDisposable
    {
        private sealed class Batch
        {
            public int Start, Count;
            public readonly Matrix4x4[] Matrices = new Matrix4x4[1023];
            public readonly Vector4[] Colors = new Vector4[1023];
            public readonly Vector4[] Patterns = new Vector4[1023], Finishes = new Vector4[1023];
            public readonly MaterialPropertyBlock Properties = new MaterialPropertyBlock();
        }
        private sealed class PropBatch
        {
            public Mesh Mesh;
            public int Slot, Count;
            public Color Color;
            public Color Emission;
            public readonly List<MapAreaViewData.Prop> Instances = new List<MapAreaViewData.Prop>();
            public readonly Matrix4x4[] Matrices = new Matrix4x4[1023];
            public readonly Vector4[] Colors = new Vector4[1023];
            public readonly MaterialPropertyBlock Properties = new MaterialPropertyBlock();
        }
        private readonly List<Batch> batches = new List<Batch>();
        private readonly List<PropBatch> propBatches = new List<PropBatch>();
        private sealed class CameraObstacle
        {
            public Bounds Bounds;
            public int InteriorId;
            public bool Cutaway;
        }
        private readonly List<CameraObstacle> cameraObstacles = new List<CameraObstacle>();
        private readonly HashSet<int> openInteriors = new HashSet<int>();
        private readonly Material material;
        private readonly Material groundMaterial;
        private readonly Mesh mesh;
        private readonly TownSurfaceRenderer townSurface;
        private readonly MapAreaViewData map;
        private readonly bool[] known, visible;
        private int revision = -1;
        private bool reveal;
        public Bounds Bounds { get; }
        public readonly List<Bounds> CameraObstacles = new List<Bounds>();
        // 从权威队员占格推导；同伴还在房内时保持剖切，最后一人离开后恢复。
        public bool IsInteriorOpen(int id) => id > 0 && openInteriors.Contains(id);
        private void AddCameraObstacle(Bounds bounds, MapAreaViewData.Prop prop)
        {
            cameraObstacles.Add(new CameraObstacle { Bounds = bounds, InteriorId = prop.InteriorId, Cutaway = prop.Cutaway });
            CameraObstacles.Add(bounds);
        }
        public MapAreaRenderer(Shader shader, GameObject prefab, MapAreaViewData map, Func<MapAreaViewData.Asset, GameObject> resolve)
        {
            if (shader == null || prefab == null || !SystemInfo.supportsInstancing) throw new InvalidOperationException("MapArea 缺少实例渲染资源。");
            this.map = map;
            var filter = prefab.GetComponent<MeshFilter>(); var source = prefab.GetComponent<MeshRenderer>();
            if (filter == null || source == null || filter.sharedMesh == null) throw new InvalidOperationException("MapArea 柱模型缺少 Mesh。");
            if (!Array.Exists(source.sharedMaterials, value => value.name == map.TintMaterial)) throw new InvalidOperationException("MapArea 模型材质与配置不一致。");
            mesh = filter.sharedMesh; material = new Material(shader) { name = "MapArea_探索实例", enableInstancing = true };
            groundMaterial = new Material(shader) { name = "MapArea_地牢材质", enableInstancing = true };
            groundMaterial.SetFloat("_UseSurfacePattern", 2);
            if (map.IsTown) townSurface = new TownSurfaceRenderer(shader, map);
            known = new bool[map.Cells.Length]; visible = new bool[map.Cells.Length];
            var bounds = new Bounds(map.Cells[0].Position, Vector3.zero);
            for (var i = 0; i < map.Cells.Length; i++)
            {
                if (!map.IsTown && i % 1023 == 0) batches.Add(new Batch { Start = i, Count = Math.Min(1023, map.Cells.Length - i) });
                bounds.Encapsulate(map.Cells[i].Position + Vector3.up * map.Cells[i].WallHeight);
            }
            bounds.Expand(map.Radius * 2); Bounds = bounds;
            // 陈设也按模型材质槽实例化绘制，不为每件物品生成场景对象。
            foreach (var asset in map.PropAssets)
            {
                var model = resolve(asset);
                var propFilter = model.GetComponent<MeshFilter>(); var propRenderer = model.GetComponent<MeshRenderer>();
                if (propFilter == null || propRenderer == null || propFilter.sharedMesh == null ||
                    model.transform.localRotation != Quaternion.identity || model.transform.localScale != Vector3.one)
                    throw new InvalidOperationException("MapArea 陈设模型不符合根网格与单位变换约定：" + asset.Id);
                var materials = propRenderer.sharedMaterials;
                // GPU 实例没有 Collider；用实际阻挡占地裁切高度包围盒，保留中庭、门洞与桥下空间。
                foreach (var prop in map.Props)
                {
                    if (prop.AssetId != asset.Id) continue;
                    var local = propFilter.sharedMesh.bounds;
                    var matrix = Matrix4x4.TRS(prop.Position, Quaternion.Euler(0, prop.Rotation, 0), prop.Scale3);
                    var obstacle = new Bounds(matrix.MultiplyPoint3x4(local.center), Vector3.zero);
                    for (var x = -1; x <= 1; x += 2) for (var y = -1; y <= 1; y += 2) for (var z = -1; z <= 1; z += 2)
                        obstacle.Encapsulate(matrix.MultiplyPoint3x4(local.center + Vector3.Scale(local.extents, new Vector3(x, y, z))));
                    if (!map.IsTown) { obstacle.Expand(.35f); AddCameraObstacle(obstacle, prop); continue; }
                    foreach (var index in prop.Cells)
                    {
                        var cell = map.Cells[index];
                        if (!cell.Blocked) continue;
                        var half = new Vector3(map.Radius * .8660254f, 0, map.Radius);
                        var minimum = Vector3.Max(obstacle.min, cell.Position - half);
                        var maximum = Vector3.Min(obstacle.max, cell.Position + half + Vector3.up * (obstacle.max.y - cell.Position.y));
                        if (maximum.x <= minimum.x || maximum.z <= minimum.z || maximum.y <= minimum.y) continue;
                        var column = new Bounds(); column.SetMinMax(minimum, maximum); column.Expand(.2f);
                        AddCameraObstacle(column, prop);
                    }
                }
                if (materials.Length != propFilter.sharedMesh.subMeshCount) throw new InvalidOperationException("陈设材质槽不一致：" + asset.Id);
                for (var slot = 0; slot < materials.Length; slot++)
                {
                    if (materials[slot] == null) throw new InvalidOperationException("陈设材质缺失：" + asset.Id);
                    PropBatch batch = null;
                    foreach (var prop in map.Props)
                    {
                        if (prop.AssetId != asset.Id) continue;
                        if (batch == null || batch.Instances.Count == 1023)
                        {
                            batch = new PropBatch { Mesh = propFilter.sharedMesh, Slot = slot, Color = materials[slot].color,
                                Emission = materials[slot].HasProperty("_EmissionColor") ? materials[slot].GetColor("_EmissionColor") : Color.black };
                            propBatches.Add(batch);
                        }
                        batch.Instances.Add(prop);
                    }
                }
            }
        }
        public void UpdateVisibility(MapAreaViewData.State state, bool revealAll)
        {
            if (state.Revision == revision && revealAll == reveal) return;
            revision = state.Revision; reveal = revealAll;
            openInteriors.Clear();
            foreach (var member in state.Members)
            {
                var id = map.Cells[member.CellIndex].InteriorId;
                if (id > 0) openInteriors.Add(id);
            }
            // 镜头持有同一列表引用。隐藏的上盖必须同时退出镜头避障，不能留下看不见的墙。
            CameraObstacles.Clear();
            foreach (var obstacle in cameraObstacles)
                if (!obstacle.Cutaway || !IsInteriorOpen(obstacle.InteriorId)) CameraObstacles.Add(obstacle.Bounds);
            Array.Clear(known, 0, known.Length); Array.Clear(visible, 0, visible.Length);
            foreach (var index in state.Known) known[index] = true;
            foreach (var index in state.Visible) visible[index] = true;
            foreach (var batch in batches)
            {
                for (var i = 0; i < batch.Count; i++)
                {
                    var index = batch.Start + i; var cell = map.Cells[index]; var discovered = reveal || known[index];
                    var top = discovered ? cell.Position.y + (cell.Kind == "wall" ? cell.WallHeight : 0) : 0;
                    var position = new Vector3(cell.Position.x, top, cell.Position.z);
                    batch.Matrices[i] = Matrix4x4.TRS(position, Quaternion.identity, new Vector3(map.Radius, top + .4f, map.Radius));
                    var color = !discovered ? new Color(.025f, .035f, .045f) : cell.Color;
                    if (discovered && cell.Kind == "entry") color = new Color(.30f, .69f, .61f);
                    if (discovered && cell.Kind == "landmark") color = new Color(.78f, .56f, .25f);
                    if (discovered && !reveal && !visible[index]) color *= .3f;
                    color.a = 1;
                    batch.Colors[i] = QualitySettings.activeColorSpace == ColorSpace.Linear ? color.linear : color;
                    // 未探索格不输出纹理；已探索但不可见的苔藓覆盖层也遵循迷雾明暗。
                    var surface = map.Surfaces[cell.SurfaceId];
                    var detail = surface.DetailColor * (discovered && (reveal || visible[index]) ? 1 : .3f);
                    if (QualitySettings.activeColorSpace == ColorSpace.Linear) detail = detail.linear;
                    batch.Patterns[i] = discovered ? surface.Pattern : Vector4.zero;
                    batch.Finishes[i] = new Vector4(detail.r, detail.g, detail.b, surface.Smoothness);
                }
                batch.Properties.SetVectorArray("_Color", batch.Colors);
                batch.Properties.SetVectorArray("_SurfaceData", batch.Patterns);
                batch.Properties.SetVectorArray("_SurfaceFinish", batch.Finishes);
            }
            foreach (var batch in propBatches)
            {
                batch.Count = 0;
                foreach (var prop in batch.Instances)
                {
                    if (prop.Cutaway && IsInteriorOpen(prop.InteriorId)) continue;
                    var discovered = reveal; var lit = reveal;
                    foreach (var index in prop.Cells) { discovered |= known[index]; lit |= visible[index]; }
                    if (!discovered) continue;
                    var color = batch.Color * (lit ? 1 : .3f); color.a = 1;
                    batch.Colors[batch.Count] = QualitySettings.activeColorSpace == ColorSpace.Linear ? color.linear : color;
                    batch.Matrices[batch.Count++] = Matrix4x4.TRS(prop.Position, Quaternion.Euler(0, prop.Rotation, 0), prop.Scale3);
                }
                batch.Properties.SetVectorArray("_Color", batch.Colors);
                batch.Properties.SetColor("_EmissionColor", batch.Emission);
            }
        }
        public void Draw(Camera camera)
        {
            townSurface?.Draw(camera);
            foreach (var batch in batches) for (var slot = 0; slot < mesh.subMeshCount; slot++)
                Graphics.DrawMeshInstanced(mesh, slot, groundMaterial, batch.Matrices, batch.Count, batch.Properties,
                    ShadowCastingMode.On, true, 0, camera, LightProbeUsage.Off);
            foreach (var batch in propBatches)
                if (batch.Count > 0) Graphics.DrawMeshInstanced(batch.Mesh, batch.Slot, material, batch.Matrices, batch.Count, batch.Properties,
                    ShadowCastingMode.On, true, 0, camera, LightProbeUsage.Off);
        }
        // 用六边形棱柱的八个半空间拾取，墙侧面也阻挡点击，避免穿墙选到背后地面。
        private static bool Clip(Vector3 normal, float limit, Vector3 origin, Vector3 direction, ref float near, ref float far)
        {
            var offset = Vector3.Dot(normal, origin) - limit; var slope = Vector3.Dot(normal, direction);
            if (Mathf.Abs(slope) < .000001f) return offset <= 0;
            var time = -offset / slope;
            if (slope < 0) near = Mathf.Max(near, time); else far = Mathf.Min(far, time);
            return near <= far;
        }
        public int Pick(Ray ray)
        {
            if (townSurface != null) { townSurface.Raycast(ray, float.PositiveInfinity, out var index); return index; }
            var best = float.PositiveInfinity; var result = -1;
            for (var i = 0; i < map.Cells.Length; i++)
            {
                if (!reveal && !known[i]) continue;
                var cell = map.Cells[i]; var top = cell.Position.y + (cell.Kind == "wall" ? cell.WallHeight : 0);
                var origin = ray.origin - new Vector3(cell.Position.x, 0, cell.Position.z);
                var near = 0f; var far = best;
                if (!Clip(Vector3.up, top, origin, ray.direction, ref near, ref far) ||
                    !Clip(Vector3.down, .4f, origin, ray.direction, ref near, ref far)) continue;
                var hit = true;
                for (var side = 0; side < 6 && hit; side++)
                {
                    var angle = side * Mathf.PI / 3;
                    hit = Clip(new Vector3(Mathf.Cos(angle), 0, Mathf.Sin(angle)), map.Radius * .8660254f, origin, ray.direction, ref near, ref far);
                }
                if (hit && near < best) { best = near; result = i; }
            }
            return result;
        }
        public float TerrainDistance(Ray ray, float distance)
        {
            if (townSurface == null) return distance;
            return townSurface.Raycast(ray, distance, out _);
        }
        public void Dispose()
        {
            townSurface?.Dispose();
            if (Application.isPlaying) Object.Destroy(material); else Object.DestroyImmediate(material);
            if (Application.isPlaying) Object.Destroy(groundMaterial); else Object.DestroyImmediate(groundMaterial);
            batches.Clear(); propBatches.Clear();
        }
    }
}
