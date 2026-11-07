// Fresh native state and JSON only. No Play, live session, or campaign files.
var data=new ProjectY.Data.AdventureData();
data.Reset(41);
var actor=data.AddPartyActor(91001,1);
var second=data.AddPartyActor(91002,1);
System.Action<bool,string> check=(ok,reason)=>{if(!ok)throw new System.Exception(reason);};
System.Action<System.Action,string> invalid=(action,reason)=>
{
    bool rejected=false;
    try{action();}catch(System.ArgumentException){rejected=true;}
    check(rejected,reason);
};
check(ProjectY.Data.ReputationState.Balance(data)==0,"Fresh reputation was not zero");
check(ProjectY.Data.ReputationState.AwardSettlement(data,"mission",11,100),"Mission award missing");
check(!ProjectY.Data.ReputationState.AwardSettlement(data,"mission",11,100),"Duplicate mission paid");
check(ProjectY.Data.ReputationState.AwardSettlement(data,"town",11,30),"Settlement kinds did not have separate receipts");
invalid(()=>ProjectY.Data.ReputationState.AwardSettlement(data,"quest",12,10),"Quest accepted as reputation settlement");
check(ProjectY.Data.ReputationState.AwardKill(data,99,2) && !ProjectY.Data.ReputationState.AwardKill(data,99,2),"Kill receipt was not global");
check(ProjectY.Data.ReputationState.Balance(data)==132,"Incorrect shared reward total");

check(ProjectY.Data.TitleState.NormalizeName("  星火守望  ")=="星火守望","Name normalization failed");
check(ProjectY.Data.TitleState.ValidName(new string('剑',16)) && !ProjectY.Data.TitleState.ValidName(new string('剑',17)),"Unicode name limit failed");
check(ProjectY.Data.TitleState.ValidName("😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀") && !ProjectY.Data.TitleState.ValidName("<color=red>剑"),"Name Unicode or markup boundary failed");
check(!ProjectY.Data.TitleState.ValidName("\t剑") && !ProjectY.Data.TitleState.ValidName("\ud800") && !ProjectY.Data.TitleState.ValidName("   "),"Unsafe name accepted");
int first=ProjectY.Data.TitleState.Craft(data,actor,"  星火守望  ","200:2,101:1",50);
check(first==-1 && ProjectY.Data.TitleState.CustomName(actor,first)=="星火守望","First custom title identity failed");
check(ProjectY.Data.TitleState.CustomCost(actor,first)==50 && ProjectY.Data.TitleState.EffectCount(actor,first)==2
    && ProjectY.Data.TitleState.EffectIdAt(actor,first,0)==101 && ProjectY.Data.TitleState.EffectRankAt(actor,first,1)==2,"Custom effect data changed");
check(ProjectY.Data.TitleState.Count(actor)==0 && ProjectY.Data.TitleState.CustomCount(actor)==1,"Custom titles polluted configured title enumeration");
int other=ProjectY.Data.TitleState.Craft(data,second,"第二个", "301:1",70);
check(other==-1 && ProjectY.Data.ReputationState.Balance(data)==12,"Second actor did not share currency");
check(ProjectY.Data.TitleState.Craft(data,actor,"余额不足","101:1",13)==0 && ProjectY.Data.TitleState.CustomCount(actor)==1,"Insufficient funds changed ownership");
invalid(()=>ProjectY.Data.TitleState.Craft(data,actor,"错误","101:1,101:2",1),"Duplicate effects accepted");
invalid(()=>ProjectY.Data.TitleState.Craft(data,new ProjectY.Data.CombatActorData(actor.Id,1),"错误","101:1",1),"Foreign actor identity accepted");
check(ProjectY.Data.ReputationState.Balance(data)==12,"Rejected crafting consumed reputation");
int next=ProjectY.Data.TitleState.Craft(data,actor,"下一称号","101:1",1);
check(next==-2,"Failed craft consumed custom identity");
ProjectY.Data.TitleState.Award(actor,7);
ProjectY.Data.TitleState.Equip(actor,first);
ProjectY.Data.TitleState.Equip(actor,7);
ProjectY.Data.TitleState.Equip(actor,0);
check(ProjectY.Data.TitleState.Owns(actor,first) && ProjectY.Data.ReputationState.Balance(data)==11,"Unequip changed ownership or refunded currency");
ProjectY.Data.TitleState.Equip(actor,first);
ProjectY.Data.TitleState.Increment(actor,"kill:0");
ProjectY.Data.TitleState.RecordSettlement(actor,"mission",11);

var flags=System.Reflection.BindingFlags.Static|System.Reflection.BindingFlags.NonPublic;
var titleType=typeof(ProjectY.Data.TitleState);
var titleSnapshot=titleType.GetMethod("Capture",flags).Invoke(null,new object[]{actor});
var titleJson=UnityEngine.JsonUtility.ToJson(titleSnapshot);
var savedTitle=UnityEngine.JsonUtility.FromJson(titleJson,titleSnapshot.GetType());
var loadedActor=new ProjectY.Data.CombatActorData(91003,1);
titleType.GetMethod("Restore",flags).Invoke(null,new object[]{loadedActor,savedTitle});
check(ProjectY.Data.TitleState.CustomCount(loadedActor)==2 && ProjectY.Data.TitleState.Equipped(loadedActor)==first
    && ProjectY.Data.TitleState.CustomCost(loadedActor,first)==50 && ProjectY.Data.TitleState.Counter(loadedActor,"kill:0")==1
    && !ProjectY.Data.TitleState.RecordSettlement(loadedActor,"mission",11),"Title roundtrip lost ownership, original price, or progress");
var legacy=UnityEngine.JsonUtility.FromJson("{\"format\":1,\"equipped\":7,\"owned\":[7],\"counters\":[{\"key\":\"kill:0\",\"value\":9}],\"settlements\":[\"mission:11\"]}",titleSnapshot.GetType());
var legacyActor=new ProjectY.Data.CombatActorData(91004,1);
titleType.GetMethod("Restore",flags).Invoke(null,new object[]{legacyActor,legacy});
check(ProjectY.Data.TitleState.Equipped(legacyActor)==7 && ProjectY.Data.TitleState.Counter(legacyActor,"kill:0")==9
    && ProjectY.Data.TitleState.CustomCount(legacyActor)==0,"Legacy title migration changed earned progress");
savedTitle.GetType().GetField("nextCustomId").SetValue(savedTitle,-1);
bool corruptRejected=false;
try{titleType.GetMethod("Restore",flags).Invoke(null,new object[]{new ProjectY.Data.CombatActorData(91005,1),savedTitle});}
catch(System.Reflection.TargetInvocationException e){if(e.InnerException is System.IO.InvalidDataException)corruptRejected=true;else throw;}
check(corruptRejected,"Conflicting custom identity counter accepted");

var instanceFlags=System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic;
var reputationField=typeof(ProjectY.Data.AdventureData).GetField("Reputation",instanceFlags);
var reputation=reputationField.GetValue(data);
var reputationType=reputation.GetType();
var reputationSnapshot=reputationType.GetMethod("Capture",instanceFlags).Invoke(reputation,null);
var reputationJson=UnityEngine.JsonUtility.ToJson(reputationSnapshot);
var restoredReputation=reputationType.GetMethod("Prepare",flags).Invoke(null,new object[]{UnityEngine.JsonUtility.FromJson(reputationJson,reputationSnapshot.GetType())});
var restoredData=new ProjectY.Data.AdventureData();
reputationType.GetMethod("TakePrepared",instanceFlags).Invoke(reputationField.GetValue(restoredData),new[]{restoredReputation});
check(ProjectY.Data.ReputationState.Balance(restoredData)==11 && !ProjectY.Data.ReputationState.AwardSettlement(restoredData,"mission",11,100),"Reputation roundtrip lost balance or permanent receipts");
check(ProjectY.Data.ReputationState.AwardKill(restoredData,99,2),"Transient kill receipt was saved");
foreach(string malformed in new[]{"{\"format\":0}","{\"format\":1,\"balance\":-1,\"settlements\":[]}",
    "{\"format\":1,\"balance\":5,\"settlements\":[\"mission:11\",\"mission:11\"]}",
    "{\"format\":1,\"balance\":5,\"settlements\":[\"quest:11\"]}"})
{
    bool rejected=false;
    var malformedSave=UnityEngine.JsonUtility.FromJson(malformed,reputationSnapshot.GetType());
    try{reputationType.GetMethod("Prepare",flags).Invoke(null,new[]{malformedSave});}
    catch(System.Reflection.TargetInvocationException e){if(e.InnerException is System.IO.InvalidDataException)rejected=true;else throw;}
    check(rejected && ProjectY.Data.ReputationState.Balance(restoredData)==13,"Malformed reputation candidate was accepted or changed live state");
}

ProjectY.Data.TitleCombatState.BeginBattle(data.Battle);
check(ProjectY.Data.TitleCombatState.RecordKill(data.Battle,99) && !ProjectY.Data.TitleCombatState.RecordKill(data.Battle,99),"Battle death dispatch was not deduplicated");
ProjectY.Data.TitleCombatState.BeginTurn(actor);
check(ProjectY.Data.TitleCombatState.TryKillBenefit(actor,2) && ProjectY.Data.TitleCombatState.TryKillBenefit(actor,2)
    && !ProjectY.Data.TitleCombatState.TryKillBenefit(actor,2),"Kill benefit limit failed");
ProjectY.Data.TitleCombatState.End(actor);
check(ProjectY.Data.TitleCombatState.TryKillBenefit(actor,2),"Combat cleanup kept benefit counter");
ProjectY.Data.ReputationState.BeginBattle(data);
check(ProjectY.Data.ReputationState.AwardKill(data,99,2),"New battle retained kill receipt");
data.Reset(42);
check(ProjectY.Data.ReputationState.Balance(data)==0 && ProjectY.Data.ReputationState.AwardSettlement(data,"mission",11,1),"New campaign retained reputation state");
return "Passed: shared reputation, permanent settlement receipts, transient kill receipts, atomic title crafting, Unicode name boundaries, legacy and current title JSON, original paid price, and combat benefit caps.";
