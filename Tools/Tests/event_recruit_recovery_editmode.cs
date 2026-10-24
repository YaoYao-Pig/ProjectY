// Existing idle Editor only. Real C# body state plus production Lua/config; no assets or player saves.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.Exception("Idle Edit Mode required");
System.Action<bool, string> expect = (ok, message) => { if (!ok) throw new System.Exception(message); };
System.Action<System.Action, string> rejects = (action, message) =>
{
    try { action(); }
    catch (System.Exception error)
    {
        if (error is System.Reflection.TargetInvocationException) error = error.InnerException;
        if (error is System.ArgumentException || error is System.IO.InvalidDataException) return;
        throw;
    }
    throw new System.Exception("Expected rejection: " + message);
};
System.Func<int, ProjectY.Data.CombatActorData> makeActor = id => new ProjectY.Data.CombatActorData(id, 920);
var actor = makeActor(10302);
ProjectY.Data.BodyHealth.Injure(actor, 4, 1, 30);
ProjectY.Data.BodyHealth.ScheduleRecovery(actor, 4, 30, 100);
ProjectY.Data.BodyHealth.Injure(actor, 4, 2, 20);
expect(ProjectY.Data.BodyHealth.RecoveryAmount(actor, 4) == 30 && ProjectY.Data.BodyHealth.RecoveryAt(actor, 4) == 100,
    "A new hit must not increase recovery or postpone it");
expect(ProjectY.Data.BodyHealth.AdvanceRecovery(actor, 99) == 0 && ProjectY.Data.BodyHealth.AdvanceRecovery(actor, 100) == 30 &&
    ProjectY.Data.BodyHealth.Damage(actor, 4) == 20 && ProjectY.Data.BodyHealth.Kind(actor, 4) == 2 &&
    ProjectY.Data.BodyHealth.AdvanceRecovery(actor, 1000) == 0, "Only the scheduled original damage recovers once");
var equipment = new ProjectY.Data.EquipmentData(); equipment.Grid.Configure(4, 4); equipment.Grid.Define(91, 1, 1); equipment.AddStack(91, 4);
var treated = makeActor(10303); ProjectY.Data.BodyHealth.Injure(treated, 2, 2, 30); ProjectY.Data.BodyHealth.ScheduleRecovery(treated, 2, 30, 200);
ProjectY.Data.BodyHealth.Injure(treated, 2, 3, 20);
expect(ProjectY.Data.BodyHealth.Treat(treated, equipment, 2, 91, 1, 10) && ProjectY.Data.BodyHealth.RecoveryAmount(treated, 2) == 20,
    "Treatment must consume scheduled damage first");
ProjectY.Data.BodyHealth.Injure(treated, 2, 3, 5);
expect(ProjectY.Data.BodyHealth.AdvanceRecovery(treated, 200) == 20 && ProjectY.Data.BodyHealth.Damage(treated, 2) == 25,
    "Recovery cannot erase additional damage after treatment");
var healed = makeActor(10304); ProjectY.Data.BodyHealth.Injure(healed, 3, 2, 30); ProjectY.Data.BodyHealth.ScheduleRecovery(healed, 3, 30, 200);
expect(ProjectY.Data.BodyHealth.Treat(healed, equipment, 3, 91, 1, 40) && ProjectY.Data.BodyHealth.RecoveryAt(healed, 3) == 0,
    "Completed treatment must remove its old recovery timer");
ProjectY.Data.BodyHealth.Injure(healed, 3, 3, 15);
expect(ProjectY.Data.BodyHealth.AdvanceRecovery(healed, 200) == 0 && ProjectY.Data.BodyHealth.Damage(healed, 3) == 15,
    "A previously treated wound cannot later clear a new injury");
var permanent = makeActor(10305); ProjectY.Data.BodyHealth.Injure(permanent, 1, 1, 30); ProjectY.Data.BodyHealth.ScheduleRecovery(permanent, 1, 30, 300);
ProjectY.Data.BodyHealth.Injure(permanent, 1, 2, 70);
expect(ProjectY.Data.BodyHealth.Permanent(permanent, 1) && ProjectY.Data.BodyHealth.RecoveryAmount(permanent, 1) == 0 &&
    ProjectY.Data.BodyHealth.RecoveryAt(permanent, 1) == 0 && ProjectY.Data.BodyHealth.AdvanceRecovery(permanent, 300) == 0,
    "Permanent injury must cancel recovery");
rejects(() => ProjectY.Data.BodyHealth.ScheduleRecovery(permanent, 1, 30, 400), "Permanent recovery");
rejects(() => ProjectY.Data.BodyHealth.ScheduleRecovery(actor, 0, 1, 400), "Healthy-part recovery");
rejects(() => ProjectY.Data.BodyHealth.ScheduleRecovery(actor, 4, 21, 400), "Recovery beyond existing damage");
rejects(() => ProjectY.Data.BodyHealth.ScheduleRecovery(actor, 4, 10, double.NaN), "NaN timer");
rejects(() => ProjectY.Data.BodyHealth.AdvanceRecovery(actor, double.PositiveInfinity), "Infinite world time");

var saved = makeActor(10306); ProjectY.Data.BodyHealth.Injure(saved, 5, 1, 30); ProjectY.Data.BodyHealth.ScheduleRecovery(saved, 5, 30, 1640);
int revision = ProjectY.Data.BodyHealth.Revision(saved);
rejects(() => ProjectY.Data.BodyHealth.ScheduleRecovery(saved, 5, 10, 5000), "Rescheduling a registered wound");
expect(ProjectY.Data.BodyHealth.Revision(saved) == revision && ProjectY.Data.BodyHealth.RecoveryAt(saved, 5) == 1640, "Rejected scheduling must not mutate the live plan");
var flags = System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic;
var capture = typeof(ProjectY.Data.CombatActorData).GetMethod("CaptureBody", flags);
var restore = typeof(ProjectY.Data.CombatActorData).GetMethod("RestoreBody", flags);
var payload = (System.Array)capture.Invoke(saved, null);
var restored = makeActor(10307); restore.Invoke(restored, new object[] { payload });
expect(ProjectY.Data.BodyHealth.RecoveryAmount(restored, 5) == 30 && ProjectY.Data.BodyHealth.RecoveryAt(restored, 5) == 1640,
    "Save restoration must retain recovery amount and absolute game time");
var row = payload.GetValue(5); var rowType = row.GetType();
rowType.GetField("recoveryAmount").SetValue(row, 31);
rejects(() => restore.Invoke(restored, new object[] { payload }), "Malformed recovery amount");
expect(ProjectY.Data.BodyHealth.RecoveryAmount(restored, 5) == 30 && ProjectY.Data.BodyHealth.RecoveryAt(restored, 5) == 1640,
    "Restore must validate every body part before any write and own its copied state");
rowType.GetField("recoveryAmount").SetValue(row, 30); rowType.GetField("recoveryAt").SetValue(row, double.NaN);
rejects(() => restore.Invoke(restored, new object[] { payload }), "Malformed saved time");
rowType.GetField("recoveryAt").SetValue(row, 1640d); rowType.GetField("damage").SetValue(row, 100); rowType.GetField("permanent").SetValue(row, true);
rejects(() => restore.Invoke(restored, new object[] { payload }), "Saved permanent injury with recovery");
payload.SetValue(UnityEngine.JsonUtility.FromJson("{\"damage\":30,\"kind\":1,\"permanent\":false}", rowType), 5);
restore.Invoke(restored, new object[] { payload });
expect(ProjectY.Data.BodyHealth.Damage(restored, 5) == 30 && ProjectY.Data.BodyHealth.RecoveryAmount(restored, 5) == 0 &&
    ProjectY.Data.BodyHealth.RecoveryAt(restored, 5) == 0 && ProjectY.Data.BodyHealth.AdvanceRecovery(restored, 99999) == 0,
    "Legacy injury saves with no recovery fields must keep their original injury");

var root = System.IO.Directory.GetParent(UnityEngine.Application.dataPath).FullName;
using (var lua = new XLua.LuaEnv())
{
    lua.AddLoader((ref string module) => System.IO.File.ReadAllBytes(System.IO.Path.Combine(root, "Lua", module.Replace('.', '/') + ".lua")));
    lua.Global.Set("RECRUIT_REAL_DATA", true);
    lua.DoString(System.IO.File.ReadAllText(System.IO.Path.Combine(root, "Tools/Tests/event_recruit_recovery.lua")));
}
return "PASS real body recovery: schedule, later hits, partial/full treatment, permanent cancellation, invalid input, capture/restore, old saves and production recruitment clock";
