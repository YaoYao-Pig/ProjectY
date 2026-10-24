using System;
using UnityEngine;

namespace ProjectY.Samples
{
    /// <summary>Camera presentation policy. Distances use map radii, never gameplay simulation ranges.</summary>
    public static class MapRenderLod
    {
        public enum Tier { Hidden, Near, Medium, Far }
        [Serializable]
        public sealed class Settings
        {
            [Min(1)] public float nearDistance = 40;
            [Min(2)] public float detailDistance = 100;
            [Min(0)] public float frustumMargin = 3;
            [Min(0)] public float distanceHysteresis = 4;
            [Range(1, 16)] public int mediumDecorationStride = 4;
            [Range(1, 16)] public int creationsPerFrame = 2;
            [Range(1, 64)] public int activationsPerFrame = 8;
            [Min(1)] public int maximumDetailedObjects = 96;
            public void Validate()
            {
                if (nearDistance <= 0 || detailDistance <= nearDistance || frustumMargin < 0 || distanceHysteresis < 0 ||
                    distanceHysteresis >= nearDistance || mediumDecorationStride < 1 || creationsPerFrame < 1 || activationsPerFrame < 1 || maximumDetailedObjects < 1)
                    throw new InvalidOperationException("Invalid world-map rendering LOD settings.");
            }
        }

        public sealed class View
        {
            private readonly Plane[] planes = new Plane[6];
            private Vector3 origin;
            private float screenScale, near, detail, hysteresis;
            private bool orthographic;
            public void Update(Camera camera, float groundHeight, float radius, Settings settings)
            {
                if (camera == null || radius <= 0) throw new ArgumentException("LOD needs a camera and positive map radius.");
                settings.Validate();
                GeometryUtility.CalculateFrustumPlanes(camera, planes);
                for (var i = 0; i < planes.Length; i++)
                { var plane = planes[i]; plane.distance += settings.frustumMargin * radius; planes[i] = plane; }
                orthographic = camera.orthographic;
                origin = camera.transform.position;
                if (orthographic)
                {
                    // The orthographic map camera is deliberately far behind the map bounds.
                    // Detail follows its ground footprint and zoom, not that artificial camera offset.
                    var ray = camera.ViewportPointToRay(new Vector3(.5f, .5f, 0));
                    if (Mathf.Abs(ray.direction.y) > .0001f)
                        origin = ray.GetPoint((groundHeight - ray.origin.y) / ray.direction.y);
                    origin.y = groundHeight;
                }
                screenScale = orthographic ? camera.orthographicSize : 0;
                near = settings.nearDistance * radius; detail = settings.detailDistance * radius;
                hysteresis = settings.distanceHysteresis * radius;
            }
            public bool Visible(Bounds bounds) => GeometryUtility.TestPlanesAABB(planes, bounds);
            public float Distance(Bounds bounds)
            {
                if (orthographic)
                {
                    var center = bounds.center; center.y = origin.y;
                    var size = bounds.size; size.y = 0; bounds = new Bounds(center, size);
                }
                return Mathf.Max(screenScale, Mathf.Sqrt(bounds.SqrDistance(origin)));
            }
            public Tier Classify(Bounds bounds, Tier previous = Tier.Hidden)
                => Visible(bounds) ? ClassifyDistance(Distance(bounds), near, detail, hysteresis, previous) : Tier.Hidden;
        }

        public static Tier ClassifyDistance(float distance, float near, float detail, float hysteresis, Tier previous)
        {
            var nearLimit = near + (previous == Tier.Near ? hysteresis : previous == Tier.Hidden ? 0 : -hysteresis);
            var detailLimit = detail + (previous == Tier.Medium ? hysteresis : previous == Tier.Far ? -hysteresis : 0);
            if (distance <= nearLimit) return Tier.Near;
            return distance <= detailLimit ? Tier.Medium : Tier.Far;
        }
        public static Bounds TransformBounds(Bounds local, Matrix4x4 matrix)
        {
            var x = matrix.MultiplyVector(new Vector3(local.extents.x, 0, 0));
            var y = matrix.MultiplyVector(new Vector3(0, local.extents.y, 0));
            var z = matrix.MultiplyVector(new Vector3(0, 0, local.extents.z));
            var extent = new Vector3(Mathf.Abs(x.x) + Mathf.Abs(y.x) + Mathf.Abs(z.x),
                Mathf.Abs(x.y) + Mathf.Abs(y.y) + Mathf.Abs(z.y), Mathf.Abs(x.z) + Mathf.Abs(y.z) + Mathf.Abs(z.z));
            return new Bounds(matrix.MultiplyPoint3x4(local.center), extent * 2);
        }
    }
}
