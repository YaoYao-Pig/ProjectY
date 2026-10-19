using System;
using System.Collections.Generic;
using System.Linq;

namespace ProjectY.Data
{
    /// <summary>One visible world party. Routes and cargo have a single persistent owner.</summary>
    public sealed class WorldPartyData
    {
        public int Id { get; internal set; }
        public int DefinitionId { get; internal set; }
        public int HomeSiteId { get; internal set; }
        public int DestinationSiteId { get; private set; }
        public int BattleSiteId { get; internal set; }
        public bool Defeated { get; internal set; }
        public bool Chasing { get; private set; }
        public double SafeUntil { get; internal set; }
        public WorldTravelData Travel { get; internal set; } = new WorldTravelData();
        public MapAreaLootData Cargo { get; internal set; }
        public int CargoCount => Cargo?.SearchItems.Length ?? 0;
        public LootItemData GetCargoAt(int index) => Cargo.SearchItems[index];
        public void SetDestination(int site) { if(site<0)throw new ArgumentOutOfRangeException(nameof(site));DestinationSiteId=site; }
        public void SetChasing(bool value) => Chasing=value;
        public void SetCargo(string name,int[] items,int[] counts,string[] kinds,int[] widths,int[] heights)
        {
            if(Defeated || BattleSiteId!=0)throw new InvalidOperationException("Cannot restock a defeated or engaged caravan.");
            Cargo=new MapAreaLootData(1,1,102,name,items,counts);
            Cargo.PrepareSearch(kinds,widths,heights);
            foreach(var item in Cargo.SearchItems){item.Revealed=true;item.Progress=1;}
        }
        internal WorldPartySave Capture() => new WorldPartySave {id=Id,definition=DefinitionId,home=HomeSiteId,destination=DestinationSiteId,
            battle=BattleSiteId,defeated=Defeated,chasing=Chasing,safeUntil=SafeUntil,travel=Travel.Capture(),hasCargo=Cargo!=null,cargo=Cargo?.Capture()};
    }

    public sealed class WorldPartiesData
    {
        private readonly List<WorldPartyData> parties=new List<WorldPartyData>();
        public static WorldPartiesData For(AdventureData adventure)=>adventure.WorldParties;
        public static WorldPartiesData Prepared(PreparedCharacterSave save)=>save.PreparedWorldParties;
        public bool Initialized { get; private set; }
        public int Count=>parties.Count;
        public int Revision { get; private set; }
        public int TargetId { get; private set; }
        public int ContactId { get; private set; }
        public bool Trading { get; private set; }
        public bool IsOpen=>ContactId!=0;
        public double Clock { get; private set; }
        public double Remainder { get; private set; }
        public WorldPartyData GetAt(int index)=>parties[index];
        public WorldPartyData Find(int id)=>parties.Find(p=>p.Id==id);
        public void Clear(){parties.Clear();Initialized=false;Clock=Remainder=0;TargetId=ContactId=0;Trading=false;Revision++;}
        public WorldPartyData Add(int definition,int q,int r,int home,uint seed)
        {
            if(Initialized || definition<1 || home<0)throw new InvalidOperationException("Invalid world party initialization.");
            var party=new WorldPartyData{Id=parties.Count+1,DefinitionId=definition,HomeSiteId=home};
            party.Travel.Reset(seed,q,r,1);parties.Add(party);return party;
        }
        public void Complete(double minutes){CheckTime(minutes);Clock=minutes;Initialized=true;Revision++;}
        private static void CheckTime(double value){if(double.IsNaN(value)||double.IsInfinity(value)||value<0)throw new ArgumentOutOfRangeException(nameof(value));}
        // Whole game-minute simulation boundaries are independent of render frame size and travel speed.
        public int ElapsedTicks(double now)
        {
            CheckTime(now);if(now<Clock)throw new InvalidOperationException("World clock moved backwards.");
            double elapsed=Remainder+now-Clock;int ticks=checked((int)Math.Floor(elapsed+1e-8));
            Remainder=Math.Max(0,elapsed-ticks);Clock=now;return ticks;
        }
        public void Target(int id){if(id!=0 && (Find(id)==null || Find(id).Defeated))throw new ArgumentException("Unknown world party.");TargetId=id;Revision++;}
        public void Open(int id)
        {
            var party=Find(id);if(IsOpen || party==null || party.Defeated)throw new InvalidOperationException("Invalid world party contact.");
            ContactId=id;TargetId=0;Trading=false;Revision++;
        }
        public void Trade(){if(!IsOpen || Find(ContactId).Cargo==null)throw new InvalidOperationException("This party has no cargo.");Trading=true;Revision++;}
        public void Close(){ContactId=0;Trading=false;Revision++;}
        public void BeginBattle(int id,int site)
        {
            var party=Find(id);if(party==null || party.Defeated || site<1)throw new InvalidOperationException("Invalid world party battle.");
            party.BattleSiteId=site;party.SetChasing(false);Close();TargetId=0;party.Travel.SetPaused(true);Revision++;
        }
        public void Settle(int site,bool victory,double safeUntil)
        {
            CheckTime(safeUntil);var party=parties.Find(p=>p.BattleSiteId==site && !p.Defeated);
            if(party==null)return;party.Defeated=victory;party.SafeUntil=safeUntil;Revision++;
        }
        private string Session(int revision)
        {return !Trading?"请先与商队交易":revision!=Revision?"交易列表已变化，请重新选择":"";}
        public string Buy(int index,int revision,int price,EquipmentData equipment,PlayerData player,int ammo,int capacity,int rounds)
        {
            string reason=Session(revision);if(reason!="")return reason;
            var party=Find(ContactId);
            if(index<0 || index>=party.CargoCount || price<0)return "无效商品";
            var item=party.GetCargoAt(index);if(item.Count==0)return "商品已经售罄";
            if(player.Coins<price)return "金币不足";
            if(item.IsStack && equipment.CountItem(item.ItemId)==int.MaxValue)return "物品数量已达上限";
            var place=equipment.Grid.SpaceFor(item.ItemId,item.IsStack);if(place==null)return "背包空间不足，请先整理背包";
            // One physical item / one unit of a stack. Stored equipment retains its exact identity.
            int previous=item.Count;item.Count=1;
            bool received;
            try{received=equipment.ReceiveLoot(item,place.X,place.Y,place.Rotated,ammo,capacity,rounds);}
            finally{item.Count=previous;}
            if(!received)return "背包空间不足";
            item.Count--;if(item.Count==0){item.ReleaseStored();party.Cargo.SearchGrid.Remove(item.Key);}
            Revision++;if(!player.TrySpendCoins(price))throw new InvalidOperationException("Validated caravan payment failed.");return "";
        }
        public string Sell(int inventoryIndex,int revision,int inventoryRevision,int unitPrice,EquipmentData equipment,PlayerData player)
        {
            string reason=Session(revision);if(reason!="")return reason;
            if(inventoryRevision!=equipment.Revision)return "背包已变化，请重新选择";
            if(inventoryIndex<0 || inventoryIndex>=equipment.Grid.Count || unitPrice<0)return "无效出售物品";
            var place=equipment.Grid.GetAt(inventoryIndex);var cargo=Find(ContactId).Cargo;
            var item=equipment.PreviewLootDeposit(cargo,place.Key);
            if(item==null)return "物品已不在背包中";
            long price=(long)unitPrice*item.Count;if(price+player.Coins>int.MaxValue)return "金币数量已达上限";
            cargo.SearchGrid.CopyShape(equipment.Grid,item.ItemId);
            if(!cargo.SearchGrid.Exchange(Array.Empty<string>(),new[]{item.Key},new[]{item.ItemId},false))return "商队货舱已满";
            equipment.CommitLootDeposit(place.Key,item);
            if(!cargo.SearchGrid.Exchange(Array.Empty<string>(),new[]{item.Key},new[]{item.ItemId},true))throw new InvalidOperationException("Validated cargo placement failed.");
            cargo.AddSearchItem(item);Revision++;player.AddCoins((int)price);return "";
        }
        public int DropCargo(int site,MapAreaStateData area,int cell)
        {
            var party=parties.Find(p=>p.BattleSiteId==site && !p.Defeated);
            if(party?.Cargo==null)return 0;
            var source=party.Cargo;
            if(!source.SearchItems.Any(item=>item.Count>0)){party.Cargo=null;return 0;}
            area.AddLoot(cell,102,source.Name,Array.Empty<int>(),Array.Empty<int>(),true);
            var target=area.GetLootAt(area.LootCount-1);target.PrepareSearch(Array.Empty<string>(),Array.Empty<int>(),Array.Empty<int>());
            // Transfer the complete physical cargo, including items sold by the player, exactly once.
            source.SearchGrid.CopyDefinitionsTo(target.SearchGrid);
            target.SearchGrid.Configure(6,source.SearchGrid.Height);
            foreach(var old in source.SearchItems.Where(item=>item.Count>0))
            {
                var next=new LootItemData(target,target.SearchItems.Length,target.SourceIndexFor(old.ItemId),old.ItemId,old.Count,old.Kind)
                {StoredWeapon=old.StoredWeapon,StoredWearable=old.StoredWearable,StoredMagazine=old.StoredMagazine,LoadedMagazine=old.LoadedMagazine};
                if(!target.SearchGrid.Exchange(Array.Empty<string>(),new[]{next.Key},new[]{next.ItemId},true))throw new InvalidOperationException("Cargo no longer fits its original capacity.");
                target.AddSearchItem(next);
            }
            party.Cargo=null;Revision++;return 1;
        }
        internal WorldPartiesSave Capture()=>new WorldPartiesSave{initialized=Initialized,clock=Clock,remainder=Remainder,parties=parties.Select(p=>p.Capture()).ToArray()};
        internal static WorldPartiesData Prepare(WorldPartiesSave save,EquipmentData equipment,HashSet<int> itemIds)
        {
            var result=new WorldPartiesData();if(save==null)return result; // Explicit pre-v12 migration.
            SaveCheck.Require(save.initialized && save.clock>=0 && !double.IsNaN(save.clock) && !double.IsInfinity(save.clock) && save.remainder>=0 && save.remainder<1,"大地图队伍时钟");
            result.Initialized=true;result.Clock=save.clock;result.Remainder=save.remainder;
            foreach(var row in SaveCheck.Rows(save.parties,256,"大地图队伍"))
            {
                SaveCheck.Require(row!=null && row.id==result.Count+1 && row.definition>0 && row.home>=0 && row.destination>=0 && row.battle>=0 && row.safeUntil>=0 && !double.IsNaN(row.safeUntil) && !double.IsInfinity(row.safeUntil),"大地图队伍身份");
                var party=new WorldPartyData{Id=row.id,DefinitionId=row.definition,HomeSiteId=row.home,BattleSiteId=row.battle,Defeated=row.defeated,SafeUntil=row.safeUntil,Travel=WorldTravelData.Prepare(row.travel)};
                party.SetDestination(row.destination);party.SetChasing(row.chasing);party.Travel.SetPaused(row.battle>0);
                if(row.hasCargo){SaveCheck.Require(!row.defeated,"已击败商队仍有货物");party.Cargo=MapAreaLootData.Prepare(row.cargo,1,1,equipment,itemIds);SaveCheck.Require(party.Cargo.SearchItems!=null,"商队货物未初始化");}
                result.parties.Add(party);
            }
            return result;
        }
        internal void TakePrepared(WorldPartiesData source){Clear();parties.AddRange(source.parties);Initialized=source.Initialized;Clock=source.Clock;Remainder=source.Remainder;Revision++;}
    }
    [Serializable] internal sealed class WorldPartiesSave {public bool initialized;public double clock,remainder;public WorldPartySave[] parties;}
    [Serializable] internal sealed class WorldPartySave {public int id,definition,home,destination,battle;public bool defeated,chasing,hasCargo;public double safeUntil;public TravelSave travel;public ContainerSave cargo;}
    public sealed partial class AdventureData {internal WorldPartiesData WorldParties {get;}=new WorldPartiesData();}
    public sealed partial class InventoryGridData {internal InventoryPlacementData SpaceFor(int item,bool stack)
        {
            if(stack){var existing=placements.Find(p=>p.ItemId==item && (p.Key[0]=='s' || p.Key[0]=='p'));if(existing!=null)return existing;}
            return AutoPlace(placements,"__incoming",item,null);
        }}
}
