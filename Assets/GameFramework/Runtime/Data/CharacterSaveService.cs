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
        internal CombatActorData[] Actors; internal bool Consumed; internal ShopData Shops;
        public int ActorCount => Actors.Length;
        public CombatActorData GetActorAt(int index) => Actors[index];
        public EquipmentData Equipment { get; internal set; }
        public uint Seed { get; internal set; }
        public int Coins { get; internal set; }
        public int PlayerLevel { get; internal set; }
        public NarrativeData Narrative { get; internal set; }
        public bool LegacyNarrative { get; internal set; }
    }
    [LuaCallCSharp]
    public sealed class CharacterSaveService
    {
        private readonly string path;
        private readonly CharacterAppearanceService appearances;
        public string FilePath => path;
        public bool HasSave { get; private set; }
        public string Status { get; private set; }
        public CharacterSaveService(CharacterAppearanceService appearance, string filePath = null)
        {
            appearances = appearance; path = filePath ?? Path.Combine(Application.persistentDataPath, "Characters", "party-v1.json");
            HasSave = File.Exists(path); Status = HasSave ? "发现角色存档，可读取队伍" : "尚无角色存档";
        }
        public void Save(AdventureData adventure, PlayerData player)
        {
            if (adventure.Phase != "map" && adventure.Phase != "area") throw new InvalidOperationException("只能在探索期间保存队伍。");
            if (adventure.Narrative.DialogueOpen) throw new InvalidOperationException("请先结束对话再保存。");
            if (adventure.Shops.IsOpen) throw new InvalidOperationException("请先关闭商店再保存。");
            var document = new CharacterSaveDocument { version = 4, savedAt = DateTime.UtcNow.ToString("o"), seed = adventure.Seed,
                coins = player.Coins, playerLevel = player.Level, actors = Enumerable.Range(0, adventure.PartyCount).Select(i => adventure.GetPartyAt(i).CaptureSave()).ToArray(), equipment = adventure.Equipment.CaptureSave(), narrative = adventure.Narrative.Capture(), shops = adventure.Shops.Capture() };
            PrepareDocument(document, adventure.Equipment); // Reject incomplete state before touching a prior save.
            string data = JsonUtility.ToJson(document, true); if (Encoding.UTF8.GetByteCount(data) > 1024 * 1024) throw new InvalidDataException("角色存档超过 1 MiB。");
            Directory.CreateDirectory(Path.GetDirectoryName(path)); string temp = path + ".tmp";
            using (var stream = new FileStream(temp, FileMode.Create, FileAccess.Write, FileShare.None))
            { var bytes = new UTF8Encoding(false).GetBytes(data); stream.Write(bytes, 0, bytes.Length); stream.Flush(true); }
            if (File.Exists(path)) File.Replace(temp, path, path + ".bak"); else File.Move(temp, path);
            HasSave = true; Status = "队伍已保存 · " + DateTime.Now.ToString("HH:mm:ss");
        }
        public PreparedCharacterSave Prepare(EquipmentData current)
        {
            var info = new FileInfo(path);
            if (!info.Exists) throw new FileNotFoundException("没有角色存档。");
            if (info.Length <= 0 || info.Length > 1024 * 1024) throw new InvalidDataException("角色存档大小无效。");
            return PrepareDocument(JsonUtility.FromJson<CharacterSaveDocument>(File.ReadAllText(path, Encoding.UTF8)), current);
        }
        private PreparedCharacterSave PrepareDocument(CharacterSaveDocument document, EquipmentData current)
        {
            SaveCheck.Require(document != null && document.version >= 1 && document.version <= 4, "不支持的版本");
            SaveCheck.Require(document.coins >= 0 && document.playerLevel >= 1, "玩家数值");
            var ids = new HashSet<int>(); var actors = SaveCheck.Rows(document.actors, 4, "队伍"); SaveCheck.Require(actors.Length > 0, "空队伍");
            // JsonUtility 的内联类不能可靠地保留 null；v2 使用显式存在标记，v1 由旧记录身份迁移。
            if(document.version==1)foreach(var actor in actors)if(actor!=null)actor.hasMount=actor.mount!=null && actor.mount.id>0;
            if(document.version<3)foreach(var actor in actors)if(actor!=null)
            {actor.effects=Array.Empty<GameEffectSave>();if(actor.hasMount){SaveCheck.Require(actor.mount!=null,"缺少坐骑记录");actor.mount.effects=Array.Empty<GameEffectSave>();}}
            var prepared = actors.Select(row => CombatActorData.FromSave(row, appearances)).ToArray();
            foreach (var actor in prepared) SaveCheck.Require(ids.Add(actor.Id), "角色编号重复");
            return new PreparedCharacterSave { Actors = prepared, Equipment = current.PrepareSave(document.equipment, ids), Seed = document.seed, Coins = document.coins, PlayerLevel = document.playerLevel,
                Narrative = document.version >= 2 ? NarrativeData.Prepare(document.narrative) : null, LegacyNarrative = document.version == 1,
                Shops = ShopData.Prepare(document.version >= 4 ? document.shops : Array.Empty<ShopStockSave>()) };
        }
        public void Apply(PreparedCharacterSave prepared, AdventureData adventure, PlayerData player)
        {
            if (prepared == null || prepared.Consumed || adventure.Phase != "map") throw new InvalidOperationException("角色存档尚未准备或已被使用。");
            adventure.TakePreparedParty(prepared.Actors, prepared.Equipment); player.RestoreProfile(prepared.Coins, prepared.PlayerLevel); prepared.Consumed = true;
            if (!prepared.LegacyNarrative) adventure.Narrative.TakePrepared(prepared.Narrative);
            adventure.Shops.TakePrepared(prepared.Shops);
            Status = prepared.LegacyNarrative ? "已读取旧版队伍 · 任务与 NPC 状态从初始开始" : "已读取队伍、任务与 NPC · 地图和战斗重新开始";
        }
    }
}
