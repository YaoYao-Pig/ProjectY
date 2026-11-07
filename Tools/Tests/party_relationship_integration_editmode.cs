// Focused relationship integration: isolated services and temporary save, no Play or scene changes.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
var originalScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();bool dirty=originalScene.isDirty;
var random=UnityEngine.Random.state;float timeScale=UnityEngine.Time.timeScale;
var folder=System.IO.Path.Combine(System.IO.Path.GetTempPath(),"project-y-relationships-"+System.Guid.NewGuid().ToString("N"));
System.IO.Directory.CreateDirectory(folder);
using(var lua=new XLua.LuaEnv())
{
    var services=new ProjectY.FrameworkServices(null,System.IO.Path.Combine(folder,"campaign.json"));
    var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
    try
    {
        var report=lua.DoString(System.IO.File.ReadAllText("Tools/Tests/social_integration.lua"),"@Tools/Tests/social_integration.lua")[0];
        if(UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=originalScene || originalScene.isDirty!=dirty)throw new System.Exception("Relationship tests changed the active scene");
        return new {report=report,temporaryDirectory=folder};
    }
    finally{lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();UnityEngine.Random.state=random;UnityEngine.Time.timeScale=timeScale;}
}
