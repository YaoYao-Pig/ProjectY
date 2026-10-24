// Unity MCP execute_code method body. Requires the saved StartMenu prefab; no Play or world creation.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode)throw new System.InvalidOperationException("Edit Mode required");
var config=UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.UI.PanelConfig>(ProjectY.UI.PanelConfig.AssetPath);
if(config==null)throw new System.Exception("PanelConfig is missing");
var entry=config.Get("StartMenu");entry.Validate(true);
if(entry.Module!="Adventure" || entry.Kind!=ProjectY.UI.UIKind.Panel || entry.Layer!="Popup" || !entry.Modal || !entry.PauseWorldOnOpen || entry.CloseOnBack)
    throw new System.Exception("StartMenu registry flags are invalid");
var reference=entry.Prefab.GetComponent<ProjectY.UI.LuaReference>();
foreach(var key in new[]{"Root","Style","Title","Caption","Hint","HomePage","NewPage","LoadPage","Start","Load","Back","Resume","Create","RandomSeed","Seed","Size","SaveContent","SaveScroll","Empty"})
    if(reference.Get(key)==null)throw new System.Exception("Missing StartMenu binding: "+key);
var originalScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();var originalDirty=originalScene.isDirty;
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
ProjectY.UI.UIHost host=null;UnityEngine.Font font=null;string report;
try
{
    var root=new UnityEngine.GameObject("StartMenu isolated validation");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
    host=root.AddComponent<ProjectY.UI.UIHost>();host.Initialize();
    font=UnityEngine.Font.CreateDynamicFontFromOSFont(new[]{"Microsoft YaHei","Noto Sans CJK SC","Arial"},16);
    using(var lua=new XLua.LuaEnv())
    {
        var services=new ProjectY.FrameworkServices(host,System.IO.Path.Combine(System.IO.Path.GetTempPath(),"start-menu-unused-"+System.Guid.NewGuid().ToString("N")+".json"));
        var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);
        lua.Global.Set("Services",services);lua.Global.Set("MenuFixtureFont",font);
        try {report=(string)lua.DoString(System.IO.File.ReadAllText("Tools/Tests/start_menu_integration.lua"),"@start_menu_integration")[0];}
        finally {lua.Global.Set<string,object>("MenuFixtureFont",null);lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();}
    }
}
finally
{
    if(host!=null)host.Shutdown();
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
    if(font!=null)UnityEngine.Object.DestroyImmediate(font);
}
if(UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=originalScene || originalScene.isDirty!=originalDirty)
    throw new System.Exception("Start menu validation changed the user's scene");
return new {passed=true,realPrefab=true,realWidgets=true,isolatedCampaignCommands=true,playMode=false,report};
