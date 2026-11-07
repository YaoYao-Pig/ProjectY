// Run only after the coordinator's single compilation, in the already open idle Editor.
// Fresh Data and in-memory serialization only; no scene, player save, or world session is changed.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new System.Exception("Idle Edit Mode required");
var checks=new System.Collections.Generic.List<string>();
System.Action<bool,string> check=(ok,label)=>{if(!ok)throw new System.Exception(label);checks.Add(label);};
System.Action<System.Action,string> rejects=(action,label)=>{try{action();}catch(System.Exception){checks.Add(label);return;}throw new System.Exception("Expected rejection: "+label);};
var appearances=new ProjectY.Data.CharacterAppearanceService();
System.Action<ProjectY.Data.CombatActorData> initialize=actor=>
{
    ProjectY.Data.CharacterBirthState.UseTemplate(actor);
    actor.Growth.Initialize(818,2,3,4);actor.Growth.JoinProfession(1);actor.Growth.GrantSkill(401);
    ProjectY.Data.CharacterBirthState.AssignProfession(actor,1,new string[0],new int[0]);
    actor.SetMaxHP(120);actor.Restore();actor.AddTrait(7);
    appearances.Create(actor,818,"human","male");
};
var data=new ProjectY.Data.AdventureData();data.Reset(818);
var people=ProjectY.Data.PeopleState.Get(data);
var first=people.CreateResident(12,100001,1,1,1,"");initialize(first.Actor);
var second=people.CreateResident(13,100001,1,1,1,"");initialize(second.Actor);
var friend=people.CreateResident(12,100002,1,3,2,"");initialize(friend.Actor);
first.SetBond(friend.Key);
check(first.Actor.Id!=second.Actor.Id && first.Key=="resident:12:100001" && second.Key=="resident:13:100001","cross-town identity uniqueness");
check(object.ReferenceEquals(first,people.CreateResident(12,100001,1,1,1,"")),"resident initialization is idempotent");
check(first.Meet() && !first.Meet(),"meeting is recorded once");first.AddTrust(1000);check(first.Trust==100,"trust is bounded");
ProjectY.Data.BodyHealth.Injure(first.Actor,2,1,27);first.Actor.Damage(31);
int health=first.Actor.HP;string appearance=first.Actor.CustomizationJson;
var recruited=ProjectY.Data.PeopleState.Recruit(data,first.Key);
check(object.ReferenceEquals(recruited,first.Actor) && object.ReferenceEquals(ProjectY.Data.PartyRoster.Find(data,recruited.Id),first.Actor) && first.Joined,
    "resident joins with the same authoritative actor");
check(recruited.HP==health && ProjectY.Data.BodyHealth.Damage(recruited,2)==27 && recruited.HasTrait(7) && recruited.CustomizationJson==appearance && recruited.Growth.HasSkill(401),
    "recruitment preserves health, injuries, trait, appearance and skills");
rejects(()=>ProjectY.Data.PeopleState.Recruit(data,first.Key),"repeat recruitment rejected");
check(ProjectY.Data.PeopleState.RecordGrowthEvent(data,first.Actor.Id,"battle","encounter:1") &&
    !ProjectY.Data.PeopleState.RecordGrowthEvent(data,first.Actor.Id,"battle","encounter:1") && first.BattleWins==1,"growth receipts are idempotent");
check(ProjectY.Data.PeopleState.RecordGrowthEvent(data,first.Actor.Id,"learn","402") && first.LearnedSkills==1,"active learning progress recorded");
check(!ProjectY.Data.PeopleState.RecordGrowthEvent(data,friend.Actor.Id,"rescue","1"),"unjoined people receive no retrospective growth");
check(ProjectY.Data.PeopleState.ChooseGrowth(data,first.Actor.Id,0,101) && !ProjectY.Data.PeopleState.ChooseGrowth(data,first.Actor.Id,0,102) &&
    ProjectY.Data.PeopleState.ChooseGrowth(data,first.Actor.Id,1,103) && first.Stage==2 && first.GetGrowthChoice(1)==101 && first.GetGrowthChoice(2)==103,
    "growth stage compare-and-set and both choices retained");

var world=ProjectY.Data.WorldPartiesData.For(data);var patrol=world.Add(1,0,0,12,18);
var soldier=patrol.AddMember(1);initialize(soldier);var remaining=patrol.AddMember(1);initialize(remaining);
patrol.SetMemberStrength(0,15);patrol.SetMemberStrength(1,20);
ProjectY.Data.EquipmentAffixData.Define(data.Equipment,101,new[]{1},new[]{1});
ProjectY.Data.EquipmentCombatState.Initialize(data.Equipment,soldier.Id,101,0,new int[0],new string[0]);
var sword=data.Equipment.Equipped(soldier.Id);ProjectY.Data.EquipmentCombatState.DamageWeapon(data.Equipment,sword.Id,19);
int durability=ProjectY.Data.EquipmentConditionData.Of(sword).Current;
var soldierPerson=ProjectY.Data.PeopleState.Bind(data,"actor:"+soldier.Id,soldier,"world",12,0,4,0,"");
check(ProjectY.Data.PeopleState.CanRecruit(data,soldierPerson.Key),"living human world member can negotiate");
ProjectY.Data.PeopleState.Recruit(data,soldierPerson.Key);
check(patrol.MemberCount==1 && object.ReferenceEquals(patrol.GetMemberAt(0),remaining) && patrol.StrengthReady && patrol.StrategicPower==20,
    "world ownership and strategic strength removed together");
check(object.ReferenceEquals(data.Equipment.Equipped(soldier.Id),sword) && ProjectY.Data.EquipmentConditionData.Of(sword).Current==durability &&
    !ProjectY.Data.EquipmentCombatState.IsInitialized(data.Equipment,soldier.Id),"world recruitment retains physical weapon and durability");
ProjectY.Data.EquipmentCombatState.RemoveActor(data.Equipment,soldier.Id);
check(object.ReferenceEquals(data.Equipment.Equipped(soldier.Id),sword),"former enemy cleanup cannot delete recruited equipment");
ProjectY.Data.EquipmentCombatState.Initialize(data.Equipment,remaining.Id,0,0,new int[0],new string[0]);
var lastPerson=ProjectY.Data.PeopleState.Bind(data,"actor:"+remaining.Id,remaining,"world",12,0,4,0,"");
check(!ProjectY.Data.PeopleState.CanRecruit(data,lastPerson.Key),"last living world member cannot implicitly dissolve the party");
rejects(()=>ProjectY.Data.PeopleState.Bind(data,"actor:77",new ProjectY.Data.CombatActorData(77,1),"world",12,0,4,0,""),"foreign actor binding rejected");
second.Actor.Damage(second.Actor.HP);check(!ProjectY.Data.PeopleState.CanRecruit(data,second.Key),"zero-health resident cannot join");

var flags=System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic;
var staticFlags=System.Reflection.BindingFlags.Static|System.Reflection.BindingFlags.NonPublic;
var capture=typeof(ProjectY.Data.PeopleData).GetMethod("Capture",flags);
var prepare=typeof(ProjectY.Data.PeopleData).GetMethod("Prepare",staticFlags);
var saved=capture.Invoke(people,new object[]{data,new System.Collections.Generic.HashSet<int>()});
var savedType=saved.GetType();saved=UnityEngine.JsonUtility.FromJson(UnityEngine.JsonUtility.ToJson(saved),savedType);
var candidate=new ProjectY.Data.PreparedCharacterSave();
var roster=new[]{first.Actor,soldier};
typeof(ProjectY.Data.PreparedCharacterSave).GetField("Actors",flags).SetValue(candidate,roster);
typeof(ProjectY.Data.PreparedCharacterSave).GetField("PreparedWorldParties",flags).SetValue(candidate,world);
System.Func<object,ProjectY.Data.PeopleData> load=payload=>(ProjectY.Data.PeopleData)prepare.Invoke(null,new object[]{payload,candidate,appearances,
    new System.Collections.Generic.HashSet<int>(new[]{first.Actor.Id,soldier.Id,remaining.Id})});
var restored=load(saved);
check(object.ReferenceEquals(restored.Find(first.Key).Actor,first.Actor) && object.ReferenceEquals(restored.Find(lastPerson.Key).Actor,remaining),
    "saved people reconnect roster and world references instead of cloning them");
check(restored.Find(friend.Key).Actor.Id==friend.Actor.Id && !object.ReferenceEquals(restored.Find(friend.Key).Actor,friend.Actor) &&
    restored.Find(friend.Key).Actor.Growth.HasSkill(401),"unjoined resident restores its owned full actor");
check(restored.Find(first.Key).BattleWins==1 && restored.Find(first.Key).Stage==2 && restored.Find(first.Key).BondKey==friend.Key,
    "progress, both branches and real relationship persist");
check(restored.Find(second.Key).Actor.HP==0 && !ProjectY.Data.DeathDoorState.Alive(restored.Find(second.Key).Actor),"dead residents do not revive on load");
typeof(ProjectY.Data.PeopleData).GetMethod("TakePrepared",flags).Invoke(people,new object[]{restored});
check(!ProjectY.Data.PeopleState.RecordGrowthEvent(data,first.Actor.Id,"battle","encounter:1") && people.Find(first.Key).BattleWins==1,
    "growth receipt remains consumed after restore");
var enemySaved=typeof(ProjectY.Data.CombatActorData).GetMethod("CaptureEnemy",flags).Invoke(remaining,null);
enemySaved=UnityEngine.JsonUtility.FromJson(UnityEngine.JsonUtility.ToJson(enemySaved),enemySaved.GetType());
var enemyRestored=(ProjectY.Data.CombatActorData)typeof(ProjectY.Data.CombatActorData).GetMethod("PrepareEnemy",staticFlags).Invoke(null,
    new object[]{enemySaved,appearances,new System.Collections.Generic.HashSet<int>()});
check(enemyRestored.Growth.Initialized && enemyRestored.Growth.HasSkill(401) && enemyRestored.HasTrait(7) && enemyRestored.HP==remaining.HP,
    "unrecruited world actor retains complete growth through EnemySave");
var rows=(System.Array)savedType.GetField("records").GetValue(saved);var savedFirst=rows.GetValue(0);var rowType=savedFirst.GetType();
rowType.GetField("actorId").SetValue(savedFirst,99);rejects(()=>load(saved),"missing shared actor reference rejected");
rowType.GetField("actorId").SetValue(savedFirst,first.Actor.Id);
rowType.GetField("receipts").SetValue(savedFirst,new[]{"battle:encounter:1","battle:encounter:1"});rejects(()=>load(saved),"duplicate growth receipt rejected");
rowType.GetField("receipts").SetValue(savedFirst,new[]{"battle:encounter:1","learn:402"});
savedType.GetField("nextActorId").SetValue(saved,600000000);rejects(()=>load(saved),"resident allocation counter cannot reuse a saved identity");

var areaData=new ProjectY.Data.AdventureData();var area=areaData.Areas.Ensure(77,30,1);var encounter=area.AddEncounter(1,1);
var ally=encounter.AddEnemy(7701,1,0,0);initialize(ally);initialize(encounter.AddEnemy(7702,1,1,0));
ProjectY.Data.EquipmentCombatState.Initialize(areaData.Equipment,ally.Id,0,0,new int[0],new string[0]);
var allyPerson=ProjectY.Data.PeopleState.Bind(areaData,"actor:"+ally.Id,ally,"area",77,0,4,0,"");
int areaRevision=area.Revision;ProjectY.Data.PeopleState.Recruit(areaData,allyPerson.Key);
check(encounter.EnemyCount==1 && object.ReferenceEquals(ProjectY.Data.PartyRoster.Find(areaData,ally.Id),ally) && area.Revision==areaRevision+1,
    "area recruitment removes the original encounter member and updates its revision");
var full=new ProjectY.Data.AdventureData();
for(int i=1;i<=ProjectY.Data.PartyRoster.ActiveLimit+ProjectY.Data.PartyRoster.ReserveLimit;i++)
{var member=full.PrepareRecruitActor(i,1);initialize(member);full.AddPreparedRecruit(member);}
var blocked=ProjectY.Data.PeopleState.Get(full).CreateResident(1,100001,1,1,1,"");initialize(blocked.Actor);
check(!ProjectY.Data.PeopleState.CanRecruit(full,blocked.Key),"full active and reserve roster refuses recruitment");
rejects(()=>ProjectY.Data.PeopleState.Recruit(full,blocked.Key),"capacity rejection precedes ownership mutation");
check(!blocked.Joined && blocked.Actor.Team==0 && ProjectY.Data.PartyRoster.Count(full)==10,"failed recruit leaves resident and roster unchanged");
data.Reset(819);check(ProjectY.Data.PeopleState.Get(data).Count==0,"new campaign resets people");
return new{passed=checks.Count,checks};
