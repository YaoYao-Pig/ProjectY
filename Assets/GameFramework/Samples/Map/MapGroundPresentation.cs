using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using Object = UnityEngine.Object;

namespace ProjectY.Samples
{
    // 大地图专用材质；源纹理共享，Texture2DArray/Material 由观察器拥有。
    public sealed class MapGroundPresentation : IDisposable
    {
        private readonly Dictionary<int, int> layers = new Dictionary<int, int>();
        private Texture2DArray textures;
        public Material Material { get; }

        public MapGroundPresentation()
        {
            if (!SystemInfo.supports2DArrayTextures || SystemInfo.copyTextureSupport == CopyTextureSupport.None)
                throw new NotSupportedException("地图地表需要纹理数组和 GPU 纹理复制。");
            var shader = Resources.Load<Shader>("MapGround");
            if (shader == null || !shader.isSupported) throw new InvalidOperationException("地图地表 Shader 缺失或不受支持。");
            Material = new Material(shader) { name = "地图_自然地表", enableInstancing = true };
        }

        public void Build(MapPreviewData map)
        {
            if (map.Surfaces == null || map.Surfaces.Length == 0 || map.Surfaces.Length > 15)
                throw new InvalidOperationException("地图地表配方必须包含 1～15 个地貌。");
            layers.Clear();
            var sources = new Texture2D[map.Surfaces.Length + 1];
            var parameters = new Vector4[16]; var tints = new Vector4[16];
            for (var i = 0; i < map.Surfaces.Length; i++)
            {
                var surface = map.Surfaces[i];
                if (surface.TextureWorldSize <= 0 || surface.TextureStrength < 0 || surface.TextureStrength > 1 || surface.WindStrength < 0)
                    throw new InvalidOperationException("地图地表配方数值无效: " + surface.Id);
                layers.Add(surface.Id, i);
                sources[i] = LoadTexture(surface.GroundTexture);
                parameters[i] = new Vector4(surface.TextureWorldSize, surface.TextureStrength, surface.WindStrength, surface.CliffTintStrength);
                tints[i] = Linear(surface.Color);
            }
            // 垂直崖面使用独立的岩土层，不把草叶或落叶贴到柱体侧面。
            var cliff = map.Surfaces.Length;
            sources[cliff] = LoadTexture("MapGround/Rock");
            parameters[cliff] = new Vector4(4.8f, .7f, 0, 0);
            tints[cliff] = Linear(new Color32(158, 150, 133, 255));
            Release(textures);
            textures = new Texture2DArray(sources[0].width, sources[0].height, sources.Length, TextureFormat.RGBA32, true, false) {
                name = "地图_地貌贴图数组", wrapMode = TextureWrapMode.Repeat, filterMode = FilterMode.Trilinear, anisoLevel = 4
            };
            // 先上传一次初始化存储，再以 GPU 复制各层；不要求源 PNG 开启 Read/Write。
            textures.Apply(false, true);
            for (var layer = 0; layer < sources.Length; layer++)
            {
                var source = sources[layer];
                if (source.width != textures.width || source.height != textures.height || source.mipmapCount != textures.mipmapCount)
                    throw new InvalidOperationException("地图贴图尺寸和 mip 数量必须一致: " + source.name);
                for (var mip = 0; mip < source.mipmapCount; mip++) Graphics.CopyTexture(source, 0, mip, textures, layer, mip);
            }
            Material.SetTexture("_GroundTextures", textures);
            Material.SetVectorArray("_LayerData", parameters); Material.SetVectorArray("_LayerTint", tints);
            Material.SetFloat("_TileRadius", map.Radius); Material.SetFloat("_CliffLayer", cliff);
        }

        public Vector4 GetData(MapPreviewData.Cell cell)
        {
            if (!layers.TryGetValue(cell.SurfaceA, out var first) || !layers.TryGetValue(cell.SurfaceB, out var second))
                throw new InvalidOperationException("地格引用未知的地表配方。");
            return new Vector4(first, second, cell.SurfaceBlend, cell.HasWater ? 0 : 1);
        }

        private static Texture2D LoadTexture(string key)
        {
            var texture = Resources.Load<Texture2D>(key);
            if (texture == null) throw new InvalidOperationException("地图地表贴图缺失: " + key);
            if (texture.format != TextureFormat.RGBA32 || texture.width != 512 || texture.height != 512 || texture.mipmapCount < 2)
                throw new InvalidOperationException("地图地表贴图须导入为 512×512 RGBA32 并开启 mipmaps: " + key);
            return texture;
        }

        private static Color Linear(Color color) { return QualitySettings.activeColorSpace == ColorSpace.Linear ? color.linear : color; }

        public void Dispose() { Release(textures); Release(Material); layers.Clear(); }
        private static void Release(Object value)
        {
            if (value == null) return;
            if (Application.isPlaying) Object.Destroy(value); else Object.DestroyImmediate(value);
        }
    }
}
