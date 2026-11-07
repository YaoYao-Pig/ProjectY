// Isolated real save integration. No Play, Assets edits, or player-save access.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Idle Edit Mode required");
var folder=System.IO.Path.Combine(System.IO.Path.GetTempPath(),"project-y-title-forge-"+System.Guid.NewGuid().ToString("N"));
System.IO.Directory.CreateDirectory(folder);
var scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();bool dirty=scene.isDirty;
var random=UnityEngine.Random.state;float timeScale=UnityEngine.Time.timeScale;
using(var lua=new XLua.LuaEnv())
{
    var services=new ProjectY.FrameworkServices(null,System.IO.Path.Combine(folder,"campaign.json"));
    var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
    var documentType=typeof(ProjectY.Data.CharacterSaveService).Assembly.GetType("ProjectY.Data.CharacterSaveDocument");
    string baseline=null;
    System.Func<ProjectY.Data.CharacterSaveService,ProjectY.Data.EquipmentData,string,ProjectY.Data.PreparedCharacterSave> fixture=(service,bag,mode)=>
    {
        string path=System.IO.Path.GetFullPath(service.FilePath);
        if(System.IO.Path.GetDirectoryName(path)!=System.IO.Path.GetFullPath(folder))throw new System.Exception("Fixture path escaped its temporary directory");
        string current=System.IO.File.ReadAllText(path);
        if(mode=="baseline"){baseline=current;return null;}
        if(mode=="legacy44" && baseline==null)throw new System.Exception("Missing pre-forge baseline");
        var document=UnityEngine.JsonUtility.FromJson(mode=="legacy44"?baseline:current,documentType);
        var actors=(System.Array)documentType.GetField("actors").GetValue(document);
        if(mode=="legacy44")
        {
            documentType.GetField("version").SetValue(document,44);
            documentType.GetField("reputation").SetValue(document,null);
            foreach(var actor in actors)
            {
                var titles=actor.GetType().GetField("titles").GetValue(actor);
                titles.GetType().GetField("format").SetValue(titles,1);
                titles.GetType().GetField("custom").SetValue(titles,null);
                titles.GetType().GetField("nextCustomId").SetValue(titles,0);
            }
        }
        else if(mode=="missingReputation")documentType.GetField("reputation").SetValue(document,null);
        else if(mode=="unknownEffect")
        {
            var actor=actors.GetValue(0);var titles=actor.GetType().GetField("titles").GetValue(actor);
            var custom=((System.Array)titles.GetType().GetField("custom").GetValue(titles)).GetValue(0);
            var effect=((System.Array)custom.GetType().GetField("effects").GetValue(custom)).GetValue(0);
            effect.GetType().GetField("id").SetValue(effect,int.MaxValue);
        }
        else throw new System.ArgumentException("Unknown title save fixture: "+mode);
        try
        {
            System.IO.File.WriteAllText(path,UnityEngine.JsonUtility.ToJson(document));
            return service.Prepare(bag);
        }
        finally{System.IO.File.WriteAllText(path,current);}
    };
    System.Func<ProjectY.Data.PreparedCharacterSave,int> balance=prepared=>
    {
        var flags=System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic;
        var reputation=typeof(ProjectY.Data.PreparedCharacterSave).GetField("Reputation",flags).GetValue(prepared);
        return (int)reputation.GetType().GetProperty("Balance",flags).GetValue(reputation);
    };
    System.Func<ProjectY.Data.CharacterSaveService,int> version=service=>
    {
        var document=UnityEngine.JsonUtility.FromJson(System.IO.File.ReadAllText(service.FilePath),documentType);
        int value=(int)documentType.GetField("version").GetValue(document);
        var catalog=ProjectY.Data.CampaignSaves.List(service);
        if(value<46 || value%2!=0 || catalog.Length!=1 || !catalog[0].CanLoad || !catalog[0].HasWorld || catalog[0].TargetCells!=2500)
            throw new System.Exception("The catalog did not recognize the title-era full expedition");
        return value;
    };
    lua.Global.Set("PrepareTitleForgeFixture",fixture);lua.Global.Set("PreparedTitleForgeBalance",balance);lua.Global.Set("CheckTitleForgeSaveVersion",version);
    try
    {
        var result=lua.DoString(System.IO.File.ReadAllText("Tools/Tests/title_forge_save.lua"),"@Tools/Tests/title_forge_save.lua")[0];
        if(UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=scene || scene.isDirty!=dirty)throw new System.Exception("Save integration changed the active scene");
        return new {report=result,temporaryDirectory=folder};
    }
    catch(System.Exception error){throw new System.Exception("Title forge save validation failed; temporary artifacts: "+folder+"\n"+error,error);}
    finally
    {
        lua.Global.Set<string,object>("Services",null);lua.Global.Set<string,object>("PrepareTitleForgeFixture",null);
        lua.Global.Set<string,object>("PreparedTitleForgeBalance",null);lua.Global.Set<string,object>("CheckTitleForgeSaveVersion",null);
        services.Player.ClearListeners();UnityEngine.Random.state=random;UnityEngine.Time.timeScale=timeScale;
    }
}
