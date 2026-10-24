// Execute once in the existing idle Editor after the coordinated project compilation.
// In-memory Data, JSON and one isolated LuaEnv only; no scenes, assets or player save files are modified.
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
var capture = typeof(ProjectY.Data.NarrativeData).GetMethod("Capture", flags);
var prepare = typeof(ProjectY.Data.NarrativeData).GetMethod("Prepare", flags);
var takePrepared = typeof(ProjectY.Data.NarrativeData).GetMethod("TakePrepared", flags);
System.Func<object, ProjectY.Data.NarrativeData> restore = saved =>
    (ProjectY.Data.NarrativeData)prepare.Invoke(null, new[] { saved });
System.Func<object, object> town = saved => field(saved, "townMissions");
System.Func<object, int, object> rowAt = (saved, index) => ((System.Array)field(town(saved), "missions")).GetValue(index);

var narrative = new ProjectY.Data.NarrativeData(); narrative.AdvanceMinutes(2880);
var data = ProjectY.Data.TownMissionData.For(narrative);
expect(object.ReferenceEquals(data, narrative.TownMissions) && data.Count == 0 && data.GetDay(1) == -1 && data.Find(999) == null,
    "One stable commission owner and optional lookups");
rejects(() => data.Add(1, 1, 100001, 0, 0, 1), "Generation requires BeginDay");
data.BeginDay(1, 0);
int revision = data.Revision, ownerRevision = narrative.Revision;
data.BeginDay(1, 0);
expect(data.Revision == revision && narrative.Revision == ownerRevision, "Same-day generation is idempotent");
var unused = data.Add(1, 1, 100001, 0, 0, 1);
var delivery = data.Add(2, 1, 100002, 0, 101, 3);
var escort = data.Add(3, 1, 100003, 0, 0, 1);
var ready = data.Add(4, 1, 100004, 0, 0, 2);
var failed = data.Add(5, 1, 100005, 0, 0, 1);
rejects(() => data.Add(6, 1, 100006, 0, 0, 1), "Daily maximum is five");
rejects(() => data.Add(1, 1, 0, 0, 0, 1), "Stable publisher ID must be positive");
rejects(() => data.Add(1, 1, 100001, 0, 0, 0), "Objective must be positive");
data.Accept(delivery.Id); data.AddProgress(delivery.Id, 1);
rejects(() => data.Accept(delivery.Id), "Cannot accept twice");
rejects(() => data.Ready(delivery.Id), "Incomplete objective cannot be ready");
rejects(() => data.Complete(delivery.Id), "Active commission cannot complete");
rejects(() => data.AddProgress(delivery.Id, 0), "Progress delta must be positive");
rejects(() => data.AddProgress(delivery.Id, -1), "Progress cannot decrease");
rejects(() => data.SetAttached(delivery.Id), "Delivery cannot attach to a caravan");
data.Accept(escort.Id);
rejects(() => data.SetEscort(escort.Id, 11, 1), "Escort destination differs from origin");
data.SetEscort(escort.Id, 11, 2); data.SetAttached(escort.Id);
data.Accept(failed.Id);
rejects(() => data.SetEscort(failed.Id, 11, 2), "One live commission per caravan");
data.SetEscort(failed.Id, 12, 2); data.SetAttached(failed.Id);
expect(data.AttachedId == failed.Id, "Switching attachment retains only one commission");
data.Fail(failed.Id);
expect(data.AttachedId == 0 && failed.State == "failed", "Failure detaches");
rejects(() => data.Fail(failed.Id), "Cannot fail a terminal commission twice");
data.SetAttached(escort.Id);
data.Accept(ready.Id); data.AddProgress(ready.Id, int.MaxValue);
expect(ready.Progress == ready.RequiredCount, "Progress clamps without integer overflow");
data.Ready(ready.Id);
data.BeginDay(1, 1);
expect(data.Find(unused.Id) == null && data.Find(delivery.Id) == delivery && data.Find(escort.Id) == escort &&
    data.Find(ready.Id) == ready && data.Find(failed.Id) == failed && data.AttachedId == escort.Id,
    "Next day expires only offers and preserves accepted, ready, failed and attached records");
rejects(() => data.BeginDay(1, 0), "Day cannot go backwards");
var next = data.Add(1, 1, 100001, 1, 0, 1);
expect(next.Id > failed.Id && narrative.Revision > ownerRevision, "IDs are never reused and mutations invalidate Narrative caches");
data.BeginDay(2, 1);
var completed = data.Add(1, 2, 200001, 1, 0, 1);
data.Accept(completed.Id); data.AddProgress(completed.Id, 1); data.Ready(completed.Id); data.Complete(completed.Id);
rejects(() => data.Complete(completed.Id), "Completed commission cannot be rewarded again");
checks.Add("daily rollover, stable IDs, ownership, progress bounds and exact-once terminal transitions");

var save = clone(capture.Invoke(narrative, null));
var restoredNarrative = restore(save);
var restored = ProjectY.Data.TownMissionData.For(restoredNarrative);
var restoredEscort = restored.Find(escort.Id);
expect(restored.Count == data.Count && restored.GetDay(1) == 1 && restored.GetDay(2) == 1 && restored.AttachedId == escort.Id &&
    restoredEscort.DefinitionId == escort.DefinitionId && restoredEscort.SiteId == 1 && restoredEscort.NpcId == 100003 &&
    restoredEscort.Day == 0 && restoredEscort.TargetId == 0 && restoredEscort.RequiredCount == 1 && restoredEscort.Progress == 0 &&
    restoredEscort.PartyId == 11 && restoredEscort.DestinationSiteId == 2 && restoredEscort.State == "active" &&
    restored.Find(delivery.Id).Progress == 1 && restored.Find(ready.Id).State == "ready" &&
    restored.Find(failed.Id).State == "failed" && restored.Find(completed.Id).State == "completed",
    "JSON roundtrip preserves all fields, generation dates and terminal states");
rejects(() => restored.Complete(completed.Id), "Completed remains terminal after load");
var live = new ProjectY.Data.NarrativeData();
var cached = ProjectY.Data.TownMissionData.For(live);
cached.BeginDay(9, 0); cached.Add(1, 9, 100001, 0, 0, 1);
revision = cached.Revision; ownerRevision = live.Revision;
takePrepared.Invoke(live, new object[] { restoredNarrative });
expect(object.ReferenceEquals(cached, ProjectY.Data.TownMissionData.For(live)) && cached.Count == restored.Count &&
    cached.GetDay(9) == -1 && cached.Revision > revision && live.Revision > ownerRevision, "Commit preserves cached identity and monotonic revisions");
var afterLoad = cached.Add(2, 1, 100002, 1, 101, 2);
expect(afterLoad.Id > completed.Id && restored.Find(afterLoad.Id) == null, "Next ID survives load without aliasing prepared records");
cached.AddProgress(escort.Id, 1); cached.Ready(escort.Id);
expect(cached.AttachedId == 0 && restoredEscort.State == "active", "Ready detaches and live state is independent of the candidate");
cached.Complete(escort.Id);
expect(cached.AttachedId == 0, "Completed escort remains detached");
var prepared = new ProjectY.Data.PreparedCharacterSave();
typeof(ProjectY.Data.PreparedCharacterSave).GetProperty("Narrative", flags).SetValue(prepared, restoredNarrative);
expect(object.ReferenceEquals(ProjectY.Data.TownMissionData.Prepared(prepared), restored), "Prepared bridge returns candidate state");
typeof(ProjectY.Data.PreparedCharacterSave).GetField("Consumed", flags).SetValue(prepared, true);
rejects(() => ProjectY.Data.TownMissionData.Prepared(prepared), "Consumed candidate is inaccessible");
checks.Add("Narrative JSON roundtrip, live commit, independent candidate and stable reflection bridges");

var legacyJson = Newtonsoft.Json.Linq.JObject.Parse(UnityEngine.JsonUtility.ToJson(save));
legacyJson.Remove("townMissions");
var legacy = restore(UnityEngine.JsonUtility.FromJson(legacyJson.ToString(), save.GetType()));
expect(ProjectY.Data.TownMissionData.For(legacy).Count == 0 && ProjectY.Data.TownMissionData.For(legacy).GetDay(1) == -1,
    "Missing legacy JSON field migrates to empty commissions");
var empty = new ProjectY.Data.NarrativeData();
expect(ProjectY.Data.TownMissionData.For(restore(clone(capture.Invoke(empty, null)))).Count == 0, "Empty current save roundtrip");

var bad = clone(save); set(rowAt(bad, 1), "id", field(rowAt(bad, 0), "id"));
rejects(() => restore(bad), "Duplicate instance ID");
bad = clone(save); set(town(bad), "nextId", completed.Id);
rejects(() => restore(bad), "Next ID must exceed every persisted instance");
bad = clone(save); set(rowAt(bad, 0), "state", "unknown");
rejects(() => restore(bad), "Unknown state");
bad = clone(save); set(rowAt(bad, 0), "progress", int.MaxValue);
rejects(() => restore(bad), "Progress exceeds objective");
bad = clone(save); set(rowAt(bad, 2), "progress", 0);
rejects(() => restore(bad), "Ready requires completed objective");
bad = clone(save); set(rowAt(bad, 1), "destinationSiteId", 0);
rejects(() => restore(bad), "Caravan and destination must be paired");
bad = clone(save); set(rowAt(bad, 1), "destinationSiteId", 1);
rejects(() => restore(bad), "Escort cannot end in its origin town");
bad = clone(save); set(rowAt(bad, 2), "partyId", 11); set(rowAt(bad, 2), "destinationSiteId", 2);
rejects(() => restore(bad), "Duplicate live caravan reference");
bad = clone(save); set(town(bad), "attachedId", ready.Id);
rejects(() => restore(bad), "Cannot attach to a ready commission");
bad = clone(save); set(town(bad), "attachedId", 99999);
rejects(() => restore(bad), "Dangling attachment");
bad = clone(save); set(((System.Array)field(town(bad), "days")).GetValue(0), "value", 3);
rejects(() => restore(bad), "Generation cannot be ahead of the saved game clock");
bad = clone(save); set(rowAt(bad, 4), "day", 0);
rejects(() => restore(bad), "An unaccepted offer cannot survive its town's rollover");
bad = clone(save); set(town(bad), "format", 0);
rejects(() => restore(bad), "Populated data cannot pretend to be the absent legacy field");
bad = clone(save); set(town(bad), "missions", null);
rejects(() => restore(bad), "Current format requires its record array");
checks.Add("legacy compatibility and corrupted identity, date, progress, state and escort references rejected");

using (var lua = new XLua.LuaEnv())
{
    var luaNarrative = new ProjectY.Data.NarrativeData();
    lua.Global.Set("TownMissionNarrative", luaNarrative);
    lua.DoString(@"
local data=CS.ProjectY.Data.TownMissionData.For(TownMissionNarrative)
assert(data.Count==0 and data:GetDay(7)==-1)
local revision=TownMissionNarrative.Revision
data:BeginDay(7,0)
local mission=data:Add(3,7,100001,0,0,1)
assert(mission.Id>0 and mission.DefinitionId==3 and mission.SiteId==7 and mission.NpcId==100001)
assert(mission.Day==0 and mission.TargetId==0 and mission.RequiredCount==1 and mission.Progress==0 and mission.State=='offered')
assert(not pcall(function() mission.Progress=1 end) and not pcall(function() mission.State='completed' end))
data:Accept(mission.Id);data:SetEscort(mission.Id,31,8);data:SetAttached(mission.Id)
assert(data.AttachedId==mission.Id and mission.PartyId==31 and mission.DestinationSiteId==8)
data:AddProgress(mission.Id,1);data:Ready(mission.Id)
assert(mission.State=='ready' and data.AttachedId==0 and TownMissionNarrative.Revision>revision)
data:Complete(mission.Id)
assert(mission.State=='completed' and data:Find(mission.Id).State=='completed')
assert(not pcall(function() data:Complete(mission.Id) end))
assert(data:GetAt(0).Id==mission.Id and data:Find(99999)==nil)
", "@town_mission_data_reflection");
    expect(ProjectY.Data.TownMissionData.For(luaNarrative).GetAt(0).State == "completed", "Lua mutated the real authoritative data");
    lua.Global.Set<string, object>("TownMissionNarrative", null);
}
revision = cached.Revision; ownerRevision = live.Revision;
live.Clear();
expect(object.ReferenceEquals(cached, ProjectY.Data.TownMissionData.For(live)) && cached.Count == 0 && cached.AttachedId == 0 &&
    cached.GetDay(1) == -1 && cached.Revision > revision && live.Revision > ownerRevision, "Narrative reset clears stable-owned commissions");
checks.Add("real Lua reflection API, terminal rejection and Narrative reset");
return "PASS town mission Data: " + string.Join("; ", checks.ToArray());
