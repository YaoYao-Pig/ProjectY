// Execute through Unity MCP in Edit Mode after SyncBodyDefaults and BuildPrefabs.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.Exception("Edit Mode required");
var active = UnityEngine.SceneManagement.SceneManager.GetActiveScene(); bool dirty = active.isDirty;
var scene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
try
{
    var camera = new GameObject("DefaultAppearanceCamera").AddComponent<Camera>();
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(camera.gameObject, scene);
    var light = new GameObject("DefaultAppearanceLight").AddComponent<Light>(); light.type = LightType.Directional;
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(light.gameObject, scene);
    var rig = UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/PawnLowPoly/PawnRig.prefab");
    var pawn = UnityEngine.Object.Instantiate(rig).GetComponent<ProjectY.Samples.PawnView>();
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(pawn.gameObject, scene);
    var custom = pawn.GetComponentInChildren<ProjectY.Samples.PawnCustomizationView>(true);
    var catalog = custom.Catalog;
    var paths = new System.Collections.Generic.Dictionary<int,string> {
        {1,"PawnLowPoly/Models/Pawn_Human"}, {15,"PawnLowPoly/Models/Pawn_HumanWarrior"},
        {19,"EquipmentDemo/Models/Equip_PawnCore"}, {17,"TownLowPoly/Models/NPC_Resident"},
        {18,"TownLowPoly/Models/NPC_Artisan"}, {2,"PawnLowPoly/Models/Pawn_Base"},
        {6,"PawnLowPoly/Models/Pawn_Helmet"}, {3,"PawnLowPoly/Models/Pawn_ArmorPlate"}, {201,"ForestAnimals/Models/Horse"}
    };
    System.Func<int,string,ProjectY.Samples.PawnAppearanceData.Part> part = (id,slot) =>
        new ProjectY.Samples.PawnAppearanceData.Part {Id=id,Slot=slot,Path="Assets/DynamicAsset/"+paths[id]+".fbx"};
    System.Func<int,ProjectY.Samples.PawnAppearanceData> appearance = id =>
        new ProjectY.Samples.PawnAppearanceData {TemplateId=id,Parts=new[]{part(id,"body"),part(2,"base")}};
    System.Func<ProjectY.Samples.PawnAppearanceData.Part,GameObject> resolve = p => UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>(p.Path);
    string defaults = JsonUtility.ToJson(catalog); int checkedBodies = 0;
    foreach (int id in new[]{1,15,19,17,18})
    {
        var value = appearance(id); pawn.ApplyAppearance(value,resolve);
        if (value.Customization != null) throw new System.Exception("Presentation mutated the input snapshot");
        if (JsonUtility.ToJson(custom.Current) != JsonUtility.ToJson(catalog.DefaultAppearance(id))) throw new System.Exception("Wrong default: "+id);
        if (!custom.Modules[0].enabled || custom.Modules[0].sharedMesh != catalog.GetPart(custom.Current.body).Mesh) throw new System.Exception("Legacy body still visible: "+id);
        var animator = pawn.GetComponentInChildren<Animator>();
        if (animator == null || !animator.avatar.isHuman || !animator.avatar.isValid) throw new System.Exception("Lost Humanoid: "+id);
        int revision=custom.Revision; pawn.ApplyAppearance(value,resolve);
        if(custom.Revision!=revision) throw new System.Exception("Default appearance changes on refresh");
        pawn.TickPresentation(.1f,2); pawn.TickPresentation(.1f,0); checkedBodies++;
    }
    var dressed=appearance(1);dressed.Parts=new[]{part(1,"body"),part(2,"base"),part(6,"head"),part(3,"chest")};
    pawn.ApplyAppearance(dressed,resolve);
    if (custom.Modules[2].enabled || custom.Modules[0].sharedMesh != catalog.BodyMesh(custom.Current.body,1)) throw new System.Exception("Default outfit bypassed fitted equipment/coverage");
    var explicitAppearance=appearance(17);explicitAppearance.Customization=catalog.Rules.Randomize(412,"elf","female");
    string explicitJson=JsonUtility.ToJson(explicitAppearance.Customization);pawn.ApplyAppearance(explicitAppearance,resolve);
    if(JsonUtility.ToJson(custom.Current)!=explicitJson) throw new System.Exception("Default overwrote explicit appearance");
    pawn.ApplyAppearance(appearance(201),resolve);
    if(custom.Current!=null || custom.gameObject.activeInHierarchy || pawn.GetComponentInChildren<Animator>()!=null) throw new System.Exception("Animal entered humanoid defaults");
    pawn.ApplyAppearance(appearance(18),resolve);
    if(custom.Current.body!="body_male_2") throw new System.Exception("Static-to-animated transition failed");
    var townRoot=new GameObject("TownAnimationFixture");UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(townRoot,scene);
    var layout=new ProjectY.Samples.MapAreaViewData {AreaType=2,Radius=1.5f,
        Cells=new[]{new ProjectY.Samples.MapAreaViewData.Cell {Position=Vector3.zero,Corners=new float[6]},
                    new ProjectY.Samples.MapAreaViewData.Cell {Position=new Vector3(2.5980762f,0,0),Corners=new float[6]}},
        Npcs=new[]{new ProjectY.Samples.MapAreaViewData.Npc {Id=71,Name="Resident",StepSeconds=1,Appearance=appearance(17)}}};
    using(var town=new ProjectY.Samples.TownNpcRenderer(townRoot.transform,rig.GetComponent<ProjectY.Samples.PawnView>(),layout,resolve))
    {
        var state=new ProjectY.Samples.MapAreaViewData.State {Npcs=new[]{new ProjectY.Samples.MapAreaViewData.NpcState {Id=71,CellIndex=0,Present=true}}};
        town.SetState(state,layout);var townCustom=townRoot.GetComponentInChildren<ProjectY.Samples.PawnCustomizationView>();
        var rotations=townCustom.Bones.Select(b=>b.localRotation).ToArray();var before=town.Position(71);
        state.Npcs[0].CellIndex=1;town.SetState(state,layout);town.Tick(.15f);
        if(Vector3.Distance(before,town.Position(71))<.01f || !townCustom.Bones.Where((b,i)=>Quaternion.Angle(rotations[i],b.localRotation)>.01f).Any())
            throw new System.Exception("Town movement did not drive the humanoid animation");
        var paused=town.Position(71);rotations=townCustom.Bones.Select(b=>b.localRotation).ToArray();town.Tick(0);
        if(town.Position(71)!=paused || townCustom.Bones.Where((b,i)=>Quaternion.Angle(rotations[i],b.localRotation)>.001f).Any())
            throw new System.Exception("Paused town advanced animation");
    }
    if(JsonUtility.ToJson(catalog)!=defaults) throw new System.Exception("Runtime mutated the default catalog");
    if(UnityEngine.SceneManagement.SceneManager.GetActiveScene()!=active || active.isDirty!=dirty) throw new System.Exception("Changed current scene");
    return "PASS: "+checkedBodies+" default bodies, stable refresh, explicit priority, fitted armor/helmet, animal isolation, town walking/pause, shared Humanoid and scene preservation";
}
finally { UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene); }
