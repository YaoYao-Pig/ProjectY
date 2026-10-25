// Native visit/inventory persistence boundary in an isolated LuaEnv. No live scene or disk save writes.
if(UnityEditor.EditorApplication.isPlayingOrWillChangePlaymode)throw new System.Exception("Edit Mode required");
var data=new ProjectY.Data.AdventureData();data.Reset(42);
data.AddPartyActor(1,1).Restore();data.Equipment.Grid.Configure(4,4);data.Equipment.Grid.Define(82,1,1);
data.Equipment.AddStack(82,2);
var restored=new ProjectY.Data.AdventureData();restored.Reset(42);restored.AddPartyActor(1,1).Restore();
var flags=System.Reflection.BindingFlags.Instance|System.Reflection.BindingFlags.NonPublic;
var saveType=typeof(ProjectY.Data.AdventureData).Assembly.GetType("ProjectY.Data.ExpeditionSave",true);
using(var lua=new XLua.LuaEnv())
{
    var loader=new ProjectY.LuaFileLoader(ProjectY.LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("NativeAdventure",data);
    lua.DoString(@"
        local config=require('Config.ConfigSystem')()
        config:OnInit({services={ReadConfig=function(_,name)
            local f=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=f:read('*a');f:close();return bytes
        end}})
        local AreaSystem=require('Game.MapArea.MapAreaSystem')
        naturalTestSite={id=91,areaConfigId=71,naturalKind='Canyon',entryItemId=82,entryItemCount=1}
        function naturalTestArea(native)
            return setmetatable({config=config,adventure=native,generator={CanGenerate=function()return true end},layouts={},
                Activate=function(self,site)
                    self.adventure.Areas:Enter(site.id,4,1);self.adventure:BeginArea(site.id);return true
                end},{__index=AreaSystem})
        end
        local areas=naturalTestArea(NativeAdventure)
        assert(areas:Enter(naturalTestSite,42));assert(NativeAdventure.Equipment:CountItem(82)==1 and NativeAdventure:HasVisited(91))
        NativeAdventure:LeaveArea();assert(areas:Enter(naturalTestSite,42));assert(NativeAdventure.Equipment:CountItem(82)==1)
        NativeAdventure:LeaveArea()
    ");
    var visited=(int[])typeof(ProjectY.Data.AdventureData).GetMethod("CaptureVisited",flags).Invoke(data,null);
    if(visited.Length!=1||visited[0]!=91)throw new System.Exception("Native visit not captured");
    var saved=UnityEngine.JsonUtility.FromJson("{\"visited\":[91],\"triggers\":[],\"activeSite\":0,\"generationVersion\":7}",saveType);
    var roundtrip=UnityEngine.JsonUtility.FromJson(UnityEngine.JsonUtility.ToJson(saved),saveType);
    typeof(ProjectY.Data.AdventureData).GetMethod("RestoreExploration",flags).Invoke(restored,new[]{roundtrip});
    lua.Global.Set("RestoredAdventure",restored);
    lua.DoString("assert(RestoredAdventure:HasVisited(91));assert(RestoredAdventure.Equipment:CountItem(82)==0);assert(naturalTestArea(RestoredAdventure):Enter(naturalTestSite,42));assert(RestoredAdventure.Equipment:CountItem(82)==0)");
    var prepared=new ProjectY.Data.PreparedCharacterSave();
    typeof(ProjectY.Data.PreparedCharacterSave).GetField("Expedition",flags).SetValue(prepared,roundtrip);
    if(ProjectY.Data.ExpeditionPersistence.Generation(prepared)!=7)throw new System.Exception("New map generation version lost");
    var legacy=UnityEngine.JsonUtility.FromJson("{}",saveType);
    typeof(ProjectY.Data.PreparedCharacterSave).GetField("Expedition",flags).SetValue(prepared,legacy);
    if(ProjectY.Data.ExpeditionPersistence.Generation(prepared)!=6)throw new System.Exception("Legacy map generation default changed");
    ProjectY.Data.ExpeditionPersistence.SetGeneration(data,8);
    if((int)typeof(ProjectY.Data.AdventureData).GetField("ExpeditionGeneration",flags).GetValue(data)!=8)throw new System.Exception("New expedition version not configured");
    var latest=UnityEngine.JsonUtility.FromJson("{\"generationVersion\":8}",saveType);
    typeof(ProjectY.Data.PreparedCharacterSave).GetField("Expedition",flags).SetValue(prepared,UnityEngine.JsonUtility.FromJson(UnityEngine.JsonUtility.ToJson(latest),saveType));
    if(ProjectY.Data.ExpeditionPersistence.Generation(prepared)!=8)throw new System.Exception("Continuous mountain version was not preserved");
}
return new {nativeInventory=true,nativeVisited=true,restoredFreeEntry=true,mapVersionRoundtrip=true,legacyVersion=6,playMode=false,playerFilesWritten=false};
