// Focused presentation regression for dynamic standing surfaces and collapsed platforms.
var layout=new ProjectY.Samples.MapAreaViewData{Radius=1,Cells=new ProjectY.Samples.MapAreaViewData.Cell[4]};
for(int i=0;i<4;i++)layout.Cells[i]=new ProjectY.Samples.MapAreaViewData.Cell{BasePosition=new Vector3(i,0,0),Position=new Vector3(i,0,0),Corners=new float[6],BaseCorners=new float[6],Neighbors=new int[0],WalkMask=63};
layout.Cells[0].Neighbors=new[]{1,2};layout.Cells[1].Neighbors=new[]{0,3};layout.Cells[2].Neighbors=new[]{0,3};layout.Cells[3].Neighbors=new[]{1,2};
var state=new ProjectY.Samples.MapAreaViewData.State{Constructions=new[]{new ProjectY.Samples.MapAreaViewData.Construction{Id=1,CellIndex=1,Kind="platform",Height=1.4f,MoveExtra=1}}};
layout.ApplyConstruction(state);
if(Mathf.Abs(layout.Cells[1].Position.y-1.4f)>.001f)throw new System.Exception("Standing surface was not raised");
foreach(float height in layout.Cells[1].Corners)if(Mathf.Abs(height-1.4f)>.001f)throw new System.Exception("Grid corners did not follow the standing surface");
var pawn=new GameObject("ConstructionHeightCheck");
try
{
    var motion=new ProjectY.Samples.PawnMotion(pawn.transform,1,layout){Speed=4};
    if(Mathf.Abs(pawn.transform.position.y-1.415f)>.001f)throw new System.Exception("Pawn did not stand on the platform");
    state.Constructions=System.Array.Empty<ProjectY.Samples.MapAreaViewData.Construction>();layout.ApplyConstruction(state);
    motion.SetDestination(1,new System.Collections.Generic.HashSet<int>());
    if(Mathf.Abs(pawn.transform.position.y-.015f)>.001f)throw new System.Exception("Collapsed platform left the pawn floating");
    foreach(float height in layout.Cells[1].Corners)if(height!=0)throw new System.Exception("Original corners were not restored");
    state.Constructions=new[]{new ProjectY.Samples.MapAreaViewData.Construction{Id=2,CellIndex=1,Kind="trench",Height=-.55f,MoveExtra=2}};layout.ApplyConstruction(state);
    motion=new ProjectY.Samples.PawnMotion(pawn.transform,0,layout){Speed=4};motion.SetDestination(3,new System.Collections.Generic.HashSet<int>());
    var route=(System.Collections.Generic.List<int>)typeof(ProjectY.Samples.PawnMotion).GetField("path",System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Instance).GetValue(motion);
    if(route[0]!=2)throw new System.Exception("Displayed route crossed expensive trench instead of matching weighted navigation");
    return "PASS raised corners, restored ground, standing pawn drop and weighted display route";
}
finally{UnityEngine.Object.DestroyImmediate(pawn);}
