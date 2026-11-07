if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode||UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
var folder=System.IO.Path.Combine(System.IO.Path.GetTempPath(),"project-y-death-door-"+System.Guid.NewGuid().ToString("N"));
System.IO.Directory.CreateDirectory(folder);
using(var lua=new XLua.LuaEnv())
{
    var services=new ProjectY.FrameworkServices(null,System.IO.Path.Combine(folder,"campaign.json"));
    var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
    System.Action<ProjectY.Data.CharacterSaveService,ProjectY.Data.EquipmentData> legacy=(service,bag)=>
    {
        var type=typeof(ProjectY.Data.CharacterSaveService).Assembly.GetType("ProjectY.Data.CharacterSaveDocument");
        string path=service.FilePath,json=System.IO.File.ReadAllText(path);var document=JsonUtility.FromJson(json,type);
        int version=(int)type.GetField("version").GetValue(document);
        if(version<40 || version%2!=0)throw new System.Exception("Full save must include the death-door schema introduced in v40");
        type.GetField("version").SetValue(document,38);
        foreach(var row in (System.Array)type.GetField("actors").GetValue(document))row.GetType().GetField("deathDoor").SetValue(row,null);
        System.IO.File.WriteAllText(path,JsonUtility.ToJson(document));
        try
        {
            var prepared=service.Prepare(bag);var actor=prepared.GetActorAt(0);
            if(actor.HP!=0 || !ProjectY.Data.DeathDoorState.Entered(actor) || ProjectY.Data.DeathDoorState.Dead(actor) || !ProjectY.Data.DeathDoorState.Alive(actor))
                throw new System.Exception("Old recoverable zero-HP actor became permanently dead");
            actor.Restore();if(actor.HP==0)throw new System.Exception("Migrated old downed actor cannot rest");
        }
        finally{System.IO.File.WriteAllText(path,json);}
    };
    lua.Global.Set("CheckDeathDoorLegacy",legacy);
    try{return new {report=lua.DoString(System.IO.File.ReadAllText("Tools/Tests/death_door_integration.lua"),"@Tools/Tests/death_door_integration.lua")[0],temporaryDirectory=folder};}
    finally{lua.Global.Set<string,object>("Services",null);lua.Global.Set<string,object>("CheckDeathDoorLegacy",null);services.Player.ClearListeners();}
}
