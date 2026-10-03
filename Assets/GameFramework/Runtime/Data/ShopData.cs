using System;
using System.Collections.Generic;
using System.Linq;
using XLua;

namespace ProjectY.Data
{
    [LuaCallCSharp]
    public sealed class ShopStockEntry
    {
        public int EntryId { get; }
        public int ItemId { get; }
        public int Price { get; }
        public int Count { get; internal set; }
        internal ShopStockEntry(int entry, int item, int count, int price)
        { EntryId = entry; ItemId = item; Count = count; Price = price; }
    }

    [LuaCallCSharp]
    public sealed class ShopStock
    {
        internal readonly List<ShopStockEntry> entries = new List<ShopStockEntry>();
        public int MerchantId { get; internal set; }
        public int SiteId { get; internal set; }
        public int LocalNpcId { get; internal set; }
        public int TemplateId { get; internal set; }
        public int Period { get; internal set; }
        public int Count => entries.Count;
        public ShopStockEntry GetAt(int index) => entries[index];
        public ShopStockEntry Find(int entry) => entries.Find(row => row.EntryId == entry);
    }

    /// <summary>每位商人的权威库存和临时交易会话。反射入口避免更改生成的 xLua Wrapper。</summary>
    [LuaCallCSharp]
    public sealed class ShopData
    {
        private readonly List<ShopStock> stocks = new List<ShopStock>();
        public static ShopData For(AdventureData adventure) => adventure.Shops;
        public static ShopData Prepared(PreparedCharacterSave prepared) => prepared.Shops;
        public ShopStock Active { get; private set; }
        public bool IsOpen => Active != null;
        public int Revision { get; private set; }
        public int Count => stocks.Count;
        public ShopStock GetAt(int index) => stocks[index];
        public ShopStock Find(int merchant, int site, int npc) => stocks.Find(row => row.MerchantId == merchant && row.SiteId == site && row.LocalNpcId == npc);
        public ShopStock Refresh(int merchant, int site, int npc, int template, int period, int[] entries, int[] items, int[] counts, int[] prices)
        {
            if (merchant < 1 || site < 1 || npc < 1 || template < 1 || period < 0 || entries == null || items == null || counts == null || prices == null ||
                entries.Length != items.Length || items.Length != counts.Length || counts.Length != prices.Length)
                throw new ArgumentException("Invalid shop stock.");
            var stock = new ShopStock { MerchantId = merchant, SiteId = site, LocalNpcId = npc, TemplateId = template, Period = period };
            var unique = new HashSet<int>();
            for (int i = 0; i < entries.Length; i++)
            {
                if (entries[i] < 1 || items[i] < 1 || counts[i] < 1 || prices[i] < 0 || !unique.Add(entries[i])) throw new ArgumentException("Invalid shop entry.");
                stock.entries.Add(new ShopStockEntry(entries[i], items[i], counts[i], prices[i]));
            }
            var old = Find(merchant, site, npc);
            if (old != null) stocks.Remove(old);
            stocks.Add(stock);
            if (Active == old && old != null) Active = stock;
            Revision++; return stock;
        }
        public void Open(ShopStock stock)
        {
            if (IsOpen || stock == null || !stocks.Contains(stock)) throw new InvalidOperationException("Invalid shop session.");
            Active = stock; Revision++;
        }
        public void Close() { if (IsOpen) { Active = null; Revision++; } }
        public void Clear() { Active = null; stocks.Clear(); Revision++; }

        // 所有可预期失败在提交之前检查，最后才通知金币监听者，避免观察到半笔交易。
        public string Buy(int entryId, int count, int revision, EquipmentData equipment, PlayerData player, string kind, int ammo, int capacity, int rounds)
        {
            if (!IsOpen || revision != Revision) return "商品列表已变化，请重新选择";
            var entry = Active.Find(entryId);
            if (entry == null || count < 1) return "无效商品或购买数量";
            if (entry.Count < count) return "商品库存不足或已经售罄";
            long total = (long)entry.Price * count;
            if (total > player.Coins) return "金币不足";
            bool stack = kind == "rune" || kind == "module" || kind == "ammo" || kind == "material";
            if (!stack && kind != "weapon" && kind != "wearable" && kind != "magazine") throw new ArgumentException("Unsupported shop item kind.");
            if (kind == "magazine" && (ammo < 1 || capacity < 1 || rounds < 0 || rounds > capacity)) throw new ArgumentException("Invalid magazine specification.");
            if (stack && (long)equipment.CountItem(entry.ItemId) + count > int.MaxValue) return "物品数量已达上限";
            if (!equipment.CanGrant(new[] { entry.ItemId }, new[] { count }, new[] { kind })) return "背包空间不足，请先整理背包";
            if (stack) equipment.AddStack(entry.ItemId, count);
            else for (int i = 0; i < count; i++)
            {
                if (kind == "weapon") equipment.AddWeapon(entry.ItemId);
                else if (kind == "wearable") equipment.AddWearable(entry.ItemId);
                else equipment.AddMagazine(entry.ItemId, ammo, capacity, rounds);
            }
            entry.Count -= count; Revision++;
            if (!player.TrySpendCoins((int)total)) throw new InvalidOperationException("Validated shop payment failed.");
            return "";
        }

        internal ShopStockSave[] Capture() => stocks.Select(stock => new ShopStockSave { merchant = stock.MerchantId, site = stock.SiteId,
            npc = stock.LocalNpcId, template = stock.TemplateId, period = stock.Period,
            entries = stock.entries.Select(entry => new ShopEntrySave { entry = entry.EntryId, item = entry.ItemId, count = entry.Count, price = entry.Price }).ToArray() }).ToArray();
        internal static ShopData Prepare(ShopStockSave[] saved)
        {
            var data = new ShopData();
            foreach (var row in SaveCheck.Rows(saved, 10000, "商人库存"))
            {
                SaveCheck.Require(row != null && row.merchant > 0 && row.site > 0 && row.npc > 0 && row.template > 0 && row.period >= 0 && data.Find(row.merchant, row.site, row.npc) == null, "商人身份或重复库存");
                var stock = new ShopStock { MerchantId = row.merchant, SiteId = row.site, LocalNpcId = row.npc, TemplateId = row.template, Period = row.period };
                foreach (var entry in SaveCheck.Rows(row.entries, 10000, "商品条目"))
                {
                    SaveCheck.Require(entry != null && entry.entry > 0 && entry.item > 0 && entry.count >= 0 && entry.price >= 0 && stock.Find(entry.entry) == null, "商品数值或重复条目");
                    stock.entries.Add(new ShopStockEntry(entry.entry, entry.item, entry.count, entry.price));
                }
                data.stocks.Add(stock);
            }
            return data;
        }
        internal void TakePrepared(ShopData source) { Clear(); stocks.AddRange(source.stocks); }
    }
    [Serializable] internal sealed class ShopEntrySave { public int entry, item, count, price; }
    [Serializable] internal sealed class ShopStockSave { public int merchant, site, npc, template, period; public ShopEntrySave[] entries; }
    public sealed partial class AdventureData { internal ShopData Shops { get; } = new ShopData(); }
}
