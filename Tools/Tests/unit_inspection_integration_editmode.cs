// Run through Unity MCP in idle Edit Mode. All save files are confined to a fresh OS temporary directory.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode||UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Idle Edit Mode required");
var originalScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();bool originalDirty=originalScene.isDirty;
float originalTime=Time.timeScale;var originalRandom=UnityEngine.Random.state;
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var root=new GameObject("Unit inspection isolated save integration");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
var host=root.AddComponent<ProjectY.UI.UIHost>();host.Initialize();
var path=System.IO.Path.Combine(System.IO.Path.GetTempPath(),"project-y-inspection-"+System.Guid.NewGuid().ToString("N"),"party.json");
try
{
    using(var lua=new XLua.LuaEnv())
    {
        var services=new ProjectY.FrameworkServices(host,path);
        var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
        try
        {
            return new {passed=true,report=lua.DoString(System.IO.File.ReadAllText("Tools/Tests/unit_inspection_integration.lua"),"@Tools/Tests/unit_inspection_integration.lua")[0],playMode=false};
        }
        finally{lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();}
    }
}
finally
{
    host.Shutdown();UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
    Time.timeScale=originalTime;UnityEngine.Random.state=originalRandom;
    if(originalScene.isDirty!=originalDirty)throw new System.Exception("Inspection save check changed the user's active scene");
}
