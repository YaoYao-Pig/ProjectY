// Execute through Unity MCP in the existing idle Editor; each case has isolated services and UI.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Idle Edit Mode required");
var files=new[]{"Tools/Tests/battle_preparation_integration.lua","Tools/Tests/equipment_catalyst_integration.lua"};
var reports=new System.Collections.Generic.List<string>();
var temporary=System.IO.Path.Combine(System.IO.Path.GetTempPath(),"project-y-ux-foundation-"+System.Guid.NewGuid().ToString("N"));
System.IO.Directory.CreateDirectory(temporary);
reports.Add("fixture_directory="+temporary);
foreach(var file in files)
{
    var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
    var root=new UnityEngine.GameObject("FoundationValidation");
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
    var host=root.AddComponent<ProjectY.UI.UIHost>();
    var oldScale=UnityEngine.Time.timeScale;
    try
    {
        host.Initialize();
        using(var lua=new XLua.LuaEnv())
        {
            var savePath=System.IO.Path.Combine(temporary,System.IO.Path.GetFileNameWithoutExtension(file)+".json");
            var services=new ProjectY.FrameworkServices(host,savePath);
            var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);
            lua.Global.Set("Services",services);
            lua.Global.Set("OpenDemo",false);
            if(file.Contains("shop_"))lua.Global.Set("ShopFont",UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Font>("Assets/DynamicAsset/UI/Fonts/NotoSansCJKsc-Regular.otf"));
            lua.Global.Set("AppearanceFixtureJson",System.IO.File.ReadAllText("Art/PawnCustomization/Integration/web-example.json"));
            try
            {
                var values=lua.DoString(System.IO.File.ReadAllText(file),"@"+file);
                var summary="";
                foreach(var value in values) { if(value is string)summary+=(string)value; var disposable=value as System.IDisposable;if(disposable!=null)disposable.Dispose(); }
                reports.Add("PASS "+file+"\n"+summary);
            }
            catch(System.Exception error) { reports.Add("FAIL "+file+"\n"+error.ToString()); }
            finally
            {
                try { lua.DoString("if CloseGrowthPreview then CloseGrowthPreview() end; if CloseCharacterIntegrationFixture then CloseCharacterIntegrationFixture() end; if CloseNarrativeFixture then CloseNarrativeFixture() end; if GameShutdown then GameShutdown() end"); }
                catch(System.Exception cleanup) { reports.Add("FAIL cleanup "+file+"\n"+cleanup.ToString()); }
                lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();
            }
        }
    }
    catch(System.Exception error) { reports.Add("FAIL host "+file+"\n"+error.ToString()); }
    finally { host.Shutdown();UnityEngine.Time.timeScale=oldScale;UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene); }
}
var report=string.Join("\n",reports.ToArray());
System.IO.Directory.CreateDirectory("Docs/Previews/GameplayFoundation");
System.IO.File.WriteAllText("Docs/Previews/GameplayFoundation/integration-"+System.DateTime.UtcNow.ToString("yyyyMMdd-HHmmss")+".txt",report);
return report;
