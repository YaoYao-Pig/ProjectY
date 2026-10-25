// Execute once in the existing idle Editor after the coordinated compilation.
// Uses isolated in-memory Data and JSON roundtrips, no scenes, Play Mode, or player files.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.Exception("Idle Edit Mode required");
var checks = new System.Collections.Generic.List<string>();
System.Action<bool, string> expect = (ok, message) => { if (!ok) throw new System.Exception(message); };
System.Action<System.Action, string> rejects = (action, message) => {
    try { action(); }
    catch (System.Exception error) {
        if (error is System.Reflection.TargetInvocationException) error = error.InnerException;
        if (error is System.InvalidOperationException || error is System.ArgumentException || error is System.IO.InvalidDataException) return;
        throw;
    }
    throw new System.Exception("Expected rejection: " + message);
};
var flags = System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.Static |
    System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic;
var capture = typeof(ProjectY.Data.WaterTravelData).GetMethod("Capture", flags);
var prepare = typeof(ProjectY.Data.WaterTravelData).GetMethod("Prepare", flags);
var commit = typeof(ProjectY.Data.WaterTravelData).GetMethod("TakePrepared", flags);
System.Func<object, object> clone = value => UnityEngine.JsonUtility.FromJson(UnityEngine.JsonUtility.ToJson(value), value.GetType());
System.Action<object, string, object> set = (value, name, content) => value.GetType().GetField(name, flags).SetValue(value, content);
var adventure = new ProjectY.Data.AdventureData(); adventure.Reset(41);
var water = ProjectY.Data.WaterTravelData.For(adventure);
var travel = ProjectY.Data.WorldTravelData.For(adventure); travel.Reset(41, 0, 0, 10);
var player = new ProjectY.Data.PlayerData(); player.AddCoins(100);
water.EnsureDock(1, true, 2); water.EnsureDock(2, false, 0); water.EnsureDock(3, false, 1);
expect(object.ReferenceEquals(water, ProjectY.Data.WaterTravelData.For(adventure)) && water.Count == 3, "Single adventure owner");
water.AcceptRepair(1); water.AcceptRepair(1);
var equipment = adventure.Equipment; equipment.Grid.Configure(4, 4); equipment.Grid.Define(83, 1, 1); equipment.AddStack(83, 3);
rejects(() => water.CompleteRepair(equipment, 1, 83, 2), "Threat blocks material deduction");
expect(equipment.CountItem(83) == 3 && water.GetDock(1).Damaged, "Failed repair preserved inventory and damage");
water.RecordKill(1, 2);
expect(!water.CompleteRepair(equipment, 1, 83, 4) && equipment.CountItem(83) == 3, "Insufficient materials do not mutate");
expect(water.CompleteRepair(equipment, 1, 83, 2) && water.GetDock(1).Ready && equipment.CountItem(83) == 1, "Repair consumes exact material amount");
rejects(() => water.CompleteRepair(equipment, 1, 83, 1), "Repeated repair");
expect(equipment.CountItem(83) == 1, "Repeated repair preserves inventory");
water.AcceptRepair(3); water.RecordKill(3, 1);
expect(water.GetDock(3).Ready && !water.GetDock(3).Accepted, "Threat-only dock opens immediately");
water.EnsureDock(1, true, 2);
expect(water.GetDock(1).Ready && water.Count == 3, "Rebinding does not undo restoration");
checks.Add("repair materials, threats and repeat safety");

expect(!water.Purchase(player, 101, 1, 1, 0) && !water.Owned && player.Coins == 100, "Insufficient boat price");
var notices = 0;
System.Action purchaseNotice = () => { notices++; expect(water.Owned && player.Coins == 40, "Purchase callback sees committed state"); };
player.AddChangedListener(purchaseNotice);
try { expect(water.Purchase(player, 60, 1, 1, 0), "Boat purchase"); }
finally { player.RemoveChangedListener(purchaseNotice); }
rejects(() => water.Purchase(player, 1, 2, 4, 0), "Duplicate boat purchase");
expect(notices == 1 && player.Coins == 40 && water.BoatQ == 1 && water.BoatDockId == 1, "Single charge and unchanged owned boat");
water.Board(1, 0); travel.Relocate(1, 0);
var revision = water.Revision; water.SyncBoat(1, 0);
expect(water.Revision == revision, "Same cell does not refresh water revision");
water.SyncBoat(2, 0); travel.Relocate(2, 0); water.Land(2, 0, 0); travel.Relocate(2, 1);
expect(water.Mode == "walk" && water.BoatDockId == 0 && water.BoatQ == 2 && water.BoatR == 0, "Wild landing leaves boat on water");
rejects(() => water.Board(2, 1), "Boarding the wrong cell");
checks.Add("purchase transaction, notification and persistent wild mooring");

expect(!water.BeginFerry(player, 41, 1, 2) && water.Mode == "walk" && player.Coins == 40, "Insufficient fare");
System.Action ferryNotice = () => { expect(water.Mode == "ferry" && water.FerryPaid == 10 && player.Coins == 30, "Fare callback sees committed trip"); };
player.AddChangedListener(ferryNotice);
try { expect(water.BeginFerry(player, 10, 1, 2), "Passenger fare"); }
finally { player.RemoveChangedListener(ferryNotice); }
rejects(() => water.BeginFerry(player, 10, 1, 2), "Repeated passenger confirmation");
expect(player.Coins == 30 && water.FerryTargetDockId == 2 && water.BoatQ == 2 && water.BoatR == 0, "Ticket confirmation never moves parked owned boat");
travel.Relocate(1, 0); travel.Plan(new[] { 2, 3 }, new[] { 0, 0 }, new[] { 4d, 4d }, 0); travel.Step(1); travel.SetPaused(true);
rejects(() => travel.Relocate(8, 8), "Paused underway relocation");
expect(travel.Q == 1 && travel.R == 0 && travel.Progress == .25 && travel.Paused, "Rejected relocation preserved paused route");
var travelSave = typeof(ProjectY.Data.WorldTravelData).GetMethod("Capture", flags).Invoke(travel, null);
var travelTwin = (ProjectY.Data.WorldTravelData)typeof(ProjectY.Data.WorldTravelData).GetMethod("Prepare", flags).Invoke(null, new[] { clone(travelSave) });
travel.DiscardEncounterTime();
expect(!travel.CheckDue(1) && travelTwin.CheckDue(1) && travel.StepCount == 2 && travel.Progress == .25 && travel.Paused &&
    travel.Q == 1 && travel.R == 0 && travel.Roll(1000) == travelTwin.Roll(1000), "Discarding water encounter time preserves route, elapsed time and random stream");
checks.Add("fare transaction and rejection while paused underway");

var saved = clone(capture.Invoke(water, null));
System.Func<object, ProjectY.Data.WaterTravelData> restore = row =>
    (ProjectY.Data.WaterTravelData)prepare.Invoke(null, new object[] { row, travel });
var prepared = restore(saved);
expect(prepared.Mode == "ferry" && prepared.FerryPaid == 10 && prepared.FerryTargetDockId == 2 && prepared.Owned &&
    prepared.BoatQ == 2 && prepared.BoatR == 0 && prepared.GetDock(1).Ready, "JSON preserves restoration, parked boat and paid trip");
expect(water.Mode == "ferry" && player.Coins == 30, "Preparing never mutates live state or charges a fare");
commit.Invoke(water, new object[] { prepared });
expect(object.ReferenceEquals(water, ProjectY.Data.WaterTravelData.For(adventure)) && water.Mode == "ferry" && player.Coins == 30,
    "Commit preserves Data identity and never recharges");
water.FinishFerry();
expect(water.Mode == "walk" && water.FerryPaid == 0 && water.FerryTargetDockId == 0 && water.BoatQ == 2, "Ferry completion keeps owned boat parked");
var bad = clone(saved); set(bad, "ferryTarget", 999);
rejects(() => restore(bad), "Unknown destination dock");
bad = clone(saved); set(bad, "mode", "owned"); set(bad, "ferryOrigin", 0); set(bad, "ferryTarget", 0); set(bad, "ferryPaid", 0);
rejects(() => restore(bad), "Aboard boat position differs from player travel");
bad = clone(saved); set(bad, "format", 99);
rejects(() => restore(bad), "Unknown water format");
var legacy = restore(null);
expect(legacy.Count == 0 && !legacy.Owned && legacy.Mode == "walk", "Legacy missing water record starts without a boat");
expect(water.Mode == "walk" && water.Owned && player.Coins == 30, "Bad candidates preserve live state");
checks.Add("JSON roundtrip, candidate validation, stable Data identity and legacy migration");
return "PASS water travel Data: " + string.Join("; ", checks.ToArray());
