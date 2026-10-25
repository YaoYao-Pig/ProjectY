// Execute only in an existing idle Editor after the coordinated project compilation.
// This fragment uses in-memory Data and JSON clones only: no scenes, Play Mode or save files.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.Exception("Idle Edit Mode required");
var flags=System.Reflection.BindingFlags.Public|System.Reflection.BindingFlags.NonPublic|
    System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.Static;
var checks=new System.Collections.Generic.List<string>();
System.Action<bool,string> expect=(ok,message)=>{if(!ok)throw new System.Exception(message);};
System.Action<System.Action,string> rejects=(action,message)=>
{
    try{action();}
    catch(System.Exception error)
    {
        if(error is System.Reflection.TargetInvocationException)error=error.InnerException;
        if(error is System.InvalidOperationException || error is System.ArgumentException || error is System.IO.InvalidDataException)return;
        throw;
    }
    throw new System.Exception("Expected rejection: "+message);
};
System.Func<object,string,object> field=(value,name)=>value.GetType().GetField(name,flags).GetValue(value);
System.Action<object,string,object> set=(value,name,content)=>value.GetType().GetField(name,flags).SetValue(value,content);
System.Func<object,object> clone=value=>UnityEngine.JsonUtility.FromJson(UnityEngine.JsonUtility.ToJson(value),value.GetType());
var actorType=typeof(ProjectY.Data.CombatActorData);
var captureEnemy=actorType.GetMethod("CaptureEnemy",flags);
var prepareEnemy=actorType.GetMethod("PrepareEnemy",flags);
var captureMount=actorType.GetMethod("CaptureMount",flags);
var restoreMount=actorType.GetMethod("RestoreMount",flags);
var captureParties=typeof(ProjectY.Data.WorldPartiesData).GetMethod("Capture",flags);
var prepareParties=typeof(ProjectY.Data.WorldPartiesData).GetMethod("Prepare",flags);
var reconnect=typeof(ProjectY.Data.ExpeditionPersistence).GetMethod("ReconnectAnimals",flags);
System.Func<int,ProjectY.Data.CombatActorData> owner=id=>
{
    var actor=new ProjectY.Data.CombatActorData(id,1);actor.SetMaxHP(80);actor.Restore();return actor;
};
System.Func<object,ProjectY.Data.CombatActorData> restoredMount=saved=>
{
    var restoredOwnerCandidate=owner(1);restoreMount.Invoke(restoredOwnerCandidate,new[]{saved});return restoredOwnerCandidate;
};
System.Func<object,ProjectY.Data.CombatActorData> restoredEnemy=saved=>
    (ProjectY.Data.CombatActorData)prepareEnemy.Invoke(null,new object[]{clone(saved),null,new System.Collections.Generic.HashSet<int>()});

var wild=new ProjectY.Data.CombatActorData(500,1);wild.InitializeAnimal(1,345u);wild.Deploy(0,2,3);
wild.SetMaxHP(100);wild.Restore();
expect(!ProjectY.Data.AnimalSpeechState.Pending(wild) && ProjectY.Data.AnimalSpeechState.Modifier(wild)==0,"Fresh animal has no result");
rejects(()=>ProjectY.Data.AnimalSpeechState.Resolve(owner(9),10),"A human is not a wild animal");
rejects(()=>ProjectY.Data.AnimalSpeechState.Resolve(wild,101),"Probability-point bound");
ProjectY.Data.AnimalSpeechState.Resolve(wild,0);
rejects(()=>ProjectY.Data.AnimalSpeechState.Resolve(wild,15),"Even a zero result cannot be rerolled");
expect(ProjectY.Data.AnimalSpeechState.Pending(wild) && ProjectY.Data.AnimalSpeechState.Consume(wild)==0 &&
    !ProjectY.Data.AnimalSpeechState.Pending(wild),"Zero result is still a one-use result");
ProjectY.Data.AnimalSpeechState.Resolve(wild,-12);wild.DelayTaming(3);wild.Deploy(2,4,5);
expect(ProjectY.Data.AnimalSpeechState.Pending(wild) && ProjectY.Data.AnimalSpeechState.Modifier(wild)==-12 && wild.TameRetryTurns==3,
    "Redeployment preserves the shared result and retry delay");
var wildSave=clone(captureEnemy.Invoke(wild,null));var wildCopy=restoredEnemy(wildSave);
expect(wildCopy.Id==wild.Id && wildCopy.HP==wild.HP && wildCopy.TameRetryTurns==3 && ProjectY.Data.AnimalSpeechState.Pending(wildCopy) &&
    ProjectY.Data.AnimalSpeechState.Consume(wildCopy)==-12 && ProjectY.Data.AnimalSpeechState.Consume(wildCopy)==0 &&
    !ProjectY.Data.AnimalSpeechState.Pending(wildCopy) && ProjectY.Data.AnimalSpeechState.Modifier(wildCopy)==0,
    "Enemy JSON roundtrip preserves the result and consumes it once");
var legacyEnemy=clone(wildSave);set(legacyEnemy,"speechPending",false);set(legacyEnemy,"speechModifier",0);
expect(!ProjectY.Data.AnimalSpeechState.Pending(restoredEnemy(legacyEnemy)),"Legacy enemy defaults to no result");
var invalidEnemy=clone(wildSave);set(invalidEnemy,"speechPending",false);
rejects(()=>restoredEnemy(invalidEnemy),"A modifier without a pending result is invalid");
wild.Damage(wild.HP);ProjectY.Data.AnimalSpeechState.Consume(wild);
rejects(()=>ProjectY.Data.AnimalSpeechState.Resolve(wild,10),"A dead animal cannot communicate");
checks.Add("shared one-use result, zero/negative outcomes, enemy persistence and invalid transitions");

var data=new ProjectY.Data.WorldPartiesData();var party=data.Add(1,0,0,0,101u);party.ConfigureFaction(1,0,0,"wildlife");
var animal=party.AddMember(1);animal.InitializeAnimal(1,678u);animal.SetMaxHP(100);animal.Restore();animal.Damage(27);
animal.AddTrait(101);animal.AddTrait(102);
ProjectY.Data.CharacterBirthState.Initialize(animal,1,
    new[]{"vitality","endurance","intellect","strength","speed","defense","animalAffinity"},new[]{12,8,5,17,9,11,4});
ProjectY.Data.CharacterBirthState.AssignProfession(animal,1,new[]{"strength","animalAffinity"},new[]{3,2});
party.SetMemberStrength(0,100);party.SetMission("patrol",0,0,10);party.SetDestination(3);party.SetChasing(true);
party.Travel.Plan(new[]{1},new[]{0},new[]{10d},3);party.Travel.Step(3);
data.Factions.Complete();data.Complete(10);data.Open(party.Id);data.Target(party.Id);
var rider=owner(1);
rejects(()=>ProjectY.Data.AnimalSpeechState.RetireParty(data,party),"Retirement requires successful taming");
// Deliberately retain a pending result in this persistence fixture. Gameplay consumes it before the taming roll.
ProjectY.Data.AnimalSpeechState.Resolve(animal,15);animal.DelayTaming(2);rider.TameAndRide(animal,7);
expect(object.ReferenceEquals(ProjectY.Data.AnimalCompanionState.Bound(rider),animal) && object.ReferenceEquals(party.GetMemberAt(0),animal) &&
    animal.AnimalOwnerId==rider.Id && animal.Team==1 && animal.TameRetryTurns==0 && animal.HP==73 && animal.HasTrait(101),
    "Taming transfers the original actor without changing HP or traits");
rejects(()=>owner(2).TameAndRide(animal,7),"The unique animal cannot be owned twice");
rejects(()=>ProjectY.Data.AnimalSpeechState.Resolve(animal,10),"Owned animals cannot receive a taming outcome");
expect(ProjectY.Data.AnimalSpeechState.RetireParty(data,party) && party.MemberCount==1 && party.LivingCount==0 &&
    party.StrategicPower==0 && party.Defeated && !party.Travel.Active && party.Travel.Paused && !party.AbstractTravel &&
    !party.Chasing && party.DestinationSiteId==0 && party.TargetPartyId==0 && party.TargetSiteId==0 && party.Mission=="idle" &&
    data.TargetId==0 && data.ContactId==party.Id && object.ReferenceEquals(party.GetMemberAt(0),animal),
    "Retirement stops the original party while retaining one actor record and the current contact");
expect(ProjectY.Data.AnimalSpeechState.RetireParty(data,party) && animal.HP==73,"Retirement is idempotent and does not damage the animal");
var mixedData=new ProjectY.Data.WorldPartiesData();var mixedParty=mixedData.Add(1,0,0,0,301u);
mixedParty.ConfigureFaction(1,0,0,"wildlife");var transferred=mixedParty.AddMember(1);transferred.InitializeAnimal(1,302u);
var survivor=mixedParty.AddMember(1);survivor.InitializeAnimal(1,303u);
mixedParty.SetMemberStrength(0,40);mixedParty.SetMemberStrength(1,60);owner(3).TameAndRide(transferred,5);
expect(!ProjectY.Data.AnimalSpeechState.RetireParty(mixedData,mixedParty) && !mixedParty.Defeated && mixedParty.LivingCount==1 &&
    mixedParty.StrategicPower==60 && mixedParty.MemberCount==2,"A surviving wild member keeps its original party active");
mixedParty.BeginAbstractTravel(2,0,0,10,1);owner(4).TameAndRide(survivor,5);
expect(ProjectY.Data.AnimalSpeechState.RetireParty(mixedData,mixedParty) && !mixedParty.AbstractTravel && mixedParty.LivingCount==0,
    "Retiring the final wild member also cancels abstract travel");
var mountSave=clone(captureMount.Invoke(rider,null));var partySave=clone(captureParties.Invoke(data,null));
var restoredRider=restoredMount(mountSave);var mount=ProjectY.Data.AnimalCompanionState.Bound(restoredRider);
expect(mount.Id==animal.Id && mount.HP==73 && mount.MaxHP==100 && mount.AnimalBond==7 && mount.TraitCount==2 && mount.HasTrait(101) && mount.HasTrait(102) &&
    mount.InitialProfessionId==1 && mount.GetInitialAttribute("strength")==17 && mount.GetInitialAttribute("animalAffinity")==4 &&
    mount.GetProfessionAttribute(1,"strength")==3 && mount.GetProfessionAttribute(1,"animalAffinity")==2 &&
    ProjectY.Data.AnimalSpeechState.Pending(mount) && ProjectY.Data.AnimalSpeechState.Modifier(mount)==15 &&
    (uint)field(mount,"animalRandom")== (uint)field(mountSave,"random"),
    "Mount JSON roundtrip preserves unique identity, health, traits, birth/profession attributes, bond, RNG and speech");
checks.Add("same-instance taming, retired party authority and complete mount snapshot");

var oldMount=clone(mountSave);set(oldMount,"detailsVersion",0);set(oldMount,"traits",null);set(oldMount,"initialAttributes",null);
set(oldMount,"professionAttributes",null);set(oldMount,"injuries",null);set(oldMount,"speechPending",false);set(oldMount,"speechModifier",0);
var oldRider=restoredMount(oldMount);var oldAnimal=ProjectY.Data.AnimalCompanionState.Bound(oldRider);
expect(oldAnimal.HP==73 && oldAnimal.MaxHP==100 && oldAnimal.AnimalBond==7 && oldAnimal.InitialAttributesAssigned &&
    !oldAnimal.HasInitialAttributes && oldAnimal.TraitCount==0 && oldAnimal.ProfessionAttributeSetCount==0 &&
    !ProjectY.Data.AnimalSpeechState.Pending(oldAnimal),"Legacy mounts preserve HP and template semantics without inventing traits");
var invalidMount=clone(mountSave);set(invalidMount,"detailsVersion",1);set(invalidMount,"traits",null);
rejects(()=>restoredMount(invalidMount),"New mount snapshots require their trait data");
invalidMount=clone(mountSave);set(invalidMount,"speechModifier",101);
rejects(()=>restoredMount(invalidMount),"Invalid saved speech modifier");
checks.Add("legacy mount migration and strict new snapshot validation");

// Exercise the same reconnect phase used by complete expedition preparation, without constructing a world.
System.Func<object,object,bool,ProjectY.Data.PreparedCharacterSave> restoreReferences=(savedMount,savedParties,withArea)=>
{
    var restoredOwner=restoredMount(savedMount);var ids=new System.Collections.Generic.HashSet<int>{restoredOwner.Id};
    var parties=(ProjectY.Data.WorldPartiesData)prepareParties.Invoke(null,new object[]{clone(savedParties),new ProjectY.Data.EquipmentData(),
        new System.Collections.Generic.HashSet<int>(),null,ids});
    var regions=new ProjectY.Data.MapAreaStateData[0];
    if(withArea)
    {
        var areas=new ProjectY.Data.MapAreaData();var area=ProjectY.Data.FactionPersistence.Ensure(areas,3,20,1);
        ProjectY.Data.FactionPersistence.AttachParty(area.AddEncounter(1,1),parties.Find(party.Id));
        regions=new[]{area};
    }
    var prepared=new ProjectY.Data.PreparedCharacterSave();set(prepared,"Actors",new[]{restoredOwner});
    set(prepared,"PreparedWorldParties",parties);set(prepared,"PreparedAreas",regions);
    reconnect.Invoke(null,new object[]{prepared,ids});return prepared;
};
var peaceful=restoreReferences(mountSave,partySave,false);var peacefulParties=ProjectY.Data.WorldPartiesData.Prepared(peaceful);
var peacefulAnimal=peacefulParties.Find(party.Id).GetMemberAt(0);
expect(object.ReferenceEquals(ProjectY.Data.AnimalCompanionState.Bound(peaceful.GetActorAt(0)),peacefulAnimal) && peacefulAnimal.HP==73 &&
    peacefulParties.Find(party.Id).Defeated && peacefulParties.Find(party.Id).StrategicPower==0,
    "Peaceful tame reconnects to the unique world roster without any area");
var attached=restoreReferences(mountSave,partySave,true);var attachedParties=ProjectY.Data.WorldPartiesData.Prepared(attached);
var attachedAreas=(ProjectY.Data.MapAreaStateData[])field(attached,"PreparedAreas");
expect(object.ReferenceEquals(ProjectY.Data.AnimalCompanionState.Bound(attached.GetActorAt(0)),attachedParties.Find(party.Id).GetMemberAt(0)) &&
    object.ReferenceEquals(attachedAreas[0].GetEncounterAt(0).GetEnemyAt(0),attachedParties.Find(party.Id).GetMemberAt(0)),
    "An already attached area reuses that same world actor");
var legacyParties=clone(partySave);var legacyMember=((System.Array)field(((System.Array)field(legacyParties,"parties")).GetValue(0),"members")).GetValue(0);
set(legacyMember,"speechPending",false);set(legacyMember,"speechModifier",0);
var legacyLinked=restoreReferences(oldMount,legacyParties,false);var legacyLinkedAnimal=ProjectY.Data.AnimalCompanionState.Bound(legacyLinked.GetActorAt(0));
expect(legacyLinkedAnimal.HasTrait(101) && legacyLinkedAnimal.GetInitialAttribute("strength")==17,
    "A legacy mount reconnects to existing world traits instead of overwriting them");
var mismatchedMount=clone(mountSave);set(mismatchedMount,"bond",8);
rejects(()=>restoreReferences(mismatchedMount,partySave,false),"Mismatched mount state");
mismatchedMount=clone(mountSave);set(mismatchedMount,"speciesId",2);
rejects(()=>restoreReferences(mismatchedMount,partySave,false),"Mismatched species on the same ID");
var mismatchedParties=clone(partySave);
var mismatchedMember=((System.Array)field(((System.Array)field(mismatchedParties,"parties")).GetValue(0),"members")).GetValue(0);
set(mismatchedMember,"owner",2);
rejects(()=>restoreReferences(mountSave,mismatchedParties,false),"Dangling owner reference");
checks.Add("peaceful and area-linked expedition identity, legacy details and inconsistent reference rejection");

// Verify native retirement/release/detachment preserves the companion; Lua conflict statistics are tested separately.
var battleParties=new ProjectY.Data.WorldPartiesData();var battleParty=battleParties.Add(1,0,0,0,501u);
battleParty.ConfigureFaction(1,0,0,"wildlife");var battleAnimal=battleParty.AddMember(1);
battleAnimal.InitializeAnimal(1,502u);battleAnimal.SetMaxHP(100);battleAnimal.Restore();battleAnimal.Damage(18);battleParty.SetMemberStrength(0,100);
battleParties.Factions.Complete();battleParties.Complete(10);
var conflict=battleParties.Factions.AddConflict(3,battleParty.Id,0,10,20,100,503u);battleParties.EngageParty(battleParty.Id,3);conflict.Engage(true);
var battleAreas=new ProjectY.Data.MapAreaData();var battleArea=ProjectY.Data.FactionPersistence.Ensure(battleAreas,3,20,1);
var group=battleArea.AddEncounter(1,1);ProjectY.Data.FactionPersistence.AttachParty(group,battleParty);
var battleRider=owner(2);ProjectY.Data.AnimalSpeechState.Resolve(battleAnimal,-12);
expect(ProjectY.Data.AnimalSpeechState.Consume(battleAnimal)==-12,"Battle attempt consumes its shared result");
battleRider.TameAndRide(battleAnimal,9);ProjectY.Data.AnimalSpeechState.RetireParty(battleParties,battleParty);
battleParties.ReleaseParty(battleParty.Id,battleParty.LivingCount==0,30);ProjectY.Data.FactionPersistence.DetachParty(group);conflict.Resolve(0,100);
expect(battleAnimal.HP==82 && object.ReferenceEquals(ProjectY.Data.AnimalCompanionState.Bound(battleRider),battleAnimal) &&
    object.ReferenceEquals(battleParty.GetMemberAt(0),battleAnimal) && battleParty.Defeated && battleParty.BattleSiteId==0 &&
    group.EnemyCount==0 && group.Detached && conflict.Phase=="resolved" && !conflict.PlayerEngaged,
    "Native conflict settlement leaves the living companion bound while detaching only the old encounter");
checks.Add("battle retirement, release and historical encounter detachment");
return "PASS animal speech Data: "+string.Join("; ",checks.ToArray());
