// Fresh services and in-memory growth serialization only; never enter Play or modify a scene.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.Exception("Idle Edit Mode required");
var originalScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();bool dirty=originalScene.isDirty;
var originalRandom=UnityEngine.Random.state;float originalTimeScale=UnityEngine.Time.timeScale;
var growth=new ProjectY.Data.CharacterGrowthData();growth.Initialize(4242,2,2,0);
growth.AddLearningOpportunity(1);growth.GrantSkill(2701);growth.GrantSkill(2702);
var flags=System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic;
var capture=typeof(ProjectY.Data.CharacterGrowthData).GetMethod("CaptureSave",flags);
var restore=typeof(ProjectY.Data.CharacterGrowthData).GetMethod("RestoreSave",flags);
var saved=capture.Invoke(growth,null);
var json=UnityEngine.JsonUtility.ToJson(saved);
var restored=new ProjectY.Data.CharacterGrowthData();
restore.Invoke(restored,new object[]{UnityEngine.JsonUtility.FromJson(json,saved.GetType())});
if(!restored.HasSkill(2701) || !restored.HasSkill(2702) || restored.PendingCount!=1 || restored.NextRandom()!=growth.NextRandom())
    throw new System.Exception("Special skill ownership, learning opportunities or RNG failed JSON roundtrip");
var folder=System.IO.Path.Combine(System.IO.Path.GetTempPath(),"project-y-special-skills-"+System.Guid.NewGuid().ToString("N"));
using(var lua=new XLua.LuaEnv())
{
    var services=new ProjectY.FrameworkServices(null,System.IO.Path.Combine(folder,"campaign.json"));
    var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
    try
    {
        var report=lua.DoString(System.IO.File.ReadAllText("Tools/Tests/special_skill_integration.lua"),"@Tools/Tests/special_skill_integration.lua")[0];
        if(UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=originalScene || originalScene.isDirty!=dirty)
            throw new System.Exception("Special skill tests changed the active scene");
        return new {report=report,growthSave="PASS skill ownership, pending opportunities and RNG JSON roundtrip",scene="unchanged"};
    }
    finally{lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();UnityEngine.Random.state=originalRandom;UnityEngine.Time.timeScale=originalTimeScale;}
}
