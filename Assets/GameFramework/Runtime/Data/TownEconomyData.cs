using System;
using System.Collections.Generic;
using System.Linq;

namespace ProjectY.Data
{
    // Configured once from the source tables; mutable gameplay state lives below.
    public sealed class EconomyRules
    {
        public int foodBase, foodLevelStep, wageBase, wagePerLevel, animalFoodBase;
        public int termDays, investmentLimit, maximumLossPercent, maximumGainPercent;
        public int historyDays, marketTarget, marketCapacity;
        public double sellMultiplier, hungerPenalty, debtPenalty, maximumPenalty;
        public int[] foodItems;
        public void Validate()
        {
            if(foodBase<1 || foodLevelStep<1 || wageBase<0 || wagePerLevel<1 || animalFoodBase<1 || termDays<1 || termDays>365 ||
                investmentLimit<1 || maximumLossPercent<1 || maximumLossPercent>=100 || maximumGainPercent<1 || maximumGainPercent>100 ||
                historyDays<2 || historyDays>365 || marketTarget<10 || marketCapacity<marketTarget*2 ||
                !(sellMultiplier>0 && sellMultiplier<1) || !(maximumPenalty>0 && maximumPenalty<1) ||
                hungerPenalty<0 || debtPenalty<0 || foodItems==null || foodItems.Length==0 || foodItems.Any(id=>id<1) || foodItems.Distinct().Count()!=foodItems.Length)
                throw new ArgumentException("Invalid economy rules.");
        }
    }
    public sealed class CommodityStock
    {
        public int ItemId {get;internal set;}
        public int BasePrice {get;internal set;}
        public double Abundance {get;internal set;}
        public int Stock {get;internal set;}
    }
    public sealed class InvestmentCandle
    {
        public int Day {get;internal set;}
        public double Open {get;internal set;}
        public double High {get;internal set;}
        public double Low {get;internal set;}
        public double Close {get;internal set;}
    }
    public sealed class TownEconomy
    {
        internal readonly List<CommodityStock> goods=new List<CommodityStock>();
        internal readonly List<InvestmentCandle> candles=new List<InvestmentCandle>();
        public int SiteId {get;internal set;}
        public double TradeAccess {get;internal set;}
        public double NetValue {get;internal set;}=100;
        public double Business {get;internal set;}=1;
        public int Principal {get;internal set;}
        public double EntryValue {get;internal set;}
        public int StartTick {get;internal set;}
        public int DueTick {get;internal set;}
        public int Payout {get;internal set;}=-1;
        public int GoodCount=>goods.Count;
        public CommodityStock GetGoodAt(int index)=>goods[index];
        public CommodityStock FindGood(int item)=>goods.Find(row=>row.ItemId==item);
        public int CandleCount=>candles.Count;
        public InvestmentCandle GetCandleAt(int index)=>candles[index];
    }
    public sealed class UpkeepAccount
    {
        public int ActorId {get;internal set;}
        public int HungryDays {get;internal set;}
        public int Arrears {get;internal set;}
        public int DailyWage {get;internal set;}
    }
    public sealed class TownEconomyData
    {
        private readonly List<TownEconomy> towns=new List<TownEconomy>();
        private readonly List<UpkeepAccount> accounts=new List<UpkeepAccount>();
        private EconomyRules rules;
        public static TownEconomyData For(AdventureData data)=>data.Economy;
        public static TownEconomyData Prepared(PreparedCharacterSave data)=>data.Economy;
        public bool Initialized {get;private set;}
        public int LastTick {get;private set;}
        public int LastFoodUsed {get;private set;}
        public int LastWagesPaid {get;private set;}
        public int Revision {get;private set;}
        public int ActiveBankSite {get;private set;}
        public int ActiveBankFacility {get;private set;}
        public int TownCount=>towns.Count;
        public TownEconomy GetTownAt(int index)=>towns[index];
        public TownEconomy FindTown(int site)=>towns.Find(row=>row.SiteId==site);
        public int AccountCount=>accounts.Count;
        public UpkeepAccount GetAccountAt(int index)=>accounts[index];
        public UpkeepAccount FindAccount(int actor)=>accounts.Find(row=>row.ActorId==actor);
        public long TotalArrears=>accounts.Sum(row=>(long)row.Arrears);
        public void Configure(EconomyRules value) { value.Validate();rules=value; }
        private EconomyRules Rules=>rules??throw new InvalidOperationException("Economy rules were not configured.");
        public void Clear()
        {towns.Clear();accounts.Clear();Initialized=false;LastTick=LastFoodUsed=LastWagesPaid=0;ActiveBankSite=ActiveBankFacility=0;Revision++;}
        public void Initialize(double minutes)
        {
            if(Initialized || !WorldFactionsData.ValidTime(minutes))throw new InvalidOperationException("Invalid economy initialization.");
            LastTick=checked((int)Math.Floor(minutes/360));Initialized=true;Revision++;
        }
        public void AddTown(int site,double access,int[] items,int[] prices,double[] abundance)
        {
            if(!Initialized || site<1 || FindTown(site)!=null || !(access>=0 && access<=1) || items==null || prices==null || abundance==null ||
                items.Length==0 || items.Length!=prices.Length || items.Length!=abundance.Length || items.Distinct().Count()!=items.Length)
                throw new ArgumentException("Invalid town economy profile.");
            var town=new TownEconomy{SiteId=site,TradeAccess=access};
            for(int i=0;i<items.Length;i++)
            {
                if(items[i]<1 || prices[i]<1 || !(abundance[i]>=0 && abundance[i]<=1))throw new ArgumentException("Invalid commodity profile.");
                town.goods.Add(new CommodityStock{ItemId=items[i],BasePrice=prices[i],Abundance=abundance[i],Stock=Rules.marketTarget});
            }
            town.candles.Add(new InvestmentCandle{Day=LastTick/4+1,Open=100,High=100,Low=100,Close=100});
            towns.Add(town);Revision++;
        }
        public void OpenBank(int site,int facility)
        {
            if(ActiveBankSite!=0 || FindTown(site)==null || facility<1)throw new InvalidOperationException("Invalid bank session.");
            ActiveBankSite=site;ActiveBankFacility=facility;Revision++;
        }
        public void CloseBank() {if(ActiveBankSite!=0){ActiveBankSite=ActiveBankFacility=0;Revision++;}}
        public int Food(EquipmentData equipment)
        {
            long value=0;foreach(int id in Rules.foodItems)value+=equipment.CountItem(id);
            return (int)Math.Min(int.MaxValue,value);
        }
        public int UnitPrice(int site,int item,bool buy,int offset=0)
        {
            var town=FindTown(site)??throw new ArgumentException("Unknown economy town.");
            var good=town.FindGood(item)??throw new ArgumentException("Unknown commodity.");
            double supply=Math.Max(0,good.Stock+(buy?-offset:offset));
            double local=1.45-.85*good.Abundance;
            double scarcity=Math.Max(.65,Math.Min(1.9,1+(Rules.marketTarget-supply)/Rules.marketTarget*.55));
            double value=good.BasePrice*local*scarcity;
            return buy?Math.Max(1,(int)Math.Ceiling(value)):Math.Max(0,(int)Math.Floor(value*Rules.sellMultiplier));
        }
        public int Quote(int site,int item,int count,bool buy)
        {
            if(count<1 || count>10000)throw new ArgumentOutOfRangeException(nameof(count));
            long total=0;for(int i=0;i<count;i++)total+=UnitPrice(site,item,buy,i);
            return checked((int)total);
        }
        public string Trade(int site,int item,int count,bool buy,int revision,EquipmentData equipment,PlayerData player)
        {
            if(revision!=Revision)return "EconomyStale";
            var town=FindTown(site);var good=town?.FindGood(item);
            if(good==null || count<1 || count>10000)return "EconomyInvalid";
            int total=Quote(site,item,count,buy);
            if(buy)
            {
                if(good.Stock<count)return "EconomyStockMissing";
                if(player.Coins<total)return "EconomyCoinsMissing";
                if((long)equipment.CountItem(item)+count>int.MaxValue || !equipment.CanGrant(new[]{item},new[]{count},new[]{"material"}))return "EconomyBagFull";
                equipment.AddStack(item,count);good.Stock-=count;Revision++;
                if(!player.TrySpendCoins(total))throw new InvalidOperationException("Validated economy payment failed.");
            }
            else
            {
                if(equipment.CountItem(item)<count)return "EconomyGoodsMissing";
                if(good.Stock>Rules.marketCapacity-count)return "EconomyWarehouseFull";
                if((long)player.Coins+total>int.MaxValue)return "EconomyCoinLimit";
                equipment.ConsumeEconomyStack(item,count);good.Stock+=count;Revision++;player.AddCoins(total);
            }
            return "";
        }
        public void ExternalTrade(int site,int item,int count,bool buy)
        {
            var good=FindTown(site)?.FindGood(item)??throw new ArgumentException("Unknown commodity trade.");
            if(count<1)throw new ArgumentOutOfRangeException(nameof(count));
            good.Stock=(int)Math.Max(0,Math.Min(Rules.marketCapacity,(long)good.Stock+(buy?-count:count)));Revision++;
        }
        public string Invest(int principal,int revision,double minutes,PlayerData player)
        {
            if(revision!=Revision)return "EconomyStale";
            var town=FindTown(ActiveBankSite);
            if(town==null || principal<1 || principal>Rules.investmentLimit || !WorldFactionsData.ValidTime(minutes) || (int)Math.Floor(minutes/360)!=LastTick)return "EconomyInvalid";
            if(town.Principal>0)return "EconomyAlreadyInvested";
            if(player.Coins<principal)return "EconomyCoinsMissing";
            town.Principal=principal;town.EntryValue=town.NetValue;town.StartTick=LastTick;
            town.DueTick=checked((int)Math.Ceiling(minutes/360)+Rules.termDays*4);town.Payout=-1;Revision++;
            if(!player.TrySpendCoins(principal))throw new InvalidOperationException("Validated bank payment failed.");
            return "";
        }
        public string Claim(int revision,PlayerData player)
        {
            if(revision!=Revision)return "EconomyStale";
            var town=FindTown(ActiveBankSite);
            if(town==null || town.Principal==0 || town.Payout<0)return "EconomyNotMature";
            int payout=town.Payout;if((long)player.Coins+payout>int.MaxValue)return "EconomyCoinLimit";
            town.Principal=0;town.EntryValue=0;town.StartTick=town.DueTick=0;town.Payout=-1;Revision++;player.AddCoins(payout);return "";
        }
        public string PayArrears(int revision,PlayerData player)
        {
            if(revision!=Revision)return "EconomyStale";
            int paid=0,budget=player.Coins;
            foreach(var row in accounts){int amount=Math.Min(row.Arrears,budget);row.Arrears-=amount;budget-=amount;paid+=amount;}
            if(paid==0)return TotalArrears==0?"EconomyNoDebt":"EconomyCoinsMissing";
            Revision++;if(!player.TrySpendCoins(paid))throw new InvalidOperationException("Validated wage payment failed.");return "";
        }
        public double Penalty(int actor)
        {
            var account=FindAccount(actor);if(account==null)return 0;
            double unpaid=account.DailyWage==0?0:(double)account.Arrears/account.DailyWage;
            return Math.Min(Rules.maximumPenalty,account.HungryDays*Rules.hungerPenalty+unpaid*Rules.debtPenalty);
        }
        // Every elapsed six-hour boundary is processed in order, independent of frame size and UI visits.
        public void Step(int tick,uint seed,int[] closedSites,int[] actors,int[] food,int[] wages,EquipmentData equipment,PlayerData player)
        {
            if(!Initialized || tick!=LastTick+1 || actors.Length!=food.Length || actors.Length!=wages.Length || actors.Distinct().Count()!=actors.Length ||
                actors.Any(id=>id<1) || food.Any(n=>n<0) || wages.Any(n=>n<0))throw new ArgumentException("Invalid economy step.");
            var closed=new HashSet<int>(closedSites);
            foreach(var town in towns)
            {
                bool blocked=closed.Contains(town.SiteId);
                double availability=0;
                foreach(var good in town.goods)
                {
                    double production=blocked?0:2+good.Abundance*6;
                    double imports=blocked?0:town.TradeAccess*Math.Max(0,Rules.marketTarget-good.Stock)*.07;
                    double drift=(Rules.marketTarget-good.Stock)*.08;
                    good.Stock=Math.Max(0,Math.Min(Rules.marketCapacity,good.Stock+(int)Math.Round(production-4+imports+drift)));
                    availability+=Math.Min(1,(double)good.Stock/Rules.marketTarget);
                }
                town.Business=availability/town.GoodCount;
                uint hash=unchecked(seed^(uint)town.SiteId*2654435761u^(uint)tick*2246822519u);
                hash^=hash>>16;hash*=3266489917u;hash^=hash>>15;
                double noise=((hash%20001)/10000.0-1)*.018;
                double operating=(town.Business-.7)*.012+(town.TradeAccess-.5)*.003-(blocked?.018:0);
                double reversion=(100-town.NetValue)/100*.004;
                town.NetValue=Math.Round(Math.Max(20,Math.Min(500,town.NetValue*(1+operating+noise+reversion))),4);
                int day=(tick-1)/4+1;var candle=town.candles[town.candles.Count-1];
                if(candle.Day!=day)
                {
                    candle=new InvestmentCandle{Day=day,Open=candle.Close,High=candle.Close,Low=candle.Close,Close=candle.Close};town.candles.Add(candle);
                    if(town.candles.Count>Rules.historyDays)town.candles.RemoveAt(0);
                }
                candle.Close=town.NetValue;candle.High=Math.Max(candle.High,candle.Close);candle.Low=Math.Min(candle.Low,candle.Close);
                if(town.Principal>0 && town.Payout<0 && tick>=town.DueTick)
                {
                    double ratio=Math.Max(1-Rules.maximumLossPercent/100.0,Math.Min(1+Rules.maximumGainPercent/100.0,town.NetValue/town.EntryValue));
                    town.Payout=checked((int)Math.Floor(town.Principal*ratio));
                }
            }
            LastTick=tick;Revision++;
            if(tick%4==0)SettleUpkeep(actors,food,wages,equipment,player);
        }
        private void SettleUpkeep(int[] actors,int[] food,int[] wages,EquipmentData equipment,PlayerData player)
        {
            int paid=0,used=0,budget=player.Coins;
            for(int i=0;i<actors.Length;i++)
            {
                var account=FindAccount(actors[i]);if(account==null){account=new UpkeepAccount{ActorId=actors[i]};accounts.Add(account);}
                int remaining=food[i];
                foreach(int id in Rules.foodItems)
                {
                    int amount=Math.Min(remaining,equipment.CountItem(id));
                    if(amount>0){equipment.ConsumeEconomyStack(id,amount);remaining-=amount;used+=amount;}
                }
                account.HungryDays=remaining==0?Math.Max(0,account.HungryDays-1):Math.Min(30,account.HungryDays+1);
                account.DailyWage=wages[i];account.Arrears=checked(account.Arrears+wages[i]);
                int payment=Math.Min(budget,account.Arrears);account.Arrears-=payment;budget-=payment;paid+=payment;
            }
            LastFoodUsed=used;LastWagesPaid=paid;Revision++;
            if(paid>0 && !player.TrySpendCoins(paid))throw new InvalidOperationException("Validated upkeep payment failed.");
        }
        internal EconomySave Capture()=>new EconomySave{initialized=Initialized,lastTick=LastTick,lastFood=LastFoodUsed,lastWages=LastWagesPaid,
            accounts=accounts.Select(a=>new UpkeepSave{actor=a.ActorId,hunger=a.HungryDays,debt=a.Arrears,wage=a.DailyWage}).ToArray(),
            towns=towns.Select(t=>new TownEconomySave{site=t.SiteId,access=t.TradeAccess,net=t.NetValue,business=t.Business,principal=t.Principal,entry=t.EntryValue,start=t.StartTick,due=t.DueTick,payout=t.Payout,
                goods=t.goods.Select(g=>new CommoditySave{item=g.ItemId,price=g.BasePrice,abundance=g.Abundance,stock=g.Stock}).ToArray(),
                candles=t.candles.Select(c=>new CandleSave{day=c.Day,open=c.Open,high=c.High,low=c.Low,close=c.Close}).ToArray()}).ToArray()};
        internal static TownEconomyData Prepare(EconomySave saved,double minutes)
        {
            SaveCheck.Require(saved!=null && saved.lastTick>=0 && saved.lastTick<=Math.Floor(minutes/360) && saved.lastFood>=0 && saved.lastWages>=0,"economy.clock");
            var data=new TownEconomyData{Initialized=saved.initialized,LastTick=saved.lastTick,LastFoodUsed=saved.lastFood,LastWagesPaid=saved.lastWages};
            foreach(var a in SaveCheck.Rows(saved.accounts,10000,"economy.accounts"))
            {
                SaveCheck.Require(a!=null && a.actor>0 && a.hunger>=0 && a.hunger<=30 && a.debt>=0 && a.wage>=0 && data.FindAccount(a.actor)==null,"economy.account");
                data.accounts.Add(new UpkeepAccount{ActorId=a.actor,HungryDays=a.hunger,Arrears=a.debt,DailyWage=a.wage});
            }
            foreach(var t in SaveCheck.Rows(saved.towns,1000,"economy.towns"))
            {
                SaveCheck.Require(t!=null && t.site>0 && data.FindTown(t.site)==null && t.access>=0 && t.access<=1 && ValidPrice(t.net) && t.business>=0 && t.business<=1 && t.principal>=0,"economy.town");
                SaveCheck.Require(t.principal==0?t.entry==0 && t.start==0 && t.due==0 && t.payout==-1:
                    ValidPrice(t.entry) && t.start>=0 && t.start<=saved.lastTick && t.due>t.start && (t.payout==-1?saved.lastTick<t.due:saved.lastTick>=t.due && t.payout>=0),"economy.investment");
                var town=new TownEconomy{SiteId=t.site,TradeAccess=t.access,NetValue=t.net,Business=t.business,Principal=t.principal,EntryValue=t.entry,StartTick=t.start,DueTick=t.due,Payout=t.payout};
                foreach(var g in SaveCheck.Rows(t.goods,64,"economy.goods"))
                {
                    SaveCheck.Require(g!=null && g.item>0 && g.price>0 && g.abundance>=0 && g.abundance<=1 && g.stock>=0 && town.FindGood(g.item)==null,"economy.good");
                    town.goods.Add(new CommodityStock{ItemId=g.item,BasePrice=g.price,Abundance=g.abundance,Stock=g.stock});
                }
                int prior=0;double previous=0;
                foreach(var c in SaveCheck.Rows(t.candles,365,"economy.candles"))
                {
                    SaveCheck.Require(c!=null && c.day>prior && (prior==0 || c.day==prior+1 && c.open==previous) && c.day<=saved.lastTick/4+1 &&
                        ValidPrice(c.open) && ValidPrice(c.close) && ValidPrice(c.high) && ValidPrice(c.low) && c.low<=Math.Min(c.open,c.close) && c.high>=Math.Max(c.open,c.close),"economy.candle");
                    town.candles.Add(new InvestmentCandle{Day=c.day,Open=c.open,High=c.high,Low=c.low,Close=c.close});prior=c.day;previous=c.close;
                }
                SaveCheck.Require(town.goods.Count>0 && town.candles.Count>0 && previous==town.NetValue,"economy.history");data.towns.Add(town);
            }
            SaveCheck.Require(saved.initialized || data.towns.Count==0 && data.accounts.Count==0,"economy.initialized");return data;
        }
        private static bool ValidPrice(double n)=>n>=20 && n<=500;
        internal void TakePrepared(TownEconomyData source)
        {Clear();Initialized=source.Initialized;LastTick=source.LastTick;LastFoodUsed=source.LastFoodUsed;LastWagesPaid=source.LastWagesPaid;towns.AddRange(source.towns);accounts.AddRange(source.accounts);}
    }
    [Serializable] internal sealed class EconomySave {public bool initialized;public int lastTick,lastFood,lastWages;public TownEconomySave[] towns;public UpkeepSave[] accounts;}
    [Serializable] internal sealed class UpkeepSave {public int actor,hunger,debt,wage;}
    [Serializable] internal sealed class CommoditySave {public int item,price,stock;public double abundance;}
    [Serializable] internal sealed class CandleSave {public int day;public double open,high,low,close;}
    [Serializable] internal sealed class TownEconomySave {public int site,principal,start,due,payout;public double access,net,business,entry;public CommoditySave[] goods;public CandleSave[] candles;}
    public sealed partial class AdventureData {internal TownEconomyData Economy {get;}=new TownEconomyData();}
    public sealed partial class EquipmentData {internal void ConsumeEconomyStack(int item,int count){ConsumeStackRows(item,count);Revision++;}}
}
