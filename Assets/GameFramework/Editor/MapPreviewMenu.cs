using UnityEditor;

namespace ProjectY.Editor
{
    /// <summary>保留原地图菜单入口，统一使用注册服务管理器启动和打开。</summary>
    public static class MapPreviewMenu
    {
        private const string MenuPath = "Project Y/地图/打开地图实验室";

        [MenuItem(MenuPath)]
        public static void Open() => WebServicesMenu.OpenMapPreview();

        [MenuItem(MenuPath, true)]
        private static bool CanOpen() => WebServicesMenu.CanRun();
    }
}
