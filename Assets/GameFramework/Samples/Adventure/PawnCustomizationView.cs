using ProjectY.Data;
using System;
using UnityEngine;

namespace ProjectY.Samples
{
    /// <summary>Shared by player, enemies and the preview. Owns visuals, never randomizes actor state.</summary>
    public sealed class PawnCustomizationView : MonoBehaviour
    {
        [SerializeField] private PawnCustomizationCatalog catalog;
        [SerializeField] private Transform[] bones;
        [SerializeField] private SkinnedMeshRenderer original;
        [SerializeField] private SkinnedMeshRenderer[] modules;
        private PawnCustomizationData applied;
        private int coverage;
        private bool hairCovered;
        private MaterialPropertyBlock block;
        public PawnCustomizationCatalog Catalog => catalog;
        public Transform[] Bones => bones;
        public SkinnedMeshRenderer[] Modules => modules;
        public int Revision { get; private set; }
        public PawnCustomizationData Current => applied;
        private static bool Same(PawnCustomizationData a, PawnCustomizationData b) => a != null && b != null && a.version == b.version && a.seed == b.seed &&
            a.race == b.race && a.sex == b.sex && a.body == b.body && a.head == b.head && a.hair == b.hair && a.skin == b.skin && a.hairColor == b.hairColor && a.clothColor == b.clothColor;
        public void Apply(PawnCustomizationData value, int covered = 0, bool coverHair = false)
        {
            if (value == null)
            {
                original.enabled = true;
                foreach (var renderer in modules) renderer.enabled = false;
                if (applied != null) Revision++;
                applied = null; coverage = 0; hairCovered = false; return;
            }
            catalog.Rules.Validate(value);
            if (Same(value, applied) && coverage == covered && hairCovered == coverHair) return;
            var ids = new[] { value.body, value.head, coverHair ? "none" : value.hair };
            var parts = new PawnCustomizationCatalog.Part[3];
            for (int i = 0; i < parts.Length; i++) if (ids[i] != "none") parts[i] = catalog.GetPart(ids[i]);
            if (block == null) block = new MaterialPropertyBlock();
            for (int i = 0; i < modules.Length; i++)
            {
                var renderer = modules[i]; var part = parts[i];
                // Clear per-index overrides before a mesh with a different material layout is assigned.
                for (int m = 0; m < renderer.sharedMaterials.Length; m++) renderer.SetPropertyBlock(null, m);
                renderer.enabled = part != null;
                if (part == null) continue;
                renderer.sharedMesh = i == 0 ? catalog.BodyMesh(value.body, covered) : part.Mesh; renderer.sharedMaterials = part.Materials;
                for (int m = 0; m < part.Materials.Length; m++)
                {
                    block.Clear(); block.SetColor("_Color", catalog.Rules.Tint(part.Roles[m], value, part.Materials[m].color));
                    renderer.SetPropertyBlock(block, m);
                }
            }
            original.enabled = false; applied = value.Copy(); coverage = covered; hairCovered = coverHair; Revision++;
        }
        public GameObject CreateFit(string path)
        {
            if (applied == null) throw new InvalidOperationException("A fitted wearable requires a character appearance.");
            var fit = catalog.Fit(path, applied); var obj = new GameObject(fit.Part.Id); obj.transform.SetParent(transform, false);
            var renderer = obj.AddComponent<SkinnedMeshRenderer>(); renderer.bones = bones; renderer.rootBone = bones[0];
            renderer.sharedMesh = fit.Part.Mesh; renderer.sharedMaterials = fit.Part.Materials; renderer.localBounds = fit.Part.Mesh.bounds; renderer.updateWhenOffscreen = true;
            return obj;
        }
#if UNITY_EDITOR
        public void Bind(PawnCustomizationCatalog source, Transform[] targets, SkinnedMeshRenderer baseline)
        {
            catalog = source; bones = targets; original = baseline;
            if (bones.Length != catalog.BoneNames.Length) throw new InvalidOperationException("Wrong customization skeleton.");
            for (int i = 0; i < bones.Length; i++) if (bones[i].name != catalog.BoneNames[i]) throw new InvalidOperationException("Bone mapping mismatch.");
            modules = new SkinnedMeshRenderer[3];
            for (int i = 0; i < modules.Length; i++)
            {
                var child = new GameObject("Customization_" + new[] { "body", "head", "hair" }[i]);
                child.transform.SetParent(transform, false);
                var renderer = child.AddComponent<SkinnedMeshRenderer>();
                renderer.bones = bones; renderer.rootBone = bones[0]; renderer.updateWhenOffscreen = true;
                renderer.localBounds = new Bounds(new Vector3(0, .95f, 0), new Vector3(3, 3, 3));
                renderer.enabled = false; modules[i] = renderer;
            }
        }
#endif
    }
}
