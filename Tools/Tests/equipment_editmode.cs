// Unity MCP execute_code method body. Existing Editor only; never enters Play.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.InvalidOperationException("Edit Mode required");
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var root=new GameObject("EquipmentValidation");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
var host=root.AddComponent<ProjectY.UI.UIHost>();host.Initialize();
try {
using(var lua=new XLua.LuaEnv()) {
var services=new ProjectY.FrameworkServices(host);
var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);
lua.Global.Set("Services",services);
try { return lua.DoString(System.IO.File.ReadAllText("Tools/Tests/equipment_integration.lua"),"@Tools/Tests/equipment_integration.lua")[0]; }
finally { lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners(); }
}
} finally { host.Shutdown();UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene); }
