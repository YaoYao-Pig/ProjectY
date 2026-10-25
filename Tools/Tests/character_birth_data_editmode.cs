// Run only after the coordinated compilation in an already idle Editor.
// In-memory Data/JSON checks only: no scene, Play Mode, file writes, or player saves.
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
var capture = typeof(ProjectY.Data.CombatActorData).GetMethod("CaptureInitialAttributes", flags);
var restore = typeof(ProjectY.Data.CombatActorData).GetMethod("RestoreInitialAttributes", flags);
var captureActor = typeof(ProjectY.Data.CombatActorData).GetMethod("CaptureSave", flags);
var captureEnemy = typeof(ProjectY.Data.CombatActorData).GetMethod("CaptureEnemy", flags);
var prepareEnemy = typeof(ProjectY.Data.CombatActorData).GetMethod("PrepareEnemy", flags);
var names = new[] { "vitality", "endurance", "intellect", "strength", "speed", "defense", "sword" };
var values = new[] { 2, 3, 4, 8, 2, 6, 0 };
var actor = new ProjectY.Data.CombatActorData(71, 1);
expect(!actor.InitialAttributesAssigned && !actor.HasInitialAttributes, "New actor has no birth assignment");
ProjectY.Data.CharacterBirthState.Initialize(actor, 12, names, values);
expect(actor.InitialAttributesAssigned && actor.HasInitialAttributes && actor.InitialProfessionId == 12 && actor.InitialAttributeCount == 7,
    "One complete rolled assignment");
expect(actor.GetInitialAttribute("strength") == 8 && actor.GetInitialAttribute("sword") == 0 && actor.GetInitialAttribute("cooking") == 0,
    "Stored zero and unspecified secondary values remain zero");
names[3] = "changed"; values[3] = 99;
expect(actor.GetInitialAttributeNameAt(3) == "strength" && actor.GetInitialAttribute("strength") == 8, "Input arrays cannot mutate actor state");
names[3] = "strength"; values[3] = 8;
actor.Growth.Initialize(17, 3, 0, 0); actor.Growth.JoinProfession(12);
actor.Growth.InvestAttribute("strength", 1, 1); actor.Growth.JoinProfession(13);
expect(actor.InitialProfessionId == 12 && actor.GetInitialAttribute("strength") == 8 && actor.Growth.GetAttribute("strength") == 1,
    "Training and profession changes do not reroll or overwrite base values");
rejects(() => ProjectY.Data.CharacterBirthState.Initialize(actor, 13, names, values), "Second roll");
rejects(() => ProjectY.Data.CharacterBirthState.UseTemplate(actor), "Replace rolled values with template");
checks.Add("PASS one-time rolled attributes are independent of investment and profession changes");

var fresh = new ProjectY.Data.CombatActorData(72, 1);
var badNames = (string[])names.Clone(); badNames[6] = "strength";
rejects(() => ProjectY.Data.CharacterBirthState.Initialize(fresh, 12, badNames, values), "Duplicate attribute");
badNames[6] = "sword"; badNames[3] = "cooking";
rejects(() => ProjectY.Data.CharacterBirthState.Initialize(fresh, 12, badNames, values), "Missing primary attribute");
var badValues = (int[])values.Clone(); badValues[2] = -1;
rejects(() => ProjectY.Data.CharacterBirthState.Initialize(fresh, 12, names, badValues), "Negative attribute");
rejects(() => ProjectY.Data.CharacterBirthState.Initialize(fresh, 0, names, values), "Missing initial profession");
expect(!fresh.InitialAttributesAssigned && fresh.InitialAttributeCount == 0, "Failed assignment is atomic");
ProjectY.Data.CharacterBirthState.UseTemplate(fresh);
expect(fresh.InitialAttributesAssigned && !fresh.HasInitialAttributes && fresh.InitialProfessionId == 0, "Explicit template mode");
rejects(() => ProjectY.Data.CharacterBirthState.Initialize(fresh, 12, names, values), "Legacy template actor must never reroll");
checks.Add("PASS invalid initialization is atomic and explicit template mode prevents rerolls");

var saved = capture.Invoke(actor, null);
var roundtrip = new ProjectY.Data.CombatActorData(73, 1);
restore.Invoke(roundtrip, new[] { clone(saved) });
expect(UnityEngine.JsonUtility.ToJson(capture.Invoke(roundtrip, null)) == UnityEngine.JsonUtility.ToJson(saved), "Complete JSON roundtrip");
var unassigned = new ProjectY.Data.CombatActorData(74, 1);
var fixedRecord = capture.Invoke(unassigned, null);
expect((int)field(fixedRecord, "mode") == 1 && !unassigned.InitialAttributesAssigned, "Pure Data capture preserves fixed template semantics without mutation");
var fixedRestored = new ProjectY.Data.CombatActorData(75, 1);
restore.Invoke(fixedRestored, new[] { clone(fixedRecord) });
expect(fixedRestored.InitialAttributesAssigned && !fixedRestored.HasInitialAttributes, "Explicit template record roundtrip");
checks.Add("PASS rolled and template records roundtrip without random generation");

System.Action<object, string> rejectRecord = (record, label) =>
    rejects(() => restore.Invoke(new ProjectY.Data.CombatActorData(76, 1), new[] { record }), label);
rejectRecord(null, "Missing new-format record");
var malformed = clone(saved); set(malformed, "mode", 0); rejectRecord(malformed, "Unknown mode");
malformed = clone(fixedRecord); set(malformed, "professionId", 12); rejectRecord(malformed, "Template profession mismatch");
malformed = clone(fixedRecord); set(malformed, "entries", field(saved, "entries")); rejectRecord(malformed, "Template entries mismatch");
malformed = clone(saved); set(malformed, "entries", null); rejectRecord(malformed, "Missing rolled entries");
malformed = clone(saved); set(malformed, "professionId", 0); rejectRecord(malformed, "Rolled profession mismatch");
malformed = clone(saved); var entries = (System.Array)field(malformed, "entries"); set(entries.GetValue(6), "name", "strength"); rejectRecord(malformed, "Duplicate saved attribute");
malformed = clone(saved); entries = (System.Array)field(malformed, "entries"); set(entries.GetValue(3), "name", "cooking"); rejectRecord(malformed, "Missing saved primary attribute");
malformed = clone(saved); entries = (System.Array)field(malformed, "entries"); set(entries.GetValue(0), "value", -1); rejectRecord(malformed, "Negative saved attribute");
malformed = clone(saved); entries = (System.Array)field(malformed, "entries"); entries.SetValue(null, 0); rejectRecord(malformed, "Null saved entry");
checks.Add("PASS malformed modes, records, profession IDs, attributes and missing primary values are rejected");

actor.SetMaxHP(60); actor.Restore(); actor.Deploy(2, 0, 0);
var actorRecord = captureActor.Invoke(actor, null);
expect(UnityEngine.JsonUtility.ToJson(field(actorRecord, "initialAttributes")) == UnityEngine.JsonUtility.ToJson(saved), "Player actor capture includes immutable bases");
var enemyRecord = captureEnemy.Invoke(actor, null);
var enemy = (ProjectY.Data.CombatActorData)prepareEnemy.Invoke(null,
    new object[] { clone(enemyRecord), null, new System.Collections.Generic.HashSet<int>() });
expect(enemy.HasInitialAttributes && enemy.InitialProfessionId == 12 && enemy.GetInitialAttribute("strength") == 8 && enemy.HP == 60,
    "Area enemy and shared world-party member record restores bases and health");
malformed = clone(enemyRecord); set(malformed, "initialAttributes", null);
rejects(() => prepareEnemy.Invoke(null, new object[] { malformed, null, new System.Collections.Generic.HashSet<int>() }), "Enemy record must include initial attributes");
checks.Add("PASS player and shared enemy/world-member records include the same immutable base state");

var captureProfession = typeof(ProjectY.Data.CombatActorData).GetMethod("CaptureProfessionAttributes", flags);
var restoreProfession = typeof(ProjectY.Data.CombatActorData).GetMethod("RestoreProfessionAttributes", flags);
var bonusNames = new[] { "strength", "sword" }; var bonusValues = new[] { 2, 0 };
ProjectY.Data.CharacterBirthState.AssignProfession(actor, 12, bonusNames, bonusValues);
ProjectY.Data.CharacterBirthState.AssignProfession(actor, 1, new[] { "vitality" }, new[] { 3 });
ProjectY.Data.CharacterBirthState.AssignProfession(actor, 13, new string[0], new int[0]);
bonusNames[0] = "speed"; bonusValues[0] = 99;
expect(actor.ProfessionAttributeSetCount == 3 && actor.HasProfessionAttributes(12) && actor.HasProfessionAttributes(13) &&
    actor.GetProfessionAttributeCount(13) == 0 && !actor.HasProfessionAttributes(2), "Recorded empty profession differs from an unassigned profession");
expect(actor.GetProfessionAttributeProfessionAt(0) == 12 && actor.GetProfessionAttributeNameAt(12, 0) == "strength" &&
    actor.GetProfessionAttribute(12, "strength") == 2 && actor.GetProfessionAttribute(12, "sword") == 0 &&
    actor.GetProfessionAttribute(12, "speed") == 0 && actor.GetProfessionAttribute(2, "speed") == 0, "Profession snapshots copy values and return zero for absent entries");
actor.Growth.JoinProfession(1);
expect(actor.GetProfessionAttribute(actor.Growth.CurrentProfessionId, "vitality") == 3 &&
    actor.GetProfessionAttribute(actor.Growth.CurrentProfessionId, "strength") == 0, "Profession query selects the current profession snapshot");
actor.Growth.JoinProfession(12);
expect(actor.GetProfessionAttribute(actor.Growth.CurrentProfessionId, "strength") == 2 &&
    actor.GetProfessionAttribute(actor.Growth.CurrentProfessionId, "vitality") == 0 && actor.GetInitialAttribute("strength") == 8,
    "Switching back retains the original profession snapshot and birth values");
rejects(() => ProjectY.Data.CharacterBirthState.AssignProfession(actor, 12, new[] { "strength" }, new[] { 8 }), "Profession reroll");
rejects(() => ProjectY.Data.CharacterBirthState.AssignProfession(actor, 13, new[] { "speed" }, new[] { 8 }), "Reroll previously empty profession");
checks.Add("PASS profession snapshots are independent, immutable and include explicitly empty results");

var bonusFresh = new ProjectY.Data.CombatActorData(81, 1);
rejects(() => ProjectY.Data.CharacterBirthState.AssignProfession(bonusFresh, 0, new string[0], new int[0]), "Invalid profession ID");
rejects(() => ProjectY.Data.CharacterBirthState.AssignProfession(bonusFresh, 1, new[] { "strength", "strength" }, new[] { 1, 2 }), "Duplicate profession attribute");
rejects(() => ProjectY.Data.CharacterBirthState.AssignProfession(bonusFresh, 1, new[] { "strength", "speed" }, new[] { 1, -1 }), "Negative later profession attribute");
rejects(() => ProjectY.Data.CharacterBirthState.AssignProfession(bonusFresh, 1, new[] { "bad name" }, new[] { 1 }), "Invalid profession attribute name");
rejects(() => ProjectY.Data.CharacterBirthState.AssignProfession(bonusFresh, 1, new[] { "speed" }, new int[0]), "Unequal profession arrays");
expect(bonusFresh.ProfessionAttributeSetCount == 0 && !bonusFresh.HasProfessionAttributes(1), "Invalid profession assignment never commits a partial set");
expect(((System.Array)captureProfession.Invoke(bonusFresh, null)).Length == 0, "Unconfigured Data captures an explicit empty profession array");
checks.Add("PASS invalid profession assignment is atomic and zero configured sets serialize explicitly");

actorRecord = captureActor.Invoke(actor, null);
var professionRows = (System.Array)field(clone(actorRecord), "professionAttributes");
var bonusRestored = new ProjectY.Data.CombatActorData(82, 1);
restoreProfession.Invoke(bonusRestored, new object[] { professionRows });
expect(bonusRestored.ProfessionAttributeSetCount == 3 && bonusRestored.GetProfessionAttribute(12, "strength") == 2 &&
    bonusRestored.GetProfessionAttribute(1, "vitality") == 3 && bonusRestored.HasProfessionAttributes(13) &&
    bonusRestored.GetProfessionAttributeCount(13) == 0, "Player JSON preserves all profession snapshots including empty results");
enemyRecord = captureEnemy.Invoke(actor, null);
enemy = (ProjectY.Data.CombatActorData)prepareEnemy.Invoke(null,
    new object[] { clone(enemyRecord), null, new System.Collections.Generic.HashSet<int>() });
expect(enemy.ProfessionAttributeSetCount == 3 && enemy.GetProfessionAttribute(12, "strength") == 2 &&
    enemy.GetProfessionAttribute(1, "vitality") == 3 && enemy.HasProfessionAttributes(13), "Enemy/world-member JSON restores profession snapshots");
checks.Add("PASS player and shared enemy/world-member JSON retain every profession result");

System.Action<object, string> rejectProfessions = (rows, label) =>
{
    var target = new ProjectY.Data.CombatActorData(83, 1);
    rejects(() => restoreProfession.Invoke(target, new object[] { rows }), label);
    expect(target.ProfessionAttributeSetCount == 0, "Malformed profession array must not partially restore");
};
rejectProfessions(null, "Missing new-format profession array");
professionRows = (System.Array)field(clone(actorRecord), "professionAttributes"); professionRows.SetValue(null, 1);
rejectProfessions(professionRows, "Null profession record");
professionRows = (System.Array)field(clone(actorRecord), "professionAttributes"); set(professionRows.GetValue(1), "professionId", 0);
rejectProfessions(professionRows, "Invalid saved profession ID");
professionRows = (System.Array)field(clone(actorRecord), "professionAttributes"); set(professionRows.GetValue(1), "professionId", 12);
rejectProfessions(professionRows, "Duplicate saved profession ID");
professionRows = (System.Array)field(clone(actorRecord), "professionAttributes"); set(professionRows.GetValue(1), "entries", null);
rejectProfessions(professionRows, "Missing profession entries array");
professionRows = (System.Array)field(clone(actorRecord), "professionAttributes"); entries = (System.Array)field(professionRows.GetValue(0), "entries"); set(entries.GetValue(1), "name", "strength");
rejectProfessions(professionRows, "Duplicate saved profession attribute");
professionRows = (System.Array)field(clone(actorRecord), "professionAttributes"); entries = (System.Array)field(professionRows.GetValue(1), "entries"); set(entries.GetValue(0), "value", -1);
rejectProfessions(professionRows, "Negative later saved profession attribute");
professionRows = (System.Array)field(clone(actorRecord), "professionAttributes"); entries = (System.Array)field(professionRows.GetValue(1), "entries"); set(entries.GetValue(0), "name", "bad name");
rejectProfessions(professionRows, "Malformed saved profession attribute name");
malformed = clone(enemyRecord); set(malformed, "professionAttributes", null);
rejects(() => prepareEnemy.Invoke(null, new object[] { malformed, null, new System.Collections.Generic.HashSet<int>() }), "Enemy requires profession snapshot array");
checks.Add("PASS malformed profession IDs, arrays, entries and duplicate snapshots are rejected atomically");
return string.Join("\n", checks);
