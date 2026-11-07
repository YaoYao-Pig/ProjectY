using System;
using UnityEngine;
using ProjectY.Data;

namespace ProjectY.Samples
{
    /// <summary>Fits authored wearables in the shared bind pose. Rigid weapons never enter this path.</summary>
    public static class PawnEquipmentAutoFit
    {
        public const float Clearance = .012f;
        static bool Torso(string name) => name == "pelvis" || name.StartsWith("spine_", StringComparison.Ordinal);
        static int MainBone(BoneWeight w)
        {
            int bone = w.boneIndex0; float max = w.weight0;
            if (w.weight1 > max) { bone = w.boneIndex1; max = w.weight1; }
            if (w.weight2 > max) { bone = w.boneIndex2; max = w.weight2; }
            if (w.weight3 > max) bone = w.boneIndex3;
            return bone;
        }
        static Bounds Envelope(Vector3[] points, Func<int, bool> include)
        {
            bool found = false; Bounds bounds = default;
            for (int i = 0; i < points.Length; i++) if (include(i))
            { if (found) bounds.Encapsulate(points[i]); else { bounds = new Bounds(points[i], Vector3.zero); found = true; } }
            if (!found) throw new InvalidOperationException("Auto-fit envelope has no vertices.");
            return bounds;
        }
        static float Ratio(float desired, float current) => Mathf.Clamp(desired / Mathf.Max(.001f, current), .70f, 1.35f);

        public static Mesh Create(PawnCustomizationCatalog catalog, PawnCustomizationCatalog.GearFit fit, PawnCustomizationData value)
        {
            if (fit == null || fit.Part == null || fit.Part.Mesh == null) throw new ArgumentException("Missing authored equipment fit.");
            var original = fit.Part.Mesh; var vertices = original.vertices; var source = (Vector3[])vertices.Clone();
            var body = catalog.GetPart(value.body).Mesh; var bodyVertices = body.vertices; var bodyWeights = body.boneWeights;
            if (fit.Slot == "head")
            {
                var head = catalog.GetPart(value.head).Mesh.vertices;
                // Crown only: nose, ears, horns and facial shape changes must not inflate a helmet.
                var crown = Envelope(head, i => head[i].y >= 1.66f && head[i].y <= 1.78f && Mathf.Abs(head[i].x) <= .205f && Mathf.Abs(head[i].z) <= .21f);
                float ringY = fit.Part.Id.Contains("magehat") ? 1.765f : 1.678f;
                var ring = Envelope(source, i => Mathf.Abs(source[i].y - ringY) < .025f);
                float sx = Ratio(crown.size.x + Clearance * 2, ring.size.x);
                float sz = Ratio(crown.size.z + Clearance * 2, ring.size.z);
                for (int i = 0; i < vertices.Length; i++)
                {
                    var p = source[i];
                    // Preserve the long crown/decoration height, move only its supporting cross-section.
                    p.x = crown.center.x + (p.x - ring.center.x) * sx;
                    p.z = crown.center.z + (p.z - ring.center.z) * sz;
                    vertices[i] = p;
                }
            }
            else if (fit.Slot == "chest")
            {
                var gearWeights = original.boneWeights;
                float[] levels = { .82f, .94f, 1.08f, 1.23f, 1.30f };
                var bodyBands = new Bounds[levels.Length]; var gearBands = new Bounds[levels.Length];
                for (int band = 0; band < levels.Length; band++)
                {
                    float y = levels[band];
                    bodyBands[band] = Envelope(bodyVertices, i => Torso(catalog.BoneNames[MainBone(bodyWeights[i])]) && Mathf.Abs(bodyVertices[i].y - y) < .105f);
                    gearBands[band] = Envelope(source, i => Torso(catalog.BoneNames[MainBone(gearWeights[i])]) && Mathf.Abs(source[i].y - y) < .105f);
                }
                for (int i = 0; i < vertices.Length; i++)
                {
                    if (!Torso(catalog.BoneNames[MainBone(gearWeights[i])]) || source[i].y < .78f || source[i].y > 1.32f) continue;
                    int a = 0; while (a + 1 < levels.Length - 1 && source[i].y > levels[a + 1]) a++;
                    int b = Math.Min(a + 1, levels.Length - 1); float t = Mathf.InverseLerp(levels[a], levels[b], source[i].y);
                    var targetCenter = Vector3.Lerp(bodyBands[a].center, bodyBands[b].center, t);
                    var gearCenter = Vector3.Lerp(gearBands[a].center, gearBands[b].center, t);
                    var targetSize = Vector3.Lerp(bodyBands[a].size, bodyBands[b].size, t);
                    var gearSize = Vector3.Lerp(gearBands[a].size, gearBands[b].size, t);
                    var p = source[i]; p.x = targetCenter.x + (p.x - gearCenter.x) * Ratio(targetSize.x + Clearance * 2, gearSize.x);
                    p.z = targetCenter.z + (p.z - gearCenter.z) * Ratio(targetSize.z + Clearance * 2, gearSize.z); vertices[i] = p;
                }
            }
            else if (fit.Slot == "back")
            {
                var torso = Envelope(bodyVertices, i => Torso(catalog.BoneNames[MainBone(bodyWeights[i])]) && bodyVertices[i].y > .9f);
                var back = Envelope(source, i => true); float offset = torso.min.z - Clearance - back.max.z;
                offset = Mathf.Clamp(offset, -.12f, .12f);
                for (int i = 0; i < vertices.Length; i++) vertices[i].z += offset;
            }
            else if (fit.Slot == "legs" || fit.Slot == "feet")
            {
                // Authored leg/boot fits preserve length and design; only expand an intersecting radial envelope.
                var weights = original.boneWeights; var binds = original.bindposes;
                for (int bone = 0; bone < catalog.BoneNames.Length; bone++)
                {
                    string name = catalog.BoneNames[bone];
                    if (!(name.StartsWith("thigh_") || name.StartsWith("calf_") || name.StartsWith("foot_") || name.StartsWith("ball_"))) continue;
                    int current = bone; bool any = Array.Exists(weights, w => MainBone(w) == current);
                    if (!any) continue;
                    var bodyLocal = Array.ConvertAll(bodyVertices, p => binds[current].MultiplyPoint3x4(p));
                    var gearLocal = Array.ConvertAll(source, p => binds[current].MultiplyPoint3x4(p));
                    var bb = Envelope(bodyLocal, i => MainBone(bodyWeights[i]) == current); var gb = Envelope(gearLocal, i => MainBone(weights[i]) == current);
                    float sx = Mathf.Clamp((bb.size.x + .008f) / Mathf.Max(gb.size.x, .001f), 1, 1.2f), sz = Mathf.Clamp((bb.size.z + .008f) / Mathf.Max(gb.size.z, .001f), 1, 1.2f);
                    var inverse = binds[current].inverse;
                    for (int i = 0; i < vertices.Length; i++) if (MainBone(weights[i]) == current)
                    { var p = gearLocal[i]; p.x = gb.center.x + (p.x - gb.center.x) * sx; p.z = gb.center.z + (p.z - gb.center.z) * sz; vertices[i] = inverse.MultiplyPoint3x4(p); }
                }
            }
            else throw new InvalidOperationException("Unsupported auto-fit wearable slot: " + fit.Slot);
            float changed = 0; for (int i = 0; i < vertices.Length; i++) changed = Mathf.Max(changed, (vertices[i] - source[i]).sqrMagnitude);
            if (changed < 1e-12f) return original;
            var mesh = UnityEngine.Object.Instantiate(original); mesh.name = original.name + "_autofit";
            mesh.vertices = vertices; mesh.RecalculateNormals(); mesh.RecalculateBounds(); return mesh;
        }
    }

}
