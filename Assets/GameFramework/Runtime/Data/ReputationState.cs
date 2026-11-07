using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;

namespace ProjectY.Data
{
    [Serializable] internal sealed class ReputationSave
    {
        public int format, balance;
        public string[] settlements;
    }

    /// <summary>Campaign currency and receipts; reward amounts are supplied by the Lua rules.</summary>
    public static class ReputationState
    {
        public static int Balance(AdventureData data) => State(data).Balance;
        public static int Revision(AdventureData data) => State(data).Revision;
        public static void BeginBattle(AdventureData data) => State(data).BeginBattle();
        public static bool AwardKill(AdventureData data,int targetId,int amount) => State(data).AwardKill(targetId,amount);
        public static bool AwardSettlement(AdventureData data,string kind,int id,int amount) => State(data).AwardSettlement(kind,id,amount);
        private static ReputationData State(AdventureData data) => (data ?? throw new ArgumentNullException(nameof(data))).Reputation;
    }

    internal sealed class ReputationData
    {
        private readonly HashSet<int> battleKills = new HashSet<int>();
        private readonly HashSet<string> settlements = new HashSet<string>(StringComparer.Ordinal);
        internal int Balance { get; private set; }
        internal int Revision { get; private set; }
        internal void BeginBattle() => battleKills.Clear();
        internal bool AwardKill(int targetId,int amount)
        {
            if(targetId<=0 || amount<=0)throw new ArgumentOutOfRangeException(nameof(targetId));
            if(battleKills.Contains(targetId))return false;
            int next=checked(Balance+amount);
            battleKills.Add(targetId);Balance=next;Revision++;return true;
        }
        internal bool AwardSettlement(string kind,int id,int amount)
        {
            if((kind!="mission" && kind!="town") || id<=0 || amount<=0)throw new ArgumentException("Invalid reputation settlement.");
            string key=kind+":"+id.ToString(CultureInfo.InvariantCulture);
            if(settlements.Contains(key))return false;
            int next=checked(Balance+amount);
            settlements.Add(key);Balance=next;Revision++;return true;
        }
        internal bool TrySpend(int amount)
        {
            if(amount<=0)throw new ArgumentOutOfRangeException(nameof(amount));
            if(Balance<amount)return false;
            Balance-=amount;Revision++;return true;
        }
        internal void Clear()
        { Balance=0;settlements.Clear();battleKills.Clear();Revision++; }
        internal ReputationSave Capture() => new ReputationSave
        { format=1,balance=Balance,settlements=settlements.OrderBy(value=>value,StringComparer.Ordinal).ToArray() };
        internal static ReputationData Prepare(ReputationSave saved)
        {
            SaveCheck.Require(saved!=null && saved.format==1 && saved.balance>=0,"reputation.format");
            var result=new ReputationData();
            foreach(string receipt in SaveCheck.Rows(saved.settlements,100000,"reputation.settlements"))
            {
                var parts=receipt?.Split(':');
                SaveCheck.Require(parts!=null && parts.Length==2 && (parts[0]=="mission" || parts[0]=="town")
                    && int.TryParse(parts[1],NumberStyles.None,CultureInfo.InvariantCulture,out int id) && id>0
                    && parts[1]==id.ToString(CultureInfo.InvariantCulture) && result.settlements.Add(receipt),"reputation.settlement");
            }
            result.Balance=saved.balance;return result;
        }
        internal void TakePrepared(ReputationData prepared)
        {
            Balance=prepared.Balance;settlements.Clear();settlements.UnionWith(prepared.settlements);
            battleKills.Clear();Revision++;
        }
    }

    public sealed partial class AdventureData
    {
        internal readonly ReputationData Reputation = new ReputationData();
    }
}
