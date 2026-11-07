using System;
using System.Linq;

namespace ProjectY.Data
{
    /// <summary>Reflection bridge. Relationship state belongs to PartyStoryData; Lua owns event rules and text.</summary>
    public static class PartyRelationshipState
    {
        public static int Grievance(PartyStoryData data,int a,int b) => data.Find(a,b)?.Grievance ?? 0;
        public static int Support(PartyStoryData data,int a,int b) => data.Find(a,b)?.Support ?? 0;
        public static int Cooperation(PartyStoryData data,int a,int b) => data.Find(a,b)?.Cooperation ?? 0;
        public static int FriendlyHits(PartyStoryData data,int a,int b) => data.Find(a,b)?.FriendlyHits ?? 0;
        public static int SocialDay(PartyStoryData data,int a,int b) => data.Find(a,b)?.SocialDay ?? 0;
        public static bool Romance(PartyStoryData data,int a,int b) => data.Find(a,b)?.Romance ?? false;
        public static bool HasRomance(PartyStoryData data,int actor)
        {
            for(int i=0;i<data.BondCount;i++)
            { var row=data.GetBondAt(i);if(row.Romance && (row.FirstActorId==actor || row.SecondActorId==actor))return true; }
            return false;
        }
        private static string Key(int a,int b,string kind) => PartyStoryData.PairKey(a,b)+":"+kind;
        public static int Count(PartyStoryData data,int a,int b,string kind) => data.interactions.TryGetValue(Key(a,b,kind),out int value)?value:0;
        private static void CheckBattle(PartyStoryData data,int a,int b)
        {
            if(!data.battleOpen || a==b || !data.IsParticipant(a) || !data.IsParticipant(b))
                throw new InvalidOperationException("Relationship event is outside the current party battle.");
        }
        private static void Change(PartyStoryData data,PartyBondData row,int amount,int grievance)
        {
            if(amount < -100 || amount>100 || grievance < -100 || grievance>100)throw new ArgumentOutOfRangeException(nameof(amount));
            row.Score=Math.Max(-100,Math.Min(100,row.Score+amount));
            row.Grievance=Math.Max(0,Math.Min(100,row.Grievance+grievance));data.Touch();
        }
        public static bool Interact(PartyStoryData data,int a,int b,string kind,int amount,int grievance,int limit)
        {
            CheckBattle(data,a,b);
            if(kind!="heal" && kind!="cooperate" && kind!="harm")throw new ArgumentException("Unknown relationship event.");
            if(limit<1 || limit>1000000 || (kind=="harm"?amount>=0:amount<=0))throw new ArgumentOutOfRangeException(nameof(amount));
            int count=Count(data,a,b,kind);
            if(count>=limit || (kind!="harm" && Count(data,a,b,"harm")>0))return false;
            string roundKey="cooperate_round:"+data.attackRound;
            if(kind=="cooperate" && Count(data,a,b,roundKey)>0)return false;
            var row=data.GetOrAdd(a,b);Change(data,row,amount,grievance);
            data.interactions[Key(a,b,kind)]=count+1;
            if(kind=="cooperate")data.interactions[Key(a,b,roundKey)]=1;
            if(kind=="heal")row.Support=Math.Min(1000000,row.Support+1);
            else if(kind=="cooperate")row.Cooperation=Math.Min(1000000,row.Cooperation+1);
            else row.FriendlyHits=Math.Min(1000000,row.FriendlyHits+1);
            return true;
        }
        public static int FriendlyDebt(PartyStoryData data,int target) => data.friendlyDamage.TryGetValue(target,out int value)?value:0;
        public static void AddFriendlyDamage(PartyStoryData data,int target,int amount)
        {
            if(!data.battleOpen || !data.IsParticipant(target) || amount<0)throw new ArgumentException("Invalid friendly damage debt.");
            data.friendlyDamage[target]=(int)Math.Min(int.MaxValue,(long)FriendlyDebt(data,target)+amount);
        }
        public static int CreditHealing(PartyStoryData data,int target,int amount)
        {
            if(!data.battleOpen || !data.IsParticipant(target) || amount<0)throw new ArgumentException("Invalid healing receipt.");
            int paid=Math.Min(amount,FriendlyDebt(data,target));data.friendlyDamage[target]=FriendlyDebt(data,target)-paid;return amount-paid;
        }
        // Only direct attacks call this. The caller checks that target is an enemy and damage was real.
        public static int[] AttackPartners(PartyStoryData data,int source,int target,int round)
        {
            if(!data.battleOpen || !data.IsParticipant(source) || target<=0 || round<1)throw new ArgumentException("Invalid cooperation receipt.");
            if(data.attackRound!=round){data.attackers.Clear();data.attackRound=round;}
            if(!data.attackers.TryGetValue(target,out var attackers))
            { attackers=new System.Collections.Generic.HashSet<int>();data.attackers.Add(target,attackers); }
            if(!attackers.Add(source))return Array.Empty<int>();
            return attackers.Where(id=>id!=source).OrderBy(id=>id).ToArray();
        }
        public static bool Social(PartyStoryData data,int a,int b,int day,int amount,int grievance)
        {
            if(data.battleOpen || day<1)throw new InvalidOperationException("Invalid relationship conversation.");
            var row=data.GetOrAdd(a,b);if(day<=row.SocialDay)return false;
            Change(data,row,amount,grievance);row.SocialDay=day;return true;
        }
        public static void SetRomance(PartyStoryData data,int a,int b,bool value)
        {
            if(data.battleOpen)throw new InvalidOperationException("Cannot change romance during combat.");
            var row=data.GetOrAdd(a,b);
            if(row.Romance==value)throw new InvalidOperationException("Relationship has not changed.");
            if(value && (HasRomance(data,a) || HasRomance(data,b)))throw new InvalidOperationException("An actor already has a partner.");
            row.Romance=value;data.Touch();
        }
    }
}
