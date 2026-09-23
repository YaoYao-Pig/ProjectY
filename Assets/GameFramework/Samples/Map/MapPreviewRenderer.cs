using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using Object = UnityEngine.Object;

namespace ProjectY.Samples
{
    // 只持有显示资源。地块用 GPU 实例批次，避免数千格各创建一个 GameObject。
    public sealed class MapPreviewRenderer : IDisposable
    {
        public enum Kind { Terrain, Water, City, Building, Decoration }
        private sealed class Model
        {
            public Mesh Mesh;
            public Material[] Materials;
            public readonly Dictionary<Kind, List<Batch>[]> Groups = new Dictionary<Kind, List<Batch>[]>();
        }
        private sealed class Batch
        {
            public Mesh Mesh;
            public int Submesh, Count;
            public Kind Kind;
            public readonly Matrix4x4[] Matrices = new Matrix4x4[1023];
            public readonly Vector4[] Colors = new Vector4[1023];
            public readonly MaterialPropertyBlock Properties = new MaterialPropertyBlock();
        }
        private readonly Dictionary<GameObject, Model> models = new Dictionary<GameObject, Model>();
        private readonly List<Batch> batches = new List<Batch>();
        private readonly Material material;
        private readonly Material roadMaterial;
        private readonly GameObject roadObject;
        private Mesh roadMesh;
        private readonly GameObject waterEdges;
        private Mesh waterMesh;
        private readonly List<Material> waterMaterials = new List<Material>();
        public Bounds Bounds { get; private set; }

        public MapPreviewRenderer(Shader shader, Transform owner)
        {
            if (!SystemInfo.supportsInstancing) throw new NotSupportedException("地图测试场景需要 GPU Instancing。");
            if (shader == null || !shader.isSupported) throw new InvalidOperationException("地图预览 Shader 缺失或不受支持。");
            material = new Material(shader) { name = "地图预览_实例材质", enableInstancing = true };
            roadMaterial = new Material(shader) { name = "地图预览_道路", color = new Color32(210, 180, 136, 255) };
            roadObject = new GameObject("生成的道路", typeof(MeshFilter), typeof(MeshRenderer));
            roadObject.transform.SetParent(owner, false);
            var renderer = roadObject.GetComponent<MeshRenderer>();
            renderer.sharedMaterial = roadMaterial;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            waterEdges = new GameObject("河流落差与瀑布", typeof(MeshFilter), typeof(MeshRenderer));
            waterEdges.transform.SetParent(owner, false);
            waterEdges.GetComponent<MeshRenderer>().shadowCastingMode = ShadowCastingMode.Off;
        }

        private Model GetModel(GameObject prefab)
        {
            if (prefab == null) throw new InvalidOperationException("测试场景缺少模型引用。");
            if (models.TryGetValue(prefab, out var model)) return model;
            var filter = prefab.GetComponent<MeshFilter>();
            var renderer = prefab.GetComponent<MeshRenderer>();
            if (filter == null || renderer == null) throw new InvalidOperationException("模型根节点需要 MeshFilter 与 MeshRenderer: " + prefab.name);
            if (prefab.transform.localRotation != Quaternion.identity || prefab.transform.localScale != Vector3.one)
                throw new InvalidOperationException("模型根变换不符合地图约定: " + prefab.name);
            model = new Model { Mesh = filter.sharedMesh, Materials = renderer.sharedMaterials };
            if (model.Mesh.subMeshCount != model.Materials.Length) throw new InvalidOperationException("模型材质槽不匹配: " + prefab.name);
            models.Add(prefab, model);
            return model;
        }

        private void Add(GameObject prefab, Kind kind, Vector3 position, Vector3 scale, Quaternion rotation,
            Color? ground = null, string tintMaterial = null)
        {
            var model = GetModel(prefab);
            if (!model.Groups.TryGetValue(kind, out var groups))
            {
                groups = new List<Batch>[model.Mesh.subMeshCount];
                for (var i = 0; i < groups.Length; i++) groups[i] = new List<Batch>();
                model.Groups.Add(kind, groups);
            }
            for (var slot = 0; slot < groups.Length; slot++)
            {
                var group = groups[slot];
                if (group.Count == 0 || group[group.Count - 1].Count == 1023)
                {
                    var added = new Batch { Mesh = model.Mesh, Submesh = slot, Kind = kind };
                    group.Add(added); batches.Add(added);
                }
                var batch = group[group.Count - 1];
                var color = model.Materials[slot].color;
                if (ground.HasValue)
                {
                    var top = model.Materials[slot].name == tintMaterial;
                    color = ground.Value * (top ? 1f : .82f); color.a = 1;
                }
                // SetVectorArray 不执行 Color 的颜色空间转换，线性项目须显式转换。
                batch.Colors[batch.Count] = QualitySettings.activeColorSpace == ColorSpace.Linear ? color.linear : color;
                batch.Matrices[batch.Count++] = Matrix4x4.TRS(position, rotation, scale);
            }
        }

        public void Build(MapPreviewData map, Func<MapPreviewData.Asset, GameObject> resolve)
        {
            // ID 与资源路径同时校验，改表后忘记同步场景时明确报错。
            var assets = new Dictionary<int, MapPreviewData.Asset>();
            var prefabs = new Dictionary<int, GameObject>();
            foreach (var asset in map.Assets)
            {
                assets.Add(asset.Id, asset);
                var prefab = resolve(asset); var model = GetModel(prefab);
                if (!string.IsNullOrEmpty(asset.TintMaterial) && !Array.Exists(model.Materials, value => value.name == asset.TintMaterial))
                    throw new InvalidOperationException("资源没有配置的顶面材质: " + asset.Path + " / " + asset.TintMaterial);
                prefabs.Add(asset.Id, prefab);
            }
            batches.Clear();
            foreach (var model in models.Values) model.Groups.Clear();
            Bounds = new Bounds(map.Cells[0].Position, Vector3.zero);
            var bottom = map.Cells[0].Position.y;
            foreach (var cell in map.Cells) { Bounds = Encapsulate(Bounds, cell.Position); bottom = Mathf.Min(bottom, cell.Position.y); }
            bottom -= map.Radius * 1.5f;
            foreach (var cell in map.Cells)
            {
                Add(prefabs[cell.TerrainAssetId], Kind.Terrain, cell.Position,
                    new Vector3(map.Radius, cell.Position.y - bottom, map.Radius), Quaternion.identity,
                    cell.Color, assets[cell.TerrainAssetId].TintMaterial);
                if (cell.HasWater)
                    Add(prefabs[cell.WaterAssetId], Kind.Water, new Vector3(cell.Position.x, cell.WaterLevel, cell.Position.z),
                        new Vector3(map.Radius, 1, map.Radius), Quaternion.identity);
            }
            foreach (var building in map.Buildings)
            {
                var prefab = prefabs[building.AssetId];
                var referenceHeight = assets[building.AssetId].ReferenceHeight;
                if (building.FootprintRadius != 0 && building.FootprintRadius != 1)
                    throw new InvalidOperationException("测试平台当前只支持单格或七格完整占地。");
                var position = map.Cells[building.Center].Position;
                var minimum = building.BaseHeight;
                foreach (var index in building.Cells) minimum = Mathf.Min(minimum, map.Cells[index].Position.y);
                position.y = building.BaseHeight + .04f;
                Add(prefabs[building.PlatformAssetId], Kind.City, position,
                    new Vector3(map.Radius, position.y - minimum + .12f, map.Radius), Quaternion.identity,
                    map.Towns[building.TownId].GroundColor, assets[building.PlatformAssetId].TintMaterial);
                // 原件正面为 +Z；入口方向由布局给出，七格底板自身不旋转。
                var direction = map.Cells[building.Entrance].Position - position; direction.y = 0;
                if (direction.sqrMagnitude < .01f) throw new InvalidOperationException("建筑入口与中心重合。");
                var scale = new Vector3(map.Radius, building.Height / referenceHeight, map.Radius);
                Add(prefab, Kind.Building, position, scale, Quaternion.LookRotation(direction));
                Bounds = Encapsulate(Bounds, position + Vector3.up * GetModel(prefab).Mesh.bounds.size.y * scale.y);
            }
            foreach (var item in map.Decorations)
            {
                var position = map.Cells[item.Cell].Position;
                var prefab = prefabs[item.AssetId];
                var scale = Vector3.one * (item.Scale * map.Radius);
                Add(prefab, Kind.Decoration, position, scale, Quaternion.Euler(0, item.Yaw, 0));
                Bounds = Encapsulate(Bounds, position + Vector3.up * GetModel(prefab).Mesh.bounds.size.y * scale.y);
            }
            Bounds = new Bounds(Bounds.center, Bounds.size + Vector3.one * map.Radius * 2);
            foreach (var batch in batches) batch.Properties.SetVectorArray("_Color", batch.Colors);
            BuildRoads(map);
            BuildWaterEdges(map, prefabs, assets);
        }

        private static Bounds Encapsulate(Bounds bounds, Vector3 point) { bounds.Encapsulate(point); return bounds; }

        private void BuildRoads(MapPreviewData map)
        {
            if (roadMesh != null) Object.Destroy(roadMesh);
            var vertices = new List<Vector3>(); var triangles = new List<int>();
            var used = new HashSet<ulong>();
            Action<Vector3, Vector3, Vector3> quad = (a, b, side) => {
                var start = vertices.Count;
                vertices.Add(a - side); vertices.Add(a + side); vertices.Add(b + side); vertices.Add(b - side);
                triangles.Add(start); triangles.Add(start + 2); triangles.Add(start + 1);
                triangles.Add(start); triangles.Add(start + 3); triangles.Add(start + 2);
            };
            foreach (var road in map.Roads)
                for (var i = 1; i < road.Cells.Length; i++)
                {
                    var first = road.Cells[i - 1]; var second = road.Cells[i];
                    var key = ((ulong)(uint)Mathf.Min(first, second) << 32) | (uint)Mathf.Max(first, second);
                    if (!used.Add(key)) continue;
                    var a = map.Cells[first].Position + Vector3.up * .045f;
                    var b = map.Cells[second].Position + Vector3.up * .045f;
                    var along = b - a; along.y = 0;
                    var side = Vector3.Cross(Vector3.up, along.normalized) * map.Radius * .19f;
                    var edgeA = (a + b) * .5f; edgeA.y = a.y;
                    var edgeB = edgeA; edgeB.y = b.y;
                    // 在各格顶面画路，高差处补立面，避免斜线穿进高格地面。
                    quad(a, edgeA, side); quad(edgeB, b, side);
                    if (Mathf.Abs(a.y - b.y) > .001f) { quad(edgeA, edgeB, side); quad(edgeB, edgeA, side); }
                }
            roadMesh = new Mesh { name = "地图预览_道路网格", indexFormat = IndexFormat.UInt32 };
            roadMesh.SetVertices(vertices); roadMesh.SetTriangles(triangles, 0); roadMesh.RecalculateNormals(); roadMesh.RecalculateBounds();
            roadObject.GetComponent<MeshFilter>().sharedMesh = roadMesh;
        }

        // 水面保持分格高度；共边补连续竖面，解决跨区落差处悬空和裂缝。
        private void BuildWaterEdges(MapPreviewData map, Dictionary<int, GameObject> prefabs,
            Dictionary<int, MapPreviewData.Asset> assets)
        {
            if (waterMesh != null) Object.Destroy(waterMesh);
            foreach (var value in waterMaterials) Object.Destroy(value);
            waterMaterials.Clear();
            var vertices = new List<Vector3>();
            var groups = new Dictionary<int, List<int>>();
            Action<Vector3, Vector3, Vector3, Vector3, List<int>> quad = (a, b, c, d, triangles) => {
                var index = vertices.Count;
                vertices.Add(a); vertices.Add(b); vertices.Add(c); vertices.Add(d);
                // 两侧必须拆开顶点，否则 RecalculateNormals 会让相反法线抵消为零。
                vertices.Add(d); vertices.Add(c); vertices.Add(b); vertices.Add(a);
                foreach (var offset in new[] { 0, 1, 2, 0, 2, 3, 4, 5, 6, 4, 6, 7 }) triangles.Add(index + offset);
            };
            foreach (var cell in map.Cells)
            {
                if (!cell.HasWater) continue;
                if (!groups.TryGetValue(cell.WaterAssetId, out var triangles))
                { triangles = new List<int>(); groups.Add(cell.WaterAssetId, triangles); }
                foreach (var index in cell.Neighbors)
                {
                    var other = map.Cells[index];
                    if (!other.HasWater || cell.WaterLevel <= other.WaterLevel + .0001f) continue;
                    var direction = other.Position - cell.Position; direction.y = 0;
                    var side = Vector3.Cross(Vector3.up, direction.normalized) * map.Radius * .5f;
                    var upper = (cell.Position + other.Position) * .5f + direction.normalized * map.Radius * .003f;
                    upper.y = cell.WaterLevel;
                    var lower = upper; lower.y = other.WaterLevel;
                    quad(upper-side, upper+side, lower+side, lower-side, triangles);
                }
            }
            // 白沫只是水面表现，不附加障碍或通行规则。
            var foam = new List<int>();
            foreach (var fall in map.Waterfalls)
            {
                var lower = map.Cells[fall.To]; var upper = map.Cells[fall.From];
                var along = lower.Position - upper.Position; along.y = 0; along.Normalize();
                var side = Vector3.Cross(Vector3.up, along) * map.Radius * .35f;
                var center = (lower.Position + upper.Position) * .5f + along * map.Radius * .24f;
                center.y = lower.WaterLevel + .025f;
                quad(center-side, center+side, center+side+along*map.Radius*.45f, center-side+along*map.Radius*.45f, foam);
            }
            waterMesh = new Mesh { name = "地图预览_水面落差", indexFormat = IndexFormat.UInt32 };
            waterMesh.SetVertices(vertices); waterMesh.subMeshCount = groups.Count + 1;
            var slot = 0;
            foreach (var group in groups)
            {
                waterMesh.SetTriangles(group.Value, slot++);
                var surface = Array.Find(GetModel(prefabs[group.Key]).Materials,
                    value => value.name == assets[group.Key].TintMaterial);
                if (surface == null) throw new InvalidOperationException("水体资源须配置水面材质: " + assets[group.Key].Path);
                waterMaterials.Add(new Material(material) { color = surface.color });
            }
            waterMesh.SetTriangles(foam, slot);
            waterMaterials.Add(new Material(material) { color = new Color(.79f, .91f, .90f) });
            waterMesh.RecalculateNormals(); waterMesh.RecalculateBounds();
            waterEdges.GetComponent<MeshFilter>().sharedMesh = waterMesh;
            waterEdges.GetComponent<MeshRenderer>().sharedMaterials = waterMaterials.ToArray();
        }

        // 同一个观察器切换到局部地图时，连同独立 Mesh 一起隐藏大地图。
        public void SetVisible(bool visible) { roadObject.SetActive(visible); waterEdges.SetActive(visible); }

        public void Draw(Camera camera, bool water, bool buildings, bool roads, bool decorations)
        {
            roadObject.SetActive(roads);
            waterEdges.SetActive(water);
            foreach (var batch in batches)
            {
                if (batch.Kind == Kind.Water && !water || batch.Kind == Kind.Building && !buildings ||
                    batch.Kind == Kind.Decoration && !decorations) continue;
                Graphics.DrawMeshInstanced(batch.Mesh, batch.Submesh, material, batch.Matrices, batch.Count, batch.Properties,
                    batch.Kind == Kind.Water ? ShadowCastingMode.Off : ShadowCastingMode.On, true, 0, camera,
                    LightProbeUsage.Off);
            }
        }

        public void Dispose()
        {
            if (roadMesh != null) Object.Destroy(roadMesh);
            if (waterMesh != null) Object.Destroy(waterMesh);
            foreach (var value in waterMaterials) Object.Destroy(value);
            waterMaterials.Clear(); Object.Destroy(waterEdges);
            Object.Destroy(roadObject); Object.Destroy(material); Object.Destroy(roadMaterial);
            batches.Clear(); models.Clear();
        }
    }
}
