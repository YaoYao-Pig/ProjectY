using System;
using System.Collections.Generic;
using ProjectY.UI;
using UnityEngine;
using UnityEngine.UI;
using Object = UnityEngine.Object;

namespace ProjectY.Samples
{
    /// <summary>Compact per-site task badges. Filters change presentation, never mission state.</summary>
    internal sealed class WorldMapMarkerView : IDisposable
    {
        private sealed class Marker
        {
            public RectTransform Root;
            public Text Label;
            public Image[] Icons;
            public UIFollower Follower;
            public MapLabelLayout.Item Placement;
            public int Count, Flags;
            public Vector3 Position;
        }
        private readonly MainHudView hud;
        private readonly MapLabelCoordinator annotations;
        private readonly MapHudLayout style;
        private readonly RectTransform root;
        private readonly LuaReference template;
        private readonly CanvasGroup group;
        private readonly Toggle available, active, ready, player, route;
        private readonly Dictionary<int, Marker> markers = new Dictionary<int, Marker>();
        private readonly Dictionary<int, AdventureViewData.Site> sites = new Dictionary<int, AdventureViewData.Site>();
        private readonly List<int> retired = new List<int>();
        private AdventureViewData.Site[] lastSites;
        public bool ShowRoute => route.isOn;
        private int EnabledFlags => (available.isOn ? 1 : 0) | (active.isOn ? 2 : 0) | (ready.isOn ? 4 : 0) | (player.isOn ? 8 : 0);
        internal WorldMapMarkerView(MainHudView owner) : this(owner, null) { }
        internal WorldMapMarkerView(MainHudView owner, MapLabelCoordinator coordinator)
        {
            hud = owner; annotations = coordinator;
            var view = owner.GetComponent<LuaReference>().GetReference("MapHud");
            root = (RectTransform)view.Get("MarkerRoot"); template = view.GetReference("MarkerTemplate");
            style = (MapHudLayout)view.Get("Layout");
            group = root.GetComponent<CanvasGroup>();
            if (group == null) throw new InvalidOperationException("Map marker root requires its saved visibility group.");
            available = view.GetToggle("AvailableMissions"); active = view.GetToggle("ActiveMissions"); ready = view.GetToggle("ReadyMissions");
            player = view.GetToggle("PlayerMarker"); route = view.GetToggle("Route");
        }
        private Marker Get(int id)
        {
            if (markers.TryGetValue(id, out var marker)) return marker;
            var reference = Object.Instantiate(template, root, false);
            marker = new Marker { Root = (RectTransform)reference.Get("Root"), Label = reference.GetText("Label"),
                Icons = new[] {reference.GetImage("AvailableIcon"), reference.GetImage("ActiveIcon"), reference.GetImage("ReadyIcon"), reference.GetImage("Icon")},
                Follower = (UIFollower)reference.Get("Follower") };
            marker.Icons[0].sprite = style.Available; marker.Icons[1].sprite = style.Active;
            marker.Icons[2].sprite = style.Ready; marker.Icons[3].sprite = style.Party;
            marker.Label.font = hud.Font;
            if (annotations != null) marker.Placement = annotations.Register(id < 0 ? -1 : id * 4 + 1, marker.Root, marker.Follower, id < 0 ? 850 : 350);
            markers.Add(id, marker); return marker;
        }
        internal AdventureViewData.Site Pick(Camera camera, Vector2 pointer)
        {
            if (!root.gameObject.activeInHierarchy || !camera.pixelRect.Contains(pointer)) return null;
            var canvas = hud.FollowerCanvas; var uiCamera = canvas.renderMode == RenderMode.ScreenSpaceOverlay ? null : canvas.worldCamera;
            foreach (var pair in markers)
            {
                var marker = pair.Value;
                if (pair.Key < 0 || (marker.Flags & EnabledFlags) == 0 || !marker.Root.gameObject.activeInHierarchy || !marker.Follower.ProjectedVisible) continue;
                if (RectTransformUtility.RectangleContainsScreenPoint(marker.Root, pointer, uiCamera)) return sites[pair.Key];
            }
            return null;
        }
        internal void Tick(Camera camera, AdventureViewData view, Vector3 playerPosition, float blend)
        {
            root.gameObject.SetActive(true); group.alpha = blend; group.blocksRaycasts = group.interactable = false;
            if (!ReferenceEquals(lastSites, view.Sites))
            {
                lastSites = view.Sites; sites.Clear(); foreach (var site in view.Sites) sites.Add(site.Id, site);
                retired.Clear(); foreach (var key in markers.Keys) if (key >= 0 && !sites.ContainsKey(key)) retired.Add(key);
                foreach (int key in retired) { ReleaseMarker(markers[key]); markers.Remove(key); }
            }
            foreach (var marker in markers.Values) { marker.Count = 0; marker.Flags = 0; }
            int enabled = EnabledFlags;
            foreach (var data in view.MapMarkers)
            {
                if (!sites.TryGetValue(data.SiteId, out var site)) continue;
                int flag;
                switch (data.Kind)
                {
                    case "available": flag = 1; break;
                    case "active": flag = 2; break;
                    case "ready": flag = 4; break;
                    default: throw new InvalidOperationException("Unknown world-map marker kind: " + data.Kind);
                }
                if ((enabled & flag) == 0) continue;
                var marker = Get(site.Id); marker.Flags |= flag; marker.Count += data.Count; marker.Position = site.Position;
            }
            if (player.isOn) { var pin = Get(-1); pin.Count = 1; pin.Flags = 8; pin.Position = playerPosition; }
            foreach (var pair in markers)
            {
                var marker = pair.Value; bool visible = marker.Count > 0;
                if (marker.Root.gameObject.activeSelf != visible) marker.Root.gameObject.SetActive(visible);
                if (!visible) continue;
                int slot = 0;
                for (int i = 0; i < marker.Icons.Length; i++)
                {
                    var icon = marker.Icons[i]; bool show = (marker.Flags & (1 << i)) != 0;
                    if (icon.gameObject.activeSelf != show) icon.gameObject.SetActive(show);
                    if (!show) continue;
                    icon.color = Color.white; icon.preserveAspect = true;
                    var rect = icon.rectTransform; rect.anchorMin = rect.anchorMax = rect.pivot = new Vector2(0, .5f);
                    rect.anchoredPosition = new Vector2(slot++ * 24, 0); rect.sizeDelta = new Vector2(22, 22);
                }
                marker.Label.text = marker.Count > 1 ? marker.Count.ToString(System.Globalization.CultureInfo.InvariantCulture) : "";
                float countWidth = marker.Count > 1 ? Mathf.Max(14, marker.Label.preferredWidth + 4) : 0;
                marker.Root.sizeDelta = new Vector2(slot * 24 + countWidth, 26);
                marker.Label.rectTransform.anchoredPosition = new Vector2(-2, 0);
                marker.Label.rectTransform.sizeDelta = new Vector2(Mathf.Max(1,countWidth - 2), 16);
                marker.Follower.SetScreenOffset(new Vector2(0, 16));
                if (marker.Placement != null) marker.Placement.Priority = pair.Key < 0 ? 850 : (marker.Flags & 4) != 0 ? 450 : (marker.Flags & 2) != 0 ? 400 : 350;
                hud.TrackPoint(marker.Follower, camera, marker.Position);
            }
        }
        internal void Hide() { if (root != null) root.gameObject.SetActive(false); }
        private void ReleaseMarker(Marker marker)
        {
            annotations?.Unregister(marker.Placement);
            if (hud != null) hud.Untrack(marker.Follower);
            if (marker.Root != null) Release(marker.Root.gameObject);
        }
        public void Dispose() { Hide(); foreach (var marker in markers.Values) ReleaseMarker(marker); markers.Clear(); }
        private static void Release(Object value)
        { if (Application.isPlaying) Object.Destroy(value); else Object.DestroyImmediate(value); }
    }
}
