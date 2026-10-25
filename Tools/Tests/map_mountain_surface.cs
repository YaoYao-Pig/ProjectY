// Execute after the task's one consolidated C# compile. Pure in-memory meshes;
// no scene changes, Play Mode, AssetDatabase refresh or persistent player data.
var shader=UnityEditor.AssetDatabase.LoadAssetAtPath<UnityEngine.Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
if(shader==null)throw new System.Exception("Map shader unavailable");
var sqrt3=UnityEngine.Mathf.Sqrt(3);
var a=new ProjectY.Samples.MapPreviewData.Cell {Q=0,R=0,RegionId=1,Position=new UnityEngine.Vector3(0,8,0),Color=UnityEngine.Color.gray,
    SurfaceCorners=new float[]{10,9,8,7,6,9}};
var b=new ProjectY.Samples.MapPreviewData.Cell {Q=1,R=0,RegionId=1,Position=new UnityEngine.Vector3(sqrt3,12,0),Color=UnityEngine.Color.white,
    SurfaceCorners=new float[]{11,13,10,9,8,9}};
var old=new ProjectY.Samples.MapPreviewData.Cell {Q=-1,R=1,RegionId=2,Position=new UnityEngine.Vector3(-sqrt3*.5f,8.5f,1.5f),Color=UnityEngine.Color.green};
var data=new ProjectY.Samples.MapPreviewData {Radius=1,Cells=new[]{a,b,old}};
using(var surface=new ProjectY.Samples.MapMountainSurface(shader))
{
    surface.Build(data,-2);
    if(surface.ChunkCount!=1)throw new System.Exception("Two adjacent surface cells should share one chunk");
    if(!float.IsNaN(a.SurfaceEdgeBottoms[5])||!float.IsNaN(b.SurfaceEdgeBottoms[2]))throw new System.Exception("An internal surface edge has a skirt");
    if(a.SurfaceEdgeBottoms[1]!=8.5f)throw new System.Exception("Legacy-neighbor skirt does not use its real top");
    var p=a.Position*.3f+ProjectY.Samples.MapMountainSurface.Corner(a,1,0)*.4f+ProjectY.Samples.MapMountainSurface.Corner(a,1,1)*.3f;
    var ray=new UnityEngine.Ray(new UnityEngine.Vector3(p.x,30,p.z),UnityEngine.Vector3.down);
    float distance;
    if(!ProjectY.Samples.MapMountainSurface.TryRaycastCell(a,1,ray,out distance)||UnityEngine.Mathf.Abs(30-distance-p.y)>.0001f)
        throw new System.Exception("Mountain fan raycast differs from its interpolated top");
    if(UnityEngine.Mathf.Abs(ProjectY.Samples.MapMountainSurface.HeightAt(a,1,p)-p.y)>.0001f)throw new System.Exception("Road height differs from rendered fan");
    var layoutType=typeof(ProjectY.Samples.AdventureRuntimeDemo).Assembly.GetType("ProjectY.Samples.WorldSiteLayout",true);
    var access=System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.Public|System.Reflection.BindingFlags.NonPublic;
    var layout=System.Activator.CreateInstance(layoutType,access,null,new object[]{data},null);
    var site=new ProjectY.Samples.AdventureViewData.Site{Id=9,Q=0,R=0,WorldRegionId=1};
    var footprint=(int[])layoutType.GetMethod("Footprint",access).Invoke(layout,new object[]{site});
    if(footprint.Length!=2||footprint[0]!=0||footprint[1]!=1)throw new System.Exception("Mountain site does not cover its complete region");
    var pickArgs=new object[]{new UnityEngine.Ray(b.Position+UnityEngine.Vector3.up*30,UnityEngine.Vector3.down),0f};
    if((int)layoutType.GetMethod("Pick",access).Invoke(layout,pickArgs)!=1)throw new System.Exception("A non-entry mountain cell cannot be selected");
    var first=ProjectY.Samples.MapMountainSurface.Corner(a,1,1);var second=ProjectY.Samples.MapMountainSurface.Corner(a,1,2);
    var edgePoint=UnityEngine.Vector3.Lerp(first,second,.1f);edgePoint.y=8.7f;
    var outward=new UnityEngine.Vector3(-.5f,0,.8660254f);
    if(!ProjectY.Samples.MapMountainSurface.TryRaycastCell(a,1,new UnityEngine.Ray(edgePoint+outward*2,-outward),out distance)||UnityEngine.Mathf.Abs(distance-2)>.001f)
        throw new System.Exception("Clipped external skirt raycast differs from its rendered edge");
    var flags=System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic;
    var chunks=(System.Collections.IList)typeof(ProjectY.Samples.MapMountainSurface).GetField("chunks",flags).GetValue(surface);
    var chunk=chunks[0];var chunkType=chunk.GetType();
    var mesh=(UnityEngine.Mesh)chunkType.GetField("Mesh").GetValue(chunk);
    var originals=(UnityEngine.Vector3[])chunkType.GetField("OriginalVertices").GetValue(chunk);
    var expectedOriginal=(UnityEngine.Vector3[])originals.Clone();
    var fullCount=mesh.GetIndexCount(0);
    var state=new ProjectY.Data.WorldMapExplorationData();state.Reset(3);surface.UpdateExploration(state);
    if(mesh.GetIndexCount(0)!=0)throw new System.Exception("Unknown mountain survives in depth/shadow geometry");
    state.Reveal(new[]{1});surface.UpdateExploration(state);
    if(mesh.GetIndexCount(0)==0||mesh.GetIndexCount(0)>=fullCount)throw new System.Exception("Known-cell filtering does not isolate one mountain cell");
    surface.SetFocusCells(new[]{0,1});surface.SetFocusLift(.24f,1);
    int pickedCell;float liftedDistance;
    if(!surface.TryPick(ray,out pickedCell,out liftedDistance)||pickedCell!=0||UnityEngine.Mathf.Abs(30-liftedDistance-(p.y+.24f))>.001f)
        throw new System.Exception("Hover picking does not follow the lifted mountain fan");
    var selected=(UnityEngine.Mesh)typeof(ProjectY.Samples.MapMountainSurface).GetField("selectionMesh",flags).GetValue(surface);
    if(selected.GetIndexCount(0)!=mesh.GetIndexCount(0))throw new System.Exception("Selected mountain mask exposes unknown triangles");
    state.Reset(3);state.Reveal(new[]{2});
    if(!surface.UpdateExploration(state))throw new System.Exception("Same-count exploration reset preserved stale mountain geometry");
    var known=(bool[])typeof(ProjectY.Samples.MapMountainSurface).GetField("known",flags).GetValue(surface);
    if(known[0]||!known[1])throw new System.Exception("Unknown mountain leaked after exploration reset");
    surface.SetFocusCells(null);
    var restored=mesh.vertices;
    for(int i=0;i<restored.Length;i++)if(restored[i]!=expectedOriginal[i])throw new System.Exception("Repeated hover accumulates surface displacement");
    state.Reveal(new[]{1,2});surface.UpdateExploration(state);
    if(mesh.GetIndexCount(0)!=fullCount)throw new System.Exception("Revealed mountain triangles were not restored");
}
return new {sharedChunk=true,noInternalWalls=true,fanRaycast=true,clippedSkirtRaycast=true,wholeMountainFootprint=true,nonEntryCellSelectable=true,roadHeight=true,unknownGeometryHidden=true,selectionMaskFiltered=true,liftedPicking=true,hoverRestored=true};
