if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode||UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Idle Edit Mode required");
using(var lua=new XLua.LuaEnv())
{
    var services=new ProjectY.FrameworkServices(null,System.IO.Path.Combine(System.IO.Path.GetTempPath(),"spellcasting-unused-"+System.Guid.NewGuid()+".json"));
    var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
    try{return lua.DoString(System.IO.File.ReadAllText("Tools/Tests/spellcasting_integration.lua"),"@Tools/Tests/spellcasting_integration.lua")[0];}
    finally{lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();}
}
