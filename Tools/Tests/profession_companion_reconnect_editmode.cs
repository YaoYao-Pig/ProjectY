if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.InvalidOperationException("Idle Edit Mode required");
var owner=new ProjectY.Data.CombatActorData(81,1);owner.SetMaxHP(80);owner.Restore();owner.Deploy(1,0,0);
var animal=new ProjectY.Data.CombatActorData(82,201);animal.InitializeAnimal(1,31);animal.SetMaxHP(100);animal.Restore();animal.Deploy(0,1,0);
owner.TameAndRide(animal,12);animal.Damage(7);ProjectY.Data.BodyHealth.Injure(animal,2,1,25);
ProjectY.Data.AnimalCompanionState.SetMode(owner,true,120,100,2);
var flags=System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic;
var type=typeof(ProjectY.Data.CombatActorData);
var save=type.GetMethod("CaptureMount",flags).Invoke(owner,null);
var restored=new ProjectY.Data.CombatActorData(81,1);restored.SetMaxHP(80);restored.Restore();restored.Deploy(1,0,0);
type.GetMethod("RestoreMount",flags).Invoke(restored,new[]{save});
var canonical=new ProjectY.Data.CombatActorData(82,201);canonical.InitializeAnimal(1,31);canonical.SetMaxHP(100);canonical.Restore();canonical.Deploy(0,120,100);canonical.Damage(7);ProjectY.Data.BodyHealth.Injure(canonical,2,1,25);
var identityOwner=new ProjectY.Data.CombatActorData(81,1);identityOwner.SetMaxHP(80);identityOwner.Restore();identityOwner.Deploy(1,0,0);identityOwner.TameAndRide(canonical,12);
type.GetMethod("ReconnectMount",flags).Invoke(restored,new object[]{canonical});
if(ProjectY.Data.AnimalCompanionState.Partner(restored)!=canonical || !ProjectY.Data.AnimalCompanionState.Independent(canonical) || ProjectY.Data.AnimalCompanionState.Layer(canonical)!=2)
    throw new System.Exception("Canonical expedition animal reconnection lost identity, mode or floor");
if(canonical.HP!=93 || canonical.AnimalBond!=12 || ProjectY.Data.BodyHealth.Damage(canonical,2)!=25 || canonical.Q!=120 || canonical.R!=100)
    throw new System.Exception("Canonical animal reconnection changed wounds or travel position");
return "PASS full-expedition canonical animal reconnection preserves identity, mode, floor, wounds and cross-area coordinates";
