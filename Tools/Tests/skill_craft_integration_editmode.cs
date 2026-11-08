if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.Exception("Idle Edit Mode required");
var originalScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();bool dirty=originalScene.isDirty;
var random=UnityEngine.Random.state;float time=UnityEngine.Time.timeScale;
using(var lua=new XLua.LuaEnv())
{
    var services=new ProjectY.FrameworkServices(null,System.IO.Path.Combine(System.IO.Path.GetTempPath(),"craft-unused-"+System.Guid.NewGuid()+".json"));
    var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
    try
    {
        var report=lua.DoString(System.IO.File.ReadAllText("Tools/Tests/skill_craft_integration.lua"),"@Tools/Tests/skill_craft_integration.lua")[0];
        var actor=lua.Global.Get<ProjectY.Data.CombatActorData>("SaveCraftActor");
        var flags=System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic;
        var capture=typeof(ProjectY.Data.CharacterGrowthData).GetMethod("CaptureSave",flags);var restore=typeof(ProjectY.Data.CharacterGrowthData).GetMethod("RestoreSave",flags);
        var saved=capture.Invoke(actor.Growth,null);var json=UnityEngine.JsonUtility.ToJson(saved);
        var restored=new ProjectY.Data.CombatActorData(2,1);
        restore.Invoke(restored.Growth,new object[]{UnityEngine.JsonUtility.FromJson(json,saved.GetType())});
        if(ProjectY.Data.SkillCraftState.Count(restored)!=2 || ProjectY.Data.SkillCraftState.Points(restored,1)!=100000 || ProjectY.Data.SkillCraftState.At(restored,0).name!="三途改")throw new System.Exception("Craft save JSON roundtrip failed");
        var copy=ProjectY.Data.SkillCraftState.At(restored,0);copy.name="changed";copy.modifierIds[0]=999;
        if(ProjectY.Data.SkillCraftState.At(restored,0).name!="三途改" || ProjectY.Data.SkillCraftState.At(restored,0).modifierIds[0]!=1)throw new System.Exception("Craft query exposed mutable authority");
        if(UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=originalScene || originalScene.isDirty!=dirty)throw new System.Exception("Scene changed");
        return report+"\nPASS real JSON roundtrip and immutable query copies";
    }
    finally{lua.Global.Set<string,object>("SaveCraftActor",null);lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();UnityEngine.Random.state=random;UnityEngine.Time.timeScale=time;}
}
