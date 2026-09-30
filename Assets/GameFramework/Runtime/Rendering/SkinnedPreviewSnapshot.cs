using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering.Universal;
using Object = UnityEngine.Object;

namespace ProjectY.Rendering
{
    /// <summary>Owned, reusable CPU pose snapshots for cameras rendered outside Unity's skinning phase.</summary>
    public sealed class SkinnedPreviewSnapshot : IDisposable
    {
        private sealed class Entry
        {
            internal SkinnedMeshRenderer Source;
            internal Mesh Mesh;
            internal Mesh BakedSource;
            internal MeshRenderer Renderer;
            internal int MaterialCount;
            internal bool Muted;
        }
        private readonly Transform root;
        private readonly List<Entry> entries = new List<Entry>();
        private readonly HashSet<SkinnedMeshRenderer> present = new HashSet<SkinnedMeshRenderer>();
        private readonly MaterialPropertyBlock block = new MaterialPropertyBlock();
        private bool rendering, disposed;

        public SkinnedPreviewSnapshot(Transform root)
        { this.root = root != null ? root : throw new ArgumentNullException(nameof(root)); RefreshSources(); }

        // Appearance changes may add/remove fitted clothing; ordinary animation reuses the same entries.
        public void RefreshSources()
        {
            if (disposed || rendering) throw new InvalidOperationException("Cannot refresh this preview snapshot.");
            present.Clear();
            foreach (var source in root.GetComponentsInChildren<SkinnedMeshRenderer>(true))
            {
                present.Add(source);
                bool found = false;
                foreach (var entry in entries) if (entry.Source == source) { found = true; break; }
                if (found) continue;
                var proxy = new GameObject(source.name + "_PreviewPose") { hideFlags = HideFlags.HideAndDontSave };
                proxy.transform.SetParent(source.transform, false);
                var mesh = new Mesh { name = source.name + "_PreviewPose", hideFlags = HideFlags.HideAndDontSave };
                mesh.MarkDynamic();
                proxy.AddComponent<MeshFilter>().sharedMesh = mesh;
                var renderer = proxy.AddComponent<MeshRenderer>(); renderer.enabled = false;
                entries.Add(new Entry { Source = source, Mesh = mesh, Renderer = renderer });
            }
            for (int i = entries.Count - 1; i >= 0; i--)
                if (!present.Contains(entries[i].Source)) { Release(entries[i]); entries.RemoveAt(i); }
        }

        public void Render(Camera camera, UniversalRenderPipeline.SingleCameraRequest request)
        {
            if (disposed || rendering) throw new InvalidOperationException("Invalid/reentrant preview snapshot render.");
            rendering = true;
            try
            {
                foreach (var entry in entries)
                {
                    var source = entry.Source;
                    if (source == null || !source.enabled || !source.gameObject.activeInHierarchy || source.forceRenderingOff || source.sharedMesh == null) continue;
                    // BakeMesh reads current bones synchronously, including same-frame topology switches.
                    // Compensate the root/bone scale to keep vertices local to the renderer's child proxy.
                    if (entry.BakedSource != source.sharedMesh || entry.Mesh.vertexCount != source.sharedMesh.vertexCount)
                    { entry.Mesh.Clear(false); entry.BakedSource = source.sharedMesh; }
                    source.BakeMesh(entry.Mesh, true); entry.Mesh.RecalculateBounds();
                    var renderer = entry.Renderer;
                    for (int i = 0; i < entry.MaterialCount; i++) renderer.SetPropertyBlock(null, i);
                    var materials = source.sharedMaterials; renderer.sharedMaterials = materials; entry.MaterialCount = materials.Length;
                    block.Clear(); source.GetPropertyBlock(block); renderer.SetPropertyBlock(block);
                    for (int i = 0; i < materials.Length; i++)
                    { block.Clear(); source.GetPropertyBlock(block, i); renderer.SetPropertyBlock(block, i); }
                    renderer.gameObject.layer = source.gameObject.layer;
                    renderer.shadowCastingMode = source.shadowCastingMode; renderer.receiveShadows = source.receiveShadows;
                    source.forceRenderingOff = true; entry.Muted = true; renderer.enabled = true;
                }
                UrpCameraRendering.Render(camera, request);
            }
            finally
            {
                foreach (var entry in entries)
                {
                    if (entry.Renderer != null) entry.Renderer.enabled = false;
                    if (entry.Muted && entry.Source != null) entry.Source.forceRenderingOff = false;
                    entry.Muted = false;
                }
                rendering = false;
            }
        }

        public void Dispose()
        {
            if (disposed) return;
            if (rendering) throw new InvalidOperationException("Cannot dispose during a preview render.");
            foreach (var entry in entries) Release(entry);
            entries.Clear(); present.Clear(); disposed = true;
        }
        private static void Release(Entry entry)
        {
            if (entry.Renderer != null) { entry.Renderer.gameObject.SetActive(false); Destroy(entry.Renderer.gameObject); }
            Destroy(entry.Mesh);
        }
        private static void Destroy(Object value)
        { if (Application.isPlaying) Object.Destroy(value); else Object.DestroyImmediate(value); }
    }
}
