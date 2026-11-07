// Unity MCP method body. Checks only boundary water heights in an idle Editor; never enters Play.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode || UnityEditor.EditorApplication.isCompiling)
    throw new Exception("Idle Editor required");
var scene=UnityEngine.SceneManagement.SceneManager.GetActiveScene();bool dirty=scene.isDirty;
var flags=System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic;
var type=typeof(ProjectY.Samples.MapPreviewRenderer).Assembly.GetType("ProjectY.Samples.MapBoundaryRenderer",true);
var reports=new System.Collections.Generic.List<string>();
Action<bool,string> check=(ok,message)=>{if(!ok)throw new Exception(message);};
Func<ProjectY.Samples.MapPreviewData> rectangle=()=>
{
    var cells=new System.Collections.Generic.List<ProjectY.Samples.MapPreviewData.Cell>();
    for(int r=-3;r<=3;r++)for(int q=-8;q<=8;q++)
        cells.Add(new ProjectY.Samples.MapPreviewData.Cell {Q=q,R=r,Position=new Vector3(1.7320508f*(q+r*.5f),4,r*1.5f)});
    return new ProjectY.Samples.MapPreviewData {Radius=1,Cells=cells.ToArray()};
};
Action<ProjectY.Samples.MapPreviewData,float,bool,Action<Texture2D,Vector4>> inspect=(map,expected,uniform,extra)=>
{
    var boundary=(IDisposable)Activator.CreateInstance(type,flags,null,new object[]{map},null);
    Texture2D pixels=null;RenderTexture target=null;var active=RenderTexture.active;
    try
    {
        var material=(Material)type.GetField("material",flags).GetValue(boundary);
        var parameters=material.GetVector("_OceanParameters");
        check(Mathf.Abs(parameters.x-expected)<.0001f,"Unexpected sea level: "+parameters.x+" expected "+expected);
        check((parameters.z>.5f)==uniform,"Wrong uniform-height path");
        check(!UnityEditor.ShaderUtil.ShaderHasError(material.shader),"Ocean shader has errors");
        var texture=(Texture2D)material.GetTexture("_WaterBoundaryField");
        target=RenderTexture.GetTemporary(texture.width,texture.height,0,RenderTextureFormat.ARGBFloat,RenderTextureReadWrite.Linear);
        UnityEngine.Graphics.Blit(texture,target);RenderTexture.active=target;
        pixels=new Texture2D(texture.width,texture.height,TextureFormat.RGBAFloat,false,true);
        pixels.ReadPixels(new Rect(0,0,texture.width,texture.height),0,0);pixels.Apply();
        if(extra!=null)extra(pixels,material.GetVector("_WaterBoundaryBounds"));
    }
    finally
    {
        RenderTexture.active=active;
        if(target!=null)RenderTexture.ReleaseTemporary(target);
        if(pixels!=null)UnityEngine.Object.DestroyImmediate(pixels);
        boundary.Dispose();
    }
};
Func<Texture2D,Vector4,float,float,Color> sample=(texture,b,x,z)=>texture.GetPixelBilinear((x-b.x)*b.z,(z-b.y)*b.w);

var high=rectangle();
var outlet=high.Cells.First(c=>c.Q==-8 && c.R==0);outlet.HasWater=true;outlet.WaterLevel=8;outlet.WaterDepth=.55f;outlet.Position.y=7.45f;
foreach(var cell in high.Cells.Where(c=>c.Q>=4))cell.Position.y=2;
var low=high.Cells.First(c=>c.Q==8 && c.R==0);
inspect(high,1.5f,false,(texture,b)=>
{
    var remote=sample(texture,b,low.Position.x+1.8f,0);
    check(remote.r<0 && Mathf.Abs(remote.g-1.5f)<.0001f,"High outlet raises the remote low coast");
    var mouth=sample(texture,b,outlet.Position.x-1.25f,0);
    check(mouth.r<0 && mouth.g>1.5f && mouth.g<8,"Outlet does not transition locally to sea level");
    check(Mathf.Abs(sample(texture,b,outlet.Position.x,0).g-8)<.0001f,"Real outlet water level changed");
    check(Mathf.Abs(sample(texture,b,0,0).g-3.5f)<.0001f,"Outlet elevation propagates through dry land");
    var higherCoast=sample(texture,b,-4,7);
    check(higherCoast.r<0 && Mathf.Abs(higherCoast.g-3.5f)<.0001f,"A separate higher dry coast was lowered to the global minimum");
});
reports.Add("PASS outlet 8, low coast 2 / water 1.5, higher coast 4 / water 3.5: independent local heights and no propagation through land");

var inland=rectangle();var center=inland.Cells.First(c=>c.Q==0 && c.R==0);
center.Position.y=-30;center.HasWater=true;center.WaterLevel=18;center.WaterDepth=48;
inspect(inland,3.5f,true,(texture,b)=>
{
    check(Mathf.Abs(sample(texture,b,0,0).g-18)<.0001f,"Inland lake surface changed");
    check(Mathf.Abs(sample(texture,b,16,0).g-3.5f)<.0001f,"Inland depression or lake changes exterior height");
});
reports.Add("PASS inland lake 18 and bed -30 do not change the dry coast's sea 3.5");

var corners=rectangle();corners.Cells.First(c=>c.Q==8 && c.R==0).SurfaceCorners=new[]{4f,4f,4f,1f,4f,4f};
inspect(corners,.5f,false,null);
reports.Add("PASS boundary surface corners participate in the local height range");

var hole=rectangle();hole.Cells=hole.Cells.Where(c=>c.Q!=0 || c.R!=0).ToArray();
foreach(var cell in hole.Cells.Where(c=>Mathf.Abs(c.Q)<=1 && Mathf.Abs(c.R)<=1))cell.Position.y=-20;
inspect(hole,3.5f,true,null);
reports.Add("PASS enclosed courtyard/shaft edges do not affect exterior water");

var water=rectangle();foreach(var cell in water.Cells){cell.HasWater=true;cell.WaterLevel=2.25f;cell.WaterDepth=1;cell.Position.y=1.25f;}
inspect(water,2.25f,true,(texture,b)=>check(Mathf.Abs(sample(texture,b,16,0).g-2.25f)<.0001f,"Uniform water extension changed"));
reports.Add("PASS uniform water 2.25 retains exact surface and fast path");
check(UnityEngine.SceneManagement.SceneManager.GetActiveScene()==scene && scene.isDirty==dirty,"Active scene changed");
reports.Add("PASS scene and Play state unchanged; GPU field readback and ocean shader checks passed");
return reports;
