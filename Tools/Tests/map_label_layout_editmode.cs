// Unity MCP execute_code method body. Pure geometry; no scene, objects, Play,
// compilation, asset writes or camera/UI dependencies. Throws on any failure.
var checks=0;
System.Action<bool,string> check=(condition,message)=>{checks++;if(!condition)throw new System.InvalidOperationException("MapLabelLayout: "+message);};
System.Func<int,int,float,float,float,float,ProjectY.Samples.MapLabelLayout.Item> item=(id,itemPriority,x,y,w,h)=>
    new ProjectY.Samples.MapLabelLayout.Item{Id=id,Priority=itemPriority,Anchor=new Vector2(x,y),Size=new Vector2(w,h)};
System.Action<System.Collections.Generic.List<ProjectY.Samples.MapLabelLayout.Item>,Rect,System.Collections.Generic.IList<Rect>,float,float> geometry=(rows,testViewport,testObstacles,gap,offset)=>{
    for(int i=0;i<rows.Count;i++){
        var current=rows[i];
        if(!current.Visible){check(current.Rect==default(Rect),"hidden label retains a stale rectangle");continue;}
        var rect=current.Rect;
        check(rect.xMin>=testViewport.xMin&&rect.xMax<=testViewport.xMax&&rect.yMin>=testViewport.yMin&&rect.yMax<=testViewport.yMax,"label leaves viewport");
        check((rect.size-current.Size).sqrMagnitude<.0001f,"label size changed");
        check((rect.center-current.Anchor).magnitude<=offset+.001f,"label exceeded the allowed displacement");
        check(current.PreferredSlot>=0&&current.PreferredSlot<=12,"successful slot is invalid");
        // Expand exactly one rectangle by the required clearance, then use Unity's
        // geometry operation instead of copying the allocator's intersection code.
        var clearance=Rect.MinMaxRect(rect.xMin-gap,rect.yMin-gap,rect.xMax+gap,rect.yMax+gap);
        for(int j=0;j<i;j++)if(rows[j].Visible)check(!clearance.Overlaps(rows[j].Rect),"accepted labels overlap or violate the gap");
        if(testObstacles!=null)foreach(var obstacle in testObstacles)
            if(obstacle.width>0&&obstacle.height>0)check(!clearance.Overlaps(obstacle),"label invades a HUD obstacle");
    }
};

var viewport=new Rect(0,0,300,220);
var obstacles=new System.Collections.Generic.List<Rect>{new Rect(130,80,44,70),new Rect(-80,0,30,40)};
var dense=new System.Collections.Generic.List<ProjectY.Samples.MapLabelLayout.Item>();
for(int i=99;i>=0;i--)dense.Add(item(i,i%5,90+i%10*13,60+i/10*9,60,18));
ProjectY.Samples.MapLabelLayout.Arrange(dense,viewport,obstacles);
geometry(dense,viewport,obstacles,4,36);
int visible=0;foreach(var row in dense)if(row.Visible)visible++;
check(visible>0&&visible<100,"dense layout must retain some labels and hide crowded ones");
for(int i=1;i<dense.Count;i++)check(dense[i-1].Priority>dense[i].Priority||dense[i-1].Priority==dense[i].Priority&&dense[i-1].Id<dense[i].Id,"priority/ID order is not deterministic");

// Fresh items with another input order must produce identical initial geometry.
var saved=new System.Collections.Generic.Dictionary<int,ProjectY.Samples.MapLabelLayout.Item>();
foreach(var row in dense)saved.Add(row.Id,new ProjectY.Samples.MapLabelLayout.Item{Id=row.Id,Visible=row.Visible,Rect=row.Rect,PreferredSlot=row.PreferredSlot});
var reordered=new System.Collections.Generic.List<ProjectY.Samples.MapLabelLayout.Item>();
for(int i=0;i<100;i++)reordered.Add(item(i,i%5,90+i%10*13,60+i/10*9,60,18));
ProjectY.Samples.MapLabelLayout.Arrange(reordered,viewport,obstacles);
foreach(var row in reordered){var previous=saved[row.Id];check(row.Visible==previous.Visible&&row.Rect==previous.Rect&&row.PreferredSlot==previous.PreferredSlot,"input order changed placement");}
// Reuse the same Item objects and last slots, as the runtime will each frame.
dense.Reverse();ProjectY.Samples.MapLabelLayout.Arrange(dense,viewport,obstacles);
foreach(var row in dense){var previous=saved[row.Id];check(row.Visible==previous.Visible&&row.Rect==previous.Rect&&row.PreferredSlot==previous.PreferredSlot,"unchanged frame moved a label");}

// With space for one label only, higher priority wins even if it appears last.
var oneSlot=new Rect(0,0,100,30);
var priority=new System.Collections.Generic.List<ProjectY.Samples.MapLabelLayout.Item>{item(1,-100,50,15,100,30),item(2,100,50,15,100,30)};
ProjectY.Samples.MapLabelLayout.Arrange(priority,oneSlot,null);
check(priority[0].Id==2&&priority[0].Visible&&!priority[1].Visible,"lower priority occupied the only available slot");
geometry(priority,oneSlot,null,4,36);
priority[1].Priority=200;ProjectY.Samples.MapLabelLayout.Arrange(priority,oneSlot,null);
check(priority[0].Id==1&&priority[0].Visible&&!priority[1].Visible,"new high priority was blocked by last frame's lower-priority output");
priority=new System.Collections.Generic.List<ProjectY.Samples.MapLabelLayout.Item>{item(9,1,50,15,100,30),item(2,1,50,15,100,30),item(5,1,50,15,100,30)};
ProjectY.Samples.MapLabelLayout.Arrange(priority,oneSlot,null);
check(priority[0].Id==2&&priority[0].Visible&&!priority[1].Visible&&!priority[2].Visible,"equal-priority ID tie was unstable");

// Previous slot stays preferred after its original blocker disappears.
var remembered=item(20,10,100,60,40,12);
var rememberedRows=new System.Collections.Generic.List<ProjectY.Samples.MapLabelLayout.Item>{remembered};
var rememberedViewport=new Rect(0,0,200,120);
var blocker=new System.Collections.Generic.List<Rect>{new Rect(80,54,40,12)};
ProjectY.Samples.MapLabelLayout.Arrange(rememberedRows,rememberedViewport,blocker);
check(remembered.Visible&&remembered.PreferredSlot==5&&remembered.Rect.center==new Vector2(100,84),"expected nearest legal upper slot");
var rememberedRect=remembered.Rect;blocker.Clear();
ProjectY.Samples.MapLabelLayout.Arrange(rememberedRows,rememberedViewport,blocker);
check(remembered.Rect==rememberedRect&&remembered.PreferredSlot==5,"previous legal slot was discarded for a free center");
// The previous slot is a preference, never permission to overlap a new obstacle.
blocker.Add(rememberedRect);ProjectY.Samples.MapLabelLayout.Arrange(rememberedRows,rememberedViewport,blocker);
check(remembered.Visible&&remembered.PreferredSlot==0,"invalidated previous slot did not fall back to the free center");
geometry(rememberedRows,rememberedViewport,blocker,4,36);

var edgeViewport=new Rect(0,0,100,100);
var edgeRows=new System.Collections.Generic.List<ProjectY.Samples.MapLabelLayout.Item>{item(30,1,1,50,20,14)};
ProjectY.Samples.MapLabelLayout.Arrange(edgeRows,edgeViewport,null);
check(edgeRows[0].Visible&&edgeRows[0].PreferredSlot==4&&edgeRows[0].Rect.center==new Vector2(13,50),"left-edge label did not move right into the viewport");
geometry(edgeRows,edgeViewport,null,4,36);
edgeRows[0].Anchor=new Vector2(10,7);edgeRows[0].PreferredSlot=0;
ProjectY.Samples.MapLabelLayout.Arrange(edgeRows,edgeViewport,null,4,0);
check(edgeRows[0].Visible&&edgeRows[0].Rect.xMin==0&&edgeRows[0].Rect.yMin==0,"exact viewport edge should be legal");
edgeRows[0].Anchor=new Vector2(-100,50);
ProjectY.Samples.MapLabelLayout.Arrange(edgeRows,edgeViewport,null);
check(!edgeRows[0].Visible,"anchor farther than maxOffset was pulled across the screen");
var insetViewport=new Rect(80,40,100,100);edgeRows[0].Anchor=new Vector2(90,47);edgeRows[0].PreferredSlot=-1;
ProjectY.Samples.MapLabelLayout.Arrange(edgeRows,insetViewport,null,4,0);
check(edgeRows[0].Visible&&edgeRows[0].Rect.xMin==80&&edgeRows[0].Rect.yMin==40,"nonzero viewport origin or invalid preferred-slot fallback is wrong");

var oversized=new System.Collections.Generic.List<ProjectY.Samples.MapLabelLayout.Item>{item(40,1,50,50,101,10),item(41,2,50,50,10,101)};
ProjectY.Samples.MapLabelLayout.Arrange(oversized,edgeViewport,null);
check(!oversized[0].Visible&&!oversized[1].Visible,"oversized labels should hide without throwing");
var blocked=new System.Collections.Generic.List<ProjectY.Samples.MapLabelLayout.Item>{item(50,999,50,50,20,10)};
ProjectY.Samples.MapLabelLayout.Arrange(blocked,edgeViewport,new[]{edgeViewport});
check(!blocked[0].Visible,"even the highest priority must respect a full HUD blocker");
ProjectY.Samples.MapLabelLayout.Arrange(blocked,new Rect(0,0,0,100),null);
check(!blocked[0].Visible,"zero-area viewport should hide labels");

var gapRows=new System.Collections.Generic.List<ProjectY.Samples.MapLabelLayout.Item>{item(60,3,10,20,20,10),item(61,2,34,20,20,10),item(62,1,33,20,20,10)};
ProjectY.Samples.MapLabelLayout.Arrange(gapRows,edgeViewport,null,4,0);
check(gapRows[0].Visible&&gapRows[1].Visible&&!gapRows[2].Visible,"exact minimum clearance or zero-offset rejection is wrong");
geometry(gapRows,edgeViewport,null,4,0);
var touching=new System.Collections.Generic.List<ProjectY.Samples.MapLabelLayout.Item>{item(70,2,10,20,20,10),item(71,1,30,20,20,10)};
ProjectY.Samples.MapLabelLayout.Arrange(touching,edgeViewport,null,0,0);
check(touching[0].Visible&&touching[1].Visible,"touching edges with zero gap are not overlapping");

return "MapLabelLayout geometry assertions passed: "+checks+"; dense labels visible: "+visible+"/100. No scene or assets were created.";
