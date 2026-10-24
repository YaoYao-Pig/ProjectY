// Execute through Unity MCP. Isolated UI/Services and temporary save path; never starts Play.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode)throw new System.InvalidOperationException("Edit Mode required");
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var root=new GameObject("BodyHealthValidation");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
var host=root.AddComponent<ProjectY.UI.UIHost>();host.Initialize();
string directory=System.IO.Path.Combine(System.IO.Path.GetTempPath(),"ProjectY-BodyHealth-"+System.Guid.NewGuid().ToString("N"));
System.IO.Directory.CreateDirectory(directory);
try
{
    using(var lua=new XLua.LuaEnv())
    {
        var services=new ProjectY.FrameworkServices(host,System.IO.Path.Combine(directory,"party.json"));
        var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
        try {return lua.DoString(System.IO.File.ReadAllText("Tools/Tests/body_injuries_integration.lua"),"@Tools/Tests/body_injuries_integration.lua")[0];}
        finally {lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();}
    }
}
finally {host.Shutdown();UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);}
