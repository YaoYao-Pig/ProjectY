using UnityEngine;
using UnityEngine.EventSystems;

namespace ProjectY.Samples
{
    public sealed partial class AdventureRuntimeDemo
    {
        private WorldSiteView worldSites;
        private MapPreviewData siteMap;
        private ProjectY.UI.MainHudView siteHud;
        private bool WorldSitePointerEnabled => !campaignMenuOpen && !equipmentOpen && !growthOpen && !storyOpen && !gmOpen &&
            fatalError == null && !Input.GetMouseButton(1) && !Input.GetMouseButton(2) &&
            (EventSystem.current == null || !EventSystem.current.IsPointerOverGameObject()) &&
            !(showEnvironment && new Rect(Screen.width - 308, 106, 290, 236).Contains(new Vector2(Input.mousePosition.x, Screen.height - Input.mousePosition.y)));
        private void TickWorldSites()
        {
            if (view.Phase != "map" || mainHud == null || campaignMenuOpen || equipmentOpen || growthOpen || storyOpen || gmOpen || fatalError != null)
            { worldSites?.Hide(); return; }
            if (siteMap != worldMap || siteHud != mainHud)
            {
                worldSites?.Dispose(); worldSites = new WorldSiteView(mainHud, worldMap, mapRenderer); siteMap = worldMap; siteHud = mainHud;
            }
            worldSites.Sync(view.Sites);
            worldSites.Tick(mapCamera, WorldSitePointerEnabled, Input.mousePosition, Time.unscaledDeltaTime);
        }
        private void ClearWorldSites()
        { worldSites?.Dispose(); worldSites = null; siteMap = null; siteHud = null; }
    }
}
