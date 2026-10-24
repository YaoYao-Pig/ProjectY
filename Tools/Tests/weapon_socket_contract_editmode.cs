// Unity MCP execute_code body. Existing idle Editor only; isolated PreviewScene, real Lua/DTO/WeaponModelView.Apply.
// Does not compile, refresh assets, save prefabs, enter Play, open a game world or write a player save.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Idle Edit Mode required");
var originalScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
bool originalDirty=originalScene.isDirty;float originalTimeScale=UnityEngine.Time.timeScale;
var preview=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var root=new UnityEngine.GameObject("WeaponSocketContractValidation");
UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(root,preview);
var host=root.AddComponent<ProjectY.UI.UIHost>();
var temporary=System.IO.Path.Combine(System.IO.Path.GetTempPath(),"ProjectY-WeaponSockets-"+System.Guid.NewGuid().ToString("N"),"unused.json");
var snapshots=new System.Collections.Generic.Dictionary<int,ProjectY.Samples.EquipmentVisualData.Weapon[]>();
var configuredIds=new System.Collections.Generic.Dictionary<int,int[]>();
var counts=new System.Collections.Generic.Dictionary<int,int>();
var catalog=UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.Samples.EquipmentAssetCatalog>(ProjectY.Editor.EquipmentAssets.CatalogPath);
System.Action<bool,string> check=(valid,message)=>{if(!valid)throw new System.InvalidOperationException(message);};
int weaponCount=0,nonemptyCount=0,attachmentCount=0,applyCount=0,switchCount=0;
UnityEngine.GameObject visible=null;
ProjectY.Samples.WeaponModelView visibleView=null;
int visibleAsset=0;string visiblePath=null;
var flags=System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic;
var mountsField=typeof(ProjectY.Samples.WeaponModelView).GetField("mounts",flags);
var attachmentsField=typeof(ProjectY.Samples.WeaponModelView).GetField("attachments",flags);
try
{
    check(catalog!=null && mountsField!=null && attachmentsField!=null,"Native equipment catalog or socket fields are unavailable");
    host.Initialize();
    using(var lua=new XLua.LuaEnv())
    {
        var services=new ProjectY.FrameworkServices(host,temporary);
        var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
        try
        {
            var values=lua.DoString(System.IO.File.ReadAllText("Tools/Tests/weapon_socket_contract_integration.lua"),"@Tools/Tests/weapon_socket_contract_integration.lua");
            using(var result=(XLua.LuaTable)values[0])
            using(var rows=result.Get<XLua.LuaTable>("rows"))
            {
                weaponCount=result.Get<int>("weaponCount");nonemptyCount=result.Get<int>("nonemptyCount");attachmentCount=result.Get<int>("attachmentCount");
                check(rows.Length==weaponCount && weaponCount>=57,"The fixture omitted configured weapons");
                for(int index=1;index<=rows.Length;index++)using(var row=rows.Get<int,XLua.LuaTable>(index))
                {
                    int id=row.Get<int>("id");
                    using(var ids=row.Get<XLua.LuaTable>("socketIds"))
                    {
                        var declared=new int[ids.Length];for(int offset=0;offset<declared.Length;offset++)declared[offset]=ids.Get<int,int>(offset+1);
                        configuredIds.Add(id,declared);
                    }
                    var stages=new ProjectY.Samples.EquipmentVisualData.Weapon[3];
                    var keys=new[]{"empty","attached","cleared"};
                    for(int stage=0;stage<keys.Length;stage++)using(var visual=row.Get<XLua.LuaTable>(keys[stage]))stages[stage]=ProjectY.Samples.EquipmentVisualData.Weapon.Read(visual);
                    snapshots.Add(id,stages);counts.Add(id,row.Get<int>("attachmentCount"));
                    check(stages[0].Model.Id==row.Get<int>("assetId") && stages[0].Model.Path==row.Get<string>("prefabPath"),"Real DTO lost the configured model identity: "+id);
                }
            }
        }
        finally {lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();}
    }

    System.Action<int,int> apply=(itemId,stage)=>
    {
        var dto=snapshots[itemId][stage];var expected=configuredIds[itemId];
        var prefab=catalog.Resolve(dto.Model);
        check(UnityEditor.AssetDatabase.GetAssetPath(prefab)==dto.Model.Path,"Catalog path differs from DTO: "+itemId);
        if(visible==null || visibleAsset!=dto.Model.Id || visiblePath!=dto.Model.Path)
        {
            if(visible!=null)UnityEngine.Object.DestroyImmediate(visible);
            visible=UnityEngine.Object.Instantiate(prefab,root.transform,false);
            visibleView=visible.GetComponent<ProjectY.Samples.WeaponModelView>();
            check(visibleView!=null,"Weapon prefab lacks WeaponModelView: "+itemId);
            visibleAsset=dto.Model.Id;visiblePath=dto.Model.Path;switchCount++;
        }
        var mounts=(ProjectY.Samples.WeaponModelView.Mount[])mountsField.GetValue(visibleView);
        check(mounts!=null && mounts.Length==expected.Length && dto.Sockets.Length==expected.Length,
            "Weapon mount count differs from configured sockets: item="+itemId+", expected="+expected.Length+", native="+(mounts==null?-1:mounts.Length));
        var unique=new System.Collections.Generic.HashSet<int>();
        foreach(var mount in mounts)
        {
            check(mount!=null && unique.Add(mount.Id) && System.Array.IndexOf(expected,mount.Id)>=0,"Missing, duplicate, or foreign socket binding: "+itemId);
            check(mount.Anchor!=null && mount.Anchor.IsChildOf(visible.transform),"Socket anchor is missing or outside its prefab: "+itemId+"/"+mount.Id);
        }
        var old=(UnityEngine.GameObject[])attachmentsField.GetValue(visibleView);
        var before=old==null?null:(UnityEngine.GameObject[])old.Clone();
        visibleView.Apply(dto,catalog);applyCount++;
        var after=(UnityEngine.GameObject[])attachmentsField.GetValue(visibleView);
        check(after!=null && after.Length==expected.Length,"Apply allocated the wrong attachment slots: "+itemId);
        int attached=0;
        foreach(var socket in dto.Sockets)
        {
            int at=System.Array.FindIndex(mounts,m=>m.Id==socket.Id);
            var anchor=visibleView.Socket(socket.Id);
            check(anchor==mounts[at].Anchor && (anchor.localPosition-socket.Position).sqrMagnitude<.000001f
                && UnityEngine.Quaternion.Angle(anchor.localRotation,UnityEngine.Quaternion.Euler(socket.Rotation))<.01f,"Apply did not resolve the actual declared anchor: "+itemId+"/"+socket.Id);
            if(socket.Attachment==null)check(after[at]==null,"Empty socket retained an attachment: "+itemId+"/"+socket.Id);
            else {check(after[at]!=null && after[at].transform.parent==anchor,"Compatible attachment was not instantiated under its socket: "+itemId+"/"+socket.Id);attached++;}
        }
        check(attached==(stage==1?counts[itemId]:0),"Actual attachment count differs from the real inventory DTO: "+itemId);
        if(stage==2 && before!=null)foreach(var attachment in before)check(attachment==null,"Clearing a socket left its old object alive: "+itemId);
        // Applying the same snapshot again must reuse existing attachment objects and anchors.
        var stable=(UnityEngine.GameObject[])after.Clone();visibleView.Apply(dto,catalog);applyCount++;
        var repeated=(UnityEngine.GameObject[])attachmentsField.GetValue(visibleView);
        for(int index=0;index<stable.Length;index++)check(stable[index]==repeated[index],"Repeated Apply recreated a compatible attachment: "+itemId);
    };
    foreach(var pair in snapshots)
    {
        apply(pair.Key,0);apply(pair.Key,1);apply(pair.Key,2);
        if(pair.Key>=101 && pair.Key<=104)check(configuredIds[pair.Key].Length==0,"Starter weapon acquired a socket");
    }
    foreach(int id in new[]{40,101,40,101,616,102,616,102,1,103,1,103,70,104,70,104})
    {
        check(snapshots.ContainsKey(id),"Starter/source switch case is missing: "+id);
        apply(id,id>=101 && id<=104?0:1);
    }
    foreach(var pair in new[]{new[]{101,40},new[]{102,616},new[]{103,1},new[]{104,70}})
    {
        var starter=snapshots[pair[0]][0].Model;var source=snapshots[pair[1]][0].Model;
        check(starter.Id!=source.Id && starter.Path!=source.Path,"Zero-slot starter shares the slotted source wrapper: "+pair[0]);
    }
}
finally
{
    host.Shutdown();UnityEngine.Time.timeScale=originalTimeScale;
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(preview);
}
check(UnityEngine.SceneManagement.SceneManager.GetActiveScene()==originalScene && originalScene.isDirty==originalDirty,"Validation changed the user's active scene");
check(!System.IO.File.Exists(temporary),"Socket validation unexpectedly wrote a save");
return new {passed=true,weapons=weaponCount,nonemptyWeapons=nonemptyCount,compatibleAttachments=attachmentCount,
    actualApplyCalls=applyCount,prefabSwitches=switchCount,starterSourceSwitches=16,playMode=false};
