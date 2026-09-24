using System;
using System.Collections.Generic;
using UnityEngine;

namespace ProjectY.Samples
{
    /// <summary>可见敌人模型和战术地格；只消费快照，地形和占格仍由 Lua/C# Data 决定。</summary>
    public sealed class AreaCombatRenderer : IDisposable
    {
        private readonly GameObject root;
        private readonly PawnView prefab;
        private readonly Func<PawnAppearanceData.Part, GameObject> resolve;
        private readonly Dictionary<int, PawnView> enemies = new Dictionary<int, PawnView>();
        private readonly Mesh ring;
        private readonly Material material;
        private readonly MaterialPropertyBlock properties = new MaterialPropertyBlock();
        private readonly List<int> removed = new List<int>();
        private readonly HashSet<int> known = new HashSet<int>();
        private readonly HashSet<int> enemyCells = new HashSet<int>();
        private readonly HashSet<int> moves = new HashSet<int>();
        private readonly HashSet<int> targets = new HashSet<int>();
        public AreaCombatRenderer(Transform parent, PawnView prefab, Shader shader, Func<PawnAppearanceData.Part, GameObject> resolve)
        {
            this.prefab = prefab; this.resolve = resolve;
            root = new GameObject("MapAreaEnemies"); root.transform.SetParent(parent, false);
            material = new Material(shader) { name = "地牢战术地格", enableInstancing = true };
            var vertices = new Vector3[12]; var triangles = new int[36];
            for (var i = 0; i < 6; i++)
            {
                var angle = (30 + 60 * i) * Mathf.Deg2Rad;
                vertices[i * 2] = new Vector3(Mathf.Cos(angle), 0, Mathf.Sin(angle));
                vertices[i * 2 + 1] = vertices[i * 2] * .87f;
                var a = i * 2; var b = ((i + 1) % 6) * 2; var t = i * 6;
                triangles[t] = a; triangles[t + 1] = a + 1; triangles[t + 2] = b;
                triangles[t + 3] = b; triangles[t + 4] = a + 1; triangles[t + 5] = b + 1;
            }
            ring = new Mesh { name = "战术六边形轮廓", vertices = vertices, triangles = triangles };
            ring.RecalculateNormals(); ring.RecalculateBounds();
        }
        public void SetState(MapAreaViewData.State state, MapAreaViewData layout)
        {
            known.Clear(); foreach (var cell in state.Known) known.Add(cell);
            enemyCells.Clear(); foreach (var actor in state.Enemies) enemyCells.Add(actor.CellIndex);
            removed.Clear();
            foreach (var pair in enemies)
                if (!Array.Exists(state.Enemies, actor => actor.Id == pair.Key)) removed.Add(pair.Key);
            foreach (var id in removed) { Destroy(enemies[id].gameObject); enemies.Remove(id); }
            foreach (var actor in state.Enemies)
            {
                if (!enemies.TryGetValue(actor.Id, out var pawn))
                {
                    pawn = UnityEngine.Object.Instantiate(prefab, root.transform, false);
                    pawn.name = actor.Name; pawn.transform.rotation = Quaternion.Euler(0, 180, 0); enemies.Add(actor.Id, pawn);
                }
                pawn.ApplyAppearance(actor.Appearance, resolve);
                pawn.transform.position = layout.Cells[actor.CellIndex].Position + Vector3.up * .02f;
            }
        }
        private void Mark(Camera camera, MapAreaViewData layout, int cell, Color color)
        {
            properties.SetColor("_Color", QualitySettings.activeColorSpace == ColorSpace.Linear ? color.linear : color);
            var position = layout.Cells[cell].Position + Vector3.up * .06f;
            Graphics.DrawMesh(ring, Matrix4x4.TRS(position, Quaternion.identity, Vector3.one * layout.Radius * .96f), material, 0, camera, 0, properties,
                UnityEngine.Rendering.ShadowCastingMode.Off, false);
        }
        public void Draw(Camera camera, AdventureViewData view, MapAreaViewData layout, bool moving, int skillId)
        {
            if (view.Phase != "battle")
            {
                foreach (var cell in enemyCells) Mark(camera, layout, cell, new Color(.85f, .27f, .2f));
                return;
            }
            moves.Clear(); targets.Clear();
            if (view.Active.Team == 1)
            {
                if (moving) foreach (var cell in view.Reachable) moves.Add(cell.CellIndex);
                var skill = Array.Find(view.Skills, row => row.Id == skillId);
                if (skill != null) foreach (var id in skill.Targets)
                    targets.Add(Array.Find(view.Units, actor => actor.Id == id).CellIndex);
            }
            foreach (var cell in view.Cells)
            {
                var index = cell.CellIndex;
                if (cell.Blocked || !known.Contains(index)) continue;
                var color = new Color(.22f, .31f, .34f);
                if (enemyCells.Contains(index)) color = new Color(.85f, .27f, .2f);
                if (moves.Contains(index)) color = new Color(.24f, .76f, .51f);
                if (targets.Contains(index)) color = new Color(.97f, .76f, .43f);
                if (view.Active.CellIndex == index) color = Color.white;
                Mark(camera, layout, index, color);
            }
        }
        private static void Destroy(UnityEngine.Object value)
        {
            if (value is GameObject gameObject) gameObject.SetActive(false);
            if (Application.isPlaying) UnityEngine.Object.Destroy(value); else UnityEngine.Object.DestroyImmediate(value);
        }
        public void Dispose() { Destroy(root); Destroy(ring); Destroy(material); enemies.Clear(); }
    }
}
