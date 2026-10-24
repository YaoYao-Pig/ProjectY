// In-memory C# LOD tests for the existing idle Editor, after one coordinated project compilation.
// No scenes, assets, saved games, Play mode, or project compilation are created by this body.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.Exception("Idle Edit Mode required");
var flags=System.Reflection.BindingFlags.Public|System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.Static;
var checks=new System.Collections.Generic.List<string>();
System.Action<bool,string> expect=(condition,label)=>{if(!condition)throw new System.Exception(label);};
System.Action<System.Action,string> reject=(operation,label)=>
{
    try{operation();}
    catch(System.Exception failure)
    {
        if(failure is System.Reflection.TargetInvocationException)failure=failure.InnerException;
        if(failure is System.InvalidOperationException || failure is System.ArgumentException || failure is System.IO.InvalidDataException)return;
        throw;
    }
    throw new System.Exception("Expected rejection: "+label);
};
System.Func<object,string,object> field=(record,name)=>record.GetType().GetField(name,flags).GetValue(record);
System.Action<object,string,object> set=(record,name,value)=>record.GetType().GetField(name,flags).SetValue(record,value);
System.Func<object,object> clone=record=>UnityEngine.JsonUtility.FromJson(UnityEngine.JsonUtility.ToJson(record),record.GetType());
var capture=typeof(ProjectY.Data.WorldPartiesData).GetMethod("Capture",flags);
var prepare=typeof(ProjectY.Data.WorldPartiesData).GetMethod("Prepare",flags);
var validateReferences=typeof(ProjectY.Data.WorldPartiesData).GetMethod("ValidateWorldReferences",flags);
var equipment=new ProjectY.Data.EquipmentData();equipment.Grid.Define(101,1,1);
System.Func<object,ProjectY.Data.WorldPartiesData> restore=record=>(ProjectY.Data.WorldPartiesData)prepare.Invoke(null,
    new object[]{record,equipment,new System.Collections.Generic.HashSet<int>(),null,new System.Collections.Generic.HashSet<int>()});
System.Func<ProjectY.Data.WorldPartiesData,int,int,ProjectY.Data.WorldPartyData> add=(collection,qCoordinate,factionId)=>
{
    var unitParty=collection.Add(1,qCoordinate,0,0,(uint)(collection.Count+1));unitParty.ConfigureFaction(factionId,qCoordinate,0,"raider");
    var unit=unitParty.AddMember(1);unit.SetMaxHP(100);unit.Restore();unitParty.SetMemberStrength(0,300);return unitParty;
};
System.Action<ProjectY.Data.WorldPartiesData> initialize=collection=>{collection.Factions.Complete();collection.Complete(0);collection.CompleteFactionMigration();};
System.Func<ProjectY.Data.WorldPartiesData,double,int,ProjectY.Data.WorldPartySimulationBatch> due=(collection,scheduledMinute,playerCoordinate)=>collection.Due(scheduledMinute,playerCoordinate,0,8,24,2,10,60);

var world=new ProjectY.Data.WorldPartiesData();var near=add(world,0,1);var medium=add(world,15,2);var far=add(world,50,2);initialize(world);
var first=due(world,0,0);
expect(first.Count==3 && near.Lod==1 && medium.Lod==2 && far.Lod==3,"Initial three-tier classification");
expect(near.NextSimulationAt==1 && medium.NextSimulationAt==10 && far.NextSimulationAt==60,"Absolute per-tier deadlines");
var minuteOne=due(world,1,0);
expect(minuteOne.Count==1 && minuteOne.GetAt(0).Party==near && minuteOne.GetAt(0).Elapsed==1,"Only due parties cross the bridge");
var promotion=due(world,5,50);
expect(promotion.Count==1 && promotion.GetAt(0).Party==far && promotion.GetAt(0).PreviousLod==3 && promotion.GetAt(0).Lod==1 && promotion.GetAt(0).Elapsed==5,
    "Promotion returns all deferred time once without minute replay");
expect(medium.SimulatedAt==0 && medium.Lod==3 && medium.NextSimulationAt==60,"Demotion retains unsettled time");
expect(due(world,5,50).Count==0,"Same-time repeated query does not resimulate actors");
checks.Add("three-tier deadlines, promotion catch-up and demotion debt");

var hysteresisWorld=new ProjectY.Data.WorldPartiesData();var edge=add(hysteresisWorld,7,1);initialize(hysteresisWorld);
due(hysteresisWorld,0,-4);expect(edge.Lod==2,"Distance eleven starts in the middle tier");
var enterNear=due(hysteresisWorld,1,-1);
expect(enterNear.Count==1 && edge.Lod==1 && enterNear.GetAt(0).PreviousLod==2 && enterNear.GetAt(0).Elapsed==1,
    "Entering distance eight immediately uses full precision");
expect(due(hysteresisWorld,2,-2).Count==1 && edge.Lod==1,"Distance nine retains full precision while leaving");
expect(due(hysteresisWorld,3,-3).Count==1 && edge.Lod==1,"Distance ten retains full precision while leaving");
expect(due(hysteresisWorld,4,-4).Count==0 && edge.Lod==2 && edge.SimulatedAt==3,"Distance eleven downgrades without discarding pending time");
expect(due(hysteresisWorld,5,-5).Count==0 && edge.SimulatedAt==3,"Middle tier accumulates its complete unsettled interval");
var reentry=due(hysteresisWorld,6,-1);
expect(reentry.Count==1 && reentry.GetAt(0).PreviousLod==2 && reentry.GetAt(0).Elapsed==3 && edge.Lod==1,
    "Reentering distance eight settles the full accumulated interval once");
expect(due(hysteresisWorld,6,-1).Count==0,"Repeated boundary query cannot settle the interval twice");
checks.Add("full precision inside near radius and hysteresis only on leaving");

var borderWorld=new ProjectY.Data.WorldPartiesData();var borderSource=add(borderWorld,8,1);var borderNeighbor=add(borderWorld,9,2);var borderChain=add(borderWorld,10,2);initialize(borderWorld);
due(borderWorld,0,-2);
expect(borderSource.Lod==2 && borderNeighbor.Lod==2 && borderChain.Lod==2,"Border parties begin in the middle tier");
var borderDue=due(borderWorld,1,0);
expect(borderDue.Count==2 && borderDue.GetAt(0).Party==borderSource && borderDue.GetAt(1).Party==borderNeighbor && borderNeighbor.Lod==1 &&
    borderDue.GetAt(1).PreviousLod==2 && borderDue.GetAt(1).Elapsed==1 && borderChain.Lod==2 && borderChain.SimulatedAt==0,
    "Initial near neighbors promote immediately in ID order without recursively promoting a chain");
var sensorWorld=new ProjectY.Data.WorldPartiesData();var sensorSource=add(sensorWorld,0,1);var sensorFirst=add(sensorWorld,1,2);var sensorSecond=add(sensorWorld,2,2);
add(sensorWorld,1,1);var sensorGuard=add(sensorWorld,1,2);sensorGuard.ConfigureFaction(2,1,0,"garrison");
var sensorOccupied=add(sensorWorld,1,2);sensorOccupied.SetMission("occupy",0,1,100);
var sensorDead=add(sensorWorld,1,2);sensorDead.GetMemberAt(0).Damage(100);sensorDead.SetDefeated(true);
var sensorProtected=add(sensorWorld,1,2);sensorWorld.ReleaseParty(sensorProtected.Id,false,101);
var sensorEngaged=add(sensorWorld,1,2);sensorWorld.EngageParty(sensorEngaged.Id,1);add(sensorWorld,20,2);initialize(sensorWorld);
var sensed=sensorWorld.NearbyMobile(sensorSource.Id,2,100);
expect(sensed.Length==2 && sensed[0]==sensorFirst && sensed[1]==sensorSecond && sensorSource.BattleSiteId==0 && sensorFirst.BattleSiteId==0,
    "C# sensor returns only nearby actionable other-faction mobile parties without mutation");
expect(sensorWorld.NearbyMobile(sensorSource.Id,0,100).Length==0,"Spatial sensor respects its requested radius");
checks.Add("single-round adjacent LOD propagation and C# mobile sensor filtering");

var splitWorld=new ProjectY.Data.WorldPartiesData();var splitParty=add(splitWorld,0,1);initialize(splitWorld);due(splitWorld,0,0);
var singleWorld=new ProjectY.Data.WorldPartiesData();var singleParty=add(singleWorld,0,1);initialize(singleWorld);due(singleWorld,0,0);
splitParty.Travel.Plan(new[]{1},new[]{0},new[]{4d},0);singleParty.Travel.Plan(new[]{1},new[]{0},new[]{4d},0);
expect(splitWorld.ElapsedTicks(.25)==0 && due(splitWorld,splitWorld.Clock-splitWorld.Remainder,0).Count==0 && splitWorld.Clock==.25 && splitWorld.Remainder==.25,
    "LOD classification preserves a fractional narrative clock and unfinished minute");
expect(splitWorld.ElapsedTicks(1)==1 && singleWorld.ElapsedTicks(1)==1,"Quarter and three-quarter frames equal one elapsed minute");
var splitDue=due(splitWorld,splitWorld.Clock-splitWorld.Remainder,0);var singleDue=due(singleWorld,singleWorld.Clock-singleWorld.Remainder,0);
splitParty.Travel.AdvanceRoute(splitDue.GetAt(0).Elapsed);singleParty.Travel.AdvanceRoute(singleDue.GetAt(0).Elapsed);
expect(splitDue.Count==singleDue.Count && splitDue.GetAt(0).Elapsed==1 && splitParty.Travel.Progress==singleParty.Travel.Progress &&
    splitWorld.Clock==singleWorld.Clock && splitWorld.Remainder==singleWorld.Remainder,"Sub-frame scheduling and route progress are partition independent");
checks.Add("fractional ElapsedTicks compatibility and frame partition invariance");

var forcedWorld=new ProjectY.Data.WorldPartiesData();var forced=add(forcedWorld,100,1);initialize(forcedWorld);due(forcedWorld,0,0);
forcedWorld.Target(forced.Id);var targetDue=due(forcedWorld,2,0);
expect(targetDue.Count==1 && forced.Lod==1 && targetDue.GetAt(0).Elapsed==2,"Explicit player target is forced near");
forcedWorld.Target(0);due(forcedWorld,3,0);
var playerConflict=forcedWorld.Factions.AddConflict(1,forced.Id,0,3,3,30,1);forcedWorld.EngageParty(forced.Id,1);playerConflict.Engage(true);
expect(due(forcedWorld,4,0).Count==1 && forced.Lod==1,"Player-engaged conflict is forced near");
playerConflict.Engage(false);
checks.Add("target and player battle promotion");

var journey=new ProjectY.Data.WorldTravelData();journey.Reset(12,0,0,1);
journey.Plan(new[]{1,2,3},new[]{0,0,0},new[]{1d,2d,3d},0);
expect(journey.AdvanceRoute(2.5)==2.5 && journey.Q==1 && journey.Progress==.75,"Batch route handles partial steps");
expect(journey.AdvanceRoute(10)==3.5 && journey.Q==3 && !journey.Active,"Batch route stops at destination and returns actual time spent");
expect(journey.AdvanceRoute(10)==0,"Route arrival never selects a new destination");
var crossingWorld=new ProjectY.Data.WorldPartiesData();var crossing=add(crossingWorld,30,1);initialize(crossingWorld);due(crossingWorld,0,0);
var qs=new int[60];var rs=new int[60];var minutes=new double[60];
for(int i=0;i<60;i++){qs[i]=29-i;rs[i]=0;minutes[i]=1;}
crossing.Travel.Plan(qs,rs,minutes,0);
var crossingDue=due(crossingWorld,24,0);
expect(crossingDue.Count==1 && crossing.Lod==1 && crossingDue.GetAt(0).Elapsed==24,"An unsettled route approaching the player promotes before its far deadline");
checks.Add("batch route progress and nearby path crossing");

var abstractWorld=new ProjectY.Data.WorldPartiesData();var abstractParty=add(abstractWorld,100,1);initialize(abstractWorld);due(abstractWorld,0,0);
abstractParty.BeginAbstractTravel(110,0,0,30,1);
expect(abstractParty.NextSimulationAt==30 && due(abstractWorld,20,0).Count==0,"Arrival deadline shortens the far schedule without completing early");
var abstractSave=clone(capture.Invoke(abstractWorld,null));var abstractRestored=restore(abstractSave);var restoredJourney=abstractRestored.Find(abstractParty.Id);
expect(restoredJourney.AbstractTravel && restoredJourney.AbstractArrivalAt==30 && restoredJourney.SimulatedAt==0 && restoredJourney.Travel.Q==100,
    "Abstract journey and unsettled time survive JSON roundtrip");
expect(!restoredJourney.CompleteAbstractTravel(29.999) && restoredJourney.Travel.Q==100,"Abstract arrival cannot happen early");
var arrivalDue=due(abstractRestored,30,0);
expect(arrivalDue.Count==1 && arrivalDue.GetAt(0).Elapsed==30 && restoredJourney.CompleteAbstractTravel(30) && restoredJourney.Travel.Q==110 && !restoredJourney.AbstractTravel,
    "A due abstract journey lands only at its scheduled arrival");
restore(clone(capture.Invoke(abstractRestored,null)));
var abstractCrossing=new ProjectY.Data.WorldPartiesData();var possible=add(abstractCrossing,-50,1);initialize(abstractCrossing);due(abstractCrossing,0,0);
possible.BeginAbstractTravel(50,0,0,60,1);
var possibleDue=due(abstractCrossing,43,0);
expect(possibleDue.Count==1 && possible.Lod==1 && possibleDue.GetAt(0).PreviousLod==3,"Abstract segment corridor promotes a possible player crossing");
double fraction=(43-possible.AbstractStartedAt)/(possible.AbstractArrivalAt-possible.AbstractStartedAt);
possible.CancelAbstractTravel();
var projectionQs=new int[100];var projectionRs=new int[100];var projectionMinutes=new double[100];
for(int i=0;i<100;i++){projectionQs[i]=-49+i;projectionMinutes[i]=2;}
possible.Travel.Plan(projectionQs,projectionRs,projectionMinutes,0);possible.Travel.AdvanceRoute(fraction*200);
expect(!possible.AbstractTravel && possible.Travel.Q==21 && possible.Travel.Progress>0,"Promotion can replace abstraction with one valid route projection");
var distantJourneyWorld=new ProjectY.Data.WorldPartiesData();var distantJourney=add(distantJourneyWorld,100,1);initialize(distantJourneyWorld);due(distantJourneyWorld,0,0);
distantJourney.BeginAbstractTravel(200,0,0,10000,1);due(distantJourneyWorld,5000,0);
expect(distantJourney.Lod==3,"Long abstract journey age must not grow an unbounded near-tier circle");
checks.Add("abstract journey persistence, strict arrival and promotion projection");

near.GetMemberAt(0).Damage(50);
expect(near.StrategicPower==150 && near.StrengthReady,"Strategic power reflects authoritative wounds without Lua actor reads");
var saved=clone(capture.Invoke(world,null));var resumed=restore(saved);
expect(resumed.Find(near.Id).StrategicPower==150 && resumed.Find(medium.Id).SimulatedAt==0 && resumed.Clock==5,"Strength weights and pending schedules roundtrip");
var legacy=clone(saved);set(legacy,"scheduleVersion",0);set(legacy,"strengthVersion",0);
var migrated=restore(legacy);
expect(!migrated.ScheduleInitialized && migrated.Find(medium.Id).SimulatedAt==5 && migrated.Find(medium.Id).NextSimulationAt==5 && !migrated.Find(near.Id).StrengthReady,
    "Legacy data starts at its saved clock and requires explicit strength calibration");
var migratedDue=due(migrated,5,0);
for(int i=0;i<migratedDue.Count;i++)expect(migratedDue.GetAt(i).Elapsed==0,"Legacy load must not replay history");
var invalid=clone(saved);var invalidRows=(System.Array)field(invalid,"parties");set(invalidRows.GetValue(0),"simulatedAt",6d);
reject(()=>restore(invalid),"Future party simulation timestamp");
invalid=clone(saved);invalidRows=(System.Array)field(invalid,"parties");set(invalidRows.GetValue(0),"memberStrengths",new[]{double.NaN});
reject(()=>restore(invalid),"Nonfinite strategic strength");
checks.Add("strength snapshot, save debt, migration and malformed schedule rejection");

var cargoWorld=new ProjectY.Data.WorldPartiesData();var winner=add(cargoWorld,0,1);var loser=add(cargoWorld,1,2);initialize(cargoWorld);
loser.ConfigureFaction(2,1,0,"caravan");
winner.SetCargo("Winner cargo",new[]{101},new[]{1},new[]{"material"},new[]{1},new[]{1});
loser.SetCargo("Defeated cargo",new[]{101},new[]{3},new[]{"material"},new[]{1},new[]{1});
var originalCargo=loser.Cargo;var abstractConflict=cargoWorld.Factions.AddAbstractConflict(1,winner.Id,loser.Id,0,10,60,5);
cargoWorld.EngageParty(winner.Id,1);cargoWorld.EngageParty(loser.Id,1);
expect(!cargoWorld.CaptureCargo(winner.Id,loser.Id) && cargoWorld.DeferCargo(loser.Id,abstractConflict) &&
    object.ReferenceEquals(originalCargo,abstractConflict.GetPendingCargoAt(0)) && loser.Cargo!=null && loser.CargoCount==0,
    "Abstract conflict retains the original overflow cargo and a valid empty caravan hold");
expect(!cargoWorld.DeferCargo(loser.Id,abstractConflict),"Deferred cargo cannot be duplicated");
validateReferences.Invoke(cargoWorld,new object[]{1,1,new System.Collections.Generic.HashSet<int>()});
var cargoSave=clone(capture.Invoke(cargoWorld,null));var cargoRestored=restore(cargoSave);var pending=cargoRestored.Factions.FindConflict(1);
expect(!pending.Materialized && pending.PendingCargoCount==1 && pending.GetPendingCargoAt(0).GetCountAt(0)==3,"Abstract result and pending cargo survive persistence without a MapArea");
reject(()=>pending.Engage(true),"Abstract battle must materialize before player engagement");
var materialized=new ProjectY.Data.MapAreaStateData(1,20,1);ProjectY.Data.ExpeditionPersistence.Definition(materialized,1);
materialized.CompleteEncounterInitialization();materialized.CompleteLootInitialization();pending.MarkMaterialized();
expect(cargoRestored.DropDeferredCargo(pending,materialized,1)==1 && cargoRestored.DropDeferredCargo(pending,materialized,1)==0 &&
    pending.PendingCargoCount==0 && materialized.LootCount==1 && materialized.GetLootAt(0).GetCountAt(0)==3,"Materialization transfers pending cargo once");
reject(()=>validateReferences.Invoke(cargoRestored,new object[]{1,1,new System.Collections.Generic.HashSet<int>()}),"Materialized conflict still requires its persistent area");
validateReferences.Invoke(cargoRestored,new object[]{1,1,new System.Collections.Generic.HashSet<int>{1}});
set(field(cargoSave,"factions"),"materializationVersion",0);
expect(restore(cargoSave).Factions.FindConflict(1).Materialized,"Legacy conflicts remain materialized by default");
checks.Add("abstract battle validation and exact-once deferred cargo ownership");

var budgetWorld=new ProjectY.Data.WorldPartiesData();for(int i=0;i<45;i++)add(budgetWorld,100+i,1);initialize(budgetWorld);due(budgetWorld,0,0);
int returned=0;var watch=System.Diagnostics.Stopwatch.StartNew();
for(int minute=1;minute<=60;minute++)returned+=due(budgetWorld,minute,0).Count;
watch.Stop();expect(returned==45,"Forty-five far parties produce one update each across sixty minutes");
checks.Add("60-minute scheduler: "+returned+" due rows, "+watch.Elapsed.TotalMilliseconds.ToString("F3")+" ms (data-only timing)");
return "PASS faction LOD Data: "+string.Join("; ",checks.ToArray());
