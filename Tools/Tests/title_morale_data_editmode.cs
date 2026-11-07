// Targeted native data check; fresh actors only, no Play and no campaign files.
var actor=new ProjectY.Data.CombatActorData(91001,1);
var second=new ProjectY.Data.CombatActorData(91002,1);
var type=typeof(ProjectY.Data.TitleState);
var flags=System.Reflection.BindingFlags.Static|System.Reflection.BindingFlags.NonPublic;
ProjectY.Data.TitleState.Increment(actor,"kill:0");
ProjectY.Data.TitleState.Increment(actor,"kill:2");
if(!ProjectY.Data.TitleState.RecordKill(actor,41) || ProjectY.Data.TitleState.RecordKill(actor,41))throw new System.Exception("Duplicate kill credited");
ProjectY.Data.TitleState.BeginBattle(actor);
if(!ProjectY.Data.TitleState.RecordKill(actor,41))throw new System.Exception("Battle kill receipt not reset");
if(!ProjectY.Data.TitleState.RecordSettlement(actor,"mission",8) || ProjectY.Data.TitleState.RecordSettlement(actor,"mission",8))throw new System.Exception("Duplicate settlement credited");
ProjectY.Data.TitleState.Award(actor,1);ProjectY.Data.TitleState.Award(actor,2);ProjectY.Data.TitleState.Award(actor,1);
ProjectY.Data.TitleState.Equip(actor,1);ProjectY.Data.TitleState.Equip(actor,2);
if(ProjectY.Data.TitleState.Count(actor)!=2 || ProjectY.Data.TitleState.Equipped(actor)!=2)throw new System.Exception("Title ownership/single slot failure");
bool rejected=false;
try{ProjectY.Data.TitleState.Equip(second,2);}catch(System.InvalidOperationException){rejected=true;}
if(!rejected)throw new System.Exception("Unearned title equipped");
var snapshot=type.GetMethod("Capture",flags).Invoke(null,new object[]{actor});
var json=UnityEngine.JsonUtility.ToJson(snapshot);
var roundtrip=UnityEngine.JsonUtility.FromJson(json,snapshot.GetType());
type.GetMethod("Restore",flags).Invoke(null,new object[]{second,roundtrip});
if(ProjectY.Data.TitleState.Equipped(second)!=2 || ProjectY.Data.TitleState.Counter(second,"kill:2")!=1
    || ProjectY.Data.TitleState.RecordSettlement(second,"mission",8))throw new System.Exception("Title save round trip lost state");
roundtrip.GetType().GetField("equipped").SetValue(roundtrip,999);rejected=false;
try{type.GetMethod("Restore",flags).Invoke(null,new object[]{new ProjectY.Data.CombatActorData(91003,1),roundtrip});}
catch(System.Reflection.TargetInvocationException e){if(e.InnerException is System.IO.InvalidDataException)rejected=true;else throw;}
if(!rejected)throw new System.Exception("Corrupt equipped title accepted");
ProjectY.Data.MoraleState.Begin(actor,100,75,0);
ProjectY.Data.MoraleState.Set(actor,100,0,-3);
if(ProjectY.Data.MoraleState.Stage(actor)!=-3 || ProjectY.Data.MoraleState.Current(actor)!=0)throw new System.Exception("Morale state failure");
ProjectY.Data.MoraleState.End(actor);
if(ProjectY.Data.MoraleState.Active(actor))throw new System.Exception("Morale survived battle cleanup");
return "Passed: native title ownership, single slot, receipts, JSON round trip, corruption rejection and transient morale cleanup.";
