using ProjectY.Data;
using System;
using System.Collections.Generic;
using UnityEngine;

namespace ProjectY.Samples
{
    [CreateAssetMenu(menuName = "Project Y/Pawn Customization Catalog")]
    public sealed class PawnCustomizationCatalog : ScriptableObject
    {
        [Serializable] public sealed class Part { public string Id; public Mesh Mesh; public Material[] Materials; public string[] Roles; }
        [Serializable] public sealed class GearFit { public string SourcePath, Body, Race, Slot; public int Coverage; public bool HideHair; public Part Part; }
        [Serializable] public sealed class CoveredBody { public string Body; public int Mask; public Mesh Mesh; }
        [Serializable] public sealed class BodyDefault { public int BodyPartId; public PawnCustomizationData Appearance; }
        public PawnCustomizationRules Rules;
        public string[] BoneNames;
        public Part[] Parts;
        public GearFit[] GearFits = Array.Empty<GearFit>();
        public CoveredBody[] CoveredBodies = Array.Empty<CoveredBody>();
        public BodyDefault[] BodyDefaults = Array.Empty<BodyDefault>();
        public PawnCustomizationData DefaultAppearance(int bodyPartId) =>
            (Array.Find(BodyDefaults, value => value.BodyPartId == bodyPartId) ??
             throw new InvalidOperationException("Missing default character appearance for body: " + bodyPartId)).Appearance;
        public Part GetPart(string id) => Array.Find(Parts, p => p.Id == id) ?? throw new InvalidOperationException("Missing customization mesh: " + id);
        public GearFit Fit(string path, PawnCustomizationData value) => Array.Find(GearFits, p => p.SourcePath == path &&
            (p.Body == "" || p.Body == value.body) && (p.Race == "" || p.Race == value.race)) ?? throw new InvalidOperationException("Missing equipment fit: " + path + " / " + value.body + " / " + value.race);
        public Mesh BodyMesh(string body, int mask) => mask == 0 ? GetPart(body).Mesh :
            (Array.Find(CoveredBodies, p => p.Body == body && p.Mask == mask) ?? throw new InvalidOperationException("Missing covered body: " + body + "/" + mask)).Mesh;
        public static bool NeedsFit(string mount) => mount == "head" || mount == "chest" || mount == "legs" || mount == "feet" || mount == "back";
    }
}
