if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)throw new System.Exception("Idle Edit Mode required");
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var root=new GameObject("WorldPartiesValidation");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
var host=root.AddComponent<ProjectY.UI.UIHost>();host.Initialize();var scale=Time.timeScale;
string path=System.IO.Path.Combine(System.IO.Path.GetTempPath(),"project-y-world-parties-"+System.Guid.NewGuid().ToString("N")+".json");
try
{
    using(var lua=new XLua.LuaEnv())
    {
        var services=new ProjectY.FrameworkServices(host,path);var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);
        lua.AddLoader(loader.Load);lua.Global.Set("Services",services);lua.Global.Set("OpenDemo",false);
        lua.Global.Set("ShopFont",UnityEditor.AssetDatabase.LoadAssetAtPath<Font>("Assets/DynamicAsset/UI/Fonts/NotoSansCJKsc-Regular.otf"));
        try
        {
            string result=(string)lua.DoString(System.IO.File.ReadAllText("Tools/Tests/world_parties_chase.lua"),"@Tools/Tests/world_parties_chase.lua")[0];

            using(var snapshot=(XLua.LuaTable)lua.DoString("return require('Main'):Get('Adventure'):Snapshot()")[0])
            {
                var view=ProjectY.Samples.AdventureViewData.Read(snapshot);
                var editorScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
                ProjectY.Samples.AdventureRuntimeDemo demo=null;
                foreach(var obj in editorScene.GetRootGameObjects())foreach(var item in obj.GetComponentsInChildren<ProjectY.Samples.AdventureRuntimeDemo>(true))demo=item;
                var flags=System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Instance;
                var bindings=typeof(ProjectY.Samples.AdventureRuntimeDemo).GetField("worldPartyBindings",flags).GetValue(demo);
                var type=typeof(ProjectY.Samples.AdventureRuntimeDemo).Assembly.GetType("ProjectY.Samples.WorldPartyView");
                var renderer=System.Activator.CreateInstance(type,new object[]{root.transform,bindings,1f});
                try{
                    type.GetMethod("Sync").Invoke(renderer,new object[]{view});
                    type.GetMethod("Tick").Invoke(renderer,new object[]{view.Travel.Position,1f});
                    var pieces=(GameObject)type.GetField("root",flags).GetValue(renderer);
                    if(pieces.transform.childCount!=view.WorldParties.Rows.Length+1 || !pieces.activeSelf)throw new System.Exception("World pieces differ from snapshot");
                    var cameraObject=new GameObject("PickingCamera",typeof(Camera));cameraObject.transform.SetParent(root.transform,false);
                    var camera=cameraObject.GetComponent<Camera>();camera.enabled=false;camera.orthographic=true;camera.orthographicSize=8;
                    var party=view.WorldParties.Rows[0];camera.transform.position=party.Position+new Vector3(0,12,-12);camera.transform.LookAt(party.Position);
                    var screen=camera.WorldToScreenPoint(party.Position+Vector3.up*.675f);
                    int hit=(int)type.GetMethod("Pick").Invoke(renderer,new object[]{camera,new Vector2(screen.x,screen.y)});
                    if(hit!=party.Id)throw new System.Exception("Visible party could not be picked");
                    view.Phase="area";type.GetMethod("Sync").Invoke(renderer,new object[]{view});if(pieces.activeSelf)throw new System.Exception("World pieces remain in local area");
                    result+="\nPASS production C# snapshot, authored models, picking, and world/area visibility";
                }finally{((System.IDisposable)renderer).Dispose();}
            }

            System.IO.File.WriteAllText("Art/WorldPartyLowPoly/Integration/presentation-validation.txt",result+"\nTemporary save: "+path);return result;
        }
        finally
        {
            using(var shutdown=lua.Global.Get<XLua.LuaFunction>("GameShutdown"))if(shutdown!=null)shutdown.Call();
            lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();
        }
    }
}
finally{host.Shutdown();UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);Time.timeScale=scale;}
