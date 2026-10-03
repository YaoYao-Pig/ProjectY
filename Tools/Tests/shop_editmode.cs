// Unity MCP execute_code 方法体：现有 Editor 内的独立数据与 UI 检查，不进入 Play、不改用户存档。
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)throw new System.InvalidOperationException("Idle Edit Mode required");
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var root=new GameObject("ShopValidation");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
var host=root.AddComponent<ProjectY.UI.UIHost>();host.Initialize();
var originalScale=Time.timeScale;
var path=System.IO.Path.Combine(System.IO.Path.GetTempPath(),"ProjectY-Shop-"+System.Guid.NewGuid().ToString("N")+".json");
try {
    using(var lua=new XLua.LuaEnv()) {
        var services=new ProjectY.FrameworkServices(host,path);
        var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
        lua.Global.Set("ShopFont",UnityEditor.AssetDatabase.LoadAssetAtPath<Font>("Assets/DynamicAsset/UI/Fonts/NotoSansCJKsc-Regular.otf"));
        try { return lua.DoString(System.IO.File.ReadAllText("Tools/Tests/shop_integration.lua"),"@Tools/Tests/shop_integration.lua")[0]; }
        finally {
            using(var shutdown=lua.Global.Get<XLua.LuaFunction>("GameShutdown"))shutdown?.Call();
            lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();
        }
    }
} finally {
    host.Shutdown();UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);Time.timeScale=originalScale;
    Debug.Log("Shop validation temporary save: "+path);
}
