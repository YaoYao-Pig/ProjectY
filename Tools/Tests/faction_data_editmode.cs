// Execute once in the existing idle Editor after the coordinated project compilation.
// This script creates only in-memory Data, uses no scene, and never reads or writes a player save.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.Exception("Idle Edit Mode required");
var flags = System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic |
    System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.Static;
var checks = new System.Collections.Generic.List<string>();
System.Action<bool, string> expect = (ok, message) => { if (!ok) throw new System.Exception(message); };
System.Action<System.Action, string> rejects = (action, message) =>
{
    try { action(); }
    catch (System.Exception error)
    {
        if (error is System.Reflection.TargetInvocationException) error = error.InnerException;
        if (error is System.InvalidOperationException || error is System.ArgumentException || error is System.IO.InvalidDataException) return;
        throw;
    }
    throw new System.Exception("Expected rejection: " + message);
};
System.Func<object, string, object> field = (value, name) => value.GetType().GetField(name, flags).GetValue(value);
System.Action<object, string, object> set = (value, name, content) => value.GetType().GetField(name, flags).SetValue(value, content);
System.Func<object, object> clone = value => UnityEngine.JsonUtility.FromJson(UnityEngine.JsonUtility.ToJson(value), value.GetType());
var captureParties = typeof(ProjectY.Data.WorldPartiesData).GetMethod("Capture", flags);
var prepareParties = typeof(ProjectY.Data.WorldPartiesData).GetMethod("Prepare", flags);
var captureArea = typeof(ProjectY.Data.MapAreaStateData).GetMethod("Capture", flags);
var prepareArea = typeof(ProjectY.Data.MapAreaStateData).GetMethod("Prepare", flags);
var equipment = new ProjectY.Data.EquipmentData();
equipment.Grid.Define(101, 1, 1);
System.Func<object, ProjectY.Data.WorldPartiesData> restoreParties = row =>
    (ProjectY.Data.WorldPartiesData)prepareParties.Invoke(null, new object[] { row, equipment, new System.Collections.Generic.HashSet<int>(), null, new System.Collections.Generic.HashSet<int>() });
System.Func<object, ProjectY.Data.WorldPartiesData, System.Collections.Generic.HashSet<int>, ProjectY.Data.MapAreaStateData> restoreArea = (row, parties, attachedPartyIds) =>
    (ProjectY.Data.MapAreaStateData)prepareArea.Invoke(null, new object[] { row, equipment, null, new System.Collections.Generic.HashSet<int>(), new System.Collections.Generic.HashSet<int>(), parties, attachedPartyIds });

var data = new ProjectY.Data.WorldPartiesData();
var guard = data.Add(1, 0, 0, 1, 1); guard.ConfigureFaction(1, 0, 0, "garrison");
var raider = data.Add(2, 1, 0, 2, 2); raider.ConfigureFaction(2, 1, 0, "raider");
var outpostGuard = data.Add(2, 1, 0, 2, 3); outpostGuard.ConfigureFaction(2, 1, 0, "garrison");
var caravan = data.Add(1, 2, 0, 1, 4); caravan.ConfigureFaction(1, 2, 0, "caravan");
foreach (var party in new[] { guard, raider, outpostGuard, caravan })
{
    var actor = party.AddMember(1); actor.SetMaxHP(100); actor.Restore();
}
expect(guard.GetMemberAt(0).Id >= 1000000000 && caravan.GetMemberAt(0).Id > guard.GetMemberAt(0).Id, "Unique stable actor IDs");
var town = data.Factions.AddSite(1, 1, guard.Id, true, 100);
data.Factions.AddSite(2, 2, outpostGuard.Id, false, 50);
data.Factions.SetRelation(1, 2, -75, 10, "raid");
expect(object.ReferenceEquals(data.Factions.FindRelation(1, 2), data.Factions.FindRelation(2, 1)), "Symmetric diplomacy authority");
rejects(() => data.Factions.SetRelation(1, 2, 101, 11, "invalid"), "Relation bounds");
town.SetOccupation(2, raider.Id, 10);
town.AddReserve(10); town.SetRecoveryAt(500);
expect(town.OccupierId == 2 && town.LiberatedAt == -1, "Time and recovery must never liberate a settlement");
town.Liberate(600, 660);
expect(town.OccupierId == 0 && town.LiberatedAt == 600 && town.ProtectedUntil == 660, "Explicit liberation restores ownership");
expect(town.SpendReserve(20) && town.Reserve == 90 && !town.SpendReserve(100), "Finite recruitment reserve");
data.Factions.Complete(); data.Complete(10); data.CompleteFactionMigration();
checks.Add("diplomacy, occupation, liberation and reserve");

var travel = new ProjectY.Data.WorldTravelData(); travel.Reset(10, 0, 0, 2);
travel.Plan(new[] { 1 }, new[] { 0 }, new[] { 10d }, 0); travel.Step(3);
var outpost = travel.AddWorldStop(8, 1, 0, 1);
var battlefield = travel.AddWorldStop(2, 0, 0, 1);
expect(outpost.Id == 2 && battlefield.Id == 3 && travel.Q == 0 && travel.R == 0 && travel.Progress == .3 && !travel.Paused && travel.StepCount == 1,
    "Offscreen stops preserve player route, position, progress and pause state");
var conflict = data.Factions.AddConflict(3, caravan.Id, raider.Id, 10, 20, 100, 222);
conflict.SetTargetSite(1); data.EngageParty(caravan.Id, 3); data.EngageParty(raider.Id, 3);
var areas = new ProjectY.Data.MapAreaData();
areas.Enter(1, 20, 1);
var area = ProjectY.Data.FactionPersistence.Ensure(areas, 3, 20, 1);
ProjectY.Data.ExpeditionPersistence.Definition(area, 1);
ProjectY.Data.FactionPersistence.AttachParty(area.AddEncounter(1, 1), caravan);
ProjectY.Data.FactionPersistence.AttachParty(area.AddEncounter(2, 1), raider);
area.CompleteEncounterInitialization(); area.CompleteLootInitialization();
caravan.GetMemberAt(0).Damage(27);
expect(areas.ActiveSiteId == 1 && object.ReferenceEquals(area.GetEncounterAt(0).GetEnemyAt(0), caravan.GetMemberAt(0)), "Offscreen area and shared actors");
caravan.SetMission("intercept", raider.Id, 0, 25);
var save = clone(captureParties.Invoke(data, null));
var restored = restoreParties(save);
var areaSave = clone(captureArea.Invoke(area, null));
var groupSave = ((System.Array)field(areaSave, "encounters")).GetValue(0);
expect(((System.Array)field(groupSave, "actors")).Length == 0 && (int)field(groupSave, "partyId") == caravan.Id, "External group saves only party reference");
var attached = new System.Collections.Generic.HashSet<int>();
var restoredArea = restoreArea(areaSave, restored, attached);
expect(object.ReferenceEquals(restoredArea.GetEncounterAt(0).GetEnemyAt(0), restored.Find(caravan.Id).GetMemberAt(0)) && restored.Find(caravan.Id).GetMemberAt(0).HP == 73,
    "Roundtrip preserves single actor authority and wounds");
expect(restored.Factions.FindConflict(3).Roll(1000) == conflict.Roll(1000), "Conflict random stream resumes identically");
rejects(() => restoreArea(areaSave, restored, attached), "Duplicate attached party ownership");
var cachedFactions = restored.Factions;
typeof(ProjectY.Data.WorldPartiesData).GetMethod("TakePrepared", flags).Invoke(restored, new object[] { restoreParties(save) });
expect(object.ReferenceEquals(cachedFactions, restored.Factions) && cachedFactions.FindSite(1) != null, "Restore retains Lua-cached faction Data identity");
typeof(ProjectY.Data.WorldPartiesData).GetMethod("ValidateWorldReferences", flags).Invoke(restored,
    new object[] { 2, 3, new System.Collections.Generic.HashSet<int> { 3 } });
checks.Add("offscreen stops, shared actor persistence, conflict RNG and cached Data identity");

var bad = clone(save);
var badParties = (System.Array)field(bad, "parties");
var firstMember = ((System.Array)field(badParties.GetValue(0), "members")).GetValue(0);
var secondMember = ((System.Array)field(badParties.GetValue(1), "members")).GetValue(0);
set(secondMember, "id", field(firstMember, "id"));
rejects(() => restoreParties(bad), "Duplicate actor IDs");
bad = clone(save); set(bad, "clock", double.NaN);
rejects(() => restoreParties(bad), "Nonfinite world time");
bad = clone(save); var factionSave = field(bad, "factions");
set(((System.Array)field(factionSave, "sites")).GetValue(0), "guard", 9999);
rejects(() => restoreParties(bad), "Missing guard party");
bad = clone(areaSave); set(((System.Array)field(bad, "encounters")).GetValue(0), "partyId", 9999);
rejects(() => restoreArea(bad, restored, new System.Collections.Generic.HashSet<int>()), "Missing external party");
checks.Add("invalid duplicate actors, nonfinite time and dangling references rejected");

// Cargo is transferred once into the battlefield without changing the active player location.
var supply = data.Add(1, 2, 0, 1, 9); supply.ConfigureFaction(1, 2, 0, "caravan");
supply.AddMember(1);
supply.SetCargo("Validation cargo", new[] { 101 }, new[] { 3 }, new[] { "material" }, new[] { 1 }, new[] { 1 });
var originalHold = supply.Cargo;
expect(data.CaptureCargo(raider.Id, supply.Id) && object.ReferenceEquals(originalHold, raider.Cargo) && supply.Cargo != null && supply.CargoCount == 0 && !data.CaptureCargo(raider.Id, supply.Id),
    "Raid moves the original cargo and leaves a living caravan with one empty hold");
var capturedRestore = restoreParties(clone(captureParties.Invoke(data, null)));
expect(capturedRestore.Find(raider.Id).Cargo.GetCountAt(0) == 3 && capturedRestore.Find(supply.Id).Cargo != null && capturedRestore.Find(supply.Id).CargoCount == 0,
    "Stolen and depleted cargo survive persistence under their new owners");
expect(data.DropPartyCargo(raider.Id, area, 1) == 1 && data.DropPartyCargo(raider.Id, area, 1) == 0 && raider.Cargo == null && area.LootCount == 1 && area.GetLootAt(0).GetCountAt(0) == 3,
    "Cargo transfers exactly once");
var before = caravan.GetMemberAt(0).HP;
data.ReleaseParty(caravan.Id, false, 50); data.ReleaseParty(raider.Id, false, 50);
ProjectY.Data.FactionPersistence.DetachParty(area.GetEncounterAt(0)); ProjectY.Data.FactionPersistence.DetachParty(area.GetEncounterAt(1));
conflict.Resolve(raider.Id, 100); conflict.Expire();
expect(caravan.GetMemberAt(0).HP == before && !caravan.Defeated && caravan.BattleSiteId == 0, "Surviving retreat preserves wounds");
save = clone(captureParties.Invoke(data, null)); restored = restoreParties(save);
var detachedSave = clone(captureArea.Invoke(area, null));
var historyA = restoreArea(detachedSave, restored, new System.Collections.Generic.HashSet<int>());
set(detachedSave, "site", 4);
var historyB = restoreArea(detachedSave, restored, new System.Collections.Generic.HashSet<int>());
expect(historyA.GetEncounterAt(0).EnemyCount == 0 && historyB.GetEncounterAt(0).EnemyCount == 0 && ProjectY.Data.FactionPersistence.Detached(historyB.GetEncounterAt(0)),
    "Historical detached groups retain identity without restoring live actors");
checks.Add("raid cargo capture, exact-once drops, surviving retreat and detached battlefield history");
var solo = data.Factions.AddConflict(4, raider.Id, 0, 120, 130, 200, 30);
data.EngageParty(raider.Id, 4);
var soloRestored = restoreParties(clone(captureParties.Invoke(data, null)));
expect(soloRestored.Factions.FindConflict(4).PartyB == 0, "Player-driven conflicts persist an optional second NPC party");
solo.Engage(true);
rejects(() => restoreParties(captureParties.Invoke(data, null)), "A player-engaged battle cannot be persisted");
solo.Engage(false); solo.Resolve(raider.Id, 200); data.ReleaseParty(raider.Id, false, 220);
checks.Add("player-driven conflict and engaged-save rejection");

var shops = new ProjectY.Data.ShopData();
var stock = shops.Refresh(1, 1, 1, 1, 0, new[] { 1, 2 }, new[] { 101, 102 }, new[] { 10, 1 }, new[] { 2, 3 });
ProjectY.Data.FactionPersistence.ApplyShopRecovery(shops, stock, 0, .25);
var revision = shops.Revision;
ProjectY.Data.FactionPersistence.ApplyShopRecovery(shops, stock, 0, .25);
expect(stock.GetAt(0).Count == 2 && stock.GetAt(1).Count == 0 && shops.Revision == revision, "Existing stock reduced once, including zero liberation minute");
var shopSave = typeof(ProjectY.Data.ShopData).GetMethod("Capture", flags).Invoke(shops, null);
shops = (ProjectY.Data.ShopData)typeof(ProjectY.Data.ShopData).GetMethod("Prepare", flags).Invoke(null, new[] { shopSave });
stock = shops.GetAt(0); ProjectY.Data.FactionPersistence.ApplyShopRecovery(shops, stock, 0, .25);
expect(stock.GetAt(0).Count == 2 && stock.OccupationRecoveryAt == 0, "Shop recovery is idempotent across restore");
stock = shops.Refresh(1, 1, 1, 1, 1, new[] { 1 }, new[] { 101 }, new[] { 10 }, new[] { 2 });
ProjectY.Data.FactionPersistence.ApplyShopRecovery(shops, stock, 0, .8);
expect(stock.GetAt(0).Count == 8, "Next restock follows current recovery factor once");
ProjectY.Data.FactionPersistence.ApplyShopRecovery(shops, stock, 100, 1);
ProjectY.Data.FactionPersistence.ApplyShopRecovery(shops, stock, 100, .25);
expect(stock.GetAt(0).Count == 8 && stock.OccupationRecoveryAt == 100, "Full recovery still records its generation");
rejects(() => ProjectY.Data.FactionPersistence.ApplyShopRecovery(shops, stock, 200, double.NaN), "Invalid recovery factor");
shopSave = typeof(ProjectY.Data.ShopData).GetMethod("Capture", flags).Invoke(shops, null);
var oldStock = ((System.Array)shopSave).GetValue(0);
set(oldStock, "hasOccupationRecovery", false); set(oldStock, "occupationRecoveryAt", 0d);
var oldShops = (ProjectY.Data.ShopData)typeof(ProjectY.Data.ShopData).GetMethod("Prepare", flags).Invoke(null, new[] { shopSave });
expect(oldShops.GetAt(0).OccupationRecoveryAt == -1, "Pre-faction stock has no liberation marker");
checks.Add("shop recovery, zero counts, save idempotence and replenishment period");
return "PASS faction Data: " + string.Join("; ", checks.ToArray());
