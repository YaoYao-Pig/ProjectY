// Run after the centralized authorized compilation and equipment import. Isolated services, no Play or player saves.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Idle Edit Mode required");
var originalScene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();
bool originalDirty=originalScene.isDirty;float originalTimeScale=UnityEngine.Time.timeScale;
var preview=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var fixture=new UnityEngine.GameObject("ProfessionExpansionIntegration");
UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(fixture,preview);
var host=fixture.AddComponent<ProjectY.UI.UIHost>();
var temporary=System.IO.Path.Combine(System.IO.Path.GetTempPath(),"ProjectY-ProfessionExpansion-"+System.Guid.NewGuid().ToString("N"));
System.IO.Directory.CreateDirectory(temporary);
var reports=new System.Collections.Generic.List<string>();
System.Action<bool,string> check=(value,message)=>{if(!value)throw new System.InvalidOperationException(message);};
try
{
    host.Initialize();
    using(var lua=new XLua.LuaEnv())
    {
        var services=new ProjectY.FrameworkServices(host,System.IO.Path.Combine(temporary,"isolated-party.json"));
        var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
        try
        {
            var values=lua.DoString(System.IO.File.ReadAllText("Tools/Tests/profession_expansion_integration.lua"),"@Tools/Tests/profession_expansion_integration.lua");
            reports.Add((string)values[0]);
            using(var assets=(XLua.LuaTable)values[1])
            {
                check(assets.Length==12,"Weapon asset test must inspect exactly twelve new weapons");
                var catalog=UnityEditor.AssetDatabase.LoadAssetAtPath<ProjectY.Samples.EquipmentAssetCatalog>(ProjectY.Editor.EquipmentAssets.CatalogPath);
                check(catalog!=null,"Equipment catalog is missing");
                for(int index=1;index<=assets.Length;index++)using(var row=assets.Get<int,XLua.LuaTable>(index))
                {
                    int id=row.Get<int>("id"),assetId=row.Get<int>("assetId");
                    string modelPath=row.Get<string>("modelPath"),prefabPath=row.Get<string>("prefabPath"),iconPath=row.Get<string>("iconPath");
                    var model=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(modelPath);
                    var prefab=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.GameObject>(prefabPath);
                    check(model!=null && prefab!=null,"Imported model or prefab is missing for "+id);
                    check(System.IO.File.Exists(modelPath+".meta") && System.IO.File.Exists(prefabPath+".meta"),"Native asset metadata is missing for "+id);
                    check(!string.IsNullOrEmpty(UnityEditor.AssetDatabase.AssetPathToGUID(prefabPath)),"Prefab GUID is missing for "+id);
                    var filters=prefab.GetComponentsInChildren<UnityEngine.MeshFilter>(true);
                    check(filters.Length>0,"Weapon prefab has no mesh: "+id);
                    foreach(var filter in filters)check(filter.sharedMesh!=null && filter.sharedMesh.vertexCount>0,"Weapon contains an empty mesh: "+id);
                    foreach(var renderer in prefab.GetComponentsInChildren<UnityEngine.Renderer>(true))
                    {
                        check(renderer.sharedMaterials.Length>0,"Weapon renderer has no material: "+id);
                        foreach(var material in renderer.sharedMaterials)check(material!=null && material.shader!=null,"Weapon material or shader is missing: "+id);
                    }
                    var resolved=catalog.Resolve(new ProjectY.Samples.EquipmentVisualData.Asset {Id=assetId,Path=prefabPath});
                    check(resolved==prefab,"Runtime equipment catalog points to another prefab: "+id);
                    check(catalog.ItemIcon(id,iconPath)!=null,"Runtime weapon icon is missing: "+id);
                }
            }
            reports.Add("PASS twelve imported weapon prefabs, meshes, materials, GUIDs, icons and runtime catalog bindings");
        }
        finally {lua.Global.Set<string,object>("Services",null);services.Player.ClearListeners();}
    }

    // The new state adapters must preserve one physical animal through mode changes and the existing save DTO.
    var owner=new ProjectY.Data.CombatActorData(81,1);owner.SetMaxHP(80);owner.Restore();owner.Deploy(1,0,0);
    var animal=new ProjectY.Data.CombatActorData(82,201);animal.InitializeAnimal(1,31);animal.SetMaxHP(100);animal.Restore();animal.Deploy(3,1,0);
    owner.TameAndRide(animal,12);animal.Damage(7);ProjectY.Data.BodyHealth.Injure(animal,2,1,25);
    ProjectY.Data.AnimalCompanionState.SetMode(owner,true,2,0,2);
    check(owner.MountedAnimal==null && ProjectY.Data.AnimalCompanionState.Partner(owner)==animal,"Independent mode copied or lost the bound animal");
    check(ProjectY.Data.AnimalCompanionState.Independent(animal) && ProjectY.Data.AnimalCompanionState.Layer(animal)==2,"Companion mode or floor was lost");
    var flags=System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic;
    var capture=typeof(ProjectY.Data.CombatActorData).GetMethod("CaptureMount",flags);
    var restore=typeof(ProjectY.Data.CombatActorData).GetMethod("RestoreMount",flags);
    check(capture!=null && restore!=null,"Existing animal save API is unavailable");
    var saved=capture.Invoke(owner,null);
    var restoredOwner=new ProjectY.Data.CombatActorData(81,1);restoredOwner.SetMaxHP(80);restoredOwner.Restore();restoredOwner.Deploy(1,0,0);
    restore.Invoke(restoredOwner,new[]{saved});
    var restoredAnimal=ProjectY.Data.AnimalCompanionState.Partner(restoredOwner);
    check(restoredAnimal!=null && restoredAnimal.Id==animal.Id && restoredAnimal.HP==animal.HP && restoredAnimal.AnimalBond==12,"Save restore changed companion identity, HP, or bond");
    check(ProjectY.Data.AnimalCompanionState.Layer(restoredAnimal)==2 && ProjectY.Data.BodyHealth.Damage(restoredAnimal,2)==25,"Save restore lost companion layer or injury");
    ProjectY.Data.AnimalCompanionState.SetMode(owner,false,owner.Q,owner.R,0);
    check(owner.MountedAnimal==animal && animal.HP==93 && ProjectY.Data.BodyHealth.Damage(animal,2)==25,"Riding switch healed or replaced the companion");
    reports.Add("PASS same-animal mode switch and existing CaptureMount/RestoreMount preserve wounds, HP, bond and floor");

    // Real duel state and damage floor, without generating a map or entering the user's active adventure.
    var duel=new ProjectY.Data.AdventureData();duel.Reset(77);
    var fighter=duel.AddPartyActor(1,1);fighter.SetMaxHP(100);fighter.Restore();
    duel.Areas.Enter(1,4,1);duel.BeginArea(1);
    duel.Battle.Reset(1801,20);duel.Battle.AddUnit(fighter,1,0,0);
    var rival=duel.Battle.AddEnemy(501,4,1,0);rival.SetMaxHP(101);rival.Restore();
    ProjectY.Data.ProfessionDuelState.Begin(duel,fighter.Id,25);
    int limited=ProjectY.Data.ProfessionDuelState.Limit(duel,rival,999);
    check(limited==75,"Duel damage floor must round up one quarter of 101 HP to 26");
    rival.Damage(limited);
    check(rival.HP==26 && ProjectY.Data.ProfessionDuelState.Result(duel)=="victory","Duel did not recognize a living opponent's surrender");
    check(ProjectY.Data.ProfessionDuelState.Limit(duel,rival,999)==0,"Duel allowed further damage below surrender threshold");
    duel.Battle.Finish("victory");ProjectY.Data.ProfessionDuelState.Finish(duel,"Integration duel completed");
    check(duel.Phase=="area" && !ProjectY.Data.ProfessionDuelState.Active(duel) && rival.HP==26,"Duel finish did not clear its contract or preserve injuries");
    reports.Add("PASS real duel damage clamp, living surrender and clean return to area");
}
finally
{
    host.Shutdown();UnityEngine.Time.timeScale=originalTimeScale;
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(preview);
}
check(UnityEngine.SceneManagement.SceneManager.GetActiveScene()==originalScene && originalScene.isDirty==originalDirty,"Validation altered the user's active scene");
check(!System.IO.File.Exists(System.IO.Path.Combine(temporary,"isolated-party.json")),"Integration unexpectedly wrote a save");
return string.Join("\n",reports.ToArray());
