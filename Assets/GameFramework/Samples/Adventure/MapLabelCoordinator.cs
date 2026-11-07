using System;
using System.Collections.Generic;
using ProjectY.UI;
using UnityEngine;

namespace ProjectY.Samples
{
    /// <summary>One post-projection layout pass for all map names, mission badges and the player pin.</summary>
    internal sealed class MapLabelCoordinator : IDisposable
    {
        private sealed class Binding
        {
            public RectTransform Rect;
            public UIFollower Follower;
            public MapLabelLayout.Item Item;
            public bool Candidate, WasVisible;
            public Rect PreviousRect;
        }
        private readonly MainHudView hud;
        private readonly MapHudLayout style;
        private readonly Dictionary<MapLabelLayout.Item, Binding> bindings = new Dictionary<MapLabelLayout.Item, Binding>();
        private readonly List<MapLabelLayout.Item> items = new List<MapLabelLayout.Item>();
        private readonly List<Rect> obstacles = new List<Rect>();
        private readonly Vector3[] corners = new Vector3[4];
        private Camera camera;
        public int Revision { get; private set; }
        public MapLabelCoordinator(MainHudView owner)
        {
            hud = owner;
            style = (MapHudLayout)owner.GetComponent<LuaReference>().GetReference("MapHud").Get("Layout");
            hud.FollowersUpdated += Arrange;
        }
        public void Configure(Camera worldCamera) { camera = worldCamera; }
        public MapLabelLayout.Item Register(int id, RectTransform rect, UIFollower follower, int priority)
        {
            var item = new MapLabelLayout.Item { Id = id, Priority = priority };
            bindings.Add(item, new Binding { Rect = rect, Follower = follower, Item = item }); return item;
        }
        public void Unregister(MapLabelLayout.Item item) { bindings.Remove(item); Revision++; }
        private Rect ScreenRect(RectTransform rect, Camera uiCamera)
        {
            rect.GetWorldCorners(corners);
            var min = RectTransformUtility.WorldToScreenPoint(uiCamera, corners[0]); var max = min;
            for (int i = 1; i < 4; i++)
            {
                var point = RectTransformUtility.WorldToScreenPoint(uiCamera, corners[i]);
                min = Vector2.Min(min, point); max = Vector2.Max(max, point);
            }
            return new Rect(min, max - min);
        }
        private void Arrange()
        {
            if (camera == null) return;
            items.Clear(); obstacles.Clear();
            var canvas = hud.FollowerCanvas;
            var uiCamera = canvas.renderMode == RenderMode.ScreenSpaceOverlay ? null : canvas.worldCamera;
            AddObstacles(style.Obstacles(false), uiCamera);
            AddObstacles(style.Obstacles(true), uiCamera);
            foreach (var binding in bindings.Values)
            {
                binding.Candidate = binding.Rect.gameObject.activeInHierarchy && binding.Follower.ProjectedVisible;
                if (!binding.Candidate) { binding.Item.Visible = false; binding.Item.Rect = default(Rect); continue; }
                var rect = ScreenRect(binding.Rect, uiCamera);
                binding.Item.Anchor = rect.center; binding.Item.Size = rect.size; items.Add(binding.Item);
            }
            var viewport = camera.pixelRect;
            viewport.xMin += 6; viewport.xMax -= 6; viewport.yMin += 6; viewport.yMax -= 6;
            MapLabelLayout.Arrange(items, viewport, obstacles);
            bool changed = false;
            foreach (var binding in bindings.Values)
            {
                var item = binding.Item;
                if (binding.Candidate) binding.Follower.ApplyScreenLayout(item.Visible, item.Rect.center - item.Anchor);
                changed |= binding.WasVisible != item.Visible || binding.PreviousRect != item.Rect;
                binding.WasVisible = item.Visible; binding.PreviousRect = item.Rect;
            }
            if (changed) Revision++;
        }
        private void AddObstacles(MapHudLayout.Obstacle[] source, Camera uiCamera)
        {
            foreach (var obstacle in source)
                if (obstacle.Rect.gameObject.activeInHierarchy && obstacle.Group.alpha > .1f)
                    obstacles.Add(ScreenRect(obstacle.Rect, uiCamera));
        }
        public void Dispose() { hud.FollowersUpdated -= Arrange; bindings.Clear(); items.Clear(); }
    }
}
