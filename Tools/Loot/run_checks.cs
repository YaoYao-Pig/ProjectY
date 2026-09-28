if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
using(var lua=new XLua.LuaEnv()){
 var services=new ProjectY.FrameworkServices(null);var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
 try{return (string)lua.DoString(System.IO.File.ReadAllText("Tools/Tests/loot_integration.lua"),"@Tools/Tests/loot_integration.lua")[0];}
 finally{lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();}
}
