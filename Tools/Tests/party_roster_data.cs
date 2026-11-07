// Run in the existing idle Editor. Independent Data only; no scenes, Play or player saves.
if(EditorApplication.isPlayingOrWillChangePlaymode||EditorApplication.isCompiling)throw new System.InvalidOperationException("Idle Edit Mode required");
System.Action<bool,string> check=(value,message)=>{if(!value)throw new System.Exception(message);};
var flags=System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Instance;
var prepare=typeof(ProjectY.Data.PartyRoster).GetMethod("Prepare",System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Static);
var capture=typeof(ProjectY.Data.AdventureData).GetMethod("CaptureRoster",flags);
var restore=typeof(ProjectY.Data.AdventureData).GetMethod("RestoreRoster",flags);
System.Func<ProjectY.Data.AdventureData> create=()=>{
    var d=new ProjectY.Data.AdventureData();d.Reset(123);
    for(int i=1;i<=4;i++){var actor=d.AddPartyActor(i,1);actor.SetMaxHP(40);actor.Restore();}
    var c=ProjectY.Data.CampData.For(d);c.Open();
    check(ProjectY.Data.PartyRoster.Move(d,2,true,c.Revision)=="","Move fixture failed");
    var patient=ProjectY.Data.PartyRoster.Find(d,2);patient.Damage(20);ProjectY.Data.BodyHealth.Injure(patient,0,1,60);return d;
};
var whole=create();var split=create();
ProjectY.Data.PartyRoster.AdvanceRecovery(whole,1440,.25,20,2);
ProjectY.Data.PartyRoster.AdvanceRecovery(split,17,.25,20,2);
var saved=capture.Invoke(split,null);
var members=new ProjectY.Data.CombatActorData[4];for(int i=0;i<4;i++)members[i]=ProjectY.Data.PartyRoster.At(split,i);
var restored=new ProjectY.Data.AdventureData();restore.Invoke(restored,new object[]{members,saved});
for(int minute=18;minute<=1440;minute++)ProjectY.Data.PartyRoster.AdvanceRecovery(restored,minute,.25,20,2);
var p=ProjectY.Data.PartyRoster.Find(restored,2);var expected=ProjectY.Data.PartyRoster.Find(whole,2);
check(p.HP==expected.HP && ProjectY.Data.BodyHealth.Damage(p,0)==ProjectY.Data.BodyHealth.Damage(expected,0),"Small ticks or restoring fractional progress changed recovery");
prepare.Invoke(null,new object[]{capture.Invoke(restored,null),members,1440.0,false});
var legacy=prepare.Invoke(null,new object[]{null,members,1440.0,true});
check((int)legacy.GetType().GetField("activeCount").GetValue(legacy)==4,"Legacy roster did not retain all active members");
check((double)legacy.GetType().GetField("recoveryMinute").GetValue(legacy)==1440,"Legacy roster retroactively rests members");
saved=capture.Invoke(restored,null);
System.Action<string,object> reject=(field,value)=>{
    var info=saved.GetType().GetField(field);var previous=info.GetValue(saved);info.SetValue(saved,value);bool failed=false;
    try{prepare.Invoke(null,new object[]{saved,members,1440.0,false});}catch(System.Reflection.TargetInvocationException){failed=true;}
    finally{info.SetValue(saved,previous);}check(failed,"Accepted invalid roster: "+field);
};
reject("activeCount",0);reject("activeCount",5);reject("protagonistId",999);reject("recoveryMinute",1441.0);
var large=new ProjectY.Data.CombatActorData[10];for(int i=0;i<10;i++)large[i]=new ProjectY.Data.CombatActorData(i+1,1);
saved.GetType().GetField("activeCount").SetValue(saved,3);bool overflow=false;
try{prepare.Invoke(null,new object[]{saved,large,1440.0,false});}catch(System.Reflection.TargetInvocationException){overflow=true;}
check(overflow,"Seven reserves accepted");
restored.Reset(124);check(ProjectY.Data.PartyRoster.Count(restored)==0,"Reset retained reserves");
return "PASS roster data: fractional time invariance and restoration; legacy migration; empty/overfull active, seven reserves, foreign protagonist and future clock rejection; new campaign reset.";
