using System;
using System.Collections.Generic;
using ProjectY.UI;
using UnityEngine;
using UnityEngine.UI;
using Object = UnityEngine.Object;

namespace ProjectY.Samples
{
    internal sealed class WorldSiteView : IDisposable
    {
        private sealed class Tag
        {
            public AdventureViewData.Site Site;
            public RectTransform Rect;
            public Text Label;
            public Image Background;
            public UIFollower Follower;
            public int[] Cells;
            public int Revision;
            public Camera BoundCamera;
            public Vector3 FollowPoint;
        }
        private readonly MainHudView hud;
        private readonly MapPreviewRenderer renderer;
        private readonly MapPreviewData map;
        private readonly WorldSiteLayout layout;
        private readonly LuaReference root, template;
        private readonly SceneFocusMask mask;
        private readonly Dictionary<int, Tag> tags = new Dictionary<int, Tag>();
        private readonly Dictionary<int, Tag> sitesByCell = new Dictionary<int, Tag>();
        private readonly List<int> retired = new List<int>();
        private int hovered, revision;
        private bool farView;
        private AdventureViewData.Site[] lastSites;
        private bool pickDirty = true;
        private Vector2 pickMouse;
        private Matrix4x4 pickView, pickProjection;
        private Rect pickViewport;
        private AdventureViewData.Site pickedSite;
        internal WorldSiteView(MainHudView owner, MapPreviewData data, MapPreviewRenderer mapRenderer)
        {
            hud = owner; map = data; renderer = mapRenderer; layout = new WorldSiteLayout(map);
            var prefab = Resources.Load<LuaReference>("UI/WorldSiteOverlay");
            if (prefab == null) throw new InvalidOperationException("WorldSiteOverlay prefab is missing; synchronize world-site UI assets.");
            root = Object.Instantiate(prefab, hud.PresentationRoot, false); root.transform.SetAsFirstSibling();
            template = root.GetReference("TagTemplate"); template.gameObject.SetActive(false);
            mask = SceneFocusMask.Create((RectTransform)root.transform);
        }
        internal void Sync(AdventureViewData.Site[] sites)
        {
            if (ReferenceEquals(lastSites, sites)) return;
            lastSites = sites; pickDirty = true;
            revision++; var changed = false;
            foreach (var site in sites)
            {
                if (!tags.TryGetValue(site.Id, out var tag))
                {
                    var reference = Object.Instantiate(template, root.transform, false);
                    tag = new Tag { Rect = (RectTransform)reference.Get("Root"), Label = reference.GetText("Label"),
                        Background = reference.GetImage("Background"), Follower = (UIFollower)reference.Get("Follower"), Cells = layout.Footprint(site) };
                    tag.Label.font = hud.Font; tags.Add(site.Id, tag); changed = true;
                }
                if (tag.Site == null || tag.Site.Name != site.Name)
                {
                    tag.Label.text = site.Name;
                    tag.Rect.sizeDelta = new Vector2(Mathf.Clamp(tag.Label.preferredWidth + 30, 90, 390), 34);
                }
                tag.Site = site; tag.Revision = revision;
            }
            retired.Clear();
            foreach (var entry in tags) if (entry.Value.Revision != revision) retired.Add(entry.Key);
            foreach (var id in retired) { var tag = tags[id]; hud.Untrack(tag.Follower); Release(tag.Rect.gameObject); tags.Remove(id); changed = true; }
            if (!changed) return;
            sitesByCell.Clear();
            // Point events remain selectable when they share a town's territory.
            foreach (var tag in tags.Values) if (tag.Site.WorldTownId > 0) foreach (var cell in tag.Cells) sitesByCell[cell] = tag;
            foreach (var tag in tags.Values) if (tag.Site.WorldTownId == 0) foreach (var cell in tag.Cells) sitesByCell[cell] = tag;
        }
        internal AdventureViewData.Site Pick(Camera camera, Vector2 mouse)
        {
            if (!camera.pixelRect.Contains(mouse)) return null;
            var view = camera.worldToCameraMatrix; var projection = camera.projectionMatrix; var viewport = camera.pixelRect;
            if (!pickDirty && mouse == pickMouse && view == pickView && projection == pickProjection && viewport == pickViewport &&
                (hovered == 0 || renderer.FocusAmount >= 1)) return pickedSite;
            pickedSite = PickUncached(camera, mouse);
            pickDirty = false; pickMouse = mouse; pickView = view; pickProjection = projection; pickViewport = viewport;
            return pickedSite;
        }
        private AdventureViewData.Site PickUncached(Camera camera, Vector2 mouse)
        {
            Tag label = null; var nearest = float.PositiveInfinity;
            foreach (var tag in tags.Values)
            {
                if (!tag.Rect.gameObject.activeInHierarchy || !tag.Follower.ProjectedVisible ||
                    !RectTransformUtility.RectangleContainsScreenPoint(tag.Rect, mouse)) continue;
                if (tag.Follower.Depth < nearest) { label = tag; nearest = tag.Follower.Depth; }
            }
            if (label != null) return label.Site;
            var ray = camera.ScreenPointToRay(mouse); var cell = layout.Pick(ray, out var distance);
            if (renderer.PickBuilding(ray, out var buildingCell, out var buildingDistance) && buildingDistance < distance) cell = buildingCell;
            return sitesByCell.TryGetValue(cell, out var site) ? site.Site : null;
        }
        internal void Tick(Camera camera, bool pointerEnabled, Vector2 mouse, float deltaTime)
        {
            root.gameObject.SetActive(true);
            // Hysteresis prevents labels flickering at the zoom boundary.
            var showFar = camera.orthographicSize >= map.Radius * (farView ? 56 : 64);
            if (farView != showFar) { farView = showFar; pickDirty = true; }
            var site = pointerEnabled ? Pick(camera, mouse) : null; var id = site == null ? 0 : site.Id;
            if (id != hovered) { hovered = id; renderer.SetFocus(id == 0 ? null : tags[id].Cells); }
            renderer.TickFocus(deltaTime);
            if (hovered == 0) mask.Hide(); else renderer.RenderFocusMask(camera, mask);
            foreach (var tag in tags.Values)
            {
                var selected = tag.Site.Id == hovered;
                var visible = farView || selected;
                if (tag.Rect.gameObject.activeSelf != visible) { tag.Rect.gameObject.SetActive(visible); pickDirty = true; }
                if (!tag.Rect.gameObject.activeSelf) continue;
                tag.Background.color = selected ? new Color(.22f, .17f, .08f, .97f) : new Color(.055f, .075f, .085f, .92f);
                tag.Label.color = selected ? new Color(1, .88f, .59f) : tag.Site.Available ? new Color(.95f, .93f, .84f) : new Color(.66f, .69f, .69f);
                var point = tag.Site.Position + Vector3.up * (selected ? renderer.FocusLift : 0);
                if (tag.BoundCamera != camera || tag.FollowPoint != point)
                { hud.TrackPoint(tag.Follower, camera, point); tag.BoundCamera = camera; tag.FollowPoint = point; pickDirty = true; }
            }
        }
        internal void Hide()
        {
            if (hovered != 0) { hovered = 0; renderer.SetFocus(null); }
            if (root != null) root.gameObject.SetActive(false); mask.Hide();
        }
        public void Dispose()
        {
            Hide(); foreach (var tag in tags.Values) if (hud != null && tag.Follower != null) hud.Untrack(tag.Follower);
            mask.Dispose(); if (root != null) Release(root.gameObject);
        }
        private static void Release(Object value)
        { if (Application.isPlaying) Object.Destroy(value); else Object.DestroyImmediate(value); }
    }
}
