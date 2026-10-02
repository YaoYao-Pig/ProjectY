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
        private readonly List<int> columnCells = new List<int>();
        private readonly List<PropBatch> propBatches = new List<PropBatch>();
        private sealed class CameraObstacle
        {
            public Bounds Bounds;
            public int InteriorId;
            public int Layer, CutawayGroup, CutawayLayer;
            public bool Cutaway;
        }
        private readonly List<CameraObstacle> cameraObstacles = new List<CameraObstacle>();
        private readonly HashSet<int> openInteriors = new HashSet<int>();
        private readonly Material material;
        private readonly Material groundMaterial;
        private readonly Mesh mesh;
        private TownSurfaceRenderer townSurface;
        private readonly Shader shader;
        private readonly MapAreaViewData map;
        private readonly bool[] known, visible;
        private readonly bool[] terrainShown;
        private readonly bool[] terrainCut;
        private readonly Dictionary<int, int> interiorLayers = new Dictionary<int, int>();
        private readonly Dictionary<int, int> groupLayers = new Dictionary<int, int>();
        private int revision = -1;
        private int constructionRevision=-1;
        private bool reveal;
        public Bounds Bounds { get; }
        public readonly List<Bounds> CameraObstacles = new List<Bounds>();
        // 从权威队员占格推导；同伴还在房内时保持剖切，最后一人离开后恢复。
        public bool IsInteriorOpen(int id) => id > 0 && openInteriors.Contains(id);
        private void AddCameraObstacle(Bounds bounds, MapAreaViewData.Prop prop)
        {
            cameraObstacles.Add(new CameraObstacle { Bounds = bounds, InteriorId = prop.InteriorId, Cutaway = prop.Cutaway,
                Layer = prop.Layer, CutawayGroup = prop.CutawayGroup, CutawayLayer = prop.CutawayLayer });
            CameraObstacles.Add(bounds);
        }
        public MapAreaRenderer(Shader shader, GameObject prefab, MapAreaViewData map, Func<MapAreaViewData.Asset, GameObject> resolve)
        {
            if (shader == null || prefab == null || !SystemInfo.supportsInstancing) throw new InvalidOperationException("MapArea 缺少实例渲染资源。");
            this.map = map; this.shader = shader;
            var filter = prefab.GetComponent<MeshFilter>(); var source = prefab.GetComponent<MeshRenderer>();
            if (filter == null || source == null || filter.sharedMesh == null) throw new InvalidOperationException("MapArea 柱模型缺少 Mesh。");
            if (!Array.Exists(source.sharedMaterials, value => value.name == map.TintMaterial)) throw new InvalidOperationException("MapArea 模型材质与配置不一致。");
            mesh = filter.sharedMesh; material = new Material(shader) { name = "MapArea_探索实例", enableInstancing = true };
            groundMaterial = new Material(shader) { name = "MapArea_地牢材质", enableInstancing = true };
            groundMaterial.SetFloat("_UseSurfacePattern", 2);
            if (map.IsTown || Array.Exists(map.Cells, cell => cell.UsesSurfaceMesh))
                townSurface = new TownSurfaceRenderer(shader, map, SurfaceCell);
            known = new bool[map.Cells.Length]; visible = new bool[map.Cells.Length];
            terrainShown = new bool[map.Cells.Length];
            terrainCut = new bool[map.Cells.Length];
            var bounds = new Bounds(map.Cells[0].Position, Vector3.zero);
            for (var i = 0; i < map.Cells.Length; i++)
            {
                if (!map.IsTown && i % 1023 == 0) batches.Add(new Batch { Start = i, Count = Math.Min(1023, map.Cells.Length - i) });
                if (!map.IsTown && map.Cells[i].RenderGround && map.Cells[i].Kind != "void" && !SurfaceCell(map.Cells[i])) columnCells.Add(i);
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
                    if (prop.AssetId != asset.Id || !prop.CameraObstacle) continue;
                    var local = propFilter.sharedMesh.bounds;
                    var matrix = Matrix4x4.TRS(prop.Position, Quaternion.Euler(0, prop.Rotation, 0), prop.Scale3);
                    var obstacle = new Bounds(matrix.MultiplyPoint3x4(local.center), Vector3.zero);
                    for (var x = -1; x <= 1; x += 2) for (var y = -1; y <= 1; y += 2) for (var z = -1; z <= 1; z += 2)
                        obstacle.Encapsulate(matrix.MultiplyPoint3x4(local.center + Vector3.Scale(local.extents, new Vector3(x, y, z))));
                    if (!map.IsTown && prop.CutawayGroup == 0) { obstacle.Expand(.35f); AddCameraObstacle(obstacle, prop); continue; }
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
            if (state.Revision == revision && state.ConstructionRevision==constructionRevision && revealAll == reveal) return;
            if (townSurface != null && constructionRevision >= 0 && state.ConstructionRevision != constructionRevision)
            { townSurface.Dispose(); townSurface = new TownSurfaceRenderer(shader, map, SurfaceCell); }
            constructionRevision=state.ConstructionRevision;
            revision = state.Revision; reveal = revealAll;
            openInteriors.Clear(); interiorLayers.Clear(); groupLayers.Clear();
            foreach (var member in state.Members)
            {
                var memberCell = map.Cells[member.CellIndex];
                if (memberCell.CutawayGroup > 0 && (!groupLayers.TryGetValue(memberCell.CutawayGroup, out var current) || memberCell.Layer > current))
                    groupLayers[memberCell.CutawayGroup] = memberCell.Layer;
                var id = memberCell.InteriorId;
                if (id > 0) openInteriors.Add(id);
                var floorId = memberCell.CoverInteriorId > 0 ? memberCell.CoverInteriorId : id;
                if (floorId > 0)
                {
                    if (!interiorLayers.TryGetValue(floorId, out var layer) || memberCell.Layer > layer)
                        interiorLayers[floorId] = memberCell.Layer;
                }
            }
            Array.Clear(known, 0, known.Length); Array.Clear(visible, 0, visible.Length);
            foreach (var index in state.Known) known[index] = true;
            foreach (var index in state.Visible) visible[index] = true;
            // The leader selects the viewed storey in their building. Stairs remain selectable from below.
            if (state.Members.Length > 0)
            {
                var leader = map.Cells[state.Members[0].CellIndex];
                if (leader.InteriorId > 0) interiorLayers[leader.InteriorId] = leader.Layer;
                if (leader.CoverInteriorId > 0) interiorLayers[leader.CoverInteriorId] = leader.Layer;
                if (leader.CutawayGroup > 0) groupLayers[leader.CutawayGroup] = leader.Layer;
            }
            // 镜头与绘制使用同一层级剖切，旧城镇上盖继续按室内占格打开。
            CameraObstacles.Clear();
            foreach (var obstacle in cameraObstacles)
                if (!IsCut(obstacle.InteriorId, obstacle.Cutaway, obstacle.Layer, obstacle.CutawayGroup, obstacle.CutawayLayer)) CameraObstacles.Add(obstacle.Bounds);
            for (var i = 0; i < map.Cells.Length; i++)
            {
                var cell = map.Cells[i];
                var interior = cell.CoverInteriorId > 0 ? cell.CoverInteriorId : cell.InteriorId;
                var cut = interior > 0 && cell.Layer > 0
                    && interiorLayers.TryGetValue(interior, out var floor) && cell.Layer > floor
                    && (cell.Kind != "stairs" || cell.Layer > floor + 1);
                cut |= cell.CutawayGroup > 0 && groupLayers.TryGetValue(cell.CutawayGroup, out var groupFloor) && cell.CutawayLayer > groupFloor;
                terrainCut[i] = cut;
                terrainShown[i] = (map.IsTown || reveal || known[i]) && !cut;
            }
            townSurface?.SetVisibility(terrainShown, reveal || map.IsTown ? null : visible);
            foreach (var batch in batches)
            {
                for (var i = 0; i < batch.Count; i++)
                {
                    var index = batch.Start + i; var cell = map.Cells[index]; var discovered = reveal || known[index];
                    var top = discovered ? cell.GroundHeight + (cell.Kind == "wall" ? cell.WallHeight : 0) :
                        cell.CutawayGroup > 0 || cell.Layer > 0 ? cell.Position.y : 0;
                    var position = new Vector3(cell.Position.x, top, cell.Position.z);
                    batch.Matrices[i] = Matrix4x4.TRS(position, Quaternion.identity,
                        !cell.RenderGround || terrainCut[index] || discovered && SurfaceCell(cell) ? Vector3.zero :
                        new Vector3(map.Radius, Mathf.Max(.2f, top - ColumnBottom(cell, top)), map.Radius));
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
                    if (IsCut(prop.InteriorId, prop.Cutaway, prop.Layer, prop.CutawayGroup, prop.CutawayLayer)) continue;
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
        private bool SurfaceCell(MapAreaViewData.Cell cell) => cell.RenderGround && (map.IsTown || cell.UsesSurfaceMesh);
        private bool IsCut(int interiorId, bool cutaway, int layer, int group, int cutawayLayer)
        {
            if (group > 0 && groupLayers.TryGetValue(group, out var groupFloor) && cutawayLayer > groupFloor) return true;
            if (layer >= 0 && interiorLayers.TryGetValue(interiorId, out var floor) && layer > floor) return true;
            return cutaway && IsInteriorOpen(interiorId);
        }
        public bool IsCellShown(int index) => terrainShown[index];
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
            var best = float.PositiveInfinity; var result = -1;
            if (townSurface != null) best = townSurface.Raycast(ray, best, out result);
            if (map.IsTown) return result;
            RaycastColumns(ray, best, ref result);
            return result;
        }
        // 分层岩壁只从所属楼板挤出，不能贯穿下面的矿道；绘制与拾取共用底面。
        private static float ColumnBottom(MapAreaViewData.Cell cell, float top) =>
            cell.Layer > 0 || cell.CutawayGroup > 0 || cell.DeckThickness > 0
                ? cell.Position.y - Mathf.Max(.2f, cell.DeckThickness) : -Mathf.Max(1f, -top + .2f);
        private float RaycastColumns(Ray ray, float best, ref int result)
        {
            foreach (var i in columnCells)
            {
                if (!terrainShown[i]) continue;
                var cell = map.Cells[i]; var top = cell.Position.y + (cell.Kind == "wall" ? cell.WallHeight : cell.ConstructionHeight);
                if (!cell.RenderGround || cell.Kind == "void") continue;
                if (SurfaceCell(cell)) continue;
                var origin = ray.origin - new Vector3(cell.Position.x, 0, cell.Position.z);
                var near = 0f; var far = best;
                if (!Clip(Vector3.up, top, origin, ray.direction, ref near, ref far) ||
                    !Clip(Vector3.down, -ColumnBottom(cell, top), origin, ray.direction, ref near, ref far)) continue;
                var hit = true;
                for (var side = 0; side < 6 && hit; side++)
                {
                    var angle = side * Mathf.PI / 3;
                    hit = Clip(new Vector3(Mathf.Cos(angle), 0, Mathf.Sin(angle)), map.Radius * .8660254f, origin, ray.direction, ref near, ref far);
                }
                if (hit && near < best) { best = near; result = i; }
            }
            return best;
        }
        public float TerrainDistance(Ray ray, float distance)
        {
            if (townSurface != null) distance = townSurface.Raycast(ray, distance, out _);
            var index = -1;
            return map.IsTown ? distance : RaycastColumns(ray, distance, ref index);
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
