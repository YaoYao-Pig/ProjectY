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
            public MapLabelLayout.Item Placement;
            public bool Expanded;
            public string Caption;
        }
        private readonly MainHudView hud;
        private readonly Toggle siteTags;
        private readonly Toggle mapSiteTags;
        private readonly MapLabelCoordinator annotations;
        private bool overview;
        private bool LabelsEnabled => overview ? mapSiteTags.isOn : siteTags.isOn;
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
        private bool labelsEnabled;
        private AdventureViewData.Site[] lastSites;
        private bool pickDirty = true;
        private Vector2 pickMouse;
        private Matrix4x4 pickView, pickProjection;
        private Rect pickViewport;
        private int pickLayoutRevision;
        private AdventureViewData.Site pickedSite;
        internal WorldSiteView(MainHudView owner, MapPreviewData data, MapPreviewRenderer mapRenderer)
            : this(owner, data, mapRenderer, null) { }
        internal WorldSiteView(MainHudView owner, MapPreviewData data, MapPreviewRenderer mapRenderer, MapLabelCoordinator coordinator)
        {
            annotations = coordinator;
            hud = owner; map = data; renderer = mapRenderer; layout = new WorldSiteLayout(map);
            siteTags = hud.GetComponent<LuaReference>().GetToggle("SiteTags");
            mapSiteTags = hud.GetComponent<LuaReference>().GetReference("MapHud").GetToggle("SiteTags");
            labelsEnabled = siteTags.isOn;
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
                    tag.Label.font = hud.Font;
                    if (annotations != null) tag.Placement = annotations.Register(site.Id * 4, tag.Rect, tag.Follower, 100);
                    tags.Add(site.Id, tag); changed = true;
                }
                if (tag.Site == null || tag.Site.Name != site.Name)
                {
                    SetCaption(tag, site.ShortName ?? site.Name, false);
                }
                tag.Site = site; tag.Revision = revision;
            }
            retired.Clear();
            foreach (var entry in tags) if (entry.Value.Revision != revision) retired.Add(entry.Key);
            foreach (var id in retired) { var tag = tags[id]; annotations?.Unregister(tag.Placement); hud.Untrack(tag.Follower); Release(tag.Rect.gameObject); tags.Remove(id); changed = true; }
            if (!changed) return;
            sitesByCell.Clear();
            // Point events remain selectable when they share a town's territory.
            foreach (var tag in tags.Values) if (tag.Site.WorldRegionId > 0) foreach (var cell in tag.Cells) sitesByCell[cell] = tag;
            foreach (var tag in tags.Values) if (tag.Site.WorldTownId > 0) foreach (var cell in tag.Cells) sitesByCell[cell] = tag;
            foreach (var tag in tags.Values) if (tag.Site.WorldWonderId > 0) foreach (var cell in tag.Cells) sitesByCell[cell] = tag;
            foreach (var tag in tags.Values) if (tag.Site.WorldTownId == 0 && tag.Site.WorldRegionId == 0 && tag.Site.WorldWonderId == 0) foreach (var cell in tag.Cells) sitesByCell[cell] = tag;
        }
        internal AdventureViewData.Site Pick(Camera camera, Vector2 mouse)
        {
            if (labelsEnabled != LabelsEnabled) { labelsEnabled = LabelsEnabled; pickDirty = true; }
            if (!camera.pixelRect.Contains(mouse)) return null;
            var view = camera.worldToCameraMatrix; var projection = camera.projectionMatrix; var viewport = camera.pixelRect;
            if (!pickDirty && pickLayoutRevision == (annotations != null ? annotations.Revision : 0) && mouse == pickMouse && view == pickView && projection == pickProjection && viewport == pickViewport &&
                (hovered == 0 || renderer.FocusAmount >= 1)) return pickedSite;
            pickedSite = PickUncached(camera, mouse);
            pickDirty = false; pickMouse = mouse; pickView = view; pickProjection = projection; pickViewport = viewport;
            pickLayoutRevision = annotations != null ? annotations.Revision : 0;
            return pickedSite;
        }
        private AdventureViewData.Site PickUncached(Camera camera, Vector2 mouse)
        {
            Tag label = null; var nearest = float.PositiveInfinity;
            foreach (var tag in tags.Values)
            {
                // A toggle can change before Tick has hidden last frame's distant labels.
                if (!LabelsEnabled && (overview || tag.Site.Id != hovered)) continue;
                if (!tag.Rect.gameObject.activeInHierarchy || !tag.Follower.ProjectedVisible ||
                    !RectTransformUtility.RectangleContainsScreenPoint(tag.Rect, mouse)) continue;
                if (tag.Follower.Depth < nearest) { label = tag; nearest = tag.Follower.Depth; }
            }
            if (label != null) return label.Site;
            var ray = camera.ScreenPointToRay(mouse); var cell = layout.Pick(ray, out var distance);
            if(renderer.PickMountainSurface(ray,out var mountainCell,out var mountainDistance) && mountainDistance<distance)
            {cell=mountainCell;distance=mountainDistance;}
            if (renderer.PickBuilding(ray, out var buildingCell, out var buildingDistance) && buildingDistance < distance)
            {cell=buildingCell;distance=buildingDistance;}
            var wonderHit=renderer.PickWonder(ray,out var wonderCell,out var wonderDistance) && wonderDistance<distance;
            if(wonderHit)cell=wonderCell;
            return cell>=0 && (wonderHit || renderer.IsWorldCellKnown(cell)) && sitesByCell.TryGetValue(cell, out var site) ? site.Site : null;
        }
        internal void SetOverview(bool value)
        {
            if (overview == value) return;
            overview = value; pickDirty = true; renderer.SetFocus(null);
        }
        private static void SetCaption(Tag tag, string caption, bool selected)
        {
            tag.Expanded = selected; tag.Caption = caption;
            tag.Label.text = caption;
            float limit = (selected ? 300 : 180) - 18;
            if (tag.Label.preferredWidth > limit)
            {
                var characters = System.Globalization.StringInfo.ParseCombiningCharacters(caption);
                int lower = 0, upper = characters.Length - 1;
                while (lower < upper)
                {
                    int count = (lower + upper + 1) / 2;
                    tag.Label.text = LuaLanguage.Format("UIWorldMapCompactName", caption.Substring(0, characters[count]));
                    if (tag.Label.preferredWidth <= limit) lower = count; else upper = count - 1;
                }
                tag.Label.text = LuaLanguage.Format("UIWorldMapCompactName", lower == 0 ? "" : caption.Substring(0, characters[lower]));
            }
            float width = Mathf.Clamp(tag.Label.preferredWidth + 18, 46, selected ? 300 : 180);
            tag.Rect.sizeDelta = new Vector2(width, 24);
        }
        internal void Tick(Camera camera, bool pointerEnabled, Vector2 mouse, float deltaTime)
        {
            root.gameObject.SetActive(true);
            // Hysteresis prevents labels flickering at the zoom boundary.
            var showFar = camera.orthographicSize >= map.Radius * (farView ? 56 : 64);
            if (farView != showFar) { farView = showFar; pickDirty = true; }
            var site = pointerEnabled ? Pick(camera, mouse) : null; var id = site == null ? 0 : site.Id;
            if (id != hovered) { hovered = id; renderer.SetFocus(id == 0 || overview ? null : tags[id].Cells); }
            renderer.TickFocus(deltaTime);
            if (hovered == 0 || overview) mask.Hide(); else renderer.RenderFocusMask(camera, mask);
            foreach (var tag in tags.Values)
            {
                var selected = tag.Site.Id == hovered;
                var visible = overview ? LabelsEnabled : (LabelsEnabled && farView) || selected;
                if (tag.Rect.gameObject.activeSelf != visible) { tag.Rect.gameObject.SetActive(visible); pickDirty = true; }
                if (!tag.Rect.gameObject.activeSelf) continue;
                var caption = selected ? tag.Site.Name : tag.Site.ShortName ?? tag.Site.Name;
                if (tag.Caption != caption || tag.Expanded != selected) SetCaption(tag, caption, selected);
                tag.Background.color = selected ? new Color(1,.95f,.80f,1) : Color.white;
                tag.Label.color = tag.Site.Available ? new Color(.22f,.23f,.20f) : new Color(.42f,.43f,.39f);
                if (tag.Placement != null) tag.Placement.Priority = selected ? 1000 : tag.Site.Kind == "town" ? 140 : tag.Site.Visited ? 120 : 100;
                var point = tag.Site.Position + Vector3.up * (selected && !overview ? renderer.FocusLift : 0);
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
            Hide(); foreach (var tag in tags.Values)
            { annotations?.Unregister(tag.Placement); if (hud != null && tag.Follower != null) hud.Untrack(tag.Follower); }
            mask.Dispose(); if (root != null) Release(root.gameObject);
        }
        private static void Release(Object value)
        { if (Application.isPlaying) Object.Destroy(value); else Object.DestroyImmediate(value); }
    }
}
