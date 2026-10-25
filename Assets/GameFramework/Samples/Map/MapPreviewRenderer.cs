using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using Object = UnityEngine.Object;

namespace ProjectY.Samples
{
    // 只持有显示资源。地块用 GPU 实例批次，避免数千格各创建一个 GameObject。
    public sealed partial class MapPreviewRenderer : IDisposable
    {
        public enum Kind { Terrain, Water, City, Building, Decoration, Wonder }
        private sealed class Model
        {
            public Mesh Mesh;
            public Material[] Materials;
            public readonly Dictionary<Kind, Dictionary<Vector2Int, List<Batch>[]>> Groups = new Dictionary<Kind, Dictionary<Vector2Int, List<Batch>[]>>();
            public readonly Dictionary<Kind, DrawGroup[]> Submissions = new Dictionary<Kind, DrawGroup[]>();
        }
        private sealed class DrawGroup
        {
            public Mesh Mesh;
            public int Submesh;
            public Kind Kind;
            public readonly List<Batch> Near = new List<Batch>(), Distant = new List<Batch>();
        }
        private sealed class Batch
        {
            public Mesh Mesh;
            public int Submesh, Count;
            public Kind Kind;
            public Matrix4x4[] Matrices = new Matrix4x4[16];
            public Vector4[] Colors = new Vector4[16];
            public int[] CellIndices = new int[16];
            public Bounds Bounds;
            public MapRenderLod.Tier Tier;
            public DrawGroup Group;
            public Vector4[] FocusFlags;
            public Vector4[] WaterFlows;
            public Vector4[] GroundData;
            public readonly MaterialPropertyBlock Properties = new MaterialPropertyBlock();
            public void Resize(int size)
            {
                Array.Resize(ref Matrices, size); Array.Resize(ref Colors, size); Array.Resize(ref CellIndices, size);
                if (WaterFlows != null) Array.Resize(ref WaterFlows, size);
                if (GroundData != null) Array.Resize(ref GroundData, size);
            }
        }
        private readonly Dictionary<GameObject, Model> models = new Dictionary<GameObject, Model>();
        private readonly List<Batch> batches = new List<Batch>();
        private readonly List<DrawGroup> drawGroups = new List<DrawGroup>();
        private readonly Material material;
        private readonly Material roadMaterial;
        private readonly GameObject roadObject;
        private Mesh roadMesh;
        private readonly GameObject waterEdges;
        private Mesh waterMesh;
        private readonly List<Material> waterMaterials = new List<Material>();
        private readonly MapWaterEffects waterEffects;
        private readonly MapGroundPresentation groundPresentation;
        private readonly MapNatureRenderer natureRenderer;
        private readonly MapCloudRenderer cloudRenderer;
        private readonly MapMountainSurface mountainSurface;
        private readonly MapRenderLod.View lodView = new MapRenderLod.View();
        private readonly MapRenderLod.Settings defaultLod = new MapRenderLod.Settings();
        private readonly Matrix4x4[] detailMatrices = new Matrix4x4[1023];
        private readonly Vector4[] detailColors = new Vector4[1023];
        private readonly Vector4[] visibleFlows = new Vector4[1023], visibleGround = new Vector4[1023];
        private readonly MaterialPropertyBlock detailProperties = new MaterialPropertyBlock();
        private float mapRadius;
        private MapPreviewData fogMap;
        private WorldFogRenderer worldFog;
        internal bool IsWorldCellKnown(int cell) => worldFog == null || worldFog.Known(cell);
        internal bool PickMountainSurface(Ray ray, out int cell, out float distance) => mountainSurface.TryPick(ray, out cell, out distance);
        public void SetExploration(ProjectY.Data.WorldMapExplorationData state)
        {
            if(state==null)return; // Standalone map previews deliberately have no expedition fog.
            if(worldFog==null)
            {
                worldFog=new WorldFogRenderer(fogMap,roadObject.transform.parent);
                worldFog.Bind(material);worldFog.Bind(roadMaterial);worldFog.Bind(groundPresentation.Material);
                worldFog.Bind(natureRenderer.SharedMaterial);worldFog.Bind(waterEffects.SurfaceMaterial);worldFog.Bind(waterEffects.FoamMaterial);
                worldFog.Bind(cloudRenderer.Material);
                worldFog.Bind(mountainSurface.Material);
                foreach(var waterMaterial in waterMaterials)worldFog.Bind(waterMaterial);
                waterEffects.VisibilityFilter=worldFog.VisibleAt;
            }
            worldFog.Update(state);
            if (mountainSurface.UpdateExploration(state)) focusMaskDirty = true;
        }
        public int SubmittedBatches { get; private set; }
        public int SubmittedInstances { get; private set; }
        public int SubmittedDetailInstances { get; private set; }
        public int CulledBatches { get; private set; }
        public Bounds Bounds { get; private set; }

        public MapPreviewRenderer(Shader shader, Transform owner)
        {
            if (!SystemInfo.supportsInstancing) throw new NotSupportedException("地图测试场景需要 GPU Instancing。");
            if (shader == null || !shader.isSupported) throw new InvalidOperationException("地图预览 Shader 缺失或不受支持。");
            material = new Material(shader) { name = "地图预览_实例材质", enableInstancing = true };
            waterEffects = new MapWaterEffects(owner);
            groundPresentation = new MapGroundPresentation();
            natureRenderer = new MapNatureRenderer(owner);
            cloudRenderer = new MapCloudRenderer();
            mountainSurface = new MapMountainSurface(shader);
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
            Color? ground = null, string tintMaterial = null, Vector4 waterFlow = default, Vector4 groundData = default, int cellIndex = -1)
        {
            var model = GetModel(prefab);
            if (!model.Groups.TryGetValue(kind, out var chunks))
            {
                chunks = new Dictionary<Vector2Int, List<Batch>[]>(); model.Groups.Add(kind, chunks);
                var submissions = new DrawGroup[model.Mesh.subMeshCount];
                for (var i = 0; i < submissions.Length; i++)
                { submissions[i] = new DrawGroup { Mesh = model.Mesh, Submesh = i, Kind = kind }; drawGroups.Add(submissions[i]); }
                model.Submissions.Add(kind, submissions);
            }
            var chunk = new Vector2Int(Mathf.FloorToInt(position.x / (mapRadius * 8)), Mathf.FloorToInt(position.z / (mapRadius * 8)));
            if (!chunks.TryGetValue(chunk, out var groups))
            {
                groups = new List<Batch>[model.Mesh.subMeshCount];
                for (var i = 0; i < groups.Length; i++) groups[i] = new List<Batch>();
                chunks.Add(chunk, groups);
            }
            for (var slot = 0; slot < groups.Length; slot++)
            {
                var group = groups[slot];
                if (group.Count == 0 || group[group.Count - 1].Count == 1023)
                {
                    var added = new Batch { Mesh = model.Mesh, Submesh = slot, Kind = kind, Group = model.Submissions[kind][slot],
                        WaterFlows = kind == Kind.Water ? new Vector4[16] : null,
                        GroundData = kind == Kind.Terrain ? new Vector4[16] : null };
                    group.Add(added); batches.Add(added);
                }
                var batch = group[group.Count - 1];
                if (batch.Count == batch.Matrices.Length) batch.Resize(Mathf.Min(1023, batch.Count * 2));
                var color = model.Materials[slot].color;
                // Empty tint binding preserves authored material palettes, including multi-color terrain variants.
                if (ground.HasValue && !string.IsNullOrEmpty(tintMaterial))
                {
                    var top = model.Materials[slot].name == tintMaterial;
                    color = ground.Value * (top ? 1f : .82f); color.a = 1;
                }
                // SetVectorArray 不执行 Color 的颜色空间转换，线性项目须显式转换。
                batch.Colors[batch.Count] = QualitySettings.activeColorSpace == ColorSpace.Linear ? color.linear : color;
                if (kind == Kind.Water) batch.WaterFlows[batch.Count] = waterFlow;
                if (kind == Kind.Terrain) batch.GroundData[batch.Count] = groundData;
                batch.Matrices[batch.Count] = Matrix4x4.TRS(position, rotation, scale);
                batch.CellIndices[batch.Count] = cellIndex;
                var bounds = InstanceBounds(model.Mesh.bounds, batch.Matrices[batch.Count]);
                bounds.Expand(new Vector3(0, mapRadius * .48f, 0)); // Includes the existing site-hover lift.
                if (batch.Count == 0) batch.Bounds = bounds; else batch.Bounds.Encapsulate(bounds);
                RegisterFocusInstance(cellIndex, batch, batch.Count);
                batch.Count++;
            }
        }

        public void Build(MapPreviewData map, Func<MapPreviewData.Asset, GameObject> resolve)
        {
            foreach (var progress in BuildIncremental(map, resolve)) { }
        }

        // Shared algorithm for synchronous previews and frame-by-frame campaign loading.
        public IEnumerable<float> BuildIncremental(MapPreviewData map, Func<MapPreviewData.Asset, GameObject> resolve)
        {
            mapRadius = map.Radius;
            worldFog?.Dispose();worldFog=null;fogMap=map;waterEffects.VisibilityFilter=null;
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
            yield return .03f;
            batches.Clear(); drawGroups.Clear();
            ResetFocus(map);
            foreach (var model in models.Values) { model.Groups.Clear(); model.Submissions.Clear(); }
            waterEffects.Build(map);
            yield return .08f;
            groundPresentation.Build(map);
            yield return .16f;
            natureRenderer.Build(map);
            cloudRenderer.Build(map);
            yield return .28f;
            Bounds = new Bounds(map.Cells[0].Position, Vector3.zero);
            var bottom = map.Cells[0].Position.y;
            foreach (var cell in map.Cells)
            {
                Bounds = Encapsulate(Bounds, cell.Position); bottom = Mathf.Min(bottom, cell.Position.y);
                if (cell.SurfaceCorners == null) continue;
                foreach (var height in cell.SurfaceCorners)
                { Bounds = Encapsulate(Bounds, new Vector3(cell.Position.x, height, cell.Position.z)); bottom = Mathf.Min(bottom, height); }
            }
            bottom -= map.Radius * 1.5f;
            mountainSurface.Build(map, bottom);
            for (var cellIndex = 0; cellIndex < map.Cells.Length; cellIndex++)
            {
                var cell = map.Cells[cellIndex];
                if (cell.SurfaceCorners == null)
                    Add(prefabs[cell.TerrainAssetId], Kind.Terrain, cell.Position,
                        new Vector3(map.Radius, cell.Position.y - bottom, map.Radius), Quaternion.identity,
                        cell.Color, assets[cell.TerrainAssetId].TintMaterial, groundData: groundPresentation.GetData(cell), cellIndex: cellIndex);
                if (cell.HasWater)
                    Add(prefabs[cell.WaterAssetId], Kind.Water, new Vector3(cell.Position.x, cell.WaterLevel, cell.Position.z),
                        new Vector3(map.Radius, 1, map.Radius), Quaternion.identity, waterFlow: waterEffects.Flows[cellIndex], cellIndex: cellIndex);
                if ((cellIndex + 1) % 512 == 0) yield return .3f + .4f * (cellIndex + 1) / map.Cells.Length;
            }
            yield return .7f;
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
                    map.Towns[building.TownId].GroundColor, assets[building.PlatformAssetId].TintMaterial, cellIndex: building.Center);
                // 原件正面为 +Z；入口方向由布局给出，七格底板自身不旋转。
                var direction = map.Cells[building.Entrance].Position - position; direction.y = 0;
                if (direction.sqrMagnitude < .01f) throw new InvalidOperationException("建筑入口与中心重合。");
                var scale = new Vector3(map.Radius, building.Height / referenceHeight, map.Radius);
                Add(prefab, Kind.Building, position, scale, Quaternion.LookRotation(direction), cellIndex: building.Center);
                Bounds = Encapsulate(Bounds, position + Vector3.up * GetModel(prefab).Mesh.bounds.size.y * scale.y);
            }
            yield return .8f;
            for (var index = 0; index < map.Decorations.Length; index++)
            {
                var item = map.Decorations[index];
                var position = map.Cells[item.Cell].Position;
                position.y = item.Height;
                var prefab = prefabs[item.AssetId];
                var scale = Vector3.one * (item.Scale * map.Radius);
                Add(prefab, item.Wonder ? Kind.Wonder : Kind.Decoration, position, scale, Quaternion.Euler(0, item.Yaw, 0), cellIndex: item.Cell);
                Bounds = Encapsulate(Bounds, position + Vector3.up * GetModel(prefab).Mesh.bounds.size.y * scale.y);
                if ((index + 1) % 512 == 0) yield return .8f + .14f * (index + 1) / map.Decorations.Length;
            }
            Bounds = new Bounds(Bounds.center, Bounds.size + Vector3.one * map.Radius * 2);
            foreach (var batch in batches)
            {
                batch.Resize(batch.Count);
                batch.Properties.SetVectorArray("_Color", batch.Colors);
                if (batch.Kind == Kind.Water) batch.Properties.SetVectorArray("_WaterFlow", batch.WaterFlows);
                if (batch.Kind == Kind.Terrain) batch.Properties.SetVectorArray("_GroundData", batch.GroundData);
            }
            yield return .94f;
            BuildRoads(map);
            yield return .97f;
            BuildWaterEdges(map, prefabs, assets);
            yield return 1;
        }

        private static Bounds Encapsulate(Bounds bounds, Vector3 point) { bounds.Encapsulate(point); return bounds; }

        private void BuildRoads(MapPreviewData map)
        {
            Release(roadMesh);
            var vertices = new List<Vector3>(); var triangles = new List<int>();
            var vertexCells = new List<int>(); int fromCell = 0, toCell = 0;
            var used = new HashSet<ulong>();
            Action<Vector3, Vector3, Vector3> quad = (a, b, side) => {
                var start = vertices.Count;
                vertices.Add(RoadPoint(map.Cells[fromCell], a - side, map.Radius)); vertices.Add(RoadPoint(map.Cells[fromCell], a + side, map.Radius));
                vertices.Add(RoadPoint(map.Cells[toCell], b + side, map.Radius)); vertices.Add(RoadPoint(map.Cells[toCell], b - side, map.Radius));
                vertexCells.Add(fromCell); vertexCells.Add(fromCell); vertexCells.Add(toCell); vertexCells.Add(toCell);
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
                    edgeA = RoadPoint(map.Cells[first], edgeA, map.Radius); edgeB = RoadPoint(map.Cells[second], edgeB, map.Radius);
                    // 在各格顶面画路，高差处补立面，避免斜线穿进高格地面。
                    fromCell = toCell = first; quad(a, edgeA, side);
                    fromCell = toCell = second; quad(edgeB, b, side);
                    if (Mathf.Abs(edgeA.y - edgeB.y) > .001f)
                    { fromCell = first; toCell = second; quad(edgeA, edgeB, side); fromCell = second; toCell = first; quad(edgeB, edgeA, side); }
                }
            roadMesh = new Mesh { name = "地图预览_道路网格", indexFormat = IndexFormat.UInt32 };
            roadMesh.SetVertices(vertices); roadMesh.SetTriangles(triangles, 0); roadMesh.RecalculateNormals(); roadMesh.RecalculateBounds();
            roadObject.GetComponent<MeshFilter>().sharedMesh = roadMesh;
            roadVertexCells = vertexCells.ToArray(); originalRoadVertices = vertices.ToArray(); focusRoadVertices = vertices.ToArray();
            CacheFocusRoadVertices();
        }

        private static Vector3 RoadPoint(MapPreviewData.Cell cell, Vector3 point, float radius)
        {
            if (cell.SurfaceCorners != null) point.y = MapMountainSurface.HeightAt(cell, radius, point) + .045f;
            return point;
        }

        // 水面保持分格高度；共边补连续竖面，解决跨区落差处悬空和裂缝。
        private void BuildWaterEdges(MapPreviewData map, Dictionary<int, GameObject> prefabs,
            Dictionary<int, MapPreviewData.Asset> assets)
        {
            Release(waterMesh);
            foreach (var value in waterMaterials) Release(value);
            waterMaterials.Clear();
            var vertices = new List<Vector3>();
            var normals = new List<Vector3>();
            var uv = new List<Vector2>();
            var groups = new Dictionary<int, List<int>>();
            var foam = new List<int>();
            Action<Vector3, Vector3, Vector3, Vector3, List<int>> quad = (a, b, c, d, triangles) => {
                var index = vertices.Count;
                var normal = Vector3.Cross(b - a, c - a).normalized;
                vertices.Add(a); vertices.Add(b); vertices.Add(c); vertices.Add(d);
                for (var i = 0; i < 4; i++) normals.Add(normal);
                uv.Add(new Vector2(0, 1)); uv.Add(new Vector2(1, 1)); uv.Add(new Vector2(1, 0)); uv.Add(new Vector2(0, 0));
                // 两侧必须拆开顶点，否则 RecalculateNormals 会让相反法线抵消为零。
                vertices.Add(d); vertices.Add(c); vertices.Add(b); vertices.Add(a);
                for (var i = 0; i < 4; i++) normals.Add(-normal);
                uv.Add(new Vector2(0, 0)); uv.Add(new Vector2(1, 0)); uv.Add(new Vector2(1, 1)); uv.Add(new Vector2(0, 1));
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
                    var direction = other.Position - cell.Position; direction.y = 0; direction.Normalize();
                    var side = Vector3.Cross(Vector3.up, direction) * map.Radius * .5f;
                    var upper = (cell.Position + other.Position) * .5f + direction * map.Radius * .003f;
                    upper.y = cell.WaterLevel;
                    var lower = upper; lower.y = other.WaterLevel;
                    var drop = cell.WaterLevel - other.WaterLevel;
                    if (drop < map.Radius * .04f) quad(upper-side, upper+side, lower+side, lower-side, triangles);
                    else AddWaterCurtain(upper, direction, drop, map.Radius, vertices, normals, uv, triangles);
                    if (drop < map.Radius * .12f) continue;
                    // 每条实际落差都覆盖上沿和撞水处，避免只有被标记的瀑布才有过渡。
                    var crest = upper + direction * map.Radius * .065f + Vector3.up * map.Radius * .028f;
                    quad(crest-side, crest+side, crest+side-direction*map.Radius*.4f, crest-side-direction*map.Radius*.4f, foam);
                    var impact = lower + direction * map.Radius * .12f + Vector3.up * map.Radius * .032f;
                    quad(impact-side, impact+side, impact+side+direction*map.Radius*.85f, impact-side+direction*map.Radius*.85f, foam);
                }
            }
            waterMesh = new Mesh { name = "地图预览_水面落差", indexFormat = IndexFormat.UInt32 };
            waterMesh.SetVertices(vertices); waterMesh.SetNormals(normals); waterMesh.SetUVs(0, uv); waterMesh.subMeshCount = groups.Count + 1;
            var slot = 0;
            foreach (var group in groups)
            {
                waterMesh.SetTriangles(group.Value, slot++);
                var surface = Array.Find(GetModel(prefabs[group.Key]).Materials,
                    value => value.name == assets[group.Key].TintMaterial);
                if (surface == null) throw new InvalidOperationException("水体资源须配置水面材质: " + assets[group.Key].Path);
                var curtain = new Material(waterEffects.SurfaceMaterial) { name = "地图_流动水幕", color = surface.color };
                curtain.SetFloat("_WaterMode", 1);
                waterMaterials.Add(curtain);
            }
            waterMesh.SetTriangles(foam, slot);
            waterMaterials.Add(new Material(waterEffects.FoamMaterial) { color = new Color(.79f, .91f, .90f) });
            waterMesh.RecalculateBounds();
            waterEdges.GetComponent<MeshFilter>().sharedMesh = waterMesh;
            waterEdges.GetComponent<MeshRenderer>().sharedMaterials = waterMaterials.ToArray();
        }

        private static void AddWaterCurtain(Vector3 upper, Vector3 direction, float drop, float radius,
            List<Vector3> vertices, List<Vector3> normals, List<Vector2> uv, List<int> triangles)
        {
            // 水体专用弧面盖住直角；地形、水位、相邻同高水面以及碰撞保持原契约。
            var bend = Mathf.Min(radius * .10f, drop * .18f);
            var profile = new[] {
                new Vector2(-.20f * radius, .008f * radius), new Vector2(.025f * radius, .012f * radius),
                new Vector2(.11f * radius, -bend), new Vector2(.14f * radius, -drop * .5f),
                new Vector2(.18f * radius, -drop + bend), new Vector2(.30f * radius, -drop + radius * .025f),
                new Vector2(.55f * radius, -drop + radius * .009f)
            };
            const int columns = 6;
            var side = Vector3.Cross(Vector3.up, direction);
            for (var face = 0; face < 2; face++)
            {
                var start = vertices.Count;
                for (var row = 0; row < profile.Length; row++)
                    for (var column = 0; column <= columns; column++)
                    {
                        var u = column / (float)columns;
                        // 端点保持共边位置，邻接水幕仍能拼接；中段轻微不规则，打散矩形轮廓。
                        var taper = Mathf.Sin(u * Mathf.PI);
                        var jitter = (Mathf.PerlinNoise(upper.x * .73f + u * 3.7f, upper.z * .61f) - .5f) * radius * .035f;
                        var point = profile[row];
                        var position = upper + side * ((u - .5f) * radius)
                            + direction * (point.x * taper + jitter * taper)
                            + Vector3.up * point.y;
                        var before = profile[Mathf.Max(0, row - 1)];
                        var after = profile[Mathf.Min(profile.Length - 1, row + 1)];
                        var tangent = direction * ((after.x - before.x) * Mathf.Max(.02f, taper)) + Vector3.up * (after.y - before.y);
                        var normal = Vector3.Cross(tangent, side).normalized;
                        vertices.Add(position); normals.Add(face == 0 ? normal : -normal);
                        uv.Add(new Vector2(u, 1 - row / (float)(profile.Length - 1)));
                    }
                for (var row = 0; row < profile.Length - 1; row++)
                    for (var column = 0; column < columns; column++)
                    {
                        var a = start + row * (columns + 1) + column;
                        var b = a + columns + 1; var c = b + 1; var d = a + 1;
                        if (face == 0) { triangles.Add(a); triangles.Add(b); triangles.Add(c); triangles.Add(a); triangles.Add(c); triangles.Add(d); }
                        else { triangles.Add(a); triangles.Add(c); triangles.Add(b); triangles.Add(a); triangles.Add(d); triangles.Add(c); }
                    }
            }
        }

        // 同一个观察器切换到局部地图时，连同独立 Mesh 一起隐藏大地图。
        public void SetVisible(bool visible)
        {
            worldFog?.SetVisible(visible);
            roadObject.SetActive(visible); waterEdges.SetActive(visible); waterEffects.SetVisible(visible);
            natureRenderer.SetVisible(visible);
            cloudRenderer.SetVisible(visible);
            mountainSurface.SetVisible(visible);
        }

        public void Draw(Camera camera, bool water, bool buildings, bool roads, bool decorations, MapRenderLod.Settings settings = null)
        {
            settings = settings ?? defaultLod;
            lodView.Update(camera, Bounds.center.y, mapRadius, settings);
            SubmittedBatches = SubmittedInstances = SubmittedDetailInstances = CulledBatches = 0;
            roadObject.SetActive(roads);
            waterEdges.SetActive(water);
            waterEffects.SetVisible(water);
            waterEffects.Tick(camera, Time.deltaTime);
            var natureVisible = decorations && (!camera.orthographic || camera.orthographicSize <= settings.nearDistance * mapRadius);
            natureRenderer.SetVisible(natureVisible);
            natureRenderer.Draw(camera, natureVisible);
            cloudRenderer.Draw(camera);
            mountainSurface.Draw(camera, lodView);
            SubmittedBatches += mountainSurface.SubmittedChunks; SubmittedInstances += mountainSurface.SubmittedCells;
            foreach (var group in drawGroups) { group.Near.Clear(); group.Distant.Clear(); }
            foreach (var batch in batches)
            {
                if (batch.Kind == Kind.Water && !water || batch.Kind == Kind.Building && !buildings ||
                    (batch.Kind == Kind.Decoration || batch.Kind == Kind.Wonder) && !decorations) continue;
                batch.Tier = lodView.Classify(batch.Bounds, batch.Tier);
                var detail = batch.Kind == Kind.Building || batch.Kind == Kind.Decoration || batch.Kind == Kind.City;
                if (batch.Tier == MapRenderLod.Tier.Hidden || detail && batch.Tier == MapRenderLod.Tier.Far)
                { CulledBatches++; continue; }
                (batch.Tier == MapRenderLod.Tier.Near ? batch.Group.Near : batch.Group.Distant).Add(batch);
            }
            // Spatial buckets are a culling index, not extra draw calls in the full-map view.
            foreach (var group in drawGroups)
            { DrawVisible(group, group.Near, camera, settings, true); DrawVisible(group, group.Distant, camera, settings, false); }
        }
        private void DrawVisible(DrawGroup group, List<Batch> visible, Camera camera, MapRenderLod.Settings settings, bool near)
        {
            var count = 0;
            var detail = group.Kind == Kind.Building || group.Kind == Kind.Decoration || group.Kind == Kind.City;
            foreach (var batch in visible)
                for (var i = 0; i < batch.Count; i++)
                {
                    if(worldFog!=null && !worldFog.Known(batch.CellIndices[i]))continue;
                    if (batch.Kind == Kind.Decoration && !near && batch.CellIndices[i] % settings.mediumDecorationStride != 0) continue;
                    if (detail && !lodView.Visible(InstanceBounds(batch.Mesh.bounds, batch.Matrices[i]))) continue;
                    detailMatrices[count] = batch.Matrices[i]; detailColors[count] = batch.Colors[i];
                    if (batch.WaterFlows != null) visibleFlows[count] = batch.WaterFlows[i];
                    if (batch.GroundData != null) visibleGround[count] = batch.GroundData[i];
                    count++;
                    if (count == 1023) { SubmitVisible(group, camera, count, near, detail); count = 0; }
                }
            if (count > 0) SubmitVisible(group, camera, count, near, detail);
        }
        private void SubmitVisible(DrawGroup group, Camera camera, int count, bool near, bool detail)
        {
            detailProperties.SetVectorArray("_Color", detailColors);
            if (group.Kind == Kind.Water) detailProperties.SetVectorArray("_WaterFlow", visibleFlows);
            if (group.Kind == Kind.Terrain) detailProperties.SetVectorArray("_GroundData", visibleGround);
            SubmittedBatches++; SubmittedInstances += count;
            if (detail) SubmittedDetailInstances += count;
            var batchMaterial = group.Kind == Kind.Water ? waterEffects.SurfaceMaterial : group.Kind == Kind.Terrain ? groundPresentation.Material : material;
            Graphics.DrawMeshInstanced(group.Mesh, group.Submesh, batchMaterial, detailMatrices, count, detailProperties,
                group.Kind == Kind.Water || !near ? ShadowCastingMode.Off : ShadowCastingMode.On, true, 0, camera, LightProbeUsage.Off);
        }

        public void Dispose()
        {
            worldFog?.Dispose();worldFog=null;
            DisposeFocus();
            Release(roadMesh); Release(waterMesh);
            foreach (var value in waterMaterials) Release(value);
            waterMaterials.Clear(); Release(waterEdges);
            waterEffects.Dispose();
            natureRenderer.Dispose(); groundPresentation.Dispose();
            cloudRenderer.Dispose();
            mountainSurface.Dispose();
            Release(roadObject); Release(material); Release(roadMaterial);
            batches.Clear(); drawGroups.Clear(); models.Clear();
        }
        private static void Release(Object value)
        {
            if(value==null)return;
            if(Application.isPlaying)Object.Destroy(value);else Object.DestroyImmediate(value);
        }
    }
}
