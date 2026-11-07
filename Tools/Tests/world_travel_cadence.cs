// Existing idle Editor only. Isolated state and JSON; no scenes or player saves.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.Exception("Idle Edit Mode required");
var checks=new System.Collections.Generic.List<string>();
System.Action<bool,string> expect=(ok,message)=>{if(!ok)throw new System.Exception(message);};
var flags=System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.Static|System.Reflection.BindingFlags.Public|System.Reflection.BindingFlags.NonPublic;
var type=typeof(ProjectY.Data.WorldTravelData);
var capture=type.GetMethod("Capture",flags);var prepare=type.GetMethod("Prepare",flags);var commit=type.GetMethod("TakePrepared",flags);
System.Func<ProjectY.Data.WorldTravelData,object> save=data=>{
    var row=capture.Invoke(data,null);return UnityEngine.JsonUtility.FromJson(UnityEngine.JsonUtility.ToJson(row),row.GetType());
};
System.Func<object,ProjectY.Data.WorldTravelData> restore=row=>(ProjectY.Data.WorldTravelData)prepare.Invoke(null,new[]{row});
System.Func<uint,ProjectY.Data.WorldTravelData> trip=seed=>{
    var data=new ProjectY.Data.WorldTravelData();data.Reset(seed,0,0,20);
    var qs=new int[32];var rs=new int[32];var costs=new double[32];
    for(int i=0;i<qs.Length;i++){qs[i]=i+1;costs[i]=720;}
    data.Plan(qs,rs,costs,0);return data;
};
var boundary=trip(1);boundary.AdvanceRoute(1439);
expect(!boundary.CheckDue(1440,1440),"No check before one full travel day");
boundary.Step(1);expect(boundary.CheckDue(1440,1440),"Check at the exact one-day boundary");
boundary.AddStop(201,0);expect(boundary.Paused && boundary.Step(100)==0,"Event pauses and preserves route");
boundary.SetPaused(false);boundary.AdvanceRoute(1439);
expect(!boundary.CheckDue(1440,1440),"Triggered event must restart the full cooldown");
boundary.Step(1);expect(boundary.CheckDue(1440,1440),"Next trigger can occur after a full day");
checks.Add("24-hour boundary and post-event cooldown");

var intervals=new System.Collections.Generic.HashSet<double>();
for(uint seed=1;seed<=32;seed++){
    var data=trip(seed);expect(!data.CheckDue(1440,2880),"Fresh trip cannot be due");
    var row=save(data);var interval=(double)row.GetType().GetField("checkInterval").GetValue(row);
    expect(interval>=1440 && interval<=2880,"Random interval outside 24-48 hours");intervals.Add(interval);
    data.AdvanceRoute(interval-0.01);expect(!data.CheckDue(1440,2880),"Random check fired early");
    data.AdvanceRoute(0.02);expect(data.CheckDue(1440,2880),"Random interval did not become due");
    expect(!data.CheckDue(1440,2880),"Check failure cannot immediately retry");
}
expect(intervals.Count>20,"Intervals must vary between seeds");
var overdue=trip(9);overdue.AdvanceRoute(10000);
expect(overdue.CheckDue(1440,2880) && !overdue.CheckDue(1440,2880),"Overdue travel cannot burst through a backlog");
checks.Add("random 24-48 hour bounds, failed-check reset and overdue backlog");

var original=trip(42);original.AdvanceRoute(900);expect(!original.CheckDue(1440,2880),"Fixture below minimum");
var saved=save(original);var twin=restore(saved);expect(twin.Paused,"Restore pauses travel");
var committed=trip(99);commit.Invoke(committed,new object[]{twin});
twin.SetPaused(false);committed.SetPaused(false);
for(int minute=0;minute<4000;minute++){
    original.Step(1);twin.Step(1);committed.Step(1);
    var due=original.CheckDue(1440,2880);
    expect(due==twin.CheckDue(1440,2880) && due==committed.CheckDue(1440,2880),"Save/prepare/commit changed the pending interval");
    if(due){var roll=original.Roll(100);expect(roll==twin.Roll(100) && roll==committed.Roll(100),"Save changed random sequence");}
}
var json=UnityEngine.JsonUtility.ToJson(saved);
var legacyJson=System.Text.RegularExpressions.Regex.Replace(json,"\"checkInterval\":[^,}]+,?","");
var legacy=restore(UnityEngine.JsonUtility.FromJson(legacyJson,saved.GetType()));legacy.SetPaused(false);
expect(!legacy.CheckDue(1440,2880),"Old saves initialize a valid interval from their saved stream");
foreach(var invalid in new[]{-1d,double.NaN,double.PositiveInfinity}){
    var bad=save(original);bad.GetType().GetField("checkInterval").SetValue(bad,invalid);bool rejected=false;
    try{restore(bad);}catch(System.Reflection.TargetInvocationException){rejected=true;}
    expect(rejected,"Invalid interval accepted from a save");
}
checks.Add("JSON roundtrip, restore/commit, old-save default and corrupt-value rejection");

var water=trip(7);water.AdvanceRoute(1000);water.CheckDue(1440,2880);var before=save(water);
water.DiscardEncounterTime();var after=save(water);
expect((double)after.GetType().GetField("sinceCheck").GetValue(after)==0 &&
    (double)before.GetType().GetField("checkInterval").GetValue(before)==(double)after.GetType().GetField("checkInterval").GetValue(after) &&
    (uint)before.GetType().GetField("random").GetValue(before)==(uint)after.GetType().GetField("random").GetValue(after),"Water reset rerolled the pending interval");
water.AdvanceRoute(1439);expect(!water.CheckDue(1440,2880),"Water travel must not count toward the land cooldown");
checks.Add("water reset preserves pending interval and random stream");

System.Func<double,string> sequence=budget=>{
    var data=trip(431);var events=new System.Collections.Generic.List<string>();double total=0;
    while(data.Active){double remaining=budget;while(data.Active && remaining>0){
        double spent=data.Step(remaining);remaining-=spent;total+=spent;
        if(data.Active && data.Progress==0 && data.CheckDue(1440,2880))events.Add(total+":"+data.Roll(100));
    }}
    return string.Join(",",events);
};
expect(sequence(3)==sequence(48) && sequence(3)==sequence(20000),"Frame budget changed check times or random sequence");
using(var lua=new XLua.LuaEnv()){
    var result=lua.DoString("local d=CS.ProjectY.Data.WorldTravelData();d:Reset(1,0,0,2);assert(not d:CheckDue(1440,2880));return true");
    expect(result.Length==1 && (bool)result[0],"xLua cannot resolve the new overload");
}
checks.Add("frame/speed determinism and real xLua overload");
return "PASS "+string.Join("\nPASS ",checks);
