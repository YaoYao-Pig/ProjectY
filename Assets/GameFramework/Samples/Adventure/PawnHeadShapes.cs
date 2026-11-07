using System;
using ProjectY.Data;
using UnityEngine;

namespace ProjectY.Samples
{
    /// <summary>Deterministic face variation. Does not touch the game RNG or skeleton.</summary>
    public static class PawnHeadShapes
    {
        public static readonly string[] Names = { "jaw_width", "face_length", "nose_width", "nose_length", "cheek_depth", "ear_length" };
        public static float[] Weights(int seed, string id)
        {
            uint hash = 2166136261u;
            unchecked { foreach (char c in id) { hash ^= c; hash *= 16777619u; } }
            uint state = (uint)seed ^ hash; if (state == 0) state = 0x9e3779b9u;
            var weights = new float[Names.Length];
            for (int i = 0; i < weights.Length; i++)
            { state ^= state << 13; state ^= state >> 17; state ^= state << 5; weights[i] = (float)(((state / (double)uint.MaxValue) * 2 - 1) * .6); }
            return weights;
        }
        public static void Apply(SkinnedMeshRenderer renderer, PawnCustomizationData value)
        {
            var mesh = renderer.sharedMesh;
            if (mesh.blendShapeCount == 0) return;
            var values = Weights(value.seed, value.head);
            for (int i = 0; i < mesh.blendShapeCount; i++)
            {
                string name = mesh.GetBlendShapeName(i); int dot = name.LastIndexOf('.');
                if (dot >= 0) name = name.Substring(dot + 1);
                int index = Array.IndexOf(Names, name);
                renderer.SetBlendShapeWeight(i, index < 0 ? 0 : values[index] * 100);
            }
        }
    }
}
