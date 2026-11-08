using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using UnityEngine;

namespace ProjectY.Data
{
    /// <summary>Read-only menu metadata. Full configuration validation still occurs when loading.</summary>
    public sealed class SaveCatalogEntry
    {
        public string Id { get; internal set; }
        public string WorldName { get; internal set; }
        public string SavedAt { get; internal set; }
        public string SavedAtUtc { get; internal set; }
        public string CreatedAtUtc { get; internal set; }
        public uint Seed { get; internal set; }
        public int TargetCells { get; internal set; }
        public int RecipeId { get; internal set; }
        public int PartyCount { get; internal set; }
        public string PartySummary { get; internal set; }
        public bool CanLoad { get; internal set; }
        public string Error { get; internal set; }
        public bool Legacy { get; internal set; }
        public bool HasWorld { get; internal set; }
        internal long SavedTicks;
    }

    // Metadata readers intentionally omit the large inventory, map and appearance payloads.
    [Serializable] internal sealed class CatalogGrowth { public int level; }
    [Serializable] internal sealed class CatalogActor { public int id; public CatalogGrowth growth; }
    [Serializable] internal sealed class CatalogExpedition { public int recipeId,targetCells; }
    [Serializable] internal sealed class CatalogDocument
    {
        public int version; public uint seed; public string savedAt, worldName, createdAt;
        public CatalogActor[] actors; public PartyRosterSave roster; public CatalogExpedition expedition;
    }

    public sealed partial class CharacterSaveService
    {
        private static bool IsCampaignId(string id)
            => id!=null && Guid.TryParseExact(id,"N",out var value) && id==value.ToString("N");

        private string SlotPath(string id)
        {
            if(id=="legacy")return legacyPath;
            if(!IsCampaignId(id))throw new ArgumentException("无效存档编号。",nameof(id));
            return Path.Combine(campaignDirectory,id+".json");
        }

        internal string NewCampaignSlot(string worldName)
        {
            string id;
            do { id=Guid.NewGuid().ToString("N"); }
            while(File.Exists(SlotPath(id)) || File.Exists(SlotPath(id)+".tmp") || File.Exists(SlotPath(id)+".bak"));
            currentSlotId=id;HasSave=false;Status="新远征已创建，尚未保存";
            currentWorldName=(worldName ?? "").Trim();currentCreatedAt=DateTime.UtcNow.ToString("o",CultureInfo.InvariantCulture);
            return id;
        }

        internal string CurrentSlotId => currentSlotId;

        internal SaveCatalogEntry[] Catalog()
        {
            var entries=new List<SaveCatalogEntry>();
            if(File.Exists(legacyPath))entries.Add(ReadEntry("legacy",legacyPath));
            if(Directory.Exists(campaignDirectory))
            {
                foreach(string path in Directory.EnumerateFiles(campaignDirectory,"*.json",SearchOption.TopDirectoryOnly))
                {
                    string id=Path.GetFileNameWithoutExtension(path);
                    if(IsCampaignId(id))entries.Add(ReadEntry(id,path));
                }
            }
            return entries.OrderByDescending(row=>row.SavedTicks).ThenBy(row=>row.Id,StringComparer.Ordinal).ToArray();
        }

        private static void SetTime(SaveCatalogEntry entry,DateTimeOffset time)
        {
            entry.SavedAtUtc=time.UtcDateTime.ToString("o",CultureInfo.InvariantCulture);
            entry.SavedAt=time.ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss",CultureInfo.InvariantCulture);
            entry.SavedTicks=time.UtcDateTime.Ticks;
        }

        private static SaveCatalogEntry ReadEntry(string id,string path)
        {
            var entry=new SaveCatalogEntry {Id=id,WorldName="",Legacy=id=="legacy",SavedAt="时间未知",SavedAtUtc="",
                PartySummary="无法读取队伍",Error="",CanLoad=false};
            try
            {
                var file=new FileInfo(path);
                if(!file.Exists)throw new FileNotFoundException("存档文件已不存在。");
                SetTime(entry,new DateTimeOffset(file.LastWriteTimeUtc));
                if(file.Length<=0 || file.Length>32*1024*1024)throw new InvalidDataException("存档大小无效（上限32 MiB）。");
                var document=JsonUtility.FromJson<CatalogDocument>(File.ReadAllText(path,Encoding.UTF8));
                if(document==null || document.version<1 || document.version>52)throw new InvalidDataException("不支持的存档版本。");
                if(document.actors==null || document.actors.Length<1 || document.actors.Length>(document.version>=43?10:4) ||
                    document.actors.Any(actor=>actor==null || actor.id<=0 || actor.growth==null || actor.growth.level<1) ||
                    document.actors.Select(actor=>actor.id).Distinct().Count()!=document.actors.Length)
                    throw new InvalidDataException("存档队伍摘要无效。");
                entry.Seed=document.seed;
                entry.WorldName=(document.worldName ?? "").Trim();
                entry.CreatedAtUtc=NormalizeCreationTime(document.createdAt,path);
                entry.HasWorld=document.version==9 || document.version==11 || document.version==12 || document.version==14 || document.version==16 || document.version==18 || document.version==20 || document.version==22 || document.version==24 || document.version==26 || document.version==28 || document.version==30 || document.version==32 || document.version==34 || document.version==36 || document.version==38 || document.version==40 || document.version==42 || document.version==44 || document.version==46 || document.version==48 || document.version==50 || document.version==52;
                if(entry.HasWorld)
                {
                    if(document.expedition==null || document.expedition.recipeId<1 || document.expedition.targetCells<0 || document.expedition.targetCells>100000)
                        throw new InvalidDataException("存档世界参数无效。");
                    entry.RecipeId=document.expedition.recipeId;entry.TargetCells=document.expedition.targetCells;
                }
                entry.PartyCount=document.actors.Length;
                if(document.version>=43 && (document.roster==null || document.roster.activeCount<1 || document.roster.activeCount>4 ||
                    document.roster.activeCount>entry.PartyCount || entry.PartyCount-document.roster.activeCount>6 ||
                    !document.actors.Any(actor=>actor.id==document.roster.protagonistId)))
                    throw new InvalidDataException(ProjectY.UI.LuaLanguage.Get("RosterSaveInvalid"));
                entry.PartySummary=entry.PartyCount+"名队员 · "+string.Join(" / ",document.actors.Select(actor=>"Lv"+actor.growth.level));
                if(DateTimeOffset.TryParse(document.savedAt,CultureInfo.InvariantCulture,DateTimeStyles.None,out var savedAt))SetTime(entry,savedAt);
                entry.CanLoad=true;
            }
            catch(Exception error) when(error is InvalidDataException || error is IOException || error is UnauthorizedAccessException || error is ArgumentException || error is FormatException)
            {
                entry.Error="无法读取此存档："+error.Message;
            }
            return entry;
        }
    }

    /// <summary>Reflection-only bridge; existing generated CharacterSaveService APIs stay intact.</summary>
    public static class CampaignSaves
    {
        public static string NewCampaign(CharacterSaveService service) => NewCampaign(service, "");
        public static string NewCampaign(CharacterSaveService service,string worldName) => Service(service).NewCampaignSlot(worldName);
        public static SaveCatalogEntry[] List(CharacterSaveService service) => Service(service).Catalog();
        public static PreparedCharacterSave PrepareSelected(CharacterSaveService service,string id,EquipmentData current)
            => Service(service).PrepareSlot(id,current);
        public static string CurrentId(CharacterSaveService service) => Service(service).CurrentSlotId;
        public static string CurrentPath(CharacterSaveService service) => Service(service).FilePath;
        private static CharacterSaveService Service(CharacterSaveService value)
            => value ?? throw new ArgumentNullException(nameof(value));
    }
}
