using System;
using UnityEngine;
using UnityEngine.Rendering;
using Object = UnityEngine.Object;

namespace ProjectY.Samples
{
    // 地形高度决定云带海拔；这些透明云团不参与导航、碰撞或玩法状态。
    public sealed class MapCloudRenderer : IDisposable
    {
        private readonly Mesh mesh;
        public Material Material { get; }
        private MapPreviewData.Cloud[] clouds = Array.Empty<MapPreviewData.Cloud>();
        private readonly Matrix4x4[] matrices = new Matrix4x4[1023];
        private readonly Vector4[] parameters = new Vector4[1023];
        private readonly MaterialPropertyBlock properties = new MaterialPropertyBlock();
        private bool visible = true;

        public MapCloudRenderer()
        {
            var shader = Resources.Load<Shader>("MountainCloud");
            if (shader == null || !shader.isSupported) throw new InvalidOperationException("Mountain cloud shader is unavailable.");
            Material = new Material(shader) { name = "Mountain cloud bands", enableInstancing = true };
            mesh = new Mesh { name = "Mountain cloud billboard" };
            mesh.vertices = new[] { new Vector3(-.5f,-.5f,0), new Vector3(.5f,-.5f,0), new Vector3(.5f,.5f,0), new Vector3(-.5f,.5f,0) };
            mesh.uv = new[] { Vector2.zero, Vector2.right, Vector2.one, Vector2.up };
            mesh.triangles = new[] { 0, 1, 2, 0, 2, 3 }; mesh.RecalculateBounds();
        }
        public void Build(MapPreviewData map) { clouds = map.Clouds; }
        public void SetVisible(bool value) { visible = value; }
        public void Draw(Camera camera)
        {
            if (!visible || clouds.Length == 0) return;
            int count = 0;
            foreach (var cloud in clouds)
            {
                var drift = new Vector3(Mathf.Sin(Time.time * .04f + cloud.Phase), 0, Mathf.Cos(Time.time * .025f + cloud.Phase)) * cloud.Drift;
                matrices[count] = Matrix4x4.TRS(cloud.Position + drift, camera.transform.rotation, new Vector3(cloud.Width, cloud.Height, 1));
                parameters[count++] = new Vector4(cloud.Opacity, cloud.Phase, 0, 0);
                if (count == matrices.Length) { Submit(camera, count); count = 0; }
            }
            if (count > 0) Submit(camera, count);
        }
        private void Submit(Camera camera, int count)
        {
            properties.SetVectorArray("_CloudData", parameters);
            Graphics.DrawMeshInstanced(mesh, 0, Material, matrices, count, properties, ShadowCastingMode.Off, false, 0, camera, LightProbeUsage.Off);
        }
        public void Dispose() { Release(mesh); Release(Material); clouds = Array.Empty<MapPreviewData.Cloud>(); }
        private static void Release(Object value) { if (Application.isPlaying) Object.Destroy(value); else Object.DestroyImmediate(value); }
    }
}
