// Unity MCP execute_code body. Isolated C# objects and one temporary LuaEnv; no scene, player state or files.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode)throw new System.InvalidOperationException("Edit Mode required.");
var data=new ProjectY.Data.ConstructionData();
var inventory=new ProjectY.Data.EquipmentData();
var record=ProjectY.Data.ProfessionCombatState.PlaceConstruction(data,1,2,301,20,inventory,System.Array.Empty<int>(),System.Array.Empty<int>(),1);
ProjectY.Data.LegendaryEquipmentState.SetConstructionAuthor(record,7);
data.Damage(1,2,7);
var revision=data.Revision;
ProjectY.Data.LegendaryEquipmentState.MoveConstruction(data,record,3,7);
if(data.At(1,2)!=null||!object.ReferenceEquals(data.At(1,3),record)||record.HP!=13||record.MaxHP!=20||data.Revision!=revision+1)
    throw new System.Exception("Construction relocation changed identity/health or failed to invalidate terrain.");
bool rejected=false;
try{ProjectY.Data.LegendaryEquipmentState.MoveConstruction(data,record,4,8);}catch(System.InvalidOperationException){rejected=true;}
if(!rejected||record.CellIndex!=3)throw new System.Exception("Another actor relocated an owned construction.");
var blocked=ProjectY.Data.ProfessionCombatState.PlaceConstruction(data,1,4,302,20,inventory,System.Array.Empty<int>(),System.Array.Empty<int>(),1);
rejected=false;
try{ProjectY.Data.LegendaryEquipmentState.MoveConstruction(data,record,4,7);}catch(System.InvalidOperationException){rejected=true;}
if(!rejected||record.CellIndex!=3||!object.ReferenceEquals(data.At(1,4),blocked))throw new System.Exception("Occupied relocation was not atomic.");
var flags=System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic;
var capture=typeof(ProjectY.Data.ConstructionData).GetMethod("Capture",flags);
var prepare=typeof(ProjectY.Data.ConstructionData).GetMethod("Prepare",System.Reflection.BindingFlags.Static|System.Reflection.BindingFlags.NonPublic);
var saved=(System.Array)capture.Invoke(data,null);
var areas=new[]{new ProjectY.Data.MapAreaStateData(1,20,1)};
var restored=(ProjectY.Data.ConstructionData)prepare.Invoke(null,new object[]{saved,areas});
if(ProjectY.Data.LegendaryEquipmentState.ConstructionAuthor(restored.At(1,3))!=7||restored.At(1,3).HP!=13)
    throw new System.Exception("Construction author/condition did not survive save capture and prepare.");
var authorField=saved.GetValue(0).GetType().GetField("ownerActorId");
authorField.SetValue(saved.GetValue(0),0);
var legacy=(ProjectY.Data.ConstructionData)prepare.Invoke(null,new object[]{saved,areas});
if(ProjectY.Data.LegendaryEquipmentState.ConstructionAuthor(legacy.At(1,3))!=0)throw new System.Exception("Unknown old-save author was fabricated.");
using(var lua=new XLua.LuaEnv())
{
    lua.Global.Set("LegendaryTestData",restored);lua.Global.Set("LegendaryTestRecord",restored.At(1,3));
    lua.DoString("assert(CS.ProjectY.Data.LegendaryEquipmentState.ConstructionAuthor(LegendaryTestRecord)==7);CS.ProjectY.Data.LegendaryEquipmentState.MoveConstruction(LegendaryTestData,LegendaryTestRecord,5,7);assert(LegendaryTestRecord.CellIndex==5 and LegendaryTestRecord.HP==13);LegendaryTestData=nil;LegendaryTestRecord=nil");
    lua.FullGc();
}
if(restored.At(1,3)!=null||restored.At(1,5)==null)throw new System.Exception("Real xLua reflection bridge did not relocate the authoritative record.");
var actor=new ProjectY.Data.CombatActorData(7,1);actor.SetMaxHP(100);actor.Restore();actor.Deploy(1,0,0);
if(!ProjectY.Data.ProfessionCombatState.Once(actor,"legendary_samples",1)||ProjectY.Data.ProfessionCombatState.Once(actor,"legendary_samples",1))
    throw new System.Exception("Encounter counter repeated.");
actor.Deploy(1,0,0);
if(ProjectY.Data.ProfessionCombatState.Mark(actor,"legendary_samples")!=0)throw new System.Exception("Legendary counters leaked between encounters.");
return "PASS legendary C# ownership, atomic relocation, save/legacy capture, actual xLua bridge and encounter cleanup";
