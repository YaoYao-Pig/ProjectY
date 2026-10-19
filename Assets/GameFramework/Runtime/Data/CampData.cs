using System;
using System.Collections.Generic;
using System.Linq;
using XLua;

namespace ProjectY.Data
{
    [LuaCallCSharp]
    public sealed class CampLevelData
    {
        public int FacilityId { get; internal set; }
        public int Level { get; internal set; }
    }
    [LuaCallCSharp]
    public sealed class CampStackData
    {
        public int ItemId { get; internal set; }
        public int Count { get; internal set; }
    }
    [LuaCallCSharp]
    public sealed class CampJobData
    {
        public int FacilityId { get; internal set; }
        public int RecipeId { get; internal set; }
        public double StartedAt { get; internal set; }
        public double ReadyAt { get; internal set; }
    }

    /// <summary>营地等级、堆叠仓储和生产订单；所有资源交易先检查再提交。</summary>
    [LuaCallCSharp]
    public sealed class CampData
    {
        private readonly List<CampLevelData> levels = new List<CampLevelData>();
        private readonly List<CampStackData> storage = new List<CampStackData>();
        private readonly List<CampJobData> jobs = new List<CampJobData>();
        public static CampData For(AdventureData adventure) => adventure.Camp;
        public static CampData Prepared(PreparedCharacterSave prepared) => prepared.Camp;
        public bool IsOpen { get; private set; }
        public int Revision { get; private set; }
        public int LevelCount => levels.Count;
        public int StorageCount => storage.Count;
        public int JobCount => jobs.Count;
        public int StoredTotal => storage.Sum(row => row.Count);
        public CampLevelData GetLevelAt(int index) => levels[index];
        public CampStackData GetStorageAt(int index) => storage[index];
        public CampJobData GetJobAt(int index) => jobs[index];
        public int GetLevel(int facility) => levels.Find(row => row.FacilityId == facility)?.Level ?? 0;
        public int Stored(int item) => storage.Find(row => row.ItemId == item)?.Count ?? 0;
        public CampJobData JobFor(int facility) => jobs.Find(row => row.FacilityId == facility);
        public void Open() { if (IsOpen) throw new InvalidOperationException("Camp is already open."); IsOpen = true; Revision++; }
        public void Close() { if (IsOpen) { IsOpen = false; Revision++; } }
        public void Clear() { IsOpen = false; levels.Clear(); storage.Clear(); jobs.Clear(); Revision++; }
        private string Session(int revision) => !IsOpen ? "请先打开营地" : revision != Revision ? "营地状态已变化，请重新选择" : "";
        private static bool ValidTime(double value) => !double.IsNaN(value) && !double.IsInfinity(value) && value >= 0 && value <= 1000000000;
        private static void CheckItems(int[] items, int[] counts)
        {
            if (items == null || counts == null || items.Length != counts.Length) throw new ArgumentException("Camp item arrays differ.");
            var unique = new HashSet<int>();
            for (int i = 0; i < items.Length; i++)
                if (items[i] < 1 || counts[i] < 1 || !unique.Add(items[i])) throw new ArgumentException("Invalid or duplicate camp item.");
        }
        private string Cost(int coins, int[] items, int[] counts, EquipmentData equipment, PlayerData player)
        {
            if (coins < 0) throw new ArgumentOutOfRangeException(nameof(coins));
            CheckItems(items, counts);
            if (player.Coins < coins) return "金币不足";
            for (int i = 0; i < items.Length; i++)
                if ((long)Stored(items[i]) + equipment.CountItem(items[i]) < counts[i]) return "材料不足（先用仓库，再用背包）";
            return "";
        }
        private void SpendMaterials(int[] items, int[] counts, EquipmentData equipment)
        {
            for (int i = 0; i < items.Length; i++)
            {
                int stored = Math.Min(Stored(items[i]), counts[i]);
                if (stored > 0) RemoveStored(items[i], stored);
                if (stored < counts[i]) equipment.ConsumeStack(items[i], counts[i] - stored);
            }
        }
        private void RemoveStored(int item, int count)
        {
            var row = storage.Find(value => value.ItemId == item);
            row.Count -= count;
            if (row.Count == 0) storage.Remove(row);
        }
        private static void SpendCoins(PlayerData player, int coins)
        {
            if (coins > 0 && !player.TrySpendCoins(coins)) throw new InvalidOperationException("Validated camp payment failed.");
        }
        public string Upgrade(int facility, int expectedLevel, int revision, int coins, int[] items, int[] counts, EquipmentData equipment, PlayerData player)
        {
            string reason = Session(revision); if (reason != "") return reason;
            if (facility < 1 || expectedLevel < 0) throw new ArgumentException("Invalid camp upgrade.");
            if (GetLevel(facility) != expectedLevel) return "设施等级已变化";
            reason = Cost(coins, items, counts, equipment, player); if (reason != "") return reason;
            SpendMaterials(items, counts, equipment);
            var row = levels.Find(value => value.FacilityId == facility);
            if (row == null) { row = new CampLevelData { FacilityId = facility }; levels.Add(row); }
            row.Level = checked(expectedLevel + 1); Revision++;
            SpendCoins(player, coins); return "";
        }
        public string Enqueue(int facility, int recipe, int requiredLevel, double now, double duration, int revision,
            int coins, int[] items, int[] counts, EquipmentData equipment, PlayerData player)
        {
            string reason = Session(revision); if (reason != "") return reason;
            if (facility < 1 || recipe < 1 || requiredLevel < 1 || !ValidTime(now) || duration <= 0 || !ValidTime(now + duration))
                throw new ArgumentException("Invalid camp production.");
            if (GetLevel(facility) < requiredLevel) return "设施等级不足";
            if (JobFor(facility) != null) return "该设施仍有订单，请先领取产物";
            reason = Cost(coins, items, counts, equipment, player); if (reason != "") return reason;
            SpendMaterials(items, counts, equipment);
            jobs.Add(new CampJobData { FacilityId = facility, RecipeId = recipe, StartedAt = now, ReadyAt = now + duration }); Revision++;
            SpendCoins(player, coins); return "";
        }
        public string Claim(int facility, int revision, double now, int[] items, int[] counts, string[] kinds, EquipmentData equipment)
        {
            string reason = Session(revision); if (reason != "") return reason;
            var job = JobFor(facility);
            if (job == null) return "该设施没有待领取订单";
            if (!ValidTime(now)) throw new ArgumentOutOfRangeException(nameof(now));
            if (now < job.ReadyAt) return "生产尚未完成";
            CheckItems(items, counts);
            if (items.Length == 0 || kinds == null || kinds.Length != items.Length) throw new ArgumentException("Invalid camp output.");
            for (int i = 0; i < items.Length; i++)
            {
                if (!StackKind(kinds[i])) throw new ArgumentException("Camp production only supports stack items.");
                if ((long)equipment.CountItem(items[i]) + counts[i] > int.MaxValue) return "物品数量已达上限";
            }
            if (!equipment.CanGrant(items, counts, kinds)) return "背包空间不足，产物仍保留在设施中";
            for (int i = 0; i < items.Length; i++) equipment.AddStack(items[i], counts[i]);
            jobs.Remove(job); Revision++; return "";
        }
        public static bool StackKind(string kind) => kind == "material" || kind == "ammo" || kind == "consumable" || kind == "rune" || kind == "module";
        public string Deposit(int item, int count, int capacity, int revision, EquipmentData equipment)
        {
            string reason = Session(revision); if (reason != "") return reason;
            if (item < 1 || count < 1 || capacity < 0) return "无效存入数量";
            if (equipment.CountItem(item) < count) return "背包物品数量不足";
            if ((long)StoredTotal + count > capacity) return "营地仓库已满，请升级或取出物品";
            equipment.ConsumeStack(item, count);
            var row = storage.Find(value => value.ItemId == item);
            if (row == null) { row = new CampStackData { ItemId = item }; storage.Add(row); }
            row.Count += count; Revision++; return "";
        }
        public string Withdraw(int item, int count, int revision, string kind, EquipmentData equipment)
        {
            string reason = Session(revision); if (reason != "") return reason;
            if (item < 1 || count < 1 || !StackKind(kind)) return "无效取出物品或数量";
            if (Stored(item) < count) return "仓库物品数量不足";
            if ((long)equipment.CountItem(item) + count > int.MaxValue) return "物品数量已达上限";
            if (!equipment.CanGrant(new[] { item }, new[] { count }, new[] { kind })) return "背包空间不足，物品仍保留在仓库中";
            equipment.AddStack(item, count); RemoveStored(item, count); Revision++; return "";
        }
        public string Wait(int minutes, int revision, NarrativeData narrative)
        {
            string reason = Session(revision); if (reason != "") return reason;
            if (minutes != 60 && minutes != 360 && minutes != 1440) return "无效等待时长";
            if (!ValidTime(narrative.Minutes + minutes)) return "游戏时间已达上限";
            narrative.AdvanceMinutes(minutes); Revision++; return "";
        }
        internal CampSave Capture() => new CampSave {
            levels = levels.Select(row => new CampLevelSave { facility = row.FacilityId, level = row.Level }).ToArray(),
            storage = storage.Select(row => new CampStackSave { item = row.ItemId, count = row.Count }).ToArray(),
            jobs = jobs.Select(row => new CampJobSave { facility = row.FacilityId, recipe = row.RecipeId, startedAt = row.StartedAt, readyAt = row.ReadyAt }).ToArray() };
        internal static CampData Prepare(CampSave save)
        {
            var data = new CampData();
            if (save == null) return data; // 仅由存档版本迁移显式传入 null。
            foreach (var row in SaveCheck.Rows(save.levels, 100, "营地设施"))
            {
                SaveCheck.Require(row != null && row.facility > 0 && row.level > 0 && row.level <= 100 && data.GetLevel(row.facility) == 0, "营地设施等级或重复设施");
                data.levels.Add(new CampLevelData { FacilityId = row.facility, Level = row.level });
            }
            long total = 0;
            foreach (var row in SaveCheck.Rows(save.storage, 10000, "营地仓库"))
            {
                SaveCheck.Require(row != null && row.item > 0 && row.count > 0 && data.Stored(row.item) == 0, "营地物品数量或重复物品");
                total += row.count; SaveCheck.Require(total <= int.MaxValue, "营地仓库总量");
                data.storage.Add(new CampStackData { ItemId = row.item, Count = row.count });
            }
            foreach (var row in SaveCheck.Rows(save.jobs, 100, "营地生产"))
            {
                SaveCheck.Require(row != null && row.facility > 0 && row.recipe > 0 && data.GetLevel(row.facility) > 0 && data.JobFor(row.facility) == null &&
                    ValidTime(row.startedAt) && ValidTime(row.readyAt) && row.readyAt > row.startedAt, "营地生产订单或完成时间");
                data.jobs.Add(new CampJobData { FacilityId = row.facility, RecipeId = row.recipe, StartedAt = row.startedAt, ReadyAt = row.readyAt });
            }
            return data;
        }
        internal void TakePrepared(CampData source)
        { Clear(); levels.AddRange(source.levels); storage.AddRange(source.storage); jobs.AddRange(source.jobs); }
    }
    [Serializable] internal sealed class CampLevelSave { public int facility, level; }
    [Serializable] internal sealed class CampStackSave { public int item, count; }
    [Serializable] internal sealed class CampJobSave { public int facility, recipe; public double startedAt, readyAt; }
    [Serializable] internal sealed class CampSave { public CampLevelSave[] levels; public CampStackSave[] storage; public CampJobSave[] jobs; }
    public sealed partial class AdventureData { internal CampData Camp { get; } = new CampData(); }
}
