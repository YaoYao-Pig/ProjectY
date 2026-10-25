using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using UnityEngine;
using XLua;

namespace ProjectY.Data
{
    [LuaCallCSharp]
    public sealed class PreparedCharacterSave
    {
        internal CharacterSaveService SourceService; internal string SourceSlotId;
        internal string WorldName;
        internal CombatActorData[] Actors; internal bool Consumed; internal ShopData Shops;
        internal CampData Camp; internal ChronicleEntryData[] Journal;
        internal ExpeditionSave Expedition; internal MapAreaStateData[] PreparedAreas;
        internal WorldPartiesData PreparedWorldParties;
        internal WorldMapExplorationData PreparedWorldFog;
        internal SkillSynergyDiscoveryData SynergyDiscovery;
        internal WorldTravelData PreparedTravel; internal ConstructionData PreparedConstruction; internal MapObstacleData PreparedObstacles;
        public PartyStoryData PartyBonds { get; internal set; }
        public int ActorCount => Actors.Length;
        public CombatActorData GetActorAt(int index) => Actors[index];
        public EquipmentData Equipment { get; internal set; }
        public uint Seed { get; internal set; }
        public int Coins { get; internal set; }
        public int PlayerLevel { get; internal set; }
        public NarrativeData Narrative { get; internal set; }
        public bool LegacyNarrative { get; internal set; }
        public bool LegacyProfessions { get; internal set; }
    }
    [LuaCallCSharp]
    public sealed partial class CharacterSaveService
    {
        private readonly string legacyPath, campaignDirectory;
        private string currentSlotId = "legacy";
        private string currentWorldName = "";
        private readonly CharacterAppearanceService appearances;
        public string FilePath => SlotPath(currentSlotId);
        public bool HasSave { get; private set; }
        public string Status { get; private set; }
        public CharacterSaveService(CharacterAppearanceService appearance, string filePath = null)
        {
            appearances = appearance;
            legacyPath = Path.GetFullPath(filePath ?? Path.Combine(Application.persistentDataPath, "Characters", "party-v1.json"));
            campaignDirectory = Path.Combine(Path.GetDirectoryName(legacyPath), "Campaigns");
            HasSave = File.Exists(legacyPath); Status = HasSave ? "发现存档，可继续远征" : "尚无存档";
        }
        public void Save(AdventureData adventure, PlayerData player)
        {
            string path = FilePath;
            if (adventure.Phase != "map" && adventure.Phase != "area") throw new InvalidOperationException("只能在探索期间保存队伍。");
            if (adventure.Narrative.DialogueOpen) throw new InvalidOperationException("请先结束对话再保存。");
            if (adventure.WorldParties.IsOpen) throw new InvalidOperationException("请先结束队伍交互再保存。");
            if (adventure.Shops.IsOpen) throw new InvalidOperationException("请先关闭商店再保存。");
            if (adventure.Camp.IsOpen) throw new InvalidOperationException("请先关闭营地面板再保存。");
            var actorIds=new HashSet<int>(Enumerable.Range(0,adventure.PartyCount).Select(i=>adventure.GetPartyAt(i).Id));
            var expedition=ExpeditionPersistence.Capture(adventure);
            if(expedition!=null)foreach(var area in expedition.areas)foreach(var group in area.encounters)foreach(var actor in group.actors)actorIds.Add(actor.id);
            if(expedition!=null)foreach(var party in expedition.parties.parties)foreach(var actor in party.members)actorIds.Add(actor.id);
            var document = new CharacterSaveDocument { version = expedition==null?23:24, savedAt = DateTime.UtcNow.ToString("o"), worldName = currentWorldName, seed = adventure.Seed,
                coins = player.Coins, playerLevel = player.Level, actors = Enumerable.Range(0, adventure.PartyCount).Select(i => adventure.GetPartyAt(i).CaptureSave()).ToArray(), equipment = adventure.Equipment.CaptureSave(actorIds), narrative = adventure.Narrative.Capture(), shops = adventure.Shops.Capture(),
                camp=adventure.Camp.Capture(),partyStory=adventure.PartyBonds.Capture(),journal=adventure.CaptureJournal(),expedition=expedition,skillSynergies=adventure.SynergyDiscovery.Capture() };
            PrepareDocument(document, adventure.Equipment); // Reject incomplete state before touching a prior save.
            string data = JsonUtility.ToJson(document); if (Encoding.UTF8.GetByteCount(data) > 32 * 1024 * 1024) throw new InvalidDataException("远征存档超过 32 MiB。");
            Directory.CreateDirectory(Path.GetDirectoryName(path)); string temp = path + ".tmp";
            using (var stream = new FileStream(temp, FileMode.Create, FileAccess.Write, FileShare.None))
            { var bytes = new UTF8Encoding(false).GetBytes(data); stream.Write(bytes, 0, bytes.Length); stream.Flush(true); }
            if (File.Exists(path)) File.Replace(temp, path, path + ".bak"); else File.Move(temp, path);
            HasSave = true; Status = "远征已保存 · " + DateTime.Now.ToString("HH:mm:ss");
        }
        public PreparedCharacterSave Prepare(EquipmentData current)
            => PrepareSlot(currentSlotId,current);
        internal PreparedCharacterSave PrepareSlot(string id,EquipmentData current)
        {
            string path = SlotPath(id);
            var info = new FileInfo(path);
            if (!info.Exists) throw new FileNotFoundException("没有角色存档。");
            if (info.Length <= 0 || info.Length > 32 * 1024 * 1024) throw new InvalidDataException("远征存档大小无效。");
            var prepared = PrepareDocument(JsonUtility.FromJson<CharacterSaveDocument>(File.ReadAllText(path, Encoding.UTF8)), current);
            prepared.SourceService=this;prepared.SourceSlotId=id;
            return prepared;
        }
        private PreparedCharacterSave PrepareDocument(CharacterSaveDocument document, EquipmentData current)
        {
            SaveCheck.Require(document != null && document.version >= 1 && document.version <= 24, "不支持的版本");
            // Old saves did not record discoveries; installed runes must not implicitly reveal them on load.
            var synergies = document.version < 13 ? new SkillSynergyDiscoveryData() : SkillSynergyDiscoveryData.Prepare(document.skillSynergies);
            SaveCheck.Require(document.coins >= 0 && document.playerLevel >= 1, "玩家数值");
            var ids = new HashSet<int>(); var actors = SaveCheck.Rows(document.actors, 4, "队伍"); SaveCheck.Require(actors.Length > 0, "空队伍");
            // JsonUtility 的内联类不能可靠地保留 null；v2 使用显式存在标记，v1 由旧记录身份迁移。
            if(document.version==1)foreach(var actor in actors)if(actor!=null)actor.hasMount=actor.mount!=null && actor.mount.id>0;
            if(document.version<3)foreach(var actor in actors)if(actor!=null)
            {actor.effects=Array.Empty<GameEffectSave>();if(actor.hasMount){SaveCheck.Require(actor.mount!=null,"缺少坐骑记录");actor.mount.effects=Array.Empty<GameEffectSave>();}}
            foreach (var actor in actors)
            {
                SaveCheck.Require(actor != null && actor.growth != null, "缺少角色养成");
                if (document.version < 5)
                {
                    actor.growth.currentProfessionId = 0; actor.growth.professions = Array.Empty<int>();
                    actor.growth.offers = Array.Empty<int>(); // 保留学习次数；旧候选不再限制主动选学。
                }
                else SaveCheck.Require(actor.growth.currentProfessionId > 0, "缺少当前职业");
            }
            if(document.version<8)
            {
                foreach(var actor in actors)
                {
                    foreach(var effect in SaveCheck.Rows(actor.effects,256,"持续效果"))
                    {SaveCheck.Require(effect!=null,"持续效果");effect.snapshotIds=Array.Empty<int>();effect.snapshotAmounts=Array.Empty<int>();effect.expiresAt=effect.nextTickAt=0;}
                    if(actor.hasMount)
                    {
                        SaveCheck.Require(actor.mount!=null,"缺少坐骑记录");
                        foreach(var effect in SaveCheck.Rows(actor.mount.effects,256,"坐骑持续效果"))
                        {SaveCheck.Require(effect!=null,"坐骑持续效果");effect.snapshotIds=Array.Empty<int>();effect.snapshotAmounts=Array.Empty<int>();effect.expiresAt=effect.nextTickAt=0;}
                    }
                }
            }
            if (document.version < 21)
            {
                foreach (var actor in actors) actor.injuries = CombatActorData.CreateHealthyBody();
                if (document.expedition != null)
                {
                    if (document.expedition.areas != null) foreach (var area in document.expedition.areas)
                        if (area != null && area.encounters != null) foreach (var group in area.encounters)
                            if (group != null && group.actors != null) foreach (var actor in group.actors)
                                if (actor != null) actor.injuries = CombatActorData.CreateHealthyBody();
                    if (document.expedition.parties != null && document.expedition.parties.parties != null)
                        foreach (var party in document.expedition.parties.parties)
                            if (party != null && party.members != null) foreach (var actor in party.members)
                                if (actor != null) actor.injuries = CombatActorData.CreateHealthyBody();
                }
            }
            if(document.version<23)
            {
                foreach(var actor in actors)CombatActorData.MigrateBody(actor.injuries,actor.maxHP,ref actor.hp);
                if(document.expedition!=null)
                {
                    if(document.expedition.areas!=null)foreach(var area in document.expedition.areas)
                        if(area!=null && area.encounters!=null)foreach(var group in area.encounters)
                            if(group!=null && group.actors!=null)foreach(var actor in group.actors)
                                if(actor!=null)CombatActorData.MigrateBody(actor.injuries,actor.maxHP,ref actor.hp);
                    if(document.expedition.parties!=null && document.expedition.parties.parties!=null)
                        foreach(var party in document.expedition.parties.parties)
                            if(party!=null && party.members!=null)foreach(var actor in party.members)
                                if(actor!=null)CombatActorData.MigrateBody(actor.injuries,actor.maxHP,ref actor.hp);
                }
            }
            var prepared = actors.Select(row => CombatActorData.FromSave(row, appearances)).ToArray();
            foreach (var actor in prepared) SaveCheck.Require(ids.Add(actor.Id), "角色编号重复");
            if(document.version<6)
            {
                SaveCheck.Require(document.equipment!=null,"缺少装备");
                foreach(var item in SaveCheck.Rows(document.equipment.weapons,10000,"武器")){SaveCheck.Require(item!=null,"武器");item.condition=EquipmentConditionSave.Fresh();}
                foreach(var item in SaveCheck.Rows(document.equipment.wearables,10000,"防具")){SaveCheck.Require(item!=null,"防具");item.condition=EquipmentConditionSave.Fresh();}
                document.camp=null;document.partyStory=new PartyStorySave{bonds=Array.Empty<PartyBondSave>(),rescues=Array.Empty<IntEntry>(),honors=Array.Empty<PartyHonorSave>()};document.journal=Array.Empty<ChronicleSave>();
            }
            else SaveCheck.Require(document.camp!=null && document.partyStory!=null && document.journal!=null,"缺少营地、关系或经历");
            if(document.version<7)
            {
                SaveCheck.Require(document.equipment!=null,"缺少装备");
                foreach(var item in SaveCheck.Rows(document.equipment.weapons,10000,"武器")){SaveCheck.Require(item!=null,"武器");item.affixId=1;}
                foreach(var item in SaveCheck.Rows(document.equipment.wearables,10000,"防具")){SaveCheck.Require(item!=null,"防具");item.affixId=1;}
            }
            if(document.version<10)
            {
                SaveCheck.Require(document.equipment!=null,"缺少装备");
                document.equipment.piles=Array.Empty<InventoryPileSave>();document.equipment.nextPileId=1;
            }
            var narrative = document.version >= 2 ? NarrativeData.Prepare(document.narrative) : null;
            var journal = AdventureData.PrepareJournal(document.journal, ids);
            double previousMinutes = 0;
            foreach (var entry in journal)
            {
                SaveCheck.Require(entry.Minutes >= previousMinutes && narrative != null && entry.Minutes <= narrative.Minutes, "经历日期与叙事时钟不一致");
                previousMinutes = entry.Minutes;
            }
            var result = new PreparedCharacterSave { Actors = prepared, Seed = document.seed, Coins = document.coins, PlayerLevel = document.playerLevel,
                WorldName = (document.worldName ?? "").Trim(),
                Narrative = narrative, LegacyNarrative = document.version == 1, LegacyProfessions = document.version < 5,
                Shops = ShopData.Prepare(document.version >= 4 ? document.shops : Array.Empty<ShopStockSave>()),
                Camp=CampData.Prepare(document.camp),PartyBonds=PartyStoryData.Prepare(document.partyStory,ids),Journal=journal,SynergyDiscovery=synergies };
            if(document.version==9 || document.version==11 || document.version==12 || document.version==14 || document.version==16 || document.version==18 || document.version==20 || document.version==22 || document.version==24)
            {
                SaveCheck.Require(document.expedition!=null,"缺少远征记录");
                if(document.version<12)document.expedition.parties=null;
                else SaveCheck.Require(document.expedition.parties!=null,"缺少大地图队伍");
                if(document.version>=16)SaveCheck.Require(document.expedition.parties.rosterVersion==1 && document.expedition.parties.factions!=null,"缺少势力与队伍编制");
                else if(document.expedition.parties!=null){document.expedition.parties.rosterVersion=0;document.expedition.parties.factions=null;}
                if(document.version>=18)SaveCheck.Require(document.expedition.parties.scheduleVersion==1 && document.expedition.parties.strengthVersion==1 && document.expedition.parties.factions.materializationVersion==1,"缺少世界模拟LOD状态");
                else if(document.expedition.parties!=null)
                {
                    document.expedition.parties.scheduleVersion=0;document.expedition.parties.strengthVersion=0;
                    if(document.expedition.parties.factions!=null)document.expedition.parties.factions.materializationVersion=0;
                }
                if(document.version>=20)SaveCheck.Require(document.expedition.worldFog!=null,"缺少大地图探索记录");
                else document.expedition.worldFog=null;
                ExpeditionPersistence.Prepare(result,document.expedition,current,appearances,ids);
            }
            result.Equipment=current.PrepareSave(document.equipment,ids);
            if(result.Expedition!=null)ExpeditionPersistence.ValidateEquipmentIds(result,document.equipment);
            return result;
        }
        public void Apply(PreparedCharacterSave prepared, AdventureData adventure, PlayerData player)
        {
            if (prepared == null || prepared.Consumed || adventure.Phase != "map") throw new InvalidOperationException("角色存档尚未准备或已被使用。");
            if(prepared.SourceService!=this || string.IsNullOrEmpty(prepared.SourceSlotId))throw new InvalidOperationException("存档候选不属于当前保存服务。");
            SlotPath(prepared.SourceSlotId); // Validate provenance before any live Data is replaced.
            adventure.TakePreparedParty(prepared.Actors, prepared.Equipment);
            if (!prepared.LegacyNarrative) adventure.Narrative.TakePrepared(prepared.Narrative);
            adventure.Shops.TakePrepared(prepared.Shops);
            adventure.Camp.TakePrepared(prepared.Camp);adventure.PartyBonds.TakePrepared(prepared.PartyBonds);adventure.RestoreJournal(prepared.Journal);
            ExpeditionPersistence.Apply(prepared,adventure);
            adventure.SynergyDiscovery.TakePrepared(prepared.SynergyDiscovery);
            prepared.Consumed = true;
            currentSlotId=prepared.SourceSlotId;HasSave=File.Exists(FilePath);
            currentWorldName=prepared.WorldName;
            Status = prepared.Expedition!=null ? "已继续远征 · 探索、战利品与剧情已恢复" : "已导入队伍 · 该存档未记录地图，已开始新地图";
            // This is the only externally observable notification. Publish after every subsystem is committed.
            player.RestoreProfile(prepared.Coins, prepared.PlayerLevel);
        }
    }
}
