// Run through Unity MCP execute_code in the existing idle Editor.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode||UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var root=new GameObject("ConstructionValidation");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
var host=root.AddComponent<ProjectY.UI.UIHost>();host.Initialize();var oldTimeScale=Time.timeScale;
try
{
    using(var lua=new XLua.LuaEnv())
    {
        var services=new ProjectY.FrameworkServices(host);var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
        try{return lua.DoString(System.IO.File.ReadAllText("Tools/Tests/construction_integration.lua"),"@Tools/Tests/construction_integration.lua")[0];}
        finally{lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();}
    }
}
finally{host.Shutdown();Time.timeScale=oldTimeScale;UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);}
