// Isolated metadata/cache/deletion regression. Never reads the player's save directory.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode)throw new System.InvalidOperationException("Edit Mode required.");
var folder=System.IO.Path.Combine(System.IO.Path.GetTempPath(),"project-y-menu-"+System.Guid.NewGuid().ToString("N"));
System.IO.Directory.CreateDirectory(folder);
var service=new ProjectY.Data.CharacterSaveService(null,System.IO.Path.Combine(folder,"legacy.json"));
var flags=System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic;
System.Func<string,object[],object> call=(name,args)=>typeof(ProjectY.Data.CharacterSaveService).GetMethod(name,flags).Invoke(service,args);
System.Action<bool,string> require=(condition,message)=>{if(!condition)throw new System.Exception(message);};
var reports=new System.Collections.Generic.List<string>();
try
{
    string first=(string)call("NewCampaignSlot",new object[]{"First"});string firstPath=service.FilePath;
    System.IO.Directory.CreateDirectory(System.IO.Path.GetDirectoryName(firstPath));
    System.IO.File.WriteAllText(firstPath,"{\"version\":32,\"seed\":274819,\"worldName\":\"First\",\"createdAt\":\"2026-10-20T01:00:00Z\",\"savedAt\":\"2026-10-27T01:00:00Z\",\"actors\":[]}");
    string second=(string)call("NewCampaignSlot",new object[]{"Second"});string secondPath=service.FilePath;
    System.IO.File.WriteAllText(secondPath,"{\"version\":32,\"seed\":274819,\"worldName\":\"Second\",\"createdAt\":\"2026-10-25T01:00:00Z\",\"savedAt\":\"2026-10-26T01:00:00Z\",\"actors\":[],\"ignoredWorld\":\""+new string('x',1000000)+"\"}");
    var latest=(ProjectY.Data.WorldMenuSelection)call("LatestMenuPreview",new object[0]);require(latest.Id==second&&latest.Status==2,"Creation time must win over last-save time; old cache is explicitly missing.");reports.Add("creation order and bounded header reads");
    var snapshot=ProjectY.Samples.CampaignPreviewCapture.Default();call("StoreMenuPreview",new object[]{snapshot});
    string previewPath=(string)call("PreviewPath",new object[]{second});require(new System.IO.FileInfo(previewPath).Length<65536,"Preview exceeds byte budget.");
    latest=(ProjectY.Data.WorldMenuSelection)call("LatestMenuPreview",new object[0]);require(latest.Status==1&&latest.Snapshot.Heights.Length==3072&&latest.Snapshot.Landmarks.Length<=128,"Snapshot round trip.");reports.Add("binary snapshot round trip and size budget");
    System.IO.File.WriteAllText(previewPath,"bad cache");latest=(ProjectY.Data.WorldMenuSelection)call("LatestMenuPreview",new object[0]);require(latest.Status==3&&latest.Snapshot==null,"Corrupt preview must be explicit.");reports.Add("corrupt cache isolation");
    System.IO.File.WriteAllText(secondPath+".bak","backup");var firstBytes=System.IO.File.ReadAllBytes(firstPath);call("DeleteCampaignSlot",new object[]{second});
    require(!System.IO.File.Exists(secondPath)&&!System.IO.File.Exists(secondPath+".bak")&&!System.IO.File.Exists(previewPath),"Deletion left selected save derivatives.");
    require(System.Linq.Enumerable.SequenceEqual(firstBytes,System.IO.File.ReadAllBytes(firstPath)),"Another save was modified.");
    latest=(ProjectY.Data.WorldMenuSelection)call("LatestMenuPreview",new object[0]);require(latest.Id==first,"Homepage must switch after newest-world deletion.");
    bool rejected=false;try{call("DeleteCampaignSlot",new object[]{"../outside"});}catch(System.Reflection.TargetInvocationException e){rejected=e.InnerException is System.ArgumentException;}require(rejected,"Opaque id path protection.");reports.Add("single-slot deletion, next-world selection and path protection");
    var map=new ProjectY.Samples.MapPreviewData{Seed=17,Cells=new ProjectY.Samples.MapPreviewData.Cell[100000],Towns=new ProjectY.Samples.MapPreviewData.Town[0]};
    for(int i=0;i<map.Cells.Length;i++)map.Cells[i]=new ProjectY.Samples.MapPreviewData.Cell{Position=new UnityEngine.Vector3(i%500,(i%73)*.2f,i/500),Color=new UnityEngine.Color(.4f,.6f,.3f),HasWater=i%11==0};
    var compact=ProjectY.Samples.CampaignPreviewCapture.Capture(map);compact.Validate();require(compact.Heights.Length==3072&&compact.Landmarks.Length<=128,"World size escaped fixed presentation budget.");reports.Add("100,000-cell input produces fixed-size presentation data");
    string validHeader=System.IO.File.ReadAllText(firstPath);System.IO.File.WriteAllText(firstPath,validHeader.Replace("2026-10-20T01:00:00Z","not-a-timestamp"));
    latest=(ProjectY.Data.WorldMenuSelection)call("LatestMenuPreview",new object[0]);require(latest.Status==3,"Invalid creation metadata must be isolated.");System.IO.File.WriteAllText(firstPath,validHeader);reports.Add("invalid creation metadata is explicit and localized");
    call("DeleteCampaignSlot",new object[]{first});latest=(ProjectY.Data.WorldMenuSelection)call("LatestMenuPreview",new object[0]);require(latest.Status==0,"Deleting final world must select authored default.");reports.Add("last-world deletion returns empty-world state");
}
catch(System.Reflection.TargetInvocationException error)
{throw new System.Exception(error.InnerException.ToString());}
finally
{
    // Leave the empty GUID-scoped fixture directory to OS temporary-file cleanup.
    // No recursive filesystem operation is required for this regression.
}
return new {passed=true,checks=reports.ToArray(),playMode=false,playerSavesTouched=false};
