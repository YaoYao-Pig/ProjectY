// Unity MCP execute_code body; execute only after SyncWorkbenchSlots in existing idle Edit Mode.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Idle Edit Mode required");
var originalScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();var originalDirty=originalScene.isDirty;
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
ProjectY.UI.UIHost host=null;object result;
try
{
    var root=new UnityEngine.GameObject("WorkbenchFourSlotsValidation");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,scene);
    host=root.AddComponent<ProjectY.UI.UIHost>();host.Initialize();
    System.Action<ProjectY.UI.EquipmentWorkbenchView,int> check=(view,count)=>
    {
        var layout=view.EditorLayout;
        if(layout.Sockets.Length!=4 || layout.SocketDots.Length!=4 || layout.SocketLeads.Length!=4 || layout.SocketTails.Length!=4)
            throw new System.Exception("Four-slot serialized layout is missing");
        view.Arrange();UnityEngine.Canvas.ForceUpdateCanvases();view.RenderPreview();
        var reference=view.GetComponent<ProjectY.UI.LuaReference>();
        for(int i=0;i<4;i++)
        {
            if(layout.Sockets[i]==null || layout.SocketDots[i]==null || layout.SocketLeads[i]==null || layout.SocketTails[i]==null)
                throw new System.Exception("A serialized socket/callout reference is missing");
            if(reference.GetButton("Socket"+(i+1)).transform!=layout.Sockets[i] || reference.GetText("SocketText"+(i+1)).transform.parent!=layout.Sockets[i])
                throw new System.Exception("Socket LuaReference and layout disagree");
            foreach(var node in new[]{layout.Sockets[i],layout.SocketDots[i],layout.SocketLeads[i],layout.SocketTails[i]})
                if(node.gameObject.activeSelf!=(i<count))throw new System.Exception("Old socket or leader remains visible after weapon switch");
        }
        for(int i=0;i<count;i++)for(int j=i+1;j<count;j++)
        {
            var a=layout.Sockets[i];var b=layout.Sockets[j];
            if(UnityEngine.Mathf.Abs(a.anchoredPosition.x-b.anchoredPosition.x)<1 &&
                UnityEngine.Mathf.Abs(a.anchoredPosition.y-b.anchoredPosition.y)<(a.rect.height+b.rect.height)*.5f)
                throw new System.Exception("Same-side callout labels overlap");
        }
        var flags=System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic;
        foreach(var name in new[]{"socketPoints","labelHeights","sortedSockets"})
            if(((System.Array)view.GetType().GetField(name,flags).GetValue(view)).Length!=layout.Sockets.Length)
                throw new System.Exception("Callout working buffer capacity differs from authored layout");
    };
    using(var lua=new XLua.LuaEnv())
    {
        var services=new ProjectY.FrameworkServices(host,System.IO.Path.Combine(System.IO.Path.GetTempPath(),"workbench-unused-"+System.Guid.NewGuid()+".json"));
        var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);
        lua.Global.Set("Services",services);lua.Global.Set("CheckWorkbenchCallouts",check);
        try {result=lua.DoString(System.IO.File.ReadAllText("Tools/Tests/workbench_four_slots_integration.lua"),"@workbench_four_slots_integration")[0];}
        finally {lua.Global.Set<string,object>("CheckWorkbenchCallouts",null);lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();}
    }
}
finally
{
    if(host!=null)host.Shutdown();UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
}
if(UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=originalScene || originalScene.isDirty!=originalDirty)
    throw new System.Exception("Workbench validation changed the user's scene");
return result;
