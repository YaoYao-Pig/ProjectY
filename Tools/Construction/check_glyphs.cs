// Run through Unity MCP execute_code: only the two skill-related UIs, without entering Play.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode||UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var root=new GameObject("SkillGlyphValidation");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
var host=root.AddComponent<ProjectY.UI.UIHost>();host.Initialize();var timeScale=Time.timeScale;
try
{
    using(var lua=new XLua.LuaEnv())
    {
        var services=new ProjectY.FrameworkServices(host);var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
        try{return lua.DoString(System.IO.File.ReadAllText("Tools/Tests/skill_glyphs_integration.lua"),"@Tools/Tests/skill_glyphs_integration.lua")[0];}
        finally{lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();}
    }
}
finally{host.Shutdown();Time.timeScale=timeScale;UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);}
