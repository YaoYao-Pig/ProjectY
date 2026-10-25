// Real save services in an isolated host and a unique temporary directory. Never touches player saves.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode||UnityEditor.EditorApplication.isCompiling)
    throw new System.Exception("Idle Edit Mode required");
var folder=System.IO.Path.Combine(System.IO.Path.GetTempPath(),"project-y-birth-"+System.Guid.NewGuid().ToString("N"));
System.IO.Directory.CreateDirectory(folder);
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();var root=new GameObject("CharacterBirthSaveValidation");
UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
var host=root.AddComponent<ProjectY.UI.UIHost>();host.Initialize();var oldTime=Time.timeScale;var oldRandom=UnityEngine.Random.state;
try
{
    using(var lua=new XLua.LuaEnv())
    {
        var services=new ProjectY.FrameworkServices(host,System.IO.Path.Combine(folder,"new-world.json"));
        var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);
        System.Action<ProjectY.Data.CharacterSaveService,ProjectY.Data.AdventureData,ProjectY.Data.PlayerData> legacy=(current,data,player)=>{
            var oldData=new ProjectY.Data.AdventureData();oldData.Reset(633);
            oldData.Equipment.Grid.Configure(8,6);
            var actor=oldData.AddPartyActor(91,1);
            ProjectY.Data.CharacterBirthState.UseTemplate(actor);
            actor.Growth.Initialize(39,2,2,2);actor.Growth.JoinProfession(1);actor.Growth.UnlockTree(1);actor.Growth.GrantSkill(401);
            ProjectY.Data.CharacterBirthState.AssignProfession(actor,1,new string[0],new int[0]);
            actor.SetMaxHP(46);actor.Restore();
            var appearances=new ProjectY.Data.CharacterAppearanceService();appearances.Apply(actor,data.GetPartyAt(0).CustomizationJson);
            var path=System.IO.Path.Combine(folder,"legacy-party.json");var service=new ProjectY.Data.CharacterSaveService(appearances,path);
            service.Save(oldData,player);
            var type=typeof(ProjectY.Data.CharacterSaveService).Assembly.GetType("ProjectY.Data.CharacterSaveDocument");
            var document=JsonUtility.FromJson(System.IO.File.ReadAllText(path),type);
            var flags=System.Reflection.BindingFlags.Public|System.Reflection.BindingFlags.Instance;
            type.GetField("version",flags).SetValue(document,23);
            var rows=(System.Array)type.GetField("actors",flags).GetValue(document);
            foreach(var row in rows)
            {
                row.GetType().GetField("initialAttributes",flags).SetValue(row,null);
                row.GetType().GetField("professionAttributes",flags).SetValue(row,null);
            }
            System.IO.File.WriteAllText(path,JsonUtility.ToJson(document));
            var prepared=service.Prepare(oldData.Equipment);var restored=prepared.GetActorAt(0);
            if(!restored.InitialAttributesAssigned||restored.HasInitialAttributes||restored.InitialProfessionId!=0||
                restored.Growth.CurrentProfessionId!=1||restored.Growth.ProfessionCount!=1||!restored.Growth.HasSkill(401)||restored.MaxHP!=46||restored.HP!=46||
                !restored.HasProfessionAttributes(1)||restored.GetProfessionAttributeCount(1)!=0)
                throw new System.Exception("Legacy party changed its original template attributes, profession or health");
            if(current.FilePath==path)throw new System.Exception("Legacy fixture replaced the active test slot");
        };
        lua.Global.Set("Services",services);lua.Global.Set("CheckBirthLegacy",legacy);
        try{return new {report=lua.DoString(System.IO.File.ReadAllText("Tools/Tests/character_birth_save_integration.lua"),"@Tools/Tests/character_birth_save_integration.lua")[0],temporaryDirectory=folder};}
        finally
        {
            lua.DoString("if CloseCharacterBirthSaveTesting then CloseCharacterBirthSaveTesting() end");
            lua.Global.Set<string,object>("CheckBirthLegacy",null);lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();
        }
    }
}
catch(System.Exception error){throw new System.Exception("Birth save validation failed; temporary artifacts: "+folder+"\n"+error,error);}
finally
{
    host.Shutdown();Time.timeScale=oldTime;UnityEngine.Random.state=oldRandom;
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
    // Return the unique directory to the caller for bounded, non-recursive cleanup of these test files.
}
