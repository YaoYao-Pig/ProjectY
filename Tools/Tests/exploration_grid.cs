// Unity MCP execute_code method body. Uses the compiled renderer; Edit Mode only, no scene changes saved.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode) throw new System.InvalidOperationException("Edit Mode required");
System.Action<bool,string> check=(ok,message)=>{if(!ok)throw new System.Exception(message);};
var shader=Resources.Load<Shader>("Rendering/ExplorationGrid");
check(shader!=null && shader.isSupported,"Exploration shader missing or unsupported");
foreach(var message in UnityEditor.ShaderUtil.GetShaderMessages(shader)) check(message.severity.ToString()!="Error",message.message);
var map=new ProjectY.Samples.MapAreaViewData {Radius=1.5f,AreaType=2,Cells=new ProjectY.Samples.MapAreaViewData.Cell[442]};
System.Func<int,int,int> at=(q,r)=>(q+10)*21+r+10;
for(int q=-10;q<=10;q++) for(int r=-10;r<=10;r++)
    map.Cells[at(q,r)]=new ProjectY.Samples.MapAreaViewData.Cell {Q=q,R=r,Position=new Vector3(map.Radius*1.7320508f*(q+r*.5f),0,map.Radius*1.5f*r),Corners=new float[6],Color=new Color(.23f,.27f,.23f),SurfaceId=1,SideSurfaceId=1};
map.Cells[441]=new ProjectY.Samples.MapAreaViewData.Cell {Layer=1,Position=Vector3.up*3,Corners=new[]{3f,3f,3f,3f,3f,3f},Color=Color.gray,SurfaceId=1,SideSurfaceId=1};
map.Surfaces.Add(1,new ProjectY.Samples.MapAreaViewData.Surface {Color=Color.gray,DetailColor=Color.gray});
int hidden=at(3,0),blocked=at(2,0),removed=at(3,1);
map.Cells[blocked].Blocked=true;
var visible=new System.Collections.Generic.List<int>();for(int i=0;i<map.Cells.Length;i++)if(i!=hidden)visible.Add(i);
var state=new ProjectY.Samples.MapAreaViewData.State {Revision=1,Visible=visible.ToArray(),Members=new[]{new ProjectY.Samples.MapAreaViewData.Member {ActorId=1,CellIndex=at(0,0)},new ProjectY.Samples.MapAreaViewData.Member {ActorId=2,CellIndex=at(-2,0)}}};
var settings=new ProjectY.Samples.ExplorationGridRenderer.Settings();
var grid=new ProjectY.Samples.ExplorationGridRenderer(map,settings);
var scene=UnityEditor.SceneManagement.EditorSceneManager.NewPreviewScene();
ProjectY.Samples.TownSurfaceRenderer terrain=null;
RenderTexture texture=null;Texture2D image=null;
var previous=RenderTexture.active;
try
{
    grid.SetState(state,true);
    check(grid.ContainsCell(at(0,0)) && grid.ContainsCell(at(-9,0)),"Grid must include the union of nearby squad cells");
    check(!grid.ContainsCell(hidden) && !grid.ContainsCell(blocked),"Hidden/blocked cells leaked into exploration grid");
    check(!grid.ContainsCell(441) && !grid.ContainsCell(at(10,10)),"Other layer/distant cells leaked into exploration grid");
    visible.Remove(removed);visible.Add(hidden);state.Visible=visible.ToArray();state.Revision++;
    grid.SetState(state,true);
    check(grid.ContainsCell(hidden) && !grid.ContainsCell(removed),"Same-count visibility changes did not rebuild the grid");
    var members=state.Members;
    state.Members=new[]{new ProjectY.Samples.MapAreaViewData.Member {ActorId=1,CellIndex=441}};state.Revision++;
    grid.SetState(state,true);check(grid.CellCount==1 && grid.ContainsCell(441),"Bridge grid crossed to the street below");
    grid.SetState(state,false);grid.Draw(null,state,id=>{throw new System.Exception("Combat must not draw exploration grid");});
    state.Members=members;state.Revision++;grid.SetState(state,true);
    check(grid.ContainsCell(at(0,0)),"Exploration grid did not resume after combat");
    // Sample triangle interiors, including clipped stair treads, against the existing walking surface.
    int surfaceTriangles=0;
    var sample=new ProjectY.Samples.MapAreaViewData {Radius=1.5f,Cells=new[]{new ProjectY.Samples.MapAreaViewData.Cell {Position=Vector3.up*.7f,Corners=new[]{.7f,.7f,.7f,.7f,.7f,.7f}}}};
    for(int mode=0;mode<3;mode++)
    {
        if(mode>0)sample.Cells[0].Corners=new[]{1.4f,1.1f,.4f,0f,.3f,1f};
        sample.Cells[0].StairRise=mode==2?.2f:0;
        var vertices=new System.Collections.Generic.List<Vector3>();var indices=new System.Collections.Generic.List<int>();
        ProjectY.Samples.TownSurfaceRenderer.AppendOverlay(sample,0,settings.CellInset,vertices,indices);
        check(indices.Count>0,"Missing surface fills");
        for(int i=0;i<indices.Count;i+=3)
        {
            var point=(vertices[indices[i]]+vertices[indices[i+1]]+vertices[indices[i+2]])/3;
            var ground=ProjectY.Samples.TownSurfaceRenderer.Ground(sample,0,0,point);
            check(Mathf.Abs(point.y-ground.y-.02f)<.001f,"Grid floats above or cuts into walking surface");surfaceTriangles++;
        }
    }
    var cameraObject=new GameObject("ExplorationGridCheck",typeof(Camera));UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(cameraObject,scene);
    var camera=cameraObject.GetComponent<Camera>();camera.scene=scene;camera.enabled=false;camera.orthographic=true;camera.orthographicSize=23;camera.aspect=1.6f;
    camera.transform.position=new Vector3(-2,40,0);camera.transform.rotation=Quaternion.Euler(90,0,0);camera.nearClipPlane=.1f;camera.farClipPlane=100;
    camera.clearFlags=CameraClearFlags.SolidColor;camera.backgroundColor=Color.black;
    texture=new RenderTexture(1600,1000,24,RenderTextureFormat.ARGB32){antiAliasing=1};texture.Create();camera.targetTexture=texture;
    image=new Texture2D(1600,1000,TextureFormat.RGB24,false);
    System.Action read=()=>{camera.Render();RenderTexture.active=texture;image.ReadPixels(new Rect(0,0,1600,1000),0,0);image.Apply();};
    // Read inside the cell: a hollow outline must fail this check. Also verify the actual GPU fade.
    System.Func<Vector3,float> brightness=world=>{
        var pixel=camera.WorldToViewportPoint(world);int x=Mathf.RoundToInt(pixel.x*image.width),y=Mathf.RoundToInt(pixel.y*image.height);float peak=0;
        for(int a=-2;a<=2;a++)for(int b=-2;b<=2;b++)peak=Mathf.Max(peak,image.GetPixel(x+a,y+b).g);return peak;
    };
    System.Func<Vector3,Color> pixelColor=world=>{
        var pixel=camera.WorldToViewportPoint(world);return image.GetPixel(Mathf.RoundToInt(pixel.x*image.width),Mathf.RoundToInt(pixel.y*image.height));
    };
    var fillPoint=map.Cells[at(0,0)].Position+new Vector3(.1f,.035f,.1f);
    var luminance=new float[3];
    for(int i=0;i<3;i++)
    {
        var center=fillPoint-Vector3.right*(new[]{1f,4.5f,6.5f}[i]*map.Radius*1.7320508f);
        grid.Draw(camera,state,id=>center);read();luminance[i]=brightness(fillPoint);
    }
    check(luminance[0]>.25f && luminance[1]>.1f && luminance[1]<luminance[0]*.9f && luminance[2]<.01f,"Rendered grid does not fade with the moving display position: "+string.Join(",",luminance));
    grid.SetInteraction(at(0,0),-1);grid.Draw(camera,state,id=>Vector3.zero);read();var hoverColor=pixelColor(fillPoint);
    check(hoverColor.g>.3f && hoverColor.b>hoverColor.r*2,"Hover fill is not cyan");
    grid.SetInteraction(at(0,0),at(0,0));grid.Draw(camera,state,id=>Vector3.zero);read();var selectedColor=pixelColor(fillPoint);
    check(selectedColor.g>selectedColor.r*2 && selectedColor.g>selectedColor.b*2,"Selected fill must override hover with green");
    grid.SetInteraction(-1,-1);grid.Draw(camera,state,id=>Vector3.zero);read();var normalColor=pixelColor(fillPoint);
    check(normalColor.r>normalColor.b*2,"Clearing hover/selection must restore the golden fill");
    grid.SetInteraction(removed,blocked);grid.Draw(camera,state,id=>Vector3.zero);read();
    check(brightness(map.Cells[removed].Position)<.01f && brightness(map.Cells[blocked].Position)<.01f,"Interaction revealed hidden or blocked cells");
    int distant=at(10,0);check(!grid.ContainsCell(distant),"Far interaction test requires a cell outside the ambient mesh");
    grid.SetInteraction(distant,-1);grid.Draw(camera,state,id=>Vector3.zero);read();
    check(brightness(map.Cells[distant].Position)>.3f,"Visible hover target disappeared beyond the fade range");
    grid.SetInteraction(-1,-1);grid.Draw(camera,state,id=>Vector3.zero);read();
    check(brightness(map.Cells[distant].Position)<.01f,"Cleared hover left stale distant geometry");
    grid.SetInteraction(at(0,0),at(0,0));
    grid.SetState(state,false);grid.Draw(camera,state,id=>Vector3.zero);read();check(brightness(fillPoint)<.01f,"Rendered exploration grid remains in combat");
    grid.SetState(state,true);
    grid.SetInteraction(at(1,1),at(1,-1));
    // A small independent preview uses the real renderer and project pawn prefabs.
    var surfaceShader=UnityEditor.AssetDatabase.LoadAssetAtPath<Shader>("Assets/GameFramework/Samples/Map/MapPreviewInstanced.shader");
    var previewMap=new ProjectY.Samples.MapAreaViewData {Radius=map.Radius,Cells=new ProjectY.Samples.MapAreaViewData.Cell[441]};
    System.Array.Copy(map.Cells,previewMap.Cells,441);previewMap.Surfaces.Add(1,map.Surfaces[1]);
    terrain=new ProjectY.Samples.TownSurfaceRenderer(surfaceShader,previewMap);
    var groundObject=new GameObject("GridPreviewGround",typeof(MeshFilter),typeof(MeshRenderer));UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(groundObject,scene);
    groundObject.GetComponent<MeshFilter>().sharedMesh=terrain.Mesh;groundObject.GetComponent<MeshRenderer>().sharedMaterial=terrain.Material;
    for(int i=0;i<state.Members.Length;i++)
    {
        var prefab=UnityEditor.AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/PawnLowPoly/Templates/Pawn_Template_"+(i+1)+".prefab");
        var pawn=(GameObject)UnityEditor.PrefabUtility.InstantiatePrefab(prefab,scene);pawn.transform.position=map.Cells[state.Members[i].CellIndex].Position+Vector3.up*.05f;
    }
    var lightObject=new GameObject("GridPreviewSun",typeof(Light));UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(lightObject,scene);
    var light=lightObject.GetComponent<Light>();light.type=LightType.Directional;light.intensity=1;lightObject.transform.rotation=Quaternion.Euler(55,-35,0);
    camera.transform.position=new Vector3(-2,34,-26);camera.transform.LookAt(new Vector3(-2,0,0));camera.orthographicSize=19;
    grid.Draw(camera,state,id=>map.Cells[state.Members[id-1].CellIndex].Position);read();
    var output=System.IO.Path.GetFullPath("Art/MapLowPoly/Previews/exploration-grid-fade.png");System.IO.Directory.CreateDirectory(System.IO.Path.GetDirectoryName(output));System.IO.File.WriteAllBytes(output,image.EncodeToPNG());
    foreach(var message in UnityEditor.ShaderUtil.GetShaderMessages(shader))check(message.severity.ToString()!="Error",message.message);
    return new {checks="PASS: visibility, blocked cells, squad union, layer isolation, combat/resume, slope/stair fit, filled cell interior, GPU distance fade, hover/selected priority, clearing interaction, distant visible targets",surfaceTriangles=surfaceTriangles,nearMidFar=luminance,hover=hoverColor.ToString(),selected=selectedColor.ToString(),preview=output};
}
finally
{
    RenderTexture.active=previous;
    UnityEditor.SceneManagement.EditorSceneManager.ClosePreviewScene(scene);
    grid.Dispose();if(terrain!=null)terrain.Dispose();
    if(texture!=null){texture.Release();UnityEngine.Object.DestroyImmediate(texture);}if(image!=null)UnityEngine.Object.DestroyImmediate(image);
}
