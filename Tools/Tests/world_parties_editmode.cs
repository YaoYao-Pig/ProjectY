if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var root=new GameObject("WorldPartiesValidation");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
var host=root.AddComponent<ProjectY.UI.UIHost>();host.Initialize();var scale=Time.timeScale;
string path=System.IO.Path.Combine(System.IO.Path.GetTempPath(),"project-y-world-parties-"+System.Guid.NewGuid().ToString("N")+".json");
try
{
    using(var lua=new XLua.LuaEnv())
    {
        var services=new ProjectY.FrameworkServices(host,path);var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);
        lua.AddLoader(loader.Load);lua.Global.Set("Services",services);lua.Global.Set("OpenDemo",false);
        lua.Global.Set("ShopFont",UnityEditor.AssetDatabase.LoadAssetAtPath<Font>("Assets/DynamicAsset/UI/Fonts/NotoSansCJKsc-Regular.otf"));
        try
        {
            string result=(string)lua.DoString(System.IO.File.ReadAllText("Tools/Tests/world_parties_integration.lua"),"@Tools/Tests/world_parties_integration.lua")[0];
            System.IO.File.WriteAllText("Art/WorldPartyLowPoly/Integration/gameplay-validation.txt",result+"\nTemporary save: "+path);return result;
        }
        finally
        {
            using(var shutdown=lua.Global.Get<XLua.LuaFunction>("GameShutdown"))if(shutdown!=null)shutdown.Call();
            lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();
        }
    }
}
finally{host.Shutdown();UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);Time.timeScale=scale;}
