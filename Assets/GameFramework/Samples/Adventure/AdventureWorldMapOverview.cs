using ProjectY.UI;
using UnityEngine;
using XLua;

namespace ProjectY.Samples
{
    public sealed partial class AdventureRuntimeDemo
    {
        private WorldMapMarkerView worldMapMarkers;
        private MainHudView markerHud;
        private MapLabelCoordinator mapLabels;
        internal float WorldMapProgress => worldMapMode.Progress;
        internal bool WorldMapVisible => view != null && view.Phase == "map" && worldMapMode.Visible;
        private float WorldMapFitSize => StrategyCameraRig.FitSize(mapRenderer.Bounds, 0, 90, (float)Screen.width / Screen.height, 8);

        private void TickWorldMapCamera()
        {
            cameraRig.Tuning = cameraSettings;
            worldMapMode.Tick(view.Phase == "map", zoom, worldMap.Radius, WorldMapFitSize, Time.unscaledDeltaTime, worldMapCameraSettings);
            cameraRig.OverviewBlend = worldMapMode.Blend;
            if (worldMapMode.Active) followTravel = false;
            worldPartyView?.SetOverview(WorldMapVisible);
            worldWaterView?.SetOverview(WorldMapVisible);
        }

        private void ResetWorldMapMode()
        {
            worldMapMode.Reset(); cameraRig.OverviewBlend = 0;
            worldMapMarkers?.Hide();
        }

        private void InitializeTravelCamera()
        {
            ResetWorldMapMode();
            if (HasArea) FitMap();
            else
            {
                followTravel = true; focus = displayedTravel;
                zoom = Mathf.Min(20 * worldMap.Radius, WorldMapCameraMode.ExitSize(worldMapCameraSettings, worldMap.Radius, WorldMapFitSize) * .85f);
                pitch = cameraSettings.defaultPitch; yaw = -25;
            }
            cameraRig.Snap(); cameraDragButton = -1; keyboardPanning = false;
        }

        internal void LeaveWorldMapOverview(bool follow)
        {
            if (view == null || view.Phase != "map") return;
            cameraRig.Stop(); cameraDragButton = -1; keyboardPanning = false;
            zoom = Mathf.Min(20 * worldMap.Radius, WorldMapCameraMode.ExitSize(worldMapCameraSettings, worldMap.Radius, WorldMapFitSize) * .85f);
            pitch = cameraSettings.defaultPitch;
            followTravel = follow;
            if (follow) focus = displayedTravel;
        }

        private void TickWorldMapMarkers()
        {
            if (!WorldMapVisible || mainHud == null || campaignMenuOpen || equipmentOpen || growthOpen || storyOpen || gmOpen || fatalError != null)
            { worldMapMarkers?.Hide(); return; }
            if (markerHud != mainHud)
            {
                worldMapMarkers?.Dispose(); markerHud = mainHud;
                worldMapMarkers = new WorldMapMarkerView(mainHud, mapLabels);
            }
            worldMapMarkers.Tick(mapCamera, view, displayedTravel, worldMapMode.Blend);
        }
        private bool WorldMapRouteVisible => !WorldMapVisible || (worldMapMarkers != null && worldMapMarkers.ShowRoute);
        private void ClearWorldMapMarkers()
        { worldMapMarkers?.Dispose(); worldMapMarkers = null; markerHud = null; }
    }

    // New bridge uses the project's reflection path without changing generated Demo bindings.
    [LuaCallCSharp]
    public static class WorldMapOverviewBridge
    {
        public static float Progress(AdventureRuntimeDemo demo) => demo.WorldMapProgress;
        public static bool Visible(AdventureRuntimeDemo demo) => demo.WorldMapVisible;
        public static void Close(AdventureRuntimeDemo demo) => demo.LeaveWorldMapOverview(false);
        public static void Home(AdventureRuntimeDemo demo) => demo.LeaveWorldMapOverview(true);
    }
}
