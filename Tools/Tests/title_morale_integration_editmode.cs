// Real gameplay systems with a unique temporary save; never enters Play or touches player saves.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Idle Edit Mode required");
var folder=System.IO.Path.Combine(System.IO.Path.GetTempPath(),"project-y-titles-"+System.Guid.NewGuid().ToString("N"));
System.IO.Directory.CreateDirectory(folder);
var scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();bool dirty=scene.isDirty;
using(var lua=new XLua.LuaEnv())
{
    var services=new ProjectY.FrameworkServices(null,System.IO.Path.Combine(folder,"campaign.json"));
    var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
    System.Func<ProjectY.Data.CharacterSaveService,ProjectY.Data.EquipmentData,ProjectY.Data.PreparedCharacterSave> legacy=(service,bag)=>
    {
        string path=service.FilePath;var type=typeof(ProjectY.Data.CharacterSaveService).Assembly.GetType("ProjectY.Data.CharacterSaveDocument");
        string json=System.IO.File.ReadAllText(path);var document=JsonUtility.FromJson(json,type);
        if((int)type.GetField("version").GetValue(document)!=38)throw new System.Exception("New full save must use v38");
        type.GetField("version").SetValue(document,36);
        foreach(var row in (System.Array)type.GetField("actors").GetValue(document))
        {
            row.GetType().GetField("titles").SetValue(row,null);
            var birth=row.GetType().GetField("initialAttributes").GetValue(row);var field=birth.GetType().GetField("entries");
            var values=(System.Array)field.GetValue(birth);var kept=new System.Collections.Generic.List<object>();
            foreach(var value in values)if((string)value.GetType().GetField("name").GetValue(value)!="courage")kept.Add(value);
            var entries=System.Array.CreateInstance(values.GetType().GetElementType(),kept.Count);
            for(int i=0;i<kept.Count;i++)entries.SetValue(kept[i],i);field.SetValue(birth,entries);
        }
        System.IO.File.WriteAllText(path,JsonUtility.ToJson(document));
        try
        {
            var prepared=service.Prepare(bag);
            for(int i=0;i<prepared.ActorCount;i++)
            {
                var actor=prepared.GetActorAt(i);
                if(ProjectY.Data.TitleState.Count(actor)!=0 || ProjectY.Data.TitleState.Equipped(actor)!=0 || ProjectY.Data.TitleState.CounterCount(actor)!=0)
                    throw new System.Exception("Old save invented title history");
            }
            return prepared;
        }
        finally{System.IO.File.WriteAllText(path,json);}
    };
    lua.Global.Set("CheckLegacyTitleSave",legacy);
    try
    {
        var result=lua.DoString(System.IO.File.ReadAllText("Tools/Tests/title_morale_integration.lua"),"@Tools/Tests/title_morale_integration.lua")[0];
        if(UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=scene || scene.isDirty!=dirty)throw new System.Exception("Integration changed active scene");
        return new {report=result,temporaryDirectory=folder};
    }
    finally{lua.Global.Set<string,object>("Services",null);lua.Global.Set<string,object>("CheckLegacyTitleSave",null);services.Player.ClearListeners();}
}
