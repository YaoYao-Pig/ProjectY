// Run through Unity MCP execute_code in the existing non-Play editor.
if (UnityEditor.EditorApplication.isPlaying) throw new System.InvalidOperationException("Audio check requires Edit Mode.");
var scene = UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
var owner = new UnityEngine.GameObject("Audio validation owner");
UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(owner, scene);
ProjectY.Audio.GameAudioService service = null;
var keys = new[] { "ProjectY.Audio.Master", "ProjectY.Audio.Music", "ProjectY.Audio.Effects" };
var hadKeys = new bool[3]; var oldValues = new float[3];
for (int i = 0; i < 3; i++) { hadKeys[i] = UnityEngine.PlayerPrefs.HasKey(keys[i]); oldValues[i] = UnityEngine.PlayerPrefs.GetFloat(keys[i]); }
System.Action<bool,string> check = (valid,message) => { if (!valid) throw new System.Exception(message); };
var evidence = new System.Collections.Generic.List<string>();
try
{
    var folder = "Assets/GameFramework/Resources/Audio/";
    var assets = UnityEditor.AssetDatabase.FindAssets("t:AudioClip", new[] { folder.TrimEnd('/') });
    check(assets.Length == 8, "Expected two music clips and six impact variants.");
    foreach (var guid in assets)
    {
        var path = UnityEditor.AssetDatabase.GUIDToAssetPath(guid);
        var clip = UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.AudioClip>(path);
        var importer = (UnityEditor.AudioImporter)UnityEditor.AssetImporter.GetAtPath(path);
        var settings = importer.defaultSampleSettings;
        bool music = path.Contains("/Music/");
        check(clip.length > 0 && clip.frequency == 44100, "Invalid audio content: " + path);
        check(settings.loadType == (music ? UnityEngine.AudioClipLoadType.Streaming : UnityEngine.AudioClipLoadType.DecompressOnLoad), "Wrong loading policy: " + path);
        check(settings.preloadAudioData == !music && importer.forceToMono == !music, "Wrong preload/mono policy: " + path);
        evidence.Add(clip.name + ": " + clip.length.ToString("F3") + "s, " + settings.loadType);
    }
    service = new ProjectY.Audio.GameAudioService(owner.transform);
    var voices = owner.GetComponentsInChildren<UnityEngine.AudioSource>();
    check(voices.Length == 18, "Audio voice pool must stay at 18 sources.");
    foreach (var voice in voices) check(!voice.playOnAwake && voice.spatialBlend == 0 && !voice.isPlaying, "Edit Mode must remain silent and sources must be 2D.");
    var exploration = System.Array.Find(voices, voice => voice.loop && voice.clip.name == "old_tower_inn_loop");
    var battle = System.Array.Find(voices, voice => voice.loop && voice.clip.name == "determined_pursuit_loop");
    service.SetVolumes(.8f,.45f,.8f);
    service.SetMusic("exploration"); service.Tick(1.25f);
    check(exploration.volume > .25f && battle.volume == 0, "Exploration fade did not settle.");
    service.SetMusic("battle"); service.Tick(.5f);
    float before = exploration.volume;
    check(battle.volume > 0 && before > 0, "Crossfade needs both voices.");
    service.SetMusic("exploration"); service.Tick(0);
    check(UnityEngine.Mathf.Approximately(before, exploration.volume), "Interrupted fade must not jump.");
    service.Tick(.25f);
    check(exploration.volume > before, "Interrupted fade did not reverse.");
    service.SetMusic("exploration"); service.Tick(1.25f);
    before = exploration.volume; service.SetMusic("exploration"); service.Tick(.1f);
    check(UnityEngine.Mathf.Approximately(before, exploration.volume), "Repeated cue restarted fade.");
    service.SetMusic("battle"); service.SetPaused(true); service.Tick(2);
    check(UnityEngine.Mathf.Approximately(before, exploration.volume), "Paused fade advanced.");
    service.SetPaused(false); service.Tick(1.25f);
    check(exploration.volume == 0 && battle.volume > 0, "Resume did not complete fade.");
    service.PlayEffect("hit"); service.PlayEffect("hit"); service.PlayEffect("hurt");
    check(service.HasActiveEffects, "Playing impact tails must keep final-hit presentation alive.");
    var active = System.Array.FindAll(voices, voice => !voice.loop && voice.clip != null);
    check(active.Length == 2, "Same-frame duplicate effects exceeded cooldown.");
    var first = System.Array.Find(active, voice => voice.clip.name.Contains("Metal")).clip;
    service.Tick(1);
    service.PlayEffect("hit");
    var second = System.Array.Find(voices, voice => !voice.loop && voice.clip != null).clip;
    check(first != second, "Consecutive variants repeated.");
    service.StopEffects();
    check(!service.HasActiveEffects, "Stopped effects still report an active tail.");
    check(System.Array.FindAll(voices, voice => !voice.loop && voice.clip != null).Length == 0, "StopEffects left an active clip.");
    service.SetVolumes(0,.45f,.8f); service.PlayEffect("hurt");
    foreach (var voice in voices) check(voice.volume == 0 || (!voice.loop && voice.clip == null), "Master mute did not apply.");
    check(UnityEngine.Mathf.Approximately(UnityEngine.PlayerPrefs.GetFloat(keys[0]),0), "Volume preference was not saved.");
    using (var lua = new XLua.LuaEnv())
    {
        using (var snapshot = (XLua.LuaTable)lua.DoString("return {audioEvents={{shot=3,critical=true}}}")[0])
        {
            var rows = ProjectY.Samples.BattleAudioEvent.Read(snapshot);
            check(rows.Length == 1 && rows[0].Shot == 3 && rows[0].Critical, "Real xLua audio snapshot bridge failed.");
        }
    }
    // Exercise the actual demo queue and modal gate using a tiny real Lua bridge.
    // No GameBootstrap.Awake/Start, game world, or Play Mode is invoked.
    service.StopEffects();
    var hostObject = new UnityEngine.GameObject("Audio bridge validation");
    UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(hostObject, scene);
    var host = hostObject.AddComponent<ProjectY.GameBootstrap>();
    var demo = hostObject.AddComponent<ProjectY.Samples.AdventureRuntimeDemo>();
    var flags = System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic;
    System.Action<object,string,object> field = (target,name,value) => target.GetType().GetField(name,flags).SetValue(target,value);
    var services = new ProjectY.FrameworkServices(null);
    typeof(ProjectY.FrameworkServices).GetProperty("Audio",flags).SetValue(services,service,null);
    field(host,"services",services); field(demo,"bootstrap",host);
    using (var lua = new XLua.LuaEnv())
    using (var query = (XLua.LuaFunction)lua.DoString("return function() end")[0])
    {
        field(host,"lua",lua); field(host,"configQuery",query);
        lua.DoString("syncCount=0; package.preload['UI.AdventureUIBridge']=function() return function(command) assert(command=='sync');syncCount=syncCount+1 end end");
        try
        {
            var snapshot = new ProjectY.Samples.AdventureViewData {
                Phase="result", AudioEvents=new[] {new ProjectY.Samples.BattleAudioEvent{Shot=1},new ProjectY.Samples.BattleAudioEvent{Shot=3,Critical=true}}
            };
            field(demo,"view",snapshot);
            var queue = demo.GetType().GetMethod("QueueBattleAudio",flags);
            var tick = demo.GetType().GetMethod("TickBattleAudio",flags);
            var update = demo.GetType().GetMethod("Update",flags);
            queue.Invoke(demo,new object[]{snapshot,0f});
            check(snapshot.AudioEvents.Length==0,"A consumed snapshot must not enqueue its hits again.");
            tick.Invoke(demo,new object[]{.01f});
            check(System.Array.FindAll(voices,voice=>!voice.loop && voice.clip!=null).Length==2,"First settled hit did not play both layers.");
            service.Tick(.25f); tick.Invoke(demo,new object[]{.2f});
            check(!service.HasActiveEffects,"Missed shot gap was collapsed.");
            tick.Invoke(demo,new object[]{.2f});
            check(service.HasActiveEffects,"Final shot did not survive the burst gap.");
            field(demo,"settlementPresentationPending",true);
            field(demo,"equipmentOpen",true); field(demo,"storyOpen",true);
            update.Invoke(demo,null);
            check(lua.Global.Get<int>("syncCount")==0,"Settlement opened before the hit tail finished.");
            service.Tick(1f);
            update.Invoke(demo,null);
            check(lua.Global.Get<int>("syncCount")==1,"Equipment/story pause gate swallowed final settlement audio.");
            check(!(bool)demo.GetType().GetField("settlementPresentationPending",flags).GetValue(demo),"Settlement remained blocked.");
        }
        finally
        {
            field(host,"configQuery",null); field(host,"lua",null); field(host,"services",null);
            UnityEngine.Object.DestroyImmediate(hostObject);
        }
    }
    bool rejected = false;
    try { service.SetMusic("missing"); } catch (System.ArgumentException) { rejected = true; }
    check(rejected, "Unknown cues must be rejected.");
    service.Dispose(); service.Dispose();
    check(owner.transform.childCount == 0, "Audio objects leaked after disposal.");
    evidence.Add("PASS: imports, 18 voices, silent Edit Mode, fade/reversal, repeated cue, pause/resume, cooldown, variant selection, mute/preferences, real xLua snapshot, actual burst queue, settlement modal gate, disposal.");
    return evidence;
}
finally
{
    if (service != null) service.Dispose();
    for (int i = 0; i < 3; i++)
    {
        if (hadKeys[i]) UnityEngine.PlayerPrefs.SetFloat(keys[i],oldValues[i]);
        else UnityEngine.PlayerPrefs.DeleteKey(keys[i]);
    }
    UnityEngine.PlayerPrefs.Save();
    UnityEngine.Object.DestroyImmediate(owner);
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
}
