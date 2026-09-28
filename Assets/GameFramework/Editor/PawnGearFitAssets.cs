using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using ProjectY.Samples;
using UnityEditor;
using UnityEngine;

namespace ProjectY.Editor
{
    public static class PawnGearFitAssets
    {
        [Serializable] private sealed class Definition { public string id, sourcePath, slot, body, race; public int coverage; public bool hideHair; }
        [Serializable] private sealed class Definitions { public int version; public Definition[] fits; }
        public static void Build(PawnCustomizationCatalog catalog, GameObject original)
        {
            const string path = PawnCustomizationAssets.Folder + "/PawnGearFits.fbx";
            var source = AssetDatabase.LoadAssetAtPath<GameObject>(path);
            if (source == null) throw new FileNotFoundException("Import PawnGearFits.fbx before syncing character resources.");
            var definitions = JsonUtility.FromJson<Definitions>(File.ReadAllText("Art/PawnCustomization/Integration/gear-manifest.json"));
            if (definitions.version != 1) throw new InvalidOperationException("Unsupported gear fit manifest.");
            var fits = new List<PawnCustomizationCatalog.GearFit>();
            foreach (var row in definitions.fits)
            {
                var renderer = Array.Find(source.GetComponentsInChildren<SkinnedMeshRenderer>(true), s => s.name == row.id + "_export");
                if (renderer == null) throw new InvalidOperationException("Missing authored gear mesh: " + row.id);
                fits.Add(new PawnCustomizationCatalog.GearFit { SourcePath = row.sourcePath, Body = row.body, Race = row.race, Slot = row.slot,
                    Coverage = row.coverage, HideHair = row.hideHair, Part = PawnCustomizationAssets.ImportPart(source, renderer, original, row.id) });
            }
            catalog.GearFits = fits.ToArray();
            var covered = new List<PawnCustomizationCatalog.CoveredBody>();
            foreach (var body in catalog.Parts.Where(p => p.Id.StartsWith("body_")))
            {
                var vertices = body.Mesh.vertices;
                for (int mask = 1; mask < 8; mask++)
                {
                    var mesh = UnityEngine.Object.Instantiate(body.Mesh); mesh.name = body.Id + "_covered_" + mask;
                    for (int sub = 0; sub < mesh.subMeshCount; sub++)
                    {
                        var triangles = mesh.GetTriangles(sub); var visible = new List<int>();
                        for (int i = 0; i < triangles.Length; i += 3)
                        {
                            var center = (vertices[triangles[i]] + vertices[triangles[i + 1]] + vertices[triangles[i + 2]]) / 3;
                            bool hide = ((mask & 1) != 0 && body.Roles[sub] == "Cloth" && center.y >= .80f) ||
                                ((mask & 2) != 0 && body.Roles[sub] == "Cloth" && center.y < .80f) ||
                                ((mask & 4) != 0 && body.Roles[sub] == "Leather" && center.y < .40f);
                            if (!hide) { visible.Add(triangles[i]); visible.Add(triangles[i + 1]); visible.Add(triangles[i + 2]); }
                        }
                        mesh.SetTriangles(visible, sub);
                    }
                    string target = PawnCustomizationAssets.Folder + "/Meshes/" + mesh.name + ".asset";
                    var existing = AssetDatabase.LoadAssetAtPath<Mesh>(target);
                    if (existing == null) AssetDatabase.CreateAsset(mesh, target);
                    else { EditorUtility.CopySerialized(mesh, existing); UnityEngine.Object.DestroyImmediate(mesh); EditorUtility.SetDirty(existing); }
                    covered.Add(new PawnCustomizationCatalog.CoveredBody { Body = body.Id, Mask = mask, Mesh = AssetDatabase.LoadAssetAtPath<Mesh>(target) });
                }
            }
            catalog.CoveredBodies = covered.ToArray(); EditorUtility.SetDirty(catalog);
        }
    }
}
