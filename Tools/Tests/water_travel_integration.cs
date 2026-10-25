// Execute once in the existing idle Editor after the coordinated compilation.
// Isolated Data + LuaEnv; no scene, generated assets, persistent player files, or Play Mode.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.Exception("Idle Edit Mode required");
var data = new ProjectY.Data.AdventureData(); data.Reset(91);
for (int id = 1; id <= 2; id++) { var actor = data.AddPartyActor(id, 1); actor.SetMaxHP(30); actor.Restore(); }
data.Equipment.Grid.Configure(4, 4); data.Equipment.Grid.Define(83, 1, 1); data.Equipment.AddStack(83, 1);
var player = new ProjectY.Data.PlayerData(); player.AddCoins(40);
var flags = System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.Static |
    System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic;
System.Func<object, object> clone = value => UnityEngine.JsonUtility.FromJson(UnityEngine.JsonUtility.ToJson(value), value.GetType());
System.Action<object, string, object> set = (value, name, content) => value.GetType().GetField(name, flags).SetValue(value, content);
System.Func<object, string, object> get = (value, name) => value.GetType().GetField(name, flags).GetValue(value);
var waterType = typeof(ProjectY.Data.WaterTravelData); var travelType = typeof(ProjectY.Data.WorldTravelData);
var expeditionType = waterType.Assembly.GetType("ProjectY.Data.ExpeditionSave", true);
System.Func<ProjectY.Data.AdventureData, string, ProjectY.Data.PreparedCharacterSave> candidate = (owner, defect) => {
    // The candidate includes only fields used by the water map validator. The subsystem's real
    // Capture/Prepare methods and JsonUtility still run; this is not a full CharacterSaveService test.
    var waterSave = clone(waterType.GetMethod("Capture", flags).Invoke(ProjectY.Data.WaterTravelData.For(owner), null));
    var travelSave = clone(travelType.GetMethod("Capture", flags).Invoke(ProjectY.Data.WorldTravelData.For(owner), null));
    if (defect == "wrong_endpoint") {
        var route = (System.Array)get(travelSave, "route");
        var shorter = System.Array.CreateInstance(route.GetType().GetElementType(), route.Length - 1);
        System.Array.Copy(route, shorter, shorter.Length); set(travelSave, "route", shorter);
    }
    else if (defect == "missing_dock") {
        var docks = (System.Array)get(waterSave, "docks");
        var shorter = System.Array.CreateInstance(docks.GetType().GetElementType(), docks.Length - 1);
        System.Array.Copy(docks, shorter, shorter.Length); set(waterSave, "docks", shorter);
    }
    else if (defect == "wrong_boat_dock") set(waterSave, "boatDock", 1);
    else if (defect != "valid") throw new System.ArgumentException("Unknown water fixture defect: " + defect);
    var preparedTravel = (ProjectY.Data.WorldTravelData)travelType.GetMethod("Prepare", flags).Invoke(null, new[] { travelSave });
    var preparedWater = (ProjectY.Data.WaterTravelData)waterType.GetMethod("Prepare", flags).Invoke(null, new object[] { waterSave, preparedTravel });
    var expedition = System.Activator.CreateInstance(expeditionType, true);
    set(expedition, "generationVersion", 9); set(expedition, "waterTravel", waterSave); set(expedition, "travel", travelSave); set(expedition, "preparedWater", preparedWater);
    var result = new ProjectY.Data.PreparedCharacterSave(); set(result, "Expedition", expedition); set(result, "PreparedTravel", preparedTravel);
    return result;
};
using (var lua = new XLua.LuaEnv()) {
    var loader = new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot); lua.AddLoader(loader.Load);
    lua.Global.Set("WaterFixtureAdventure", data); lua.Global.Set("WaterFixturePlayer", player); lua.Global.Set("MakeWaterCandidate", candidate);
    try {
        return lua.DoString(System.IO.File.ReadAllText("Tools/Tests/water_travel_integration.lua"), "@Tools/Tests/water_travel_integration.lua")[0];
    }
    finally {
        lua.Global.Set<string, object>("MakeWaterCandidate", null);
        lua.Global.Set<string, object>("WaterFixtureAdventure", null); lua.Global.Set<string, object>("WaterFixturePlayer", null);
        player.ClearListeners();
    }
}
