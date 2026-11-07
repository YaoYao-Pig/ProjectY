using UnityEngine;
namespace ProjectY.Samples
{
    /// <summary>The fitted instance owns its mesh; replacing equipment cannot retain dead mesh copies.</summary>
    [ExecuteAlways]
    public sealed class PawnAutoFitMeshOwner : MonoBehaviour
    {
        public Mesh OwnedMesh { get; set; }
        public void Release()
        {
            if (OwnedMesh == null) return;
            if (Application.isPlaying) Destroy(OwnedMesh); else DestroyImmediate(OwnedMesh);
            OwnedMesh = null;
        }
        private void OnDestroy() { Release(); }
    }
}
