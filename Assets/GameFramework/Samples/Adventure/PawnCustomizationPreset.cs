using ProjectY.Data;
using UnityEngine;

namespace ProjectY.Samples
{
    /// <summary>A serialized preview preset. Gameplay supplies the same descriptor through PawnAppearanceData.</summary>
    [ExecuteAlways, RequireComponent(typeof(PawnView))]
    public sealed class PawnCustomizationPreset : MonoBehaviour
    {
        public PawnCustomizationData Appearance;
        public PawnCustomizationView View;
        private void OnEnable()
        {
            // AddComponent runs once before the importer assigns either serialized field.
            if (!Application.isPlaying && View == null && Appearance == null) return;
            View.Apply(Appearance);
        }
    }
}
