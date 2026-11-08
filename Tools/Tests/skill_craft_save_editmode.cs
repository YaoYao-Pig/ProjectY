if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.Exception("Idle Edit Mode required");
var folder=System.IO.Path.Combine(System.IO.Path.GetTempPath(),"project-y-skill-craft-"+System.Guid.NewGuid().ToString("N"));
System.IO.Directory.CreateDirectory(folder);
var scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();bool dirty=scene.isDirty;
var random=UnityEngine.Random.state;float time=UnityEngine.Time.timeScale;
using(var lua=new XLua.LuaEnv())
{
    var services=new ProjectY.FrameworkServices(null,System.IO.Path.Combine(folder,"campaign.json"));
    var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
    System.Func<ProjectY.Data.CharacterSaveService,ProjectY.Data.EquipmentData,ProjectY.Data.PreparedCharacterSave> legacy=(service,bag)=>{
        string path=System.IO.Path.GetFullPath(service.FilePath);
        if(!path.StartsWith(System.IO.Path.GetFullPath(folder)+System.IO.Path.DirectorySeparatorChar,System.StringComparison.OrdinalIgnoreCase))throw new System.Exception("Fixture escaped temporary directory");
        string current=System.IO.File.ReadAllText(path);
        var json=Newtonsoft.Json.Linq.JObject.Parse(current);
        if((int)json["version"]!=52)throw new System.Exception("New full save must use v52");
        var catalog=ProjectY.Data.CampaignSaves.List(service);
        if(catalog.Length!=1 || !catalog[0].CanLoad || !catalog[0].HasWorld)throw new System.Exception("Catalog rejected crafted-skill save");
        json["version"]=50;
        var fields=new System.Collections.Generic.List<Newtonsoft.Json.Linq.JToken>(json.SelectTokens("$..skillCraft"));
        foreach(var field in fields)field.Parent.Remove();
        try{System.IO.File.WriteAllText(path,json.ToString(Newtonsoft.Json.Formatting.None));return service.Prepare(bag);}
        finally{System.IO.File.WriteAllText(path,current);}
    };
    lua.Global.Set("PrepareCraftLegacy",legacy);
    try{
        var report=lua.DoString(System.IO.File.ReadAllText("Tools/Tests/skill_craft_save.lua"),"@Tools/Tests/skill_craft_save.lua")[0];
        if(UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=scene || scene.isDirty!=dirty)throw new System.Exception("Save check changed scene");
        return new {report=report,temporaryDirectory=folder};
    }
    finally{lua.Global.Set<string,object>("PrepareCraftLegacy",null);lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();UnityEngine.Random.state=random;UnityEngine.Time.timeScale=time;}
}
