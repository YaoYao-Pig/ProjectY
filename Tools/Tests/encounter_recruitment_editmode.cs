// Run in the already open idle Editor after the coordinated compilation. In-memory Data only.
if (UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.Exception("Idle Edit Mode required");
System.Action<bool, string> expect = (ok, message) => { if (!ok) throw new System.Exception(message); };
System.Action<System.Action, string> rejects = (action, message) =>
{
    try { action(); }
    catch (System.InvalidOperationException) { return; }
    throw new System.Exception("Expected rejection: " + message);
};
System.Func<ProjectY.Data.AdventureData> fixture = () =>
{
    var value = new ProjectY.Data.AdventureData();
    var state = value.Areas.Ensure(99, 20, 1);
    var encounter = state.AddEncounter(1, 301);
    encounter.AddEnemy(100, 1, 0, 0).Damage(1);
    var recruit = encounter.AddEnemy(10301, 910, 1, 0);
    recruit.Deploy(4, 1, 0); recruit.SetMaxHP(60); recruit.Damage(43);
    state.CompleteEncounterInitialization();
    ProjectY.Data.EquipmentAffixData.Define(value.Equipment, 101, new[] { 1 }, new[] { 1 });
    ProjectY.Data.EquipmentAffixData.Define(value.Equipment, 102, new[] { 1 }, new[] { 1 });
    ProjectY.Data.EquipmentCombatState.Initialize(value.Equipment, recruit.Id, 101, 0, new[] { 102 }, new[] { "body" });
    return value;
};
var data = fixture();
var area = data.Areas.Find(99); var group = area.GetEncounterAt(0); var actor = group.GetEnemyAt(1);
var weapon = data.Equipment.Equipped(actor.Id); var armor = data.Equipment.Worn(actor.Id, "body");
ProjectY.Data.EquipmentCombatState.DamageWeapon(data.Equipment, weapon.Id, 63);
ProjectY.Data.EquipmentCombatState.DamageArmor(data.Equipment, actor.Id, 29);
var durability = ProjectY.Data.EquipmentConditionData.Of(weapon);
var armorDurability = ProjectY.Data.EquipmentConditionData.Of(armor);
int weaponHP = durability.Current, weaponMax = durability.Maximum, armorHP = armorDurability.Current;
int revision = area.Revision, equipmentRevision = data.Equipment.Revision;
ProjectY.Data.EncounterRecruitment.Validate(data, group, actor);
expect(!actor.Growth.Initialized && group.EnemyCount == 2 && data.PartyCount == 0 && data.Equipment.Revision == equipmentRevision,
    "Prepare must not change the living ally or equipment");
rejects(() => ProjectY.Data.EncounterRecruitment.Transfer(data, group, actor), "Growth must be prepared");
expect(group.EnemyCount == 2 && actor.Team == 4 && data.Equipment.Revision == equipmentRevision, "Rejected transfer must not write");
actor.Growth.Initialize(1, 0, 0, 0);
ProjectY.Data.EncounterRecruitment.Transfer(data, group, actor);
ProjectY.Data.EquipmentCombatState.RefreshMaximum(actor, 75);
expect(data.PartyCount == 1 && object.ReferenceEquals(data.GetPartyAt(0), actor) && actor.Team == 1 && actor.HP == 17 && actor.MaxHP == 75,
    "Recruit must preserve the living actor and current health");
expect(group.EnemyCount == 1 && group.Defeated && area.Revision == revision + 1, "Original encounter must release the ally and remain cleared");
expect(!ProjectY.Data.EquipmentCombatState.IsInitialized(data.Equipment, actor.Id) && data.Equipment.WeaponCount == 1 && data.Equipment.WearableCount == 1 &&
    object.ReferenceEquals(data.Equipment.Equipped(actor.Id), weapon) && object.ReferenceEquals(data.Equipment.Worn(actor.Id, "body"), armor) &&
    durability.Current == weaponHP && durability.Maximum == weaponMax && armorDurability.Current == armorHP,
    "Transfer must preserve both physical item instances, worn condition and permanent durability loss");
rejects(() => ProjectY.Data.EncounterRecruitment.Transfer(data, group, actor), "Cannot recruit twice");
ProjectY.Data.EquipmentCombatState.RemoveActor(data.Equipment, actor.Id);
expect(data.Equipment.WeaponCount == 1 && data.Equipment.WearableCount == 1, "Later encounter cleanup cannot delete recruited equipment");

var full = fixture(); var fullGroup = full.Areas.Find(99).GetEncounterAt(0); var fullActor = fullGroup.GetEnemyAt(1);
fullActor.Growth.Initialize(1, 0, 0, 0);
for (int i = 1; i <= 4; i++) full.AddPartyActor(i, 1);
rejects(() => ProjectY.Data.EncounterRecruitment.Transfer(full, fullGroup, fullActor), "Full party");
expect(fullGroup.EnemyCount == 2 && fullActor.Team == 4 && ProjectY.Data.EquipmentCombatState.IsInitialized(full.Equipment, fullActor.Id), "Full party must preserve scene ownership");
var dead = fixture(); var deadGroup = dead.Areas.Find(99).GetEncounterAt(0); var deadActor = deadGroup.GetEnemyAt(1);
deadActor.Growth.Initialize(1, 0, 0, 0); deadActor.Damage(deadActor.HP);
rejects(() => ProjectY.Data.EncounterRecruitment.Transfer(dead, deadGroup, deadActor), "Dead ally");
expect(dead.PartyCount == 0 && deadGroup.EnemyCount == 2, "Dead ally cannot move into the party");
var foreign = fixture();
rejects(() => ProjectY.Data.EncounterRecruitment.Validate(foreign, fullGroup, fullActor), "Foreign encounter ownership");
var duplicate = fixture(); var duplicateGroup = duplicate.Areas.Find(99).GetEncounterAt(0); var duplicateActor = duplicateGroup.GetEnemyAt(1);
duplicate.AddPartyActor(duplicateActor.Id, 1);
rejects(() => ProjectY.Data.EncounterRecruitment.Validate(duplicate, duplicateGroup, duplicateActor), "Duplicate actor ID");
var wrongPhase = fixture(); var phaseGroup = wrongPhase.Areas.Find(99).GetEncounterAt(0); var phaseActor = phaseGroup.GetEnemyAt(1);
wrongPhase.BeginEvent(99, 301);
rejects(() => ProjectY.Data.EncounterRecruitment.Validate(wrongPhase, phaseGroup, phaseActor), "Event phase");
var active = fixture(); var activeGroup = active.Areas.Find(99).GetEncounterAt(0); var activeActor = activeGroup.GetEnemyAt(1);
active.Areas.Enter(99, 20, 1); active.BeginArea(99); activeActor.Growth.Initialize(1, 0, 0, 0);
ProjectY.Data.EncounterRecruitment.Transfer(active, activeGroup, activeActor);
expect(active.PartyCount == 1 && activeActor.HP == 17, "Active-area recruitment must also preserve health");
return "PASS event recruitment: identity, HP, physical equipment/durability, cleanup immunity, full party, dead/duplicate/foreign actors, phases and exact-once transfer";
